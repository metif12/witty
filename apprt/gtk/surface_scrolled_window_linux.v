@[has_globals]
module gtk

// surface_scrolled_window_linux.v - The GObject SurfaceScrolledWindow widget
// class for the GTK apprt.
//
// Translated from ghostty/src/apprt/gtk/class/surface_scrolled_window.zig.
//
// A wrapper widget that embeds a Surface inside a GtkScrolledWindow to provide
// scrollbar functionality for the terminal surface. The embedded surface can be
// set during initialization or changed dynamically via the `surface` property.
// It also carries a `config` property (bound from the surface) that drives the
// scrollbar policy.
//
// The GObject class registration (ghostty's `gobject.ext.defineClass`), the
// blueprint template with its scrollbar_policy/notify_surface callbacks, and
// the `config` / `surface` properties are hand-expanded onto the raw GObject/
// GTK C API below (there are no signals). The real logic (swapping the
// scrolled-window child, the config->scrollbar-policy mapping, config
// refcounting) is translated. The class is additionally modeled as a plain V
// struct wrapping the GObject/GtkWidget ptr for callers in V.
//
// Reuses: `Config` (config_class_linux.v), `SurfaceWidget`
// (surface_class_linux.v — the GObject `Surface` in Zig), `GtkWidget`
// (c_gtk_linux.v). GtkWidget parent helpers are declared in
// search_overlay_linux.v.
import configpkg as _

// --- New C bindings unique to this file -----------------------------------

// GtkScrolledWindow*.
pub type GtkScrolledWindow = voidptr

fn C.gtk_scrolled_window_set_child(sw GtkScrolledWindow, child GtkWidget)

// --- PolicyType -----------------------------------------------------------

// PolicyType mirrors gtk.PolicyType (the scrollbar display policy).
pub enum PolicyType {
	always
	automatic
	never
	external
}

// --- SurfaceScrolledWindow ------------------------------------------------

// SurfaceScrolledWindow is the V model of the `GhostttySurfaceScrolledWindow`
// GObject class. Fields mirror the Zig `Private` struct. The GObject binding
// object is out of scope, so `config_binding` is not modeled; config is bound
// eagerly instead (see set_surface).
@[heap]
pub struct SurfaceScrolledWindow {

	// The GtkWidget (adw.Bin) pointer for this instance.
pub mut:
	widget GtkWidget = unsafe { nil }

	// The configuration this widget uses. nil means "unset".
	config &Config = unsafe { nil }

	// The embedded surface widget. nil means "unset".
	surface &SurfaceWidget = unsafe { nil }
}

// new_surface_scrolled_window creates a new SurfaceScrolledWindow. Mirrors
// `gobject.ext.newInstance` + the instance `init` (which just runs the
// template).
pub fn new_surface_scrolled_window() &SurfaceScrolledWindow {
	obj := C.g_object_new(surface_scrolled_window_get_type(), &char(unsafe { nil }))
	return &SurfaceScrolledWindow{
		widget: obj
	}
}

// get_surface returns the embedded surface widget. Mirrors `getSurface`.
pub fn (self &SurfaceScrolledWindow) get_surface() &SurfaceWidget {
	return self.surface
}

// set_surface sets the embedded surface widget and re-parents it into the
// scrolled window, rebinding the config. Mirrors `setSurface` + `propSurface`.
pub fn (mut self SurfaceScrolledWindow) set_surface(surface &SurfaceWidget) {
	if surface == self.surface {
		return
	}

	// freezeNotify / notifyByPspec(properties.surface) / thawNotify.
	if !isnil(self.widget) {
		C.g_object_freeze_notify(self.widget)
		C.g_object_notify_by_pspec(self.widget, g_surface_scrolled_window_pspec_surface)
	}
	self.surface = surface

	// Re-parent: put the new surface's widget into the scrolled window, which is
	// this widget's (AdwBin's) single template child. Mirrors
	// `self.as(Parent).getChild()` cast to a gtk.ScrolledWindow, then setChild.
	scrolled_window := if !isnil(self.widget) {
		C.adw_bin_get_child(self.widget)
	} else {
		GtkWidget(unsafe { nil })
	}
	child := if !isnil(self.surface) { self.surface.as_widget() } else { GtkWidget(unsafe { nil }) }
	if !isnil(scrolled_window) {
		C.gtk_scrolled_window_set_child(scrolled_window, child)
	}

	// Bind config from the surface to our config property. In ghostty this is a
	// gobject.Object.bindProperty; here we just copy the surface's config
	// pointer (with refcounting) so the scrollbar policy can be derived.
	if !isnil(self.surface) && !isnil(self.surface.config) {
		self.set_config(self.surface.config)
	}

	if !isnil(self.widget) {
		C.g_object_thaw_notify(self.widget)
	}
}

// set_config replaces the config (with refcounting). Mirrors the config
// property accessor's refcounting behavior in dispose/propSurface.
fn (mut self SurfaceScrolledWindow) set_config(config &Config) {
	if !isnil(self.config) {
		self.config.unref()
		self.config = unsafe { nil }
	}
	if isnil(config) {
		return
	}
	self.config = ssw_config_ref(config)
}

// ssw_config_ref is a non-mut wrapper around `Config.ref()` (see the note on
// the analogous helper in command_palette_linux.v).
fn ssw_config_ref(config &Config) &Config {
	mut c := config
	return c.ref()
}

// scrollbar_policy maps the config's scrollbar setting to a GtkPolicyType.
// Mirrors `closureScrollbarPolicy`.
pub fn (self &SurfaceScrolledWindow) scrollbar_policy() PolicyType {
	if isnil(self.config) {
		return .automatic
	}
	cfg := self.config.get()
	return match cfg.scrollbar {
		.never { PolicyType.never }
		.system { PolicyType.automatic }
	}
}

// dispose releases the config reference. Mirrors the `dispose` virtual method
// (the config_binding unref is omitted since we don't model the binding).
pub fn (mut self SurfaceScrolledWindow) dispose() {
	if !isnil(self.config) {
		self.config.unref()
		self.config = unsafe { nil }
	}
	if !isnil(self.widget) {
		surface_scrolled_window_dispose(voidptr(self.widget))
	}
}

// --- GObject class registration -------------------------------------------
// Hand-expansion of ghostty's `gobject.ext.defineClass` for
// `GhostttySurfaceScrolledWindow` (note ghostty's triple-t typo in the type
// name, kept for parity; parent adw.Bin): a `.ui` template with
// scrollbar_policy/notify_surface callbacks, the `config` / `surface`
// properties, and dispose/finalize vfuncs. There are no signals.

// --- New C bindings unique to this file (registration) --------------------

// adw_bin_get_child returns the single child of an AdwBin (the ScrolledWindow).
fn C.adw_bin_get_child(bin GtkWidget) GtkWidget

// g_object_freeze_notify / g_object_thaw_notify batch property-change notifs.
fn C.g_object_freeze_notify(object voidptr)

fn C.g_object_thaw_notify(object voidptr)

// gtk_policy_type_get_type is the registered GType of gtk.PolicyType, used as
// the scrollbar_policy closure's return type.
fn C.gtk_policy_type_get_type() GType

// The blueprint (ui/1.5/surface-scrolled-window.blp) translated to a GtkBuilder
// .ui XML string. `notify::surface => $notify_surface()` becomes a <signal>;
// `hscrollbar-policy: never` becomes a <property>; `vscrollbar-policy: bind
// $scrollbar_policy(template.config) as <Gtk.PolicyType>` becomes a <closure>.
const surface_scrolled_window_ui = '<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <template class="GhostttySurfaceScrolledWindow" parent="AdwBin">
    <signal name="notify::surface" handler="notify_surface"/>
    <child>
      <object class="GtkScrolledWindow">
        <property name="hscrollbar-policy">never</property>
        <property name="vscrollbar-policy">
          <binding>
            <closure type="GtkPolicyType" function="scrollbar_policy">
              <lookup name="config">GhostttySurfaceScrolledWindow</lookup>
            </closure>
          </binding>
        </property>
      </object>
    </child>
  </template>
</interface>
'

// The C-layout private struct mirroring ghostty\'s `Private`: the config /
// surface pointers. The config_binding (a gobject.Binding) is not modeled; the
// config is bound eagerly by the wrapper. These are served as opaque pointer
// properties (Config / SurfaceWidget are V structs, not registered GObjects).
struct C.GhostttySurfaceScrolledWindowPrivate {
mut:
	config  voidptr
	surface voidptr
}

// The GObject type id and private-data offset, registered lazily.
__global g_surface_scrolled_window_type = GType(0)
__global g_surface_scrolled_window_priv_offset = int(0)

// Registered GParamSpec* pointers, captured for notify.
__global g_surface_scrolled_window_pspec_config = &C.GParamSpec(unsafe { nil })
__global g_surface_scrolled_window_pspec_surface = &C.GParamSpec(unsafe { nil })

// Property ids for the get/set vfunc dispatch.
const surface_scrolled_window_prop_config = u32(1)
const surface_scrolled_window_prop_surface = u32(2)

fn surface_scrolled_window_priv(obj voidptr) &C.GhostttySurfaceScrolledWindowPrivate {
	return &C.GhostttySurfaceScrolledWindowPrivate(C.g_type_instance_get_private(obj, g_surface_scrolled_window_type))
}

// surface_scrolled_window_get_property implements get_property for config/surface.
fn surface_scrolled_window_get_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	priv := surface_scrolled_window_priv(obj)
	match property_id {
		surface_scrolled_window_prop_config { C.g_value_set_pointer(value, priv.config) }
		surface_scrolled_window_prop_surface { C.g_value_set_pointer(value, priv.surface) }
		else {}
	}
}

// surface_scrolled_window_set_property implements set_property for config/surface.
fn surface_scrolled_window_set_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	mut priv := surface_scrolled_window_priv(obj)
	match property_id {
		surface_scrolled_window_prop_config {
			priv.config = C.g_value_get_pointer(value)
		}
		surface_scrolled_window_prop_surface {
			priv.surface = C.g_value_get_pointer(value)
		}
		else {}
	}
}

// surface_scrolled_window_scrollbar_policy_cb maps the config's scrollbar
// setting to a GtkPolicyType. Mirrors `closureScrollbarPolicy`. `config_` is
// the opaque `config` property value; here the wrapper drives the policy so
// this returns .automatic when unset.
fn surface_scrolled_window_scrollbar_policy_cb(instance voidptr, config_ voidptr) int {
	if isnil(config_) {
		return int(PolicyType.automatic)
	}
	cfg := unsafe { &Config(config_) }.get()
	return match cfg.scrollbar {
		.never { int(PolicyType.never) }
		.system { int(PolicyType.automatic) }
	}
}

// surface_scrolled_window_notify_surface_cb is the `notify::surface` callback
// (propSurface). The wrapper's `set_surface` performs the re-parent + config
// bind directly, so this trampoline is a no-op placeholder kept for parity.
fn surface_scrolled_window_notify_surface_cb(obj voidptr, pspec voidptr, instance voidptr) {
}

// surface_scrolled_window_dispose disposes the template and chains up. Mirrors
// `dispose` (the config unref is done by the wrapper).
fn surface_scrolled_window_dispose(obj voidptr) {
	C.gtk_widget_dispose_template(obj, g_surface_scrolled_window_type)
	parent_class := &C.GObjectClass(C.g_type_class_peek_parent(C.g_type_check_instance_get_class(obj)))
	if !isnil(parent_class.dispose) {
		f := DisposeFn(parent_class.dispose)
		f(obj)
	}
}

// surface_scrolled_window_finalize chains up. Mirrors `finalize`.
fn surface_scrolled_window_finalize(obj voidptr) {
	parent_class := &C.GObjectClass(C.g_type_class_peek_parent(C.g_type_check_instance_get_class(obj)))
	if !isnil(parent_class.finalize) {
		f := FinalizeFn(parent_class.finalize)
		f(obj)
	}
}

// surface_scrolled_window_class_init installs the template, wires the
// scrollbar_policy/notify_surface callbacks, registers the config/surface
// properties, and overrides the get/set/dispose/finalize vfuncs. Mirrors the
// ghostty `Class.init`.
fn surface_scrolled_window_class_init(klass voidptr, class_data voidptr) {
	bytes := C.g_bytes_new_static(surface_scrolled_window_ui.str, usize(surface_scrolled_window_ui.len))
	C.gtk_widget_class_set_template(klass, bytes)

	// Template callbacks.
	C.gtk_widget_class_bind_template_callback_full(klass, c'scrollbar_policy', voidptr(surface_scrolled_window_scrollbar_policy_cb))
	C.gtk_widget_class_bind_template_callback_full(klass, c'notify_surface', voidptr(surface_scrolled_window_notify_surface_cb))

	// Properties (config/surface as opaque pointers).
	g_surface_scrolled_window_pspec_config = C.g_param_spec_pointer(c'config', c'config', c'The configuration', g_param_readwrite)
	g_surface_scrolled_window_pspec_surface = C.g_param_spec_pointer(c'surface', c'surface', c'The embedded surface', g_param_readwrite)
	mut obj_class := &C.GObjectClass(klass)
	obj_class.get_property = voidptr(surface_scrolled_window_get_property)
	obj_class.set_property = voidptr(surface_scrolled_window_set_property)
	obj_class.dispose = voidptr(surface_scrolled_window_dispose)
	obj_class.finalize = voidptr(surface_scrolled_window_finalize)
	C.g_object_class_install_property(klass, surface_scrolled_window_prop_config, g_surface_scrolled_window_pspec_config)
	C.g_object_class_install_property(klass, surface_scrolled_window_prop_surface, g_surface_scrolled_window_pspec_surface)
}

fn surface_scrolled_window_instance_init(instance voidptr, klass voidptr) {
	C.gtk_widget_init_template(instance)
}

// surface_scrolled_window_get_type lazily registers the
// GhostttySurfaceScrolledWindow GObject type, parented to AdwBin, with
// instance-private data.
pub fn surface_scrolled_window_get_type() GType {
	if g_surface_scrolled_window_type == GType(0) {
		parent := C.adw_bin_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size: u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init: voidptr(surface_scrolled_window_class_init)
			instance_init: voidptr(surface_scrolled_window_instance_init)
		}
		g_surface_scrolled_window_type = C.g_type_register_static(parent, c'GhostttySurfaceScrolledWindow', &info, 0)
		g_surface_scrolled_window_priv_offset = C.g_type_add_instance_private(g_surface_scrolled_window_type, sizeof(C.GhostttySurfaceScrolledWindowPrivate))
	}
	return g_surface_scrolled_window_type
}
