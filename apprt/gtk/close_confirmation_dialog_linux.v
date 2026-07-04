module gtk

// close_confirmation_dialog_linux.v - Close confirmation dialog
// (GhosttyCloseConfirmationDialog).
//
// Translated from ghostty/src/apprt/gtk/class/close_confirmation_dialog.zig.
//
// In ghostty this is a GObject class (subclass of the base `Dialog`) that asks
// the user to confirm closing the app / a window / a tab / a split. It carries
// a `target` property, emits `close-request` / `cancel` signals, and derives
// its heading/body from the target.
//
// V has no GObject class-registration / comptime / template / signal
// machinery, so:
//   * The class is modeled as a plain V struct `CloseConfirmationDialog`
//     wrapping the base `Dialog` plus the `target` private field.
//   * GObject type registration (`defineClass`), the `target` PROPERTY, the
//     `.ui` template, and the `close-request`/`cancel` SIGNALS are STUBBED —
//     see the "GObject class registration" section. Signal emission is modeled
//     via optional V callbacks so the response routing stays observable.
//   * The real LOGIC — the target -> heading/body text and the response-id ->
//     signal routing — is translated directly.

// --- CloseTarget ----------------------------------------------------------
//
// The target of a close dialog. This consolidates all logic for prompting the
// user and closing windows/tabs/surfaces into one source of truth. Mirrors the
// Zig `Target` enum (renamed `CloseTarget` here to avoid colliding with
// apprt's target concept and to be self-documenting).
pub enum CloseTarget {
	app
	tab
	window
	surface
}

// title returns the dialog heading for this target. Mirrors `Target.title`.
pub fn (t CloseTarget) title() string {
	return match t {
		.app { i18n_('Quit Ghostty?') }
		.tab { i18n_('Close Tab?') }
		.window { i18n_('Close Window?') }
		.surface { i18n_('Close Split?') }
	}
}

// body returns the dialog body for this target. Mirrors `Target.body`.
pub fn (t CloseTarget) body() string {
	return match t {
		.app { i18n_('All terminal sessions will be terminated.') }
		.tab { i18n_('All terminal sessions in this tab will be terminated.') }
		.window { i18n_('All terminal sessions in this window will be terminated.') }
		.surface { i18n_('The currently running process in this split will be terminated.') }
	}
}

// --- CloseConfirmationDialog ----------------------------------------------

// CloseConfirmationDialog is the close-confirmation dialog GObject
// (`GhosttyCloseConfirmationDialog`, a subclass of `Dialog`). Modeled as a
// struct embedding the base `Dialog` plus the private `target`.
@[heap]
pub struct CloseConfirmationDialog {
mut:
	// The base dialog. In ghostty this is the parent instance (`Dialog`).
	dialog Dialog

	// The close target. Mirrors `Private.target` (the `target` property).
	target CloseTarget = .app

	// Signal callbacks. Ghostty emits GObject signals (`close-request` /
	// `cancel`); we model them as optional V callbacks so callers can observe
	// the response routing.
	//
	// TODO(gtk): GObject signals — registered via `gobject.ext.defineSignal`
	// and emitted with `.impl.emit(...)`. Stubbed as plain callbacks here.
	on_close_request ?fn ()
	on_cancel        ?fn ()
}

// close_confirmation_dialog_new creates a new dialog for the given target.
// Mirrors `CloseConfirmationDialog.new`.
//
// TODO(gtk): ghostty uses `gobject.ext.newInstance(Self, .{ .target = target })`
// which builds the GObject and runs the `.ui` template init. Here we allocate
// the plain wrapper.
pub fn close_confirmation_dialog_new(target CloseTarget) &CloseConfirmationDialog {
	return &CloseConfirmationDialog{
		target: target
	}
}

// present sets up the title/body from the target and shows the dialog. Mirrors
// `CloseConfirmationDialog.present`.
pub fn (mut self CloseConfirmationDialog) present(parent GtkWidget) {
	// Setup our title/body text.
	self.dialog.set_heading(&char(self.target.title().str))
	self.dialog.set_body(&char(self.target.body().str))

	// Show it.
	self.dialog.present(parent)
}

// close closes the dialog. Mirrors `CloseConfirmationDialog.close`.
pub fn (mut self CloseConfirmationDialog) close() {
	self.dialog.close()
}

// response routes an AdwAlertDialog response id to the appropriate signal.
// Mirrors the `response` virtual method: "close" -> close-request, anything
// else -> cancel.
//
// TODO(gtk): GObject virtual method — implemented via
// `Dialog.virtual_methods.response.implement(class, &response)` in ghostty.
// Here it is a plain method invoked by the (stubbed) response wiring.
fn (mut self CloseConfirmationDialog) response(response_id string) {
	if response_id == 'close' {
		if cb := self.on_close_request {
			cb()
		}
	} else {
		if cb := self.on_cancel {
			cb()
		}
	}
}

// --- GObject reference counting -------------------------------------------
// Mirrors the `Common(Self, Private)` ref helpers (ref/refSink/unref).

// ref increments the reference count of the dialog GObject. Mirrors `ref`.
pub fn (mut self CloseConfirmationDialog) ref() {
	self.dialog.ref()
}

// unref decrements the reference count of the dialog GObject. Mirrors `unref`.
pub fn (mut self CloseConfirmationDialog) unref() {
	self.dialog.unref()
}
