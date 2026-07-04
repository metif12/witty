module gtk

// clipboard_confirmation_dialog_linux.v - Clipboard confirmation dialog
// (GhosttyClipboardConfirmationDialog).
//
// Translated from ghostty/src/apprt/gtk/class/clipboard_confirmation_dialog.zig.
//
// In ghostty this is a GObject class (subclass of the base `Dialog`) that asks
// the user to authorize a clipboard read/write (OSC 52) or an unsafe paste. It
// carries `request` / `clipboard-contents` / `blur` / `can-remember`
// properties, `confirm` / `deny` signals (each carrying whether the choice
// should be remembered), template children (the text view, reveal/hide
// buttons, remember switch), and blur/reveal/hide behavior.
//
// V has no GObject class-registration / comptime / template / signal
// machinery, so:
//   * The class is modeled as a plain V struct `ClipboardConfirmationDialog`
//     wrapping the base `Dialog` plus the private fields.
//   * GObject type registration (`defineClass`), the four PROPERTIES, the `.ui`
//     template + child bindings, and the `confirm`/`deny` SIGNALS are STUBBED —
//     see the "GObject class registration" section. Signal emission is modeled
//     via optional V callbacks.
//   * The real LOGIC — the request -> heading/body text (prop_request), the
//     blur / reveal / hide widget-state toggles, and the response-id -> signal
//     routing (with the remember flag) — is translated directly.

import apprt

// --- New opaque handle aliases --------------------------------------------
// (Grep-verified: not declared elsewhere in the module.)
// NOTE: GtkScrolledWindow is declared in surface_scrolled_window_linux.v —
// reused here, NOT redeclared.

// GtkTextView is a gtk.TextView*.
pub type GtkTextView = voidptr

// GtkButton is a gtk.Button*.
pub type GtkButton = voidptr

// AdwSwitchRow is an adw.SwitchRow* (libadwaita >= 1.4).
pub type AdwSwitchRow = voidptr

// --- New GTK/Adw C bindings -----------------------------------------------
// Only functions not already declared anywhere else in the module.
// NOTE: gtk_widget_set_visible / gtk_widget_add_css_class /
// gtk_widget_remove_css_class are declared in window_linux.v (int form) —
// reused here via `b2i`, NOT redeclared.

fn C.gtk_widget_set_sensitive(widget GtkWidget, sensitive int)
fn C.adw_switch_row_get_active(row AdwSwitchRow) int

// --- ClipboardConfirmationDialog ------------------------------------------

// ClipboardConfirmationDialog is the clipboard-confirmation dialog GObject
// (`GhosttyClipboardConfirmationDialog`, a subclass of `Dialog`). Modeled as a
// struct embedding the base `Dialog` plus the private fields.
@[heap]
pub struct ClipboardConfirmationDialog {
mut:
	// The base dialog (`Dialog` parent instance).
	dialog Dialog

	// The request that this dialog is for. Mirrors `Private.request`.
	request ?apprt.ClipboardRequest

	// The clipboard contents being read/written. Mirrors
	// `Private.clipboard_contents`.
	clipboard_contents GtkTextBuffer = unsafe { nil }

	// Whether the contents should be blurred. Mirrors `Private.blur`.
	blur bool

	// Whether the user can remember the choice. Mirrors `Private.can_remember`.
	can_remember bool

	// Template children (out of scope widgets). Mirrors the `Private` template
	// bindings.
	//
	// TODO(gtk): bound via `bindTemplateChildPrivate(...)`. Stubbed handles.
	text_view_scroll GtkScrolledWindow = unsafe { nil }
	text_view        GtkTextView       = unsafe { nil }
	reveal_button    GtkButton         = unsafe { nil }
	hide_button      GtkButton         = unsafe { nil }
	remember_choice  AdwSwitchRow      = unsafe { nil }

	// Signal callbacks. Ghostty emits GObject `confirm` / `deny` signals, each
	// carrying the remember flag; modeled here as optional V callbacks.
	//
	// TODO(gtk): GObject signals — registered via `gobject.ext.defineSignal`.
	on_confirm ?fn (remember bool)
	on_deny    ?fn (remember bool)
}

// clipboard_confirmation_dialog_new creates a new dialog. Mirrors
// `ClipboardConfirmationDialog.new`.
//
// TODO(gtk): ghostty uses `gobject.ext.newInstance` + `.ui` template init, then
// triggers the initial `propBlur`/`propRequest`. Here we allocate the wrapper
// and run those two initializers directly.
pub fn clipboard_confirmation_dialog_new() &ClipboardConfirmationDialog {
	mut self := &ClipboardConfirmationDialog{}
	// Trigger initial values (matches ghostty's `init`).
	self.prop_blur()
	self.prop_request()
	return self
}

// present shows the dialog. Mirrors `ClipboardConfirmationDialog.present`.
pub fn (mut self ClipboardConfirmationDialog) present(parent GtkWidget) {
	self.dialog.present(parent)
}

// get_request returns the clipboard request without copying. Mirrors
// `getRequest`.
pub fn (self &ClipboardConfirmationDialog) get_request() ?apprt.ClipboardRequest {
	return self.request
}

// get_clipboard_contents returns the clipboard contents buffer without copying.
// Mirrors `getClipboardContents`.
pub fn (self &ClipboardConfirmationDialog) get_clipboard_contents() GtkTextBuffer {
	return self.clipboard_contents
}

// --- Signal Handlers ------------------------------------------------------

// prop_blur applies the current blur state to the text view + reveal/hide
// buttons. Mirrors `propBlur` (the `notify::blur` callback).
fn (mut self ClipboardConfirmationDialog) prop_blur() {
	if isnil(self.text_view_scroll) {
		return
	}
	if self.blur {
		C.gtk_widget_set_sensitive(self.text_view_scroll, b2i(false))
		C.gtk_widget_add_css_class(self.text_view, c'blurred')
		C.gtk_widget_set_visible(self.reveal_button, b2i(true))
		C.gtk_widget_set_visible(self.hide_button, b2i(false))
	} else {
		C.gtk_widget_set_sensitive(self.text_view_scroll, b2i(true))
		C.gtk_widget_remove_css_class(self.text_view, c'blurred')
		C.gtk_widget_set_visible(self.reveal_button, b2i(false))
		C.gtk_widget_set_visible(self.hide_button, b2i(false))
	}
}

// prop_request applies the current request to the dialog heading/body. Mirrors
// `propRequest` (the `notify::request` callback).
fn (mut self ClipboardConfirmationDialog) prop_request() {
	req := self.request or { return }
	match req.kind {
		.osc_52_write {
			self.dialog.set_heading(&char(i18n_('Authorize Clipboard Access').str))
			self.dialog.set_body(&char(i18n_('An application is attempting to write to the clipboard. The current clipboard contents are shown below.').str))
		}
		.osc_52_read {
			self.dialog.set_heading(&char(i18n_('Authorize Clipboard Access').str))
			self.dialog.set_body(&char(i18n_('An application is attempting to read from the clipboard. The current clipboard contents are shown below.').str))
		}
		.paste {
			self.dialog.set_heading(&char(i18n_('Warning: Potentially Unsafe Paste').str))
			self.dialog.set_body(&char(i18n_('Pasting this text into the terminal may be dangerous as it looks like some commands may be executed.').str))
		}
	}
}

// reveal_button_clicked un-blurs the contents. Mirrors `revealButtonClicked`
// (the `reveal_clicked` template callback).
fn (mut self ClipboardConfirmationDialog) reveal_button_clicked() {
	C.gtk_widget_set_sensitive(self.text_view_scroll, b2i(true))
	C.gtk_widget_remove_css_class(self.text_view, c'blurred')
	C.gtk_widget_set_visible(self.hide_button, b2i(true))
	C.gtk_widget_set_visible(self.reveal_button, b2i(false))
}

// hide_button_clicked re-blurs the contents. Mirrors `hideButtonClicked` (the
// `hide_clicked` template callback).
fn (mut self ClipboardConfirmationDialog) hide_button_clicked() {
	C.gtk_widget_set_sensitive(self.text_view_scroll, b2i(false))
	C.gtk_widget_add_css_class(self.text_view, c'blurred')
	C.gtk_widget_set_visible(self.hide_button, b2i(false))
	C.gtk_widget_set_visible(self.reveal_button, b2i(true))
}

// --- Virtual methods ------------------------------------------------------

// response routes an AdwAlertDialog response id to confirm/deny, carrying the
// remember flag. Mirrors the `response` virtual method.
//
// TODO(gtk): GObject virtual method — implemented via
// `Dialog.virtual_methods.response.implement(class, &response)` in ghostty.
fn (mut self ClipboardConfirmationDialog) response(response_id string) {
	// The remember switch only exists on libadwaita >= 1.4.
	remember := if self.can_remember && !isnil(self.remember_choice) {
		C.adw_switch_row_get_active(self.remember_choice) != 0
	} else {
		false
	}

	if response_id == 'cancel' {
		if cb := self.on_deny {
			cb(remember)
		}
	} else if response_id == 'ok' {
		if cb := self.on_confirm {
			cb(remember)
		}
	}
}

// dispose releases the clipboard-contents buffer. Mirrors the `dispose` vfunc.
//
// TODO(gtk): GObject vfunc + `gtk.Widget.disposeTemplate` — stubbed. Here we
// unref the text buffer directly.
pub fn (mut self ClipboardConfirmationDialog) dispose() {
	if !isnil(self.clipboard_contents) {
		object_unref(self.clipboard_contents)
		self.clipboard_contents = unsafe { nil }
	}
}

// finalize clears the owned request. Mirrors the `finalize` vfunc.
//
// TODO(gtk): GObject vfunc — in ghostty this `glib.ext.destroy`s the boxed
// request. Here `request` is a plain V optional value freed by the GC.
pub fn (mut self ClipboardConfirmationDialog) finalize() {
	self.request = none
}

// --- GObject reference counting -------------------------------------------
// Mirrors the `Common(Self, Private)` ref helpers.

// ref increments the reference count of the dialog GObject. Mirrors `ref`.
pub fn (mut self ClipboardConfirmationDialog) ref() {
	self.dialog.ref()
}

// unref decrements the reference count of the dialog GObject. Mirrors `unref`.
pub fn (mut self ClipboardConfirmationDialog) unref() {
	self.dialog.unref()
}
