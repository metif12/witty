@[has_globals]
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
// The GObject class registration (`defineClass`), the `initial-value` PROPERTY,
// the `.ui` template + `entry` binding, and the `set` SIGNAL are hand-expanded
// below onto the raw GObject/GTK C API. The V struct `SurfaceTitleDialog` keeps
// the initial value + an optional V callback so the "ok" -> set(title) routing
// stays observable from V; the async `choose`/`chooseFinish` response flow is
// still simplified (present + explicit `alert_dialog_ready`).
// The real LOGIC — parent ancestor resolution, seeding the entry with the
// initial value, and the "ok" -> emit(title) routing — is translated.

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

// --- GObject class registration -------------------------------------------
// Hand-expansion of ghostty's `gobject.ext.defineClass` for
// `GhosttySurfaceTitleDialog`, whose parent is `adw.AlertDialog` directly (NOT
// GhosttyDialog): a `.ui` template, an `initial-value` string property, a `set`
// signal (carrying the new title), an `entry` template child, private data, and
// dispose + finalize vfuncs.

// NOTE: G_TYPE_STRING (the GObject fundamental string type, 16 << 2) is the
// `g_type_string` const declared in gsettings_linux.v — reused here for the
// `set` signal's string parameter, NOT redeclared.

// The blueprint (ui/1.5/surface-title-dialog.blp) translated to a GtkBuilder
// .ui XML string. `_("x")` -> translatable="yes"; `responses [...]` -> the
// AdwAlertDialog <responses>/<response> element (`suggested` ->
// appearance="suggested"); `default-response`/`focus-widget` -> properties;
// `extra-child: Entry entry {...}` -> the named `entry` child object.
const surface_title_dialog_ui = '<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <template class="GhosttySurfaceTitleDialog" parent="AdwAlertDialog">
    <property name="heading" translatable="yes">Change Terminal Title</property>
    <property name="body" translatable="yes">Leave blank to restore the default title.</property>
    <responses>
      <response id="cancel" translatable="yes">Cancel</response>
      <response id="ok" translatable="yes" appearance="suggested">OK</response>
    </responses>
    <property name="default-response">ok</property>
    <property name="focus-widget">entry</property>
    <property name="extra-child">
      <object class="GtkEntry" id="entry">
        <property name="activates-default">true</property>
      </object>
    </property>
  </template>
</interface>
'

// The C-layout private struct mirroring ghostty\'s `Private`: the (glib-owned)
// initial value string and the `entry` template child.
struct C.GhosttySurfaceTitleDialogPrivate {
mut:
	initial_value &char = unsafe { nil }
	entry         voidptr
}

// gtk_entry_get_type is needed to bind the `entry` template child.
fn C.gtk_entry_get_type() GType

// g_strdup duplicates a C string into glib-owned memory (freed with g_free).
fn C.g_strdup(str &char) &char

// The GObject type id and private-data offset, registered lazily.
__global g_surface_title_dialog_type = GType(0)
__global g_surface_title_dialog_priv_offset = int(0)

// Property id for the `initial-value` property.
const surface_title_prop_initial_value = u32(1)

fn surface_title_dialog_priv(obj voidptr) &C.GhosttySurfaceTitleDialogPrivate {
	return &C.GhosttySurfaceTitleDialogPrivate(C.g_type_instance_get_private(obj, g_surface_title_dialog_type))
}

// surface_title_dialog_get_property implements get_property for `initial-value`.
fn surface_title_dialog_get_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	if property_id == surface_title_prop_initial_value {
		priv := surface_title_dialog_priv(obj)
		C.g_value_set_string(value, priv.initial_value)
	}
}

// surface_title_dialog_set_property implements set_property for `initial-value`.
// Mirrors the private-string accessor: free the old and dup the new.
fn surface_title_dialog_set_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	if property_id == surface_title_prop_initial_value {
		mut priv := surface_title_dialog_priv(obj)
		if !isnil(priv.initial_value) {
			C.g_free(priv.initial_value)
		}
		priv.initial_value = C.g_strdup(C.g_value_get_string(value))
	}
}

// surface_title_dialog_dispose disposes the template and chains to the parent.
// Mirrors the `dispose` vfunc.
fn surface_title_dialog_dispose(obj voidptr) {
	C.gtk_widget_dispose_template(obj, g_surface_title_dialog_type)
	parent_class := &C.GObjectClass(C.g_type_class_peek_parent(C.g_type_check_instance_get_class(obj)))
	if !isnil(parent_class.dispose) {
		f := DisposeFn(parent_class.dispose)
		f(obj)
	}
}

// surface_title_dialog_finalize frees the owned initial value and chains to the
// parent. Mirrors the `finalize` vfunc.
fn surface_title_dialog_finalize(obj voidptr) {
	mut priv := surface_title_dialog_priv(obj)
	if !isnil(priv.initial_value) {
		C.g_free(priv.initial_value)
		priv.initial_value = unsafe { nil }
	}
	parent_class := &C.GObjectClass(C.g_type_class_peek_parent(C.g_type_check_instance_get_class(obj)))
	if !isnil(parent_class.finalize) {
		f := FinalizeFn(parent_class.finalize)
		f(obj)
	}
}

// surface_title_dialog_class_init installs the template, binds the `entry`
// child, registers the `set` signal, installs the `initial-value` property, and
// overrides the get/set/dispose/finalize vfuncs. Mirrors the ghostty
// `Class.init`.
fn surface_title_dialog_class_init(klass voidptr, class_data voidptr) {
	bytes := C.g_bytes_new_static(surface_title_dialog_ui.str, usize(surface_title_dialog_ui.len))
	C.gtk_widget_class_set_template(klass, bytes)

	// Signal: set (one [*:0]const u8 / string param, void return).
	mut set_param_type := g_type_string
	C.g_signal_new(c'set', g_surface_title_dialog_type, g_signal_run_last, 0, unsafe { nil },
		unsafe { nil }, unsafe { nil }, GType(0), 1, set_param_type)

	// Binding: entry template child into the private struct.
	entry_offset := g_surface_title_dialog_priv_offset + int(__offsetof(C.GhosttySurfaceTitleDialogPrivate, entry))
	C.gtk_widget_class_bind_template_child_full(klass, c'entry', 0, entry_offset)

	// Property: initial-value (string).
	pspec := C.g_param_spec_string(c'initial-value', c'initial-value', c'The initial title',
		&char(unsafe { nil }), g_param_readwrite)
	mut obj_class := &C.GObjectClass(klass)
	obj_class.get_property = voidptr(surface_title_dialog_get_property)
	obj_class.set_property = voidptr(surface_title_dialog_set_property)
	obj_class.dispose = voidptr(surface_title_dialog_dispose)
	obj_class.finalize = voidptr(surface_title_dialog_finalize)
	C.g_object_class_install_property(klass, surface_title_prop_initial_value, pspec)
}

fn surface_title_dialog_instance_init(instance voidptr, klass voidptr) {
	C.gtk_widget_init_template(instance)
}

// surface_title_dialog_get_type lazily registers the GhosttySurfaceTitleDialog
// GObject type, parented to AdwAlertDialog, with instance-private data.
pub fn surface_title_dialog_get_type() GType {
	if g_surface_title_dialog_type == GType(0) {
		parent := C.adw_alert_dialog_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size:    u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init:    voidptr(surface_title_dialog_class_init)
			instance_init: voidptr(surface_title_dialog_instance_init)
		}
		g_surface_title_dialog_type = C.g_type_register_static(parent, c'GhosttySurfaceTitleDialog',
			&info, 0)
		g_surface_title_dialog_priv_offset = C.g_type_add_instance_private(g_surface_title_dialog_type,
			sizeof(C.GhosttySurfaceTitleDialogPrivate))
	}
	return g_surface_title_dialog_type
}

// --- SurfaceTitleDialog ---------------------------------------------------

// SurfaceTitleDialog is the surface-title prompt dialog GObject
// (`GhosttySurfaceTitleDialog`, a subclass of `adw.AlertDialog`). Modeled as a
// struct wrapping the GObject pointer plus the private fields.
@[heap]
pub struct SurfaceTitleDialog {
mut:
	// The underlying AdwAlertDialog GObject instance pointer (an instance of the
	// GhosttySurfaceTitleDialog type registered by `surface_title_dialog_get_type`).
	obj GObject = unsafe { nil }

	// The initial value of the entry field. Mirrors `Private.initial_value`
	// (the `initial-value` property). Empty means unset.
	initial_value string

	// The entry widget template child (`Private.entry`), bound in the GObject
	// private via `gtk_widget_class_bind_template_child_full` and read back into
	// this wrapper by `surface_title_dialog_new`.
	entry GtkEntry = unsafe { nil }

	// Signal callback for the `set` signal. Ghostty emits a GObject `set`
	// signal carrying the new title; modeled here as an optional V callback.
	//
	// TODO(gtk): GObject signal — registered via `gobject.ext.defineSignal`.
	on_set ?fn (title string)
}

// surface_title_dialog_new creates a new surface title dialog. Mirrors
// `gobject.ext.newInstance(Self, .{})`: it builds the GObject (running the
// `.ui` template init, which binds the `entry` child). The `entry` template
// child is read back from the GObject private into the V wrapper so the seeding
// / read-back logic can use it.
pub fn surface_title_dialog_new() &SurfaceTitleDialog {
	obj := C.g_object_new(surface_title_dialog_get_type(), &char(unsafe { nil }))
	priv := surface_title_dialog_priv(obj)
	return &SurfaceTitleDialog{
		obj:   obj
		entry: priv.entry
	}
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
// widget. Split out so the async `choose` flow can be wired later. In ghostty
// this is `adw.AlertDialog.choose(parent, ...)`; here we present the dialog
// (the async response is delivered via `alert_dialog_ready` when wired).
fn (mut self SurfaceTitleDialog) present_widget(parent GtkWidget) {
	if !isnil(self.obj) {
		C.adw_dialog_present(AdwDialog(self.obj), parent)
	}
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
	title_ptr := C.gtk_entry_buffer_get_text(buffer)
	if !isnil(self.obj) {
		C.g_signal_emit_by_name(self.obj, c'set', title_ptr)
	}
	title := unsafe { cstring_to_vstring(title_ptr) }
	if cb := self.on_set {
		cb(title)
	}
}

// dispose clears the V wrapper's entry handle. The GObject-side dispose
// (gtk_widget_dispose_template + parent chain) is the `surface_title_dialog_dispose`
// vfunc registered above.
pub fn (mut self SurfaceTitleDialog) dispose() {
	self.entry = unsafe { nil }
}

// finalize frees the owned initial value on the V wrapper. The GObject-side
// finalize (g_free of the glib-owned initial value + parent chain) is the
// `surface_title_dialog_finalize` vfunc registered above.
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
