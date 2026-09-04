@[has_globals]
module gtk

// config_errors_dialog_linux.v - Config errors dialog
// (GhosttyConfigErrorsDialog).
//
// Translated from ghostty/src/apprt/gtk/class/config_errors_dialog.zig.
//
// In ghostty this is a GObject class (subclass of the base `Dialog`) that shows
// the configuration diagnostics and offers to reload. It holds a `config`
// property (a ref-counted `Config` GObject) and emits a `reload-config` signal
// when the user picks "reload".
//
// The GObject class registration (`defineClass`), the `config` PROPERTY, the
// `.ui` template, and the `reload-config` SIGNAL are hand-expanded below onto
// the raw GObject/GTK C API. The V struct `ConfigErrorsDialog` keeps the
// `&Config` and an optional V callback so ownership + response routing stay
// observable from V. The real LOGIC — the response-id routing ("reload" ->
// emit) and the config ref/unref ownership (get/set/dispose) — is translated
// directly.
//
// The `config` property is typed as GhosttyConfig, matching the pinned class.

// --- GObject class registration -------------------------------------------
// Hand-expansion of ghostty's `gobject.ext.defineClass` for
// `GhosttyConfigErrorsDialog`: a `.ui` template, a `config` object property,
// a `reload-config` signal, private data, and a dispose vfunc.

// The blueprint (ui/1.2/config-errors-dialog.blp) translated to a GtkBuilder
// .ui XML string. `_("x")` -> translatable="yes"; `responses [...]` -> the
// AdwAlertDialog <responses>/<response> element (`suggested` ->
// appearance="suggested"); `extra-child: X` -> a <property name="extra-child">
// wrapping the object; the `bind (template.config as <$GhosttyConfig>)
// .diagnostics-buffer` expression is translated faithfully.
const config_errors_dialog_ui = '<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <template class="GhosttyConfigErrorsDialog" parent="GhosttyDialog">
    <property name="heading" translatable="yes">Configuration Errors</property>
    <property name="body" translatable="yes">One or more configuration errors were found. Please review the errors below, and either reload your configuration or ignore these errors.</property>
    <responses>
      <response id="ignore" translatable="yes">Ignore</response>
      <response id="reload" translatable="yes" appearance="suggested">Reload Configuration</response>
    </responses>
    <property name="extra-child">
      <object class="GtkScrolledWindow">
        <property name="min-content-width">500</property>
        <property name="min-content-height">100</property>
        <child>
          <object class="GtkTextView">
            <property name="editable">false</property>
            <property name="cursor-visible">false</property>
            <property name="top-margin">8</property>
            <property name="bottom-margin">8</property>
            <property name="left-margin">8</property>
            <property name="right-margin">8</property>
            <binding name="buffer">
              <lookup name="diagnostics-buffer" type="GhosttyConfig">
                <lookup name="config">GhosttyConfigErrorsDialog</lookup>
              </lookup>
            </binding>
          </object>
        </child>
      </object>
    </property>
  </template>
</interface>
'

// The C-layout private struct mirroring ghostty\'s `Private`. It holds the
// GObject pointer of the wrapped Config (Config.obj).
struct C.GhosttyConfigErrorsDialogPrivate {
mut:
	config voidptr
}

// The GObject type id and private-data offset, registered lazily.
__global g_config_errors_dialog_type = GType(0)
__global g_config_errors_dialog_priv_offset = int(0)

// Property id for the `config` property.
const config_errors_prop_config = u32(1)

fn config_errors_dialog_priv(obj voidptr) &C.GhosttyConfigErrorsDialogPrivate {
	return &C.GhosttyConfigErrorsDialogPrivate(C.g_type_instance_get_private(obj, g_config_errors_dialog_type))
}

// config_errors_dialog_get_property implements get_property for `config`.
// Mirrors `getConfig`.
fn config_errors_dialog_get_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	if property_id == config_errors_prop_config {
		priv := config_errors_dialog_priv(obj)
		C.g_value_set_object(value, priv.config)
	}
}

// config_errors_dialog_set_property implements set_property for `config`.
// Mirrors `setConfig`: unref the old, take the new (the GValue object
// accessor refs it).
fn config_errors_dialog_set_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	if property_id == config_errors_prop_config {
		mut priv := config_errors_dialog_priv(obj)
		if !isnil(priv.config) {
			object_unref(GObject(priv.config))
		}
		newv := GObject(C.g_value_get_object(value))
		if !isnil(newv) {
			priv.config = voidptr(object_ref(newv))
		} else {
			priv.config = unsafe { nil }
		}
	}
}

// config_errors_dialog_dispose releases the held config, disposes the template
// and chains to the parent. Mirrors the `dispose` vfunc.
fn config_errors_dialog_dispose(obj voidptr) {
	mut priv := config_errors_dialog_priv(obj)
	if !isnil(priv.config) {
		object_unref(GObject(priv.config))
		priv.config = unsafe { nil }
	}
	C.gtk_widget_dispose_template(obj, g_config_errors_dialog_type)
	C.witty_gobject_call_parent_dispose(obj)
}

// config_errors_dialog_class_init installs the template, the `config` property,
// the `reload-config` signal, and overrides the get/set/dispose vfuncs.
fn config_errors_dialog_class_init(klass voidptr, class_data voidptr) {
	dialog_get_type()

	bytes := C.g_bytes_new_static(config_errors_dialog_ui.str, usize(config_errors_dialog_ui.len))
	C.gtk_widget_class_set_template(klass, bytes)

	pspec := C.g_param_spec_object(c'config', c'config', c'The config being shown', config_get_type(), g_param_readwrite)
	C.witty_gobject_class_set_get_property(klass, voidptr(config_errors_dialog_get_property))
	C.witty_gobject_class_set_set_property(klass, voidptr(config_errors_dialog_set_property))
	C.witty_gobject_class_set_dispose(klass, voidptr(config_errors_dialog_dispose))
	C.g_object_class_install_property(klass, config_errors_prop_config, pspec)

	C.g_signal_new(c'reload-config', g_config_errors_dialog_type, g_signal_run_last, 0, unsafe { nil }, unsafe { nil }, unsafe { nil }, GType(0), 0)
}

fn config_errors_dialog_instance_init(instance voidptr, klass voidptr) {
	C.gtk_widget_init_template(instance)
}

// config_errors_dialog_get_type lazily registers the GhosttyConfigErrorsDialog
// GObject type, parented to GhosttyDialog, with instance-private data.
pub fn config_errors_dialog_get_type() GType {
	if g_config_errors_dialog_type == GType(0) {
		parent := dialog_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size: u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init: voidptr(config_errors_dialog_class_init)
			instance_init: voidptr(config_errors_dialog_instance_init)
		}
		g_config_errors_dialog_type = C.g_type_register_static(parent, c'GhosttyConfigErrorsDialog', &info, 0)
		g_config_errors_dialog_priv_offset = C.g_type_add_instance_private(g_config_errors_dialog_type, sizeof(C.GhosttyConfigErrorsDialogPrivate))
	}
	return g_config_errors_dialog_type
}

// --- ConfigErrorsDialog ---------------------------------------------------

// ConfigErrorsDialog is the config-errors dialog GObject
// (`GhosttyConfigErrorsDialog`, a subclass of `Dialog`). Modeled as a struct
// embedding the base `Dialog` plus the private `config`.
@[heap]
pub struct ConfigErrorsDialog {
mut:
	// The base dialog (`Dialog` parent instance).
	dialog Dialog

	// The config whose diagnostics we display. Mirrors `Private.config` (the
	// ref-counted `config` property). Nil when unset.
	config &Config = unsafe { nil }

	// Signal callback. Ghostty emits a GObject `reload-config` signal; modeled
	// here as both the native signal and an optional direct V callback.
	on_reload_config ?fn ()
}

// config_errors_dialog_new creates a new dialog for the given config. Mirrors
// `gobject.ext.newInstance(Self, .{ .config = config })`: it builds the GObject
// (running the `.ui` template init) with the `config` property set (the setter
// takes a reference).
pub fn config_errors_dialog_new(config &Config) &ConfigErrorsDialog {
	mut config_obj := GObject(unsafe { nil })
	if !isnil(config) {
		config_obj = config.obj
	}
	obj := C.g_object_new(config_errors_dialog_get_type(), c'config', config_obj, &char(unsafe { nil }))
	mut self := &ConfigErrorsDialog{
		dialog: Dialog{
			obj: obj
		}
	}
	self.set_config(config)
	C.g_signal_connect_data(obj, c'response', GCallback(voidptr(config_errors_dialog_response_cb)), voidptr(self), unsafe { nil }, 0)
	return self
}

fn config_errors_dialog_response_cb(obj GObject, response_id &char, data voidptr) {
	_ = obj
	if isnil(response_id) || isnil(data) {
		return
	}
	mut self := unsafe { &ConfigErrorsDialog(data) }
	self.response(unsafe { cstring_to_vstring(response_id) })
}

// present shows the dialog. Mirrors `ConfigErrorsDialog.present`.
pub fn (mut self ConfigErrorsDialog) present(parent GtkWidget) {
	self.dialog.present(parent)
}

// close closes the dialog. Mirrors `ConfigErrorsDialog.close`.
pub fn (mut self ConfigErrorsDialog) close() {
	self.dialog.close()
}

// response routes an AdwAlertDialog response id: only "reload" emits the
// reload-config signal. Mirrors the `response` virtual method. Emits the real
// GObject signal and invokes the optional V callback.
fn (mut self ConfigErrorsDialog) response(response_id string) {
	if response_id != 'reload' {
		return
	}
	if !isnil(self.dialog.obj) {
		C.g_signal_emit_by_name(self.dialog.obj, c'reload-config')
	}
	if cb := self.on_reload_config {
		cb()
	}
}

// dispose releases the held config reference on the V wrapper. The GObject-side
// dispose (config unref + gtk_widget_dispose_template + parent chain) is the
// `config_errors_dialog_dispose` vfunc registered above.
pub fn (mut self ConfigErrorsDialog) dispose() {
	if !isnil(self.config) {
		self.config.unref()
		self.config = unsafe { nil }
	}
}

// get_config returns the held config (without taking a reference). Mirrors
// `getConfig` (the `config` property getter).
pub fn (self &ConfigErrorsDialog) get_config() &Config {
	return self.config
}

// set_config sets the held config, unref-ing any previous one and ref-ing the
// new one. Mirrors `setConfig`.
//
// NOTE: in ghostty the property setter itself handles the reference (using
// `GValue.get` vs. `take`), so `setConfig` does not ref. Here there is no
// property machinery, so we take the reference explicitly to keep ownership
// correct.
fn (mut self ConfigErrorsDialog) set_config(config &Config) {
	if !isnil(self.config) {
		self.config.unref()
	}
	self.config = unsafe { config }
	if !isnil(self.config) {
		self.config.ref()
	}
	if !isnil(self.dialog.obj) {
		config_obj := if isnil(config) { GObject(unsafe { nil }) } else { config.obj }
		C.g_object_set(self.dialog.obj, c'config', config_obj, unsafe { nil })
	}
}

// --- GObject reference counting -------------------------------------------
// Mirrors the `Common(Self, Private)` ref helpers.

// ref increments the reference count of the dialog GObject. Mirrors `ref`.
pub fn (mut self ConfigErrorsDialog) ref() {
	self.dialog.ref()
}

// unref decrements the reference count of the dialog GObject. Mirrors `unref`.
pub fn (mut self ConfigErrorsDialog) unref() {
	self.dialog.unref()
}
