module gtk

// gobject_c_linux.v - Raw GObject/GTK C-API bindings for hand-expanding the
// class registration that ghostty performs via `gobject.ext.defineClass`,
// `defineProperty`, `defineSignal`, and the blueprint/gresource template
// machinery. These are direct declarations of the GObject C API (the same
// API zig-gobject wraps); each witty class hand-expands its registration
// onto them instead of using a comptime helper.

#include <gtk/gtk.h>

#include <glib-object.h>

#include "gobject_shims.h"

// GType (usize) and GBytes (voidptr) aliases are declared elsewhere in the
// module (c_gtk_linux.v / ipc_dbus_linux.v) and reused here.

pub type GtkWidgetClass = voidptr

pub type GObjectClass = voidptr

// Opaque GObject property metadata. The concrete definition is supplied by
// <glib-object.h>; declaring it here gives V one canonical pointer type.
@[typedef]
pub struct C.GParamSpec {}

// GClassInitFunc:    fn (gpointer klass, gpointer class_data)
// GInstanceInitFunc: fn (GTypeInstance *instance, gpointer klass)
// Both are passed as plain function pointers (voidptr) in GTypeInfo below.

// GTypeInfo mirrors the C struct used by g_type_register_static. Field names
// match <gobject/gtype.h> so V's codegen assigns into the real struct.
@[typedef]
pub struct C.GTypeInfo {
pub mut:
	class_size     u16
	base_init      voidptr
	base_finalize  voidptr
	class_init     voidptr
	class_finalize voidptr
	class_data     voidptr
	instance_size  u16
	n_preallocs    u16
	instance_init  voidptr
	value_table    voidptr
}

// GInterfaceInfo describes an interface implementation attached to a type.
@[typedef]
pub struct C.GInterfaceInfo {
pub mut:
	interface_init     voidptr
	interface_finalize voidptr
	interface_data     voidptr
}

// GTypeQuery mirrors the C struct filled by g_type_query.
@[typedef]
pub struct C.GTypeQuery {
pub mut:
	type          GType
	type_name     &char
	class_size    u32
	instance_size u32
}

// --- Type registration ----------------------------------------------------

fn C.g_type_register_static(parent_type GType, type_name &char, info &C.GTypeInfo, flags int) GType

fn C.g_type_query(type GType, query &C.GTypeQuery)

fn C.g_type_add_instance_private(type GType, private_size uint) int

fn C.g_type_add_interface_static(instance_type GType, interface_type GType, info &C.GInterfaceInfo)

fn C.g_type_class_peek_parent(g_class voidptr) voidptr

fn C.g_type_class_adjust_private_offset(g_class voidptr, private_size_or_offset &int)

// instance_private returns the private data at `private_offset` bytes from
// `instance`, as zig-gobject's `getPrivate` (G_STRUCT_MEMBER_P) does. The offset
// is only valid once class_init has run g_type_class_adjust_private_offset.
fn instance_private(instance voidptr, private_offset int) voidptr {
	return unsafe { voidptr(&u8(instance) + private_offset) }
}

fn C.g_type_check_instance_cast(instance voidptr, iface_type GType) voidptr

fn C.g_type_check_instance_is_a(instance voidptr, iface_type GType) int

fn C.g_boxed_type_register_static(type_name &char, boxed_copy voidptr, boxed_free voidptr) GType

// GEnumValue and g_enum_register_static back hand-expanded enum GTypes such
// as GhosttyMouseShape. The values array passed to GLib is static storage and
// ends with an entry whose name and nick are null.
@[typedef]
pub struct C.GEnumValue {
pub mut:
	value      int
	value_name &char
	value_nick &char
}

fn C.g_enum_register_static(name &char, values &C.GEnumValue) GType

// --- Parent type get_type() functions --------------------------------------

fn C.adw_bin_get_type() GType

fn C.adw_dialog_get_type() GType

fn C.adw_application_window_get_type() GType

fn C.adw_application_get_type() GType

fn C.adw_window_get_type() GType

fn C.gtk_box_get_type() GType

fn C.gtk_widget_get_type() GType

fn C.gtk_window_get_type() GType

// --- Template (blueprint/.ui) loading --------------------------------------
// ghostty uses setTemplateFromResource against a compiled gresource; witty
// loads the equivalent .ui bytes directly via set_template.

fn C.g_bytes_new_static(data voidptr, size uint) GBytes

fn C.gtk_widget_class_set_template(widget_class voidptr, template_bytes GBytes)

fn C.gtk_widget_init_template(widget voidptr)

fn C.gtk_widget_dispose_template(widget voidptr, widget_type GType)

fn C.gtk_widget_class_bind_template_child_full(widget_class voidptr, name &char, internal int, struct_offset int)

// --- Property registration -------------------------------------------------

fn C.g_object_class_install_property(oclass voidptr, property_id u32, pspec &C.GParamSpec)

fn C.g_object_class_override_property(oclass voidptr, property_id u32, name &char)

fn C.g_param_spec_boolean(name &char, nick &char, blurb &char, default_value int, flags int) &C.GParamSpec

fn C.g_param_spec_int(name &char, nick &char, blurb &char, minimum int, maximum int, default_value int, flags int) &C.GParamSpec

fn C.g_param_spec_uint(name &char, nick &char, blurb &char, minimum u32, maximum u32, default_value u32, flags int) &C.GParamSpec

fn C.g_param_spec_string(name &char, nick &char, blurb &char, default_value &char, flags int) &C.GParamSpec

fn C.g_param_spec_object(name &char, nick &char, blurb &char, object_type GType, flags int) &C.GParamSpec

fn C.g_param_spec_boxed(name &char, nick &char, blurb &char, boxed_type GType, flags int) &C.GParamSpec

fn C.g_param_spec_enum(name &char, nick &char, blurb &char, enum_type GType, default_value int, flags int) &C.GParamSpec

// --- Signal registration ---------------------------------------------------

fn C.g_signal_new(signal_name &char, itype GType, signal_flags int, class_offset u32, accumulator voidptr, accu_data voidptr, c_marshaller voidptr, return_type GType, n_params u32, ...) u32

fn C.g_signal_emit_by_name(instance voidptr, detailed_signal &char, ...)

// GObject GParamFlags we use (from <gobject/gparam.h>).
pub const g_param_readable = int(1)
pub const g_param_writable = int(2)
pub const g_param_readwrite = int(3) // readable | writable
pub const g_param_construct = int(4)

// GSignalFlags (from <gobject/gsignal.h>).
pub const g_signal_run_last = int(2)
pub const g_signal_run_first = int(1)

// GType fundamentals we reference by their C constant expressions.
fn C.g_object_get_type() GType

fn C.g_object_ref_sink(object GObject) GObject

fn C.g_object_weak_ref(object GObject, notify voidptr, data voidptr)

fn C.g_object_set(object GObject, first_property_name &char, ...)

fn C.g_object_get(object GObject, first_property_name &char, ...)

fn C.g_object_set_data(object GObject, key &char, data voidptr)

fn C.g_object_get_data(object GObject, key &char) voidptr

fn C.g_object_bind_property(source voidptr, source_property &char, target voidptr, target_property &char, flags int) voidptr

// --- Instance creation -----------------------------------------------------

fn C.g_object_new(object_type GType, first_property_name &char, ...) voidptr

// --- Property/vfunc overriding --------------------------------------------
// These tiny C shims operate on GLib's real public class structs. V's external
// struct declarations use a different C tag for typedef-backed GLib structs,
// so accessing their fields directly would be ABI-incorrect.

fn C.witty_gobject_class_set_get_property(klass voidptr, callback voidptr)

fn C.witty_gobject_class_set_set_property(klass voidptr, callback voidptr)

fn C.witty_gobject_class_set_dispose(klass voidptr, callback voidptr)

fn C.witty_gobject_class_set_finalize(klass voidptr, callback voidptr)

fn C.witty_gobject_call_parent_dispose(instance voidptr)

fn C.witty_gobject_call_parent_finalize(instance voidptr)

fn C.witty_gapplication_class_set_startup(klass voidptr, callback voidptr)

fn C.witty_gapplication_class_set_activate(klass voidptr, callback voidptr)

fn C.witty_gapplication_call_parent_startup(instance voidptr)

fn C.witty_gapplication_call_parent_activate(instance voidptr)

fn C.witty_dialog_class_set_response(klass voidptr, alert_dialog int, callback voidptr)

fn C.g_object_class_find_property(oclass voidptr, property_name &char) &C.GParamSpec

fn C.g_object_notify_by_pspec(object voidptr, pspec &C.GParamSpec)

// GValue accessors (the GValue* is passed as voidptr).
fn C.g_value_get_boolean(value voidptr) int

fn C.g_value_set_boolean(value voidptr, v_boolean int)

fn C.g_value_get_string(value voidptr) &char

fn C.g_value_set_string(value voidptr, v_string &char)

fn C.g_value_get_object(value voidptr) voidptr

fn C.g_value_set_object(value voidptr, v_object voidptr)

fn C.g_value_get_int(value voidptr) int

fn C.g_value_set_int(value voidptr, v_int int)

fn C.g_value_get_uint(value voidptr) u32

fn C.g_value_set_uint(value voidptr, v_uint u32)

fn C.g_value_get_boxed(value voidptr) voidptr

fn C.g_value_dup_boxed(value voidptr) voidptr

fn C.g_value_set_boxed(value voidptr, v_boxed voidptr)

fn C.g_value_take_boxed(value voidptr, v_boxed voidptr)
