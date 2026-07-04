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
// so we do not need the arena machinery. We keep the type and its API faithful
// in shape. Registering the boxed GObject type (gobject.ext.defineBoxed) is a
// comptime GObject construction that has no clean V equivalent, so it is stubbed
// with a `get_gobject_type` placeholder — TODO(gtk).

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
// `StringList.deinit`. With V's memory management this is a no-op, kept for
// API parity.
pub fn (mut self StringList) deinit() {}

// destroy frees the StringList itself. Mirrors `StringList.destroy`.
pub fn (mut self StringList) destroy() {
	self.deinit()
}

// get_gobject_type returns the registered boxed GObject type for StringList.
//
// TODO(gtk): the Zig original registers a boxed GObject type via
// `gobject.ext.defineBoxed(StringList, .{ .name = "GhosttyStringList", ... })`
// with C copy/free trampolines. That comptime GObject registration has no clean
// V equivalent; this returns 0 (G_TYPE_INVALID) as a placeholder.
pub fn StringList.get_gobject_type() GType {
	return GType(0)
}
