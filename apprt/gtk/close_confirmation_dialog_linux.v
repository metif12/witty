@[has_globals]
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
// The GObject class registration (`defineClass`), the `target` PROPERTY, the
// `.ui` template, and the `close-request`/`cancel` SIGNALS are hand-expanded
// below onto the raw GObject/GTK C API. The wrapping V struct
// `CloseConfirmationDialog` additionally keeps optional V callbacks so the
// response routing stays observable from V without a GObject signal connect.
// The real LOGIC — the target -> heading/body text and the response-id ->
// signal routing — is translated directly.

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

// --- GObject class registration -------------------------------------------
// Hand-expansion of ghostty's `gobject.ext.defineClass` for
// `GhosttyCloseConfirmationDialog`: a `.ui` template, a `target` enum property,
// `close-request`/`cancel` signals, private data, and a dispose vfunc.

// The blueprint (ui/1.2/close-confirmation-dialog.blp) translated to a
// GtkBuilder .ui XML string. `responses [...]` become the AdwAlertDialog
// <responses>/<response> element; `_("x")` become translatable="yes";
// `destructive` becomes appearance="destructive".
const close_confirmation_dialog_ui = '<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <template class="GhosttyCloseConfirmationDialog" parent="GhosttyDialog">
    <property name="close-response">cancel</property>
    <responses>
      <response id="cancel" translatable="yes">Cancel</response>
      <response id="close" translatable="yes" appearance="destructive">Close</response>
    </responses>
  </template>
</interface>
'

// The C-layout private struct mirroring ghostty's `Private` (the `target`
// field). Registered via g_type_add_instance_private and used to back the
// `target` property.
struct C.GhosttyCloseConfirmationDialogPrivate {
mut:
	target int
}

// The GObject type id and the private-data offset (returned by
// g_type_add_instance_private), both registered lazily on first use.
__global g_close_confirmation_dialog_type = GType(0)
__global g_close_confirmation_dialog_priv_offset = int(0)

// Property ids for the get/set vfunc dispatch.
const close_confirmation_prop_target = u32(1)

// close_confirmation_dialog_priv returns the instance private data pointer.
fn close_confirmation_dialog_priv(obj voidptr) &C.GhosttyCloseConfirmationDialogPrivate {
	return &C.GhosttyCloseConfirmationDialogPrivate(C.g_type_instance_get_private(obj, g_close_confirmation_dialog_type))
}

// close_confirmation_dialog_get_property implements the GObjectClass
// get_property vfunc for the `target` property.
fn close_confirmation_dialog_get_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	if property_id == close_confirmation_prop_target {
		priv := close_confirmation_dialog_priv(obj)
		C.g_value_set_int(value, priv.target)
	}
}

// close_confirmation_dialog_set_property implements the GObjectClass
// set_property vfunc for the `target` property.
fn close_confirmation_dialog_set_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	if property_id == close_confirmation_prop_target {
		mut priv := close_confirmation_dialog_priv(obj)
		priv.target = C.g_value_get_int(value)
	}
}

// close_confirmation_dialog_dispose disposes the template and chains to the
// parent. Mirrors the `dispose` vfunc.
fn close_confirmation_dialog_dispose(obj voidptr) {
	C.gtk_widget_dispose_template(obj, g_close_confirmation_dialog_type)
	C.witty_gobject_call_parent_dispose(obj)
}

// close_confirmation_dialog_class_init installs the template, the `target`
// property, the signals, and overrides the get/set/dispose vfuncs. Mirrors the
// ghostty `Class.init`.
fn close_confirmation_dialog_class_init(klass voidptr, class_data voidptr) {
	// Ensure the parent Dialog type is registered (ghostty's ensureType).
	dialog_get_type()

	// Template.
	bytes := C.g_bytes_new_static(close_confirmation_dialog_ui.str, usize(close_confirmation_dialog_ui.len))
	C.gtk_widget_class_set_template(klass, bytes)

	// Property: target (enum, modeled as int).
	pspec := C.g_param_spec_int(c'target', c'target', c'The close target', 0, 3, 0, g_param_readwrite)
	C.witty_gobject_class_set_get_property(klass, voidptr(close_confirmation_dialog_get_property))
	C.witty_gobject_class_set_set_property(klass, voidptr(close_confirmation_dialog_set_property))
	C.witty_gobject_class_set_dispose(klass, voidptr(close_confirmation_dialog_dispose))
	C.g_object_class_install_property(klass, close_confirmation_prop_target, pspec)

	// Signals: close-request, cancel (both void, no params).
	self_type := g_close_confirmation_dialog_type
	C.g_signal_new(c'close-request', self_type, g_signal_run_last, 0, unsafe { nil }, unsafe { nil }, unsafe { nil }, GType(0), 0)
	C.g_signal_new(c'cancel', self_type, g_signal_run_last, 0, unsafe { nil }, unsafe { nil }, unsafe { nil }, GType(0), 0)
}

// close_confirmation_dialog_instance_init builds the template. Mirrors the
// ghostty `init` (instanceInit).
fn close_confirmation_dialog_instance_init(instance voidptr, klass voidptr) {
	C.gtk_widget_init_template(instance)
}

// close_confirmation_dialog_get_type lazily registers the
// GhosttyCloseConfirmationDialog GObject type. Its parent is the GhosttyDialog
// type; it adds instance-private data for the `target` field.
pub fn close_confirmation_dialog_get_type() GType {
	if g_close_confirmation_dialog_type == GType(0) {
		parent := dialog_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size: u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init: voidptr(close_confirmation_dialog_class_init)
			instance_init: voidptr(close_confirmation_dialog_instance_init)
		}
		g_close_confirmation_dialog_type = C.g_type_register_static(parent, c'GhosttyCloseConfirmationDialog', &info, 0)
		g_close_confirmation_dialog_priv_offset = C.g_type_add_instance_private(g_close_confirmation_dialog_type, sizeof(C.GhosttyCloseConfirmationDialogPrivate))
	}
	return g_close_confirmation_dialog_type
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
// Mirrors `gobject.ext.newInstance(Self, .{ .target = target })`: it builds the
// GObject (running the `.ui` template init) with the `target` property set.
pub fn close_confirmation_dialog_new(target CloseTarget) &CloseConfirmationDialog {
	obj := C.g_object_new(close_confirmation_dialog_get_type(), c'target', int(target), &char(unsafe { nil }))
	C.g_signal_connect_data(obj, c'response', GCallback(voidptr(close_confirmation_native_response_cb)), unsafe { nil }, unsafe { nil }, 0)
	return &CloseConfirmationDialog{
		dialog: Dialog{
			obj: obj
		}
		target: target
	}
}

// AdwAlertDialog and AdwMessageDialog both expose the same response signal.
// Ghostty overrides the corresponding virtual method; connecting the inherited
// signal here provides the same routing without relying on a generated Zig
// virtual-method trampoline.
fn close_confirmation_native_response_cb(obj GObject, response_id &char, user_data voidptr) {
	_ = user_data
	if isnil(obj) || isnil(response_id) {
		return
	}
	response := unsafe { cstring_to_vstring(response_id) }
	if response == 'close' {
		C.g_signal_emit_by_name(obj, c'close-request')
	} else {
		C.g_signal_emit_by_name(obj, c'cancel')
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
// else -> cancel. In addition to emitting the real GObject signal, it invokes
// the optional V callback so the routing is observable from V.
fn (mut self CloseConfirmationDialog) response(response_id string) {
	if response_id == 'close' {
		if !isnil(self.dialog.obj) {
			C.g_signal_emit_by_name(self.dialog.obj, c'close-request')
		}
		if cb := self.on_close_request {
			cb()
		}
	} else {
		if !isnil(self.dialog.obj) {
			C.g_signal_emit_by_name(self.dialog.obj, c'cancel')
		}
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
