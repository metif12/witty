module gtk

// surface_title_dialog_linux.v - Surface title prompt dialog
// (GhosttySurfaceTitleDialog).
//
// Translated from ghostty/src/apprt/gtk/class/surface_title_dialog.zig.
//
// In ghostty this is a GObject class (subclass of `adw.AlertDialog`, NOT the
// base `Dialog`) that prompts the user for a new surface title with a text
// entry. It carries an `initial-value` property, a `set` signal (emitted with
// the new title), and an `entry` template child. Its response is handled
// asynchronously via `adw.AlertDialog.choose` / `chooseFinish`.
//
// V has no GObject class-registration / comptime / template / signal / async
// machinery, so:
//   * The class is modeled as a plain V struct `SurfaceTitleDialog` wrapping
//     the `adw.AlertDialog` GObject pointer plus the private fields
//     (`initial_value`, `entry`).
//   * GObject type registration (`defineClass`), the `initial-value` PROPERTY,
//     the `.ui` template + `entry` binding, the `set` SIGNAL, and the async
//     `choose`/`chooseFinish` response flow are STUBBED — see the "GObject
//     class registration" section. The `set` signal is modeled as an optional
//     V callback.
//   * The real LOGIC — parent ancestor resolution, seeding the entry with the
//     initial value, and the "ok" -> emit(title) routing — is translated.

// --- New opaque handle aliases --------------------------------------------
// (Grep-verified: not declared elsewhere in the module.)

// AdwWindow is an AdwWindow* (a window ancestor we prefer to attach to).
pub type AdwWindow = voidptr

// AdwEntryBuffer is a gtk.EntryBuffer* backing the title entry.
pub type GtkEntry = voidptr

// GtkEntryBuffer is a gtk.EntryBuffer*.
pub type GtkEntryBuffer = voidptr

// --- New GTK C bindings ---------------------------------------------------
// Only functions not already declared anywhere else in the module.

fn C.gtk_entry_get_buffer(entry GtkEntry) GtkEntryBuffer
fn C.gtk_entry_buffer_set_text(buffer GtkEntryBuffer, chars &char, n_chars int)
fn C.gtk_entry_buffer_get_text(buffer GtkEntryBuffer) &char

// --- SurfaceTitleDialog ---------------------------------------------------

// SurfaceTitleDialog is the surface-title prompt dialog GObject
// (`GhosttySurfaceTitleDialog`, a subclass of `adw.AlertDialog`). Modeled as a
// struct wrapping the GObject pointer plus the private fields.
@[heap]
pub struct SurfaceTitleDialog {
mut:
	// The underlying AdwAlertDialog GObject instance pointer.
	//
	// TODO(gtk): GObject class registration — created via
	// `gobject.ext.defineClass`/`newInstance`; stubbed handle here.
	obj GObject = unsafe { nil }

	// The initial value of the entry field. Mirrors `Private.initial_value`
	// (the `initial-value` property). Empty means unset.
	initial_value string

	// The entry widget template child. Mirrors `Private.entry`.
	//
	// TODO(gtk): bound via `bindTemplateChildPrivate("entry", .{})`. Stubbed.
	entry GtkEntry = unsafe { nil }

	// Signal callback for the `set` signal. Ghostty emits a GObject `set`
	// signal carrying the new title; modeled here as an optional V callback.
	//
	// TODO(gtk): GObject signal — registered via `gobject.ext.defineSignal`.
	on_set ?fn (title string)
}

// surface_title_dialog_new creates a new surface title dialog.
//
// TODO(gtk): ghostty uses `gobject.ext.newInstance` + `.ui` template init.
pub fn surface_title_dialog_new() &SurfaceTitleDialog {
	return &SurfaceTitleDialog{}
}

// present shows the dialog attached to the best available window ancestor and
// seeds the entry with the initial value. Mirrors `SurfaceTitleDialog.present`.
pub fn (mut self SurfaceTitleDialog) present(parent GtkWidget) {
	// If we have a window we can attach to, we prefer that.
	//
	// TODO(gtk): ghostty uses `ext.getAncestor(adw.ApplicationWindow, ...)`
	// then `adw.Window` — these need the GObject types for the type check. Here
	// we fall back to the given parent widget. The `get_ancestor` helper
	// (ext_linux.v) takes an explicit GType which we don't have for these
	// widget classes yet.
	attach_to := parent

	// Set our initial value.
	if self.initial_value.len > 0 && !isnil(self.entry) {
		buffer := C.gtk_entry_get_buffer(self.entry)
		C.gtk_entry_buffer_set_text(buffer, &char(self.initial_value.str), -1)
	}

	// Show it. In ghostty this uses `adw.AlertDialog.choose` with an async
	// callback (`alertDialogReady`); we present via the (stubbed) dialog path.
	//
	// TODO(gtk): async `choose`/`chooseFinish` flow — replaced by presenting
	// and (when wired) invoking `alert_dialog_ready` on the response.
	self.present_widget(attach_to)
}

// present_widget presents the underlying AdwAlertDialog against a parent
// widget. Split out so the async `choose` flow can be wired later.
//
// TODO(gtk): GObject/adw presentation — stubbed.
fn (mut self SurfaceTitleDialog) present_widget(parent GtkWidget) {
	_ = parent
}

// alert_dialog_ready handles the async result of the AlertDialog. If the user
// hit "ok" it emits the `set` signal with the current entry text. Mirrors
// `alertDialogReady`.
//
// TODO(gtk): async callback — in ghostty this is a `gio.AsyncResult` callback
// passed to `choose`. Here it is invoked directly by the (stubbed) response
// wiring with the response id.
fn (mut self SurfaceTitleDialog) alert_dialog_ready(response_id string) {
	// If we didn't hit "ok" then we do nothing.
	if response_id != 'ok' {
		return
	}

	// Emit our signal with the new title.
	if isnil(self.entry) {
		return
	}
	buffer := C.gtk_entry_get_buffer(self.entry)
	title := unsafe { cstring_to_vstring(C.gtk_entry_buffer_get_text(buffer)) }
	if cb := self.on_set {
		cb(title)
	}
}

// dispose disposes the template. Mirrors the `dispose` vfunc.
//
// TODO(gtk): GObject vfunc + `gtk.Widget.disposeTemplate` — stubbed.
pub fn (mut self SurfaceTitleDialog) dispose() {}

// finalize frees the owned initial value. Mirrors the `finalize` vfunc.
//
// TODO(gtk): GObject vfunc — in ghostty this `glib.free`s the (glib-owned)
// initial value string. Here `initial_value` is a V string freed by the GC.
pub fn (mut self SurfaceTitleDialog) finalize() {
	self.initial_value = ''
}

// --- GObject reference counting -------------------------------------------
// Mirrors the `Common(Self, Private)` ref helpers.

// ref increments the reference count of the dialog GObject. Mirrors `ref`.
pub fn (mut self SurfaceTitleDialog) ref() {
	if !isnil(self.obj) {
		object_ref(self.obj)
	}
}

// unref decrements the reference count of the dialog GObject. Mirrors `unref`.
pub fn (mut self SurfaceTitleDialog) unref() {
	if !isnil(self.obj) {
		object_unref(self.obj)
	}
}
