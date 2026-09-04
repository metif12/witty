module gtk

// ext_linux.v - Extensions/helpers for GTK objects.
//
// Translated from ghostty/src/apprt/gtk/ext.zig.
//
// The Zig original is a small grab-bag of Zig-friendly wrappers around GTK/
// GObject functionality:
//   * boxedCopy / boxedFree - copy/free a boxed GObject type.
//   * listFind              - find an element in a glib.List by predicate.
//   * getAncestor           - get a widget's ancestor of a given type.
//   * gValueHolds           - equivalent of the G_VALUE_HOLDS() macro.
//
// It also re-exports `actions` (ext/actions.zig) and `StringList`
// (ext/slice.zig). In V those live in the same `gtk` module, so no re-export is
// needed — the symbols (Action, add_to_map, StringList, ...) are directly
// available.
//
// The Zig helpers that are generic over a GObject type `T` (boxedCopy,
// boxedFree, getAncestor, listFind) rely on `T.getGObjectType()` /
// comptime type reflection, which V does not have here. We translate them
// against the raw GType / voidptr handles instead, which is the faithful
// low-level behavior.

// --- New C bindings -------------------------------------------------------

fn C.g_boxed_copy(boxed_type GType, src_boxed voidptr) voidptr
fn C.g_boxed_free(boxed_type GType, boxed voidptr)
fn C.g_list_find_custom(list GList, data voidptr, func GCompareFunc) GList
fn C.gtk_widget_get_ancestor(widget GtkWidget, widget_type GType) GtkWidget
fn C.g_type_check_value_holds(value GValue, type GType) int

// --- Opaque handle aliases (module-local) ---------------------------------

// GList is a glib.List*.
pub type GList = voidptr

// GValue is a gobject.Value*.
pub type GValue = voidptr

// GCompareFunc is a glib.CompareFunc (C callback: (a, b) -> int).
pub type GCompareFunc = voidptr

// --- Boxed type helpers ---------------------------------------------------

// boxed_copy copies a boxed value of the given boxed GType. Mirrors `boxedCopy`
// (which in Zig takes a comptime type `T` and calls `T.getGObjectType()`; here
// the GType is passed explicitly).
pub fn boxed_copy(boxed_type GType, ptr voidptr) voidptr {
	return C.g_boxed_copy(boxed_type, ptr)
}

// boxed_free frees a boxed value of the given boxed GType. Mirrors `boxedFree`.
pub fn boxed_free(boxed_type GType, ptr voidptr) {
	if isnil(ptr) {
		return
	}
	C.g_boxed_free(boxed_type, ptr)
}

// --- List helpers ---------------------------------------------------------

// list_find finds an element in the list for which `func` returns true (0 in
// the underlying GCompareFunc convention). Mirrors `listFind`.
//
// `func` is a GCompareFunc-style C callback: it receives the element data and
// must return 0 for a match (non-zero otherwise), matching glib's
// findCustom contract.
pub fn list_find(list GList, func GCompareFunc) voidptr {
	elem := C.g_list_find_custom(list, unsafe { nil }, func)
	if isnil(elem) {
		return unsafe { nil }
	}
	// elem is a GList node; its `data` field is the matched element.
	return list_node_data(elem)
}

fn C.g_list_nth_data(list GList, n u32) voidptr

fn C.g_list_length(list GList) u32

// list_node_data returns the `data` payload of a GList node (element index 0).
fn list_node_data(node GList) voidptr {
	return C.g_list_nth_data(node, 0)
}

// list_length returns the number of nodes in a GLib list.
fn list_length(list GList) u32 {
	return C.g_list_length(list)
}

// list_data_at returns the data pointer at an index, or nil.
fn list_data_at(list GList, index u32) voidptr {
	return C.g_list_nth_data(list, index)
}

// --- Widget ancestor ------------------------------------------------------

// get_ancestor returns the widget's ancestor of the given GType, or nil if
// none. Mirrors `getAncestor` (which takes a comptime type `T`; here the
// GType is explicit).
pub fn get_ancestor(widget GtkWidget, widget_type GType) GtkWidget {
	return C.gtk_widget_get_ancestor(widget, widget_type)
}

// --- GValue type check ----------------------------------------------------

// g_value_holds checks a gobject.Value to see what type it is wrapping. This is
// the equivalent of GTK's `G_VALUE_HOLDS()` macro. Mirrors `gValueHolds`.
pub fn g_value_holds(value GValue, g_type GType) bool {
	if isnil(value) {
		return false
	}
	return C.g_type_check_value_holds(value, g_type) != 0
}
