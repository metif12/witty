@[has_globals]
module gtk

// dialog_linux.v - Base dialog helper (GhosttyDialog).
//
// Translated from ghostty/src/apprt/gtk/class/dialog.zig.
//
// In ghostty, `Dialog` is a GObject class that abstracts over `adw.AlertDialog`
// (libadwaita >= 1.5) and `adw.MessageDialog` (older libadwaita), chosen at
// comptime based on the linked Adwaita version. It gives subclasses a stable
// `present`/`close`/`response` surface so that once support for Adwaita <= 1.2
// is dropped the abstraction can be removed entirely and `adw.AlertDialog` used
// directly.
//
// V has no GObject class-registration / comptime machinery, so:
//   * The class is modeled as a plain V struct `Dialog` wrapping the underlying
//     GObject pointer (`obj`). The "parent" (AlertDialog vs MessageDialog) is
//     resolved at RUNTIME via `adw_supports_dialogs()` instead of at comptime.
//   * GObject type registration (`defineClass`), the forwarded `response`
//     virtual method, and the `Common` ref helpers are STUBBED — see the
//     "GObject class registration" section — with bodies that type-check.
//   * The real `present`/`close` LOGIC (AlertDialog.present vs the
//     MessageDialog transient-for/present dance) is translated directly.

// --- New opaque handle aliases --------------------------------------------
// (Grep-verified: none of these aliases or `fn C.*` are declared elsewhere in
// the module.)

// AdwDialog is an AdwDialog* (the base for AdwAlertDialog, 1.5+).
pub type AdwDialog = voidptr

// AdwAlertDialog is an AdwAlertDialog* (libadwaita >= 1.5).
pub type AdwAlertDialog = voidptr

// AdwMessageDialog is an AdwMessageDialog* (older libadwaita fallback).
pub type AdwMessageDialog = voidptr

// GtkTextBuffer is a gtk.TextBuffer* (used by the config/clipboard dialogs).
pub type GtkTextBuffer = voidptr

// --- New GTK/Adw C bindings -----------------------------------------------
// Only functions not already declared anywhere else in the module.

// AdwDialog (1.5+): present against a parent widget, force-close.
fn C.adw_dialog_present(dialog AdwDialog, parent GtkWidget)
fn C.adw_dialog_force_close(dialog AdwDialog)

// AdwAlertDialog / AdwMessageDialog heading + body setters. The AlertDialog
// and MessageDialog APIs are the same shape for these calls.
fn C.adw_alert_dialog_set_heading(dialog AdwAlertDialog, heading &char)
fn C.adw_alert_dialog_set_body(dialog AdwAlertDialog, body &char)
fn C.adw_message_dialog_set_heading(dialog AdwMessageDialog, heading &char)
fn C.adw_message_dialog_set_body(dialog AdwMessageDialog, body &char)

// GtkWindow transient-for + present/close for the MessageDialog fallback.
// NOTE: gtk_window_present / gtk_window_close are declared in window_linux.v —
// reused here, NOT redeclared.
fn C.gtk_window_set_transient_for(window GtkWindow, parent GtkWindow)
fn C.gtk_widget_get_root(widget GtkWidget) GtkWidget

// Parent get_type() functions for the (runtime-chosen) Dialog base class.
fn C.adw_alert_dialog_get_type() GType
fn C.adw_message_dialog_get_type() GType

// Shared helpers for the dialog subclasses' hand-expanded vfunc chaining.
// g_type_check_instance_get_class returns the GTypeClass* of an instance; its
// parent (g_type_class_peek_parent, declared in gobject_c_linux.v) is the
// GObjectClass whose dispose/finalize vfuncs we chain to.
fn C.g_type_check_instance_get_class(instance voidptr) voidptr

// DisposeFn / FinalizeFn are the GObjectClass dispose/finalize vfunc signatures
// (a single GObject* argument). Used to call the parent-class vfunc pointer.
pub type DisposeFn = fn (obj voidptr)
pub type FinalizeFn = fn (obj voidptr)

// --- GObject class registration -------------------------------------------
// Hand-expansion of ghostty's `gobject.ext.defineClass(Self, .{ .name =
// "GhosttyDialog", .classInit = &Class.init, .parent_class = &Class.parent })`.
//
// `Dialog` in ghostty has NO instanceInit, NO private data, NO properties, NO
// template and NO signals of its own — it only forwards the parent's `response`
// virtual method. So the registration is minimal: an empty class_init and a
// lazily-registered type whose parent is resolved at runtime (AlertDialog for
// libadwaita >= 1.5, else MessageDialog), mirroring ghostty's comptime
// `Parent` selection.

// The GObject type id, registered lazily on first use.
__global g_dialog_type = GType(0)

// dialog_class_init mirrors the empty ghostty `Dialog.Class.init`.
fn dialog_class_init(klass voidptr, class_data voidptr) {
	// Nothing to do: Dialog installs no template/properties/signals.
}

// dialog_get_type lazily registers the GhosttyDialog GObject type. Queries the
// runtime-chosen parent (AdwAlertDialog vs AdwMessageDialog) for its
// class/instance sizes.
pub fn dialog_get_type() GType {
	if g_dialog_type == GType(0) {
		parent := if adw_supports_dialogs() {
			C.adw_alert_dialog_get_type()
		} else {
			C.adw_message_dialog_get_type()
		}
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size:    u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init:    voidptr(dialog_class_init)
		}
		g_dialog_type = C.g_type_register_static(parent, c'GhosttyDialog', &info, 0)
	}
	return g_dialog_type
}

// --- Dialog ---------------------------------------------------------------

// Dialog is the base dialog GObject (`GhosttyDialog`). Modeled as a struct
// wrapping the GObject pointer. Its parent class is `adw.AlertDialog` when the
// runtime libadwaita supports dialogs, else `adw.MessageDialog`.
@[heap]
pub struct Dialog {
mut:
	// The underlying AdwAlertDialog/AdwMessageDialog GObject, an instance of the
	// GhosttyDialog type registered by `dialog_get_type()`. Subclasses create
	// the real instance and stash the pointer here.
	obj GObject = unsafe { nil }
}

// present shows the dialog, attaching to the given parent widget. Mirrors
// `Dialog.present`.
//
// The comptime `switch (Parent)` becomes a runtime branch on
// `adw_supports_dialogs()`.
pub fn (mut self Dialog) present(parent GtkWidget) {
	if adw_supports_dialogs() {
		// AdwAlertDialog path: present directly against the parent widget.
		C.adw_dialog_present(AdwDialog(self.obj), parent)
		return
	}

	// AdwMessageDialog path.
	//
	// Reset the previous parent window.
	C.gtk_window_set_transient_for(GtkWindow(self.obj), unsafe { nil })

	// We need to get the window for the parent in order to set the
	// transient-for property on the MessageDialog.
	if !isnil(parent) {
		root := C.gtk_widget_get_root(parent)
		if !isnil(root) {
			// TODO(gtk): ghostty casts the root to `gtk.Window` via
			// `gobject.ext.cast` (a runtime type check). Without the GObject type
			// system here we forward the root directly (it is a GtkWindow for a
			// realized toplevel).
			C.gtk_window_set_transient_for(GtkWindow(self.obj), GtkWindow(root))
		}
	}

	C.gtk_window_present(GtkWindow(self.obj))
}

// close closes the dialog. Mirrors `Dialog.close`.
pub fn (mut self Dialog) close() {
	if adw_supports_dialogs() {
		C.adw_dialog_force_close(AdwDialog(self.obj))
	} else {
		C.gtk_window_close(GtkWindow(self.obj))
	}
}

// set_heading sets the dialog heading (title), abstracting over the
// AlertDialog/MessageDialog parent. This mirrors the `self.as(Dialog.Parent)
// .setHeading(...)` calls that subclasses make in ghostty.
pub fn (mut self Dialog) set_heading(heading &char) {
	if adw_supports_dialogs() {
		C.adw_alert_dialog_set_heading(AdwAlertDialog(self.obj), heading)
	} else {
		C.adw_message_dialog_set_heading(AdwMessageDialog(self.obj), heading)
	}
}

// set_body sets the dialog body text, abstracting over the parent. Mirrors
// `self.as(Dialog.Parent).setBody(...)`.
pub fn (mut self Dialog) set_body(body &char) {
	if adw_supports_dialogs() {
		C.adw_alert_dialog_set_body(AdwAlertDialog(self.obj), body)
	} else {
		C.adw_message_dialog_set_body(AdwMessageDialog(self.obj), body)
	}
}

// --- GObject reference counting -------------------------------------------
// Mirrors the `Common(Self, null)` ref helpers.

// ref increments the reference count of the Dialog GObject. Mirrors `ref`.
pub fn (mut self Dialog) ref() {
	if !isnil(self.obj) {
		object_ref(self.obj)
	}
}

// unref decrements the reference count of the Dialog GObject. Mirrors `unref`.
pub fn (mut self Dialog) unref() {
	if !isnil(self.obj) {
		object_unref(self.obj)
	}
}

// --- i18n -----------------------------------------------------------------

// i18n_ translates a message via the process gettext domain. Mirrors ghostty's
// `i18n._`, which resolves against the global gettext domain.
//
// TODO(gtk): the gettext domain is not yet initialized in this apprt (see
// application_linux.v `initGlobalDomain` TODO). Until then this is an identity
// translation — it returns the message unchanged so the dialog wiring stays
// faithful while producing readable (untranslated) strings.
pub fn i18n_(msg string) string {
	return msg
}
