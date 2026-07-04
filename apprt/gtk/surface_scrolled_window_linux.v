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
// FOLLOWING THE ESTABLISHED PATTERN: GObject registration, `.ui`/blueprint
// template, and property/binding machinery are stubbed with `// TODO(gtk)`; the
// real logic (swapping the scrolled-window child, the config->scrollbar-policy
// mapping, config refcounting) is translated. The class is a plain V struct
// wrapping the GObject/GtkWidget ptr.
//
// Reuses: `Config` (window_linux.v), `SurfaceWidget` (surface_class_linux.v —
// the GObject `Surface` in Zig), `GtkWidget` (c_gtk_linux.v). GtkWidget parent
// helpers are declared in search_overlay_linux.v.

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
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The configuration this widget uses. nil means "unset".
	config &Config = unsafe { nil }

	// The embedded surface widget. nil means "unset".
	surface &SurfaceWidget = unsafe { nil }
}

// new_surface_scrolled_window creates a new SurfaceScrolledWindow. Mirrors
// instance `init`.
pub fn new_surface_scrolled_window() &SurfaceScrolledWindow {
	return &SurfaceScrolledWindow{}
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

	// TODO(gtk): freeze/thaw notify + notifyByPspec(properties.surface).
	self.surface = surface

	// Re-parent: put the new surface's widget into the scrolled window (which is
	// this widget's single child in the template).
	//
	// TODO(gtk): the scrolled window is `self.as(Parent).getChild()` cast to a
	// gtk.ScrolledWindow. We don't have the template child wired, so we call the
	// child setter with the widget we do have as a faithful placeholder.
	child := if !isnil(self.surface) { self.surface.as_widget() } else { GtkWidget(unsafe { nil }) }
	if !isnil(self.widget) {
		C.gtk_scrolled_window_set_child(self.widget, child)
	}

	// Bind config from the surface to our config property. In ghostty this is a
	// gobject.Object.bindProperty; here we just copy the surface's config
	// pointer (with refcounting) so the scrollbar policy can be derived.
	if !isnil(self.surface) && !isnil(self.surface.config) {
		self.set_config(self.surface.config)
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
	// TODO(gtk): gtk.Widget.disposeTemplate + chain up to parent dispose.
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty this class is registered via gobject.ext.defineClass.
// classInit loads the `surface-scrolled-window` blueprint `.ui` template, wires
// the `scrollbar_policy` / `notify_surface` template callbacks, registers the
// `config` / `surface` properties, and wires dispose/finalize. V has no such
// machinery, so all of that is stubbed; the handlers above are plain methods
// instead of C template callbacks.
