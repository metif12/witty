@[has_globals]
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
// The GObject class registration (`defineClass`), the four PROPERTIES, the
// `.ui` template + child bindings + template callbacks, and the
// `confirm`/`deny` SIGNALS are hand-expanded below onto the raw GObject/GTK C
// API. The V struct `ClipboardConfirmationDialog` keeps the private fields +
// optional V callbacks so the response routing stays observable from V.
// The real LOGIC — the request -> heading/body text (prop_request), the blur /
// reveal / hide widget-state toggles, and the response-id -> signal routing
// (with the remember flag) — is translated directly.
//
// NOTE(types): ghostty's `request` is a boxed `?*apprt.ClipboardRequest` and
// `clipboard-contents` is an object `?*gtk.TextBuffer`. witty's request is a
// plain V struct with no boxed GType, so the `request` property is installed
// against `G_TYPE_POINTER`; `clipboard-contents` is installed against
// `G_TYPE_OBJECT`. The 1.4 blueprint (with the AdwSwitchRow remember switch) is
// used — the newest — matching `adw_supports_switch_row()` at runtime.

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

fn C.gtk_text_view_set_buffer(text_view GtkTextView, buffer GtkTextBuffer)

// Template-callback binding.
fn C.gtk_widget_class_bind_template_callback_full(widget_class voidptr, callback_name &char, callback_symbol voidptr)

// GValue pointer accessors + a pointer GParamSpec (for the boxed-less request
// property). Not declared in gobject_c_linux.v.
fn C.g_value_get_pointer(value voidptr) voidptr

fn C.g_value_set_pointer(value voidptr, v_pointer voidptr)

fn C.g_param_spec_pointer(name &char, nick &char, blurb &char, flags int) &C.GParamSpec

// --- GObject class registration -------------------------------------------
// Hand-expansion of ghostty's `gobject.ext.defineClass` for
// `GhosttyClipboardConfirmationDialog`: a `.ui` template with child bindings +
// callbacks, four properties (blur, can-remember, clipboard-contents, request),
// `confirm`/`deny` signals (each carrying the remember bool), private data, and
// dispose + finalize vfuncs.

// GObject fundamental types used for the property pspecs.
// G_TYPE_BOOLEAN = 5 << 2, G_TYPE_POINTER = 17 << 2.
const g_type_boolean = GType(5 << 2)
const g_type_pointer = GType(17 << 2)

// The blueprint (ui/1.4/clipboard-confirmation-dialog.blp, the newest — with
// the AdwSwitchRow remember switch) translated to a GtkBuilder .ui XML string.
// `styles [...]` -> <style><class .../></style>; `_("x")` -> translatable="yes"
// (`suggested`/`destructive` -> appearance="..."); `notify::blur =>
// $notify_blur()` -> <signal name="notify::blur" handler="notify_blur"/>;
// `clicked => $reveal_clicked()` -> <signal name="clicked"
// handler="reveal_clicked"/>; `[overlay]` children -> <child type="overlay">;
// `bind template.X` -> <binding>/<lookup name="X">Self</lookup></binding>.
const clipboard_confirmation_dialog_ui = '<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <template class="GhosttyClipboardConfirmationDialog" parent="GhosttyDialog">
    <style>
      <class name="clipboard-confirmation-dialog"/>
    </style>
    <signal name="notify::blur" handler="notify_blur"/>
    <signal name="notify::request" handler="notify_request"/>
    <property name="heading" translatable="yes">Authorize Clipboard Access</property>
    <property name="body">If you see this text, there is a bug in Ghostty. Please report it.</property>
    <responses>
      <response id="cancel" translatable="yes" appearance="suggested">Deny</response>
      <response id="ok" translatable="yes" appearance="destructive">Allow</response>
    </responses>
    <property name="default-response">cancel</property>
    <property name="close-response">cancel</property>
    <property name="extra-child">
      <object class="GtkListBox">
        <property name="selection-mode">none</property>
        <child>
          <object class="GtkOverlay">
            <style>
              <class name="osd"/>
              <class name="clipboard-overlay"/>
            </style>
            <child>
              <object class="GtkScrolledWindow" id="text_view_scroll">
                <property name="width-request">500</property>
                <property name="height-request">200</property>
                <child>
                  <object class="GtkTextView" id="text_view">
                    <style>
                      <class name="clipboard-contents"/>
                    </style>
                    <property name="cursor-visible">false</property>
                    <property name="editable">false</property>
                    <property name="monospace">true</property>
                    <property name="top-margin">8</property>
                    <property name="left-margin">8</property>
                    <property name="bottom-margin">8</property>
                    <property name="right-margin">8</property>
                    <binding name="buffer">
                      <lookup name="clipboard-contents">GhosttyClipboardConfirmationDialog</lookup>
                    </binding>
                  </object>
                </child>
              </object>
            </child>
            <child type="overlay">
              <object class="GtkButton" id="reveal_button">
                <signal name="clicked" handler="reveal_clicked"/>
                <property name="visible">false</property>
                <property name="halign">end</property>
                <property name="valign">start</property>
                <property name="margin-end">12</property>
                <property name="margin-top">12</property>
                <child>
                  <object class="GtkImage">
                    <property name="icon-name">view-reveal-symbolic</property>
                  </object>
                </child>
              </object>
            </child>
            <child type="overlay">
              <object class="GtkButton" id="hide_button">
                <signal name="clicked" handler="hide_clicked"/>
                <property name="visible">false</property>
                <property name="halign">end</property>
                <property name="valign">start</property>
                <property name="margin-end">12</property>
                <property name="margin-top">12</property>
                <style>
                  <class name="opaque"/>
                </style>
                <child>
                  <object class="GtkImage">
                    <property name="icon-name">view-conceal-symbolic</property>
                  </object>
                </child>
              </object>
            </child>
          </object>
        </child>
        <child>
          <object class="AdwSwitchRow" id="remember_choice">
            <style>
              <class name="card"/>
            </style>
            <binding name="visible">
              <lookup name="can-remember">GhosttyClipboardConfirmationDialog</lookup>
            </binding>
            <property name="title" translatable="yes">Remember choice for this split</property>
            <property name="subtitle" translatable="yes">Reload configuration to show this prompt again</property>
          </object>
      </object>
    </property>
  </template>
</interface>
'

// The C-layout private struct mirroring ghostty\'s `Private`: the four property
// fields followed by the template-child pointers (bound at their offsets).
struct C.GhosttyClipboardConfirmationDialogPrivate {
mut:
	request            voidptr
	clipboard_contents voidptr
	blur               int
	can_remember       int
	text_view_scroll   voidptr
	text_view          voidptr
	reveal_button      voidptr
	hide_button        voidptr
	remember_choice    voidptr
}

// The GObject type id and private-data offset, registered lazily.
__global g_clipboard_confirmation_dialog_type = GType(0)
__global g_clipboard_confirmation_dialog_priv_offset = int(0)

// Property ids for the get/set vfunc dispatch.
const clipboard_prop_blur = u32(1)
const clipboard_prop_can_remember = u32(2)
const clipboard_prop_clipboard_contents = u32(3)
const clipboard_prop_request = u32(4)

fn clipboard_confirmation_dialog_priv(obj voidptr) &C.GhosttyClipboardConfirmationDialogPrivate {
	return &C.GhosttyClipboardConfirmationDialogPrivate(C.g_type_instance_get_private(obj, g_clipboard_confirmation_dialog_type))
}

// clipboard_confirmation_dialog_get_property implements get_property for all
// four properties.
fn clipboard_confirmation_dialog_get_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	priv := clipboard_confirmation_dialog_priv(obj)
	match property_id {
		clipboard_prop_blur { C.g_value_set_boolean(value, priv.blur) }
		clipboard_prop_can_remember { C.g_value_set_boolean(value, priv.can_remember) }
		clipboard_prop_clipboard_contents { C.g_value_set_object(value, priv.clipboard_contents) }
		clipboard_prop_request { C.g_value_set_pointer(value, priv.request) }
		else {}
	}
}

// clipboard_confirmation_dialog_set_property implements set_property for all
// four properties. The object property takes a reference (matching the default
// object-property machinery ghostty relies on).
fn clipboard_confirmation_dialog_set_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	mut priv := clipboard_confirmation_dialog_priv(obj)
	match property_id {
		clipboard_prop_blur {
			priv.blur = C.g_value_get_boolean(value)
		}
		clipboard_prop_can_remember {
			priv.can_remember = C.g_value_get_boolean(value)
		}
		clipboard_prop_clipboard_contents {
			if !isnil(priv.clipboard_contents) {
				object_unref(GObject(priv.clipboard_contents))
			}
			newv := GObject(C.g_value_get_object(value))
			if !isnil(newv) {
				priv.clipboard_contents = voidptr(object_ref(newv))
			} else {
				priv.clipboard_contents = unsafe { nil }
			}
		}
		clipboard_prop_request {
			priv.request = C.g_value_get_pointer(value)
		}
		else {}
	}
}

// clipboard_confirmation_dialog_dispose unrefs the clipboard contents, disposes
// the template and chains to the parent. Mirrors the `dispose` vfunc.
fn clipboard_confirmation_dialog_dispose(obj voidptr) {
	mut priv := clipboard_confirmation_dialog_priv(obj)
	if !isnil(priv.clipboard_contents) {
		object_unref(GObject(priv.clipboard_contents))
		priv.clipboard_contents = unsafe { nil }
	}
	C.gtk_widget_dispose_template(obj, g_clipboard_confirmation_dialog_type)
	C.witty_gobject_call_parent_dispose(obj)
}

// clipboard_confirmation_dialog_finalize clears the boxed request and chains to
// the parent. Mirrors the `finalize` vfunc.
fn clipboard_confirmation_dialog_finalize(obj voidptr) {
	mut priv := clipboard_confirmation_dialog_priv(obj)
	priv.request = unsafe { nil }
	C.witty_gobject_call_parent_finalize(obj)
}

// --- Template callbacks (C-callable) --------------------------------------
// These operate on the GObject private directly (mirroring ghostty, whose
// callbacks use `self.private()`).

fn clipboard_confirmation_notify_blur_cb(obj voidptr, pspec voidptr, ud voidptr) {
	priv := clipboard_confirmation_dialog_priv(obj)
	if priv.blur != 0 {
		C.gtk_widget_set_sensitive(priv.text_view_scroll, b2i(false))
		C.gtk_widget_add_css_class(priv.text_view, c'blurred')
		C.gtk_widget_set_visible(priv.reveal_button, b2i(true))
		C.gtk_widget_set_visible(priv.hide_button, b2i(false))
	} else {
		C.gtk_widget_set_sensitive(priv.text_view_scroll, b2i(true))
		C.gtk_widget_remove_css_class(priv.text_view, c'blurred')
		C.gtk_widget_set_visible(priv.reveal_button, b2i(false))
		C.gtk_widget_set_visible(priv.hide_button, b2i(false))
	}
}

fn clipboard_confirmation_notify_request_cb(obj voidptr, pspec voidptr, ud voidptr) {
	// The request heading/body is applied V-side (prop_request) since the
	// request is a plain V value, not a boxed GObject. Nothing to do here.
}

fn clipboard_confirmation_reveal_clicked_cb(button voidptr, obj voidptr) {
	priv := clipboard_confirmation_dialog_priv(obj)
	C.gtk_widget_set_sensitive(priv.text_view_scroll, b2i(true))
	C.gtk_widget_remove_css_class(priv.text_view, c'blurred')
	C.gtk_widget_set_visible(priv.hide_button, b2i(true))
	C.gtk_widget_set_visible(priv.reveal_button, b2i(false))
}

fn clipboard_confirmation_hide_clicked_cb(button voidptr, obj voidptr) {
	priv := clipboard_confirmation_dialog_priv(obj)
	C.gtk_widget_set_sensitive(priv.text_view_scroll, b2i(false))
	C.gtk_widget_add_css_class(priv.text_view, c'blurred')
	C.gtk_widget_set_visible(priv.hide_button, b2i(false))
	C.gtk_widget_set_visible(priv.reveal_button, b2i(true))
}

// clipboard_confirmation_dialog_class_init installs the template, binds the
// template children + callbacks, installs the four properties, registers the
// confirm/deny signals, and overrides the get/set/dispose/finalize vfuncs.
fn clipboard_confirmation_dialog_class_init(klass voidptr, class_data voidptr) {
	bytes := C.g_bytes_new_static(clipboard_confirmation_dialog_ui.str, usize(clipboard_confirmation_dialog_ui.len))
	C.gtk_widget_class_set_template(klass, bytes)

	// Template child bindings (into the private struct).
	off := g_clipboard_confirmation_dialog_priv_offset
	C.gtk_widget_class_bind_template_child_full(klass, c'text_view_scroll', 0, off + int(__offsetof(C.GhosttyClipboardConfirmationDialogPrivate, text_view_scroll)))
	C.gtk_widget_class_bind_template_child_full(klass, c'text_view', 0, off + int(__offsetof(C.GhosttyClipboardConfirmationDialogPrivate, text_view)))
	C.gtk_widget_class_bind_template_child_full(klass, c'hide_button', 0, off + int(__offsetof(C.GhosttyClipboardConfirmationDialogPrivate, hide_button)))
	C.gtk_widget_class_bind_template_child_full(klass, c'reveal_button', 0, off + int(__offsetof(C.GhosttyClipboardConfirmationDialogPrivate, reveal_button)))
	if adw_supports_switch_row() {
		C.gtk_widget_class_bind_template_child_full(klass, c'remember_choice', 0, off + int(__offsetof(C.GhosttyClipboardConfirmationDialogPrivate, remember_choice)))
	}

	// Template callbacks.
	C.gtk_widget_class_bind_template_callback_full(klass, c'reveal_clicked', voidptr(clipboard_confirmation_reveal_clicked_cb))
	C.gtk_widget_class_bind_template_callback_full(klass, c'hide_clicked', voidptr(clipboard_confirmation_hide_clicked_cb))
	C.gtk_widget_class_bind_template_callback_full(klass, c'notify_blur', voidptr(clipboard_confirmation_notify_blur_cb))
	C.gtk_widget_class_bind_template_callback_full(klass, c'notify_request', voidptr(clipboard_confirmation_notify_request_cb))

	// Properties.
	blur_pspec := C.g_param_spec_boolean(c'blur', c'blur', c'Whether contents are blurred', 0, g_param_readwrite)
	can_remember_pspec := C.g_param_spec_boolean(c'can-remember', c'can-remember', c'Whether the choice can be remembered', 0, g_param_readwrite)
	contents_pspec := C.g_param_spec_object(c'clipboard-contents', c'clipboard-contents', c'The clipboard contents', C.g_object_get_type(), g_param_readwrite)
	request_pspec := C.g_param_spec_pointer(c'request', c'request', c'The clipboard request', g_param_readwrite)
	C.witty_gobject_class_set_get_property(klass, voidptr(clipboard_confirmation_dialog_get_property))
	C.witty_gobject_class_set_set_property(klass, voidptr(clipboard_confirmation_dialog_set_property))
	C.witty_gobject_class_set_dispose(klass, voidptr(clipboard_confirmation_dialog_dispose))
	C.witty_gobject_class_set_finalize(klass, voidptr(clipboard_confirmation_dialog_finalize))
	C.g_object_class_install_property(klass, clipboard_prop_blur, blur_pspec)
	C.g_object_class_install_property(klass, clipboard_prop_can_remember, can_remember_pspec)
	C.g_object_class_install_property(klass, clipboard_prop_clipboard_contents, contents_pspec)
	C.g_object_class_install_property(klass, clipboard_prop_request, request_pspec)

	// Signals: confirm, deny (each carrying a bool "remember" param).
	mut bool_param := g_type_boolean
	C.g_signal_new(c'confirm', g_clipboard_confirmation_dialog_type, g_signal_run_last, 0, unsafe { nil }, unsafe { nil }, unsafe { nil }, GType(0), 1, bool_param)
	C.g_signal_new(c'deny', g_clipboard_confirmation_dialog_type, g_signal_run_last, 0, unsafe { nil }, unsafe { nil }, unsafe { nil }, GType(0), 1, bool_param)
}

fn clipboard_confirmation_dialog_instance_init(instance voidptr, klass voidptr) {
	C.gtk_widget_init_template(instance)
}

// clipboard_confirmation_dialog_get_type lazily registers the
// GhosttyClipboardConfirmationDialog GObject type, parented to GhosttyDialog,
// with instance-private data.
pub fn clipboard_confirmation_dialog_get_type() GType {
	if g_clipboard_confirmation_dialog_type == GType(0) {
		parent := dialog_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size: u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init: voidptr(clipboard_confirmation_dialog_class_init)
			instance_init: voidptr(clipboard_confirmation_dialog_instance_init)
		}
		g_clipboard_confirmation_dialog_type = C.g_type_register_static(parent, c'GhosttyClipboardConfirmationDialog', &info, 0)
		g_clipboard_confirmation_dialog_priv_offset = C.g_type_add_instance_private(g_clipboard_confirmation_dialog_type, sizeof(C.GhosttyClipboardConfirmationDialogPrivate))
	}
	return g_clipboard_confirmation_dialog_type
}

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

	// Template children. Bound in the GObject private via
	// `gtk_widget_class_bind_template_child_full` and read back into this wrapper
	// by `clipboard_confirmation_dialog_new`. Mirrors the `Private` bindings.
	text_view_scroll GtkScrolledWindow = unsafe { nil }
	text_view        GtkTextView = unsafe { nil }
	reveal_button    GtkButton = unsafe { nil }
	hide_button      GtkButton = unsafe { nil }
	remember_choice  AdwSwitchRow = unsafe { nil }

	// Signal callbacks. Ghostty emits GObject `confirm` / `deny` signals, each
	// carrying the remember flag; modeled here as optional V callbacks.
	//
	// TODO(gtk): GObject signals — registered via `gobject.ext.defineSignal`.
	on_confirm ?fn (remember bool)
	on_deny    ?fn (remember bool)

	// V owns the request payload and text while the dialog is presented. The
	// generated Zig bindings keep the same values in boxed/object properties.
	text string
}

// clipboard_confirmation_dialog_new creates a new dialog. Mirrors
// `gobject.ext.newInstance(Self, .{})` + the `init` instanceInit which triggers
// the initial `propBlur`/`propRequest`. The template children are read back from
// the GObject private into the V wrapper.
pub fn clipboard_confirmation_dialog_new() &ClipboardConfirmationDialog {
	obj := C.g_object_new(clipboard_confirmation_dialog_get_type(), &char(unsafe { nil }))
	C.g_signal_connect_data(obj, c'response', GCallback(voidptr(clipboard_confirmation_native_response_cb)), unsafe { nil }, unsafe { nil }, 0)
	priv := clipboard_confirmation_dialog_priv(obj)
	mut self := &ClipboardConfirmationDialog{
		dialog: Dialog{
			obj: obj
		}
		can_remember: adw_supports_switch_row()
		text_view_scroll: priv.text_view_scroll
		text_view: priv.text_view
		reveal_button: priv.reveal_button
		hide_button: priv.hide_button
		remember_choice: priv.remember_choice
	}
	// Trigger initial values (matches ghostty's `init`).
	self.prop_blur()
	self.prop_request()
	return self
}

// clipboard_confirmation_dialog_new_for_request constructs the populated
// dialog used by Surface.show_clipboard_confirmation.
pub fn clipboard_confirmation_dialog_new_for_request(req apprt.ClipboardRequest, text string) &ClipboardConfirmationDialog {
	mut self := clipboard_confirmation_dialog_new()
	buffer := C.gtk_text_buffer_new(unsafe { nil })
	C.gtk_text_buffer_insert_at_cursor(buffer, &char(text.str), text.len)

	self.request = req
	self.text = text
	self.clipboard_contents = buffer
	self.can_remember = req.kind in [.osc_52_read, .osc_52_write]

	mut priv := clipboard_confirmation_dialog_priv(self.dialog.obj)
	priv.can_remember = b2i(self.can_remember)
	priv.clipboard_contents = voidptr(object_ref(buffer))
	C.gtk_text_view_set_buffer(self.text_view, buffer)
	if !isnil(self.remember_choice) {
		C.gtk_widget_set_visible(self.remember_choice, b2i(self.can_remember))
	}
	self.prop_request()
	return self
}

// Route the inherited Adwaita response signal to Ghostty's confirm/deny
// signals. This is the runtime C-API equivalent of the Zig response-vfunc
// override.
fn clipboard_confirmation_native_response_cb(obj GObject, response_id &char, user_data voidptr) {
	_ = user_data
	if isnil(obj) || isnil(response_id) {
		return
	}
	priv := clipboard_confirmation_dialog_priv(obj)
	remember := priv.can_remember != 0 && !isnil(priv.remember_choice)
		&& C.adw_switch_row_get_active(priv.remember_choice) != 0
	response := unsafe { cstring_to_vstring(response_id) }
	if response == 'cancel' {
		C.g_signal_emit_by_name(obj, c'deny', b2i(remember))
	} else if response == 'ok' {
		C.g_signal_emit_by_name(obj, c'confirm', b2i(remember))
	}
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
		if !isnil(self.dialog.obj) {
			C.g_signal_emit_by_name(self.dialog.obj, c'deny', b2i(remember))
		}
		if cb := self.on_deny {
			cb(remember)
		}
	} else if response_id == 'ok' {
		if !isnil(self.dialog.obj) {
			C.g_signal_emit_by_name(self.dialog.obj, c'confirm', b2i(remember))
		}
		if cb := self.on_confirm {
			cb(remember)
		}
	}
}

// dispose releases the clipboard-contents buffer held by the V wrapper. The
// GObject-side dispose (buffer unref + gtk_widget_dispose_template + parent
// chain) is the `clipboard_confirmation_dialog_dispose` vfunc registered above.
pub fn (mut self ClipboardConfirmationDialog) dispose() {
	if !isnil(self.clipboard_contents) {
		object_unref(self.clipboard_contents)
		self.clipboard_contents = unsafe { nil }
	}
}

// finalize clears the owned request on the V wrapper. The GObject-side finalize
// (request clear + parent chain) is the `clipboard_confirmation_dialog_finalize`
// vfunc registered above. Here `request` is a plain V optional value.
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
