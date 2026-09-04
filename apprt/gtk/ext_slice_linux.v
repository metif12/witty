@[has_globals]
module gtk

// ext_slice_linux.v - Slice helpers for GTK objects.
//
// Translated from ghostty/src/apprt/gtk/ext/slice.zig.
//
// The Zig original defines a boxed `StringList` type: a list of NUL-terminated
// string slices backed by an arena allocator, registered as a GObject boxed
// type ("GhosttyStringList") with copy/free funcs.
//
// V has automatic memory management (GC / autofree) for the `[]string` payload,
// so the arena allocation is represented by owned string clones. The GObject
// boxed type and its deep-copy/free callbacks are registered explicitly through
// the C API.

// StringList is a boxed type that holds a list of string slices.
//
// Faithful to the Zig `StringList` struct. In Zig the strings are stored as
// `[:0]const u8` (NUL-terminated) in an arena; in V we store plain `[]string`
// and rely on V's memory management.
pub struct StringList {
pub mut:
	strings []string
}

// create builds a StringList from the given strings, duplicating each so the
// StringList owns its own copies. Mirrors `StringList.create`.
pub fn StringList.create(strings []string) &StringList {
	mut stored := []string{cap: strings.len}
	for s in strings {
		stored << s.clone()
	}
	return &StringList{
		strings: stored
	}
}

// deinit releases the resources held by the StringList. Mirrors
// `StringList.deinit`. Clearing the owned slice releases its references under
// V's memory management.
pub fn (mut self StringList) deinit() {
	self.strings = []
}

// destroy frees the StringList itself. Mirrors `StringList.destroy`.
pub fn (mut self StringList) destroy() {
	self.deinit()
}

__global g_string_list_type = GType(0)

fn string_list_boxed_copy(value voidptr) voidptr {
	if isnil(value) {
		return unsafe { nil }
	}
	list := unsafe { &StringList(value) }
	return voidptr(StringList.create(list.strings))
}

fn string_list_boxed_free(value voidptr) {
	if isnil(value) {
		return
	}
	mut list := unsafe { &StringList(value) }
	list.destroy()
}

// get_gobject_type returns the registered boxed GObject type for StringList.
// Mirrors `gobject.ext.defineBoxed` with the GhosttyStringList name and the
// deep-copy/free functions above.
pub fn StringList.get_gobject_type() GType {
	if g_string_list_type == GType(0) {
		g_string_list_type = C.g_boxed_type_register_static(c'GhosttyStringList', voidptr(string_list_boxed_copy), voidptr(string_list_boxed_free))
	}
	return g_string_list_type
}
