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
// V has no GObject class-registration / comptime / template / signal
// machinery, so:
//   * The class is modeled as a plain V struct `ConfigErrorsDialog` wrapping
//     the base `Dialog` plus the `config` private field (a `&Config`).
//   * GObject type registration (`defineClass`), the `config` PROPERTY, the
//     `.ui` template, and the `reload-config` SIGNAL are STUBBED — see the
//     "GObject class registration" section. Signal emission is modeled via an
//     optional V callback.
//   * The real LOGIC — the response-id routing ("reload" -> emit) and the
//     config ref/unref ownership (get/set/dispose) — is translated directly.

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
	// here as an optional V callback.
	//
	// TODO(gtk): GObject signal — registered via `gobject.ext.defineSignal` and
	// emitted with `.impl.emit(...)`.
	on_reload_config ?fn ()
}

// config_errors_dialog_new creates a new dialog for the given config. Mirrors
// `ConfigErrorsDialog.new`.
//
// TODO(gtk): ghostty uses `gobject.ext.newInstance(Self, .{ .config = config })`
// which builds the GObject and runs the `.ui` template init. The property
// setter takes a reference to the config; here we do it explicitly via
// `set_config`.
pub fn config_errors_dialog_new(config &Config) &ConfigErrorsDialog {
	mut self := &ConfigErrorsDialog{}
	self.set_config(config)
	return self
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
// reload-config signal. Mirrors the `response` virtual method.
//
// TODO(gtk): GObject virtual method — implemented via
// `Dialog.virtual_methods.response.implement(class, &response)` in ghostty.
fn (mut self ConfigErrorsDialog) response(response_id string) {
	if response_id != 'reload' {
		return
	}
	if cb := self.on_reload_config {
		cb()
	}
}

// dispose releases the held config reference. Mirrors the `dispose` vfunc.
//
// TODO(gtk): GObject vfunc — implemented via
// `gobject.Object.virtual_methods.dispose` and chained to the parent, plus
// `gtk.Widget.disposeTemplate`. Here we release the config ref directly.
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
