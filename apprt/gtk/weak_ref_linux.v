module gtk

// weak_ref_linux.v - GObject weak reference wrapper.
//
// Translated from ghostty/src/apprt/gtk/weak_ref.zig.
//
// The Zig original is generic: `WeakRef(comptime T: type)` wraps a
// `gobject.WeakRef` to make it type-safe over a single GObject subtype. V's
// generics over the opaque `GObject` type alias are awkward (all our GObject
// handles are just `voidptr`), so per the translation guidance we model a
// single *concrete* `WeakRef` over `GObject`. The get/set/ref semantics are
// kept faithful to the original:
//
//   - `set`  : point the weak ref at an object WITHOUT taking a strong ref
//              (or clear it when given nil).
//   - `get`  : take a NEW strong reference to the object (bumping the refcount
//              by one), or return nil if the object has been finalized.
//
// A `GWeakRef` must live at a stable address for the lifetime of the weak
// reference (GLib stores a pointer to it internally), so `WeakRef` embeds the
// GLib `GWeakRef` struct by value and the caller is expected to keep the
// `WeakRef` itself pinned (e.g. as a struct field), exactly as in ghostty.

// --- GObject weak-ref C bindings ------------------------------------------
//
// `GWeakRef` is an opaque-ish public GLib struct whose only documented use is
// via the g_weak_ref_* API. We treat it as a fixed-size byte blob so we never
// need to spell out its internal layout; GLib only ever touches it through the
// functions below. It is two pointers wide in practice; we over-allocate a
// little to stay safe across GLib versions.
struct C.GWeakRef {
	priv [2]voidptr
}

fn C.g_weak_ref_init(weak_ref &C.GWeakRef, object GObject)
fn C.g_weak_ref_clear(weak_ref &C.GWeakRef)
fn C.g_weak_ref_set(weak_ref &C.GWeakRef, object GObject)
fn C.g_weak_ref_get(weak_ref &C.GWeakRef) GObject

// --- WeakRef --------------------------------------------------------------

// WeakRef is a lightweight wrapper around a GLib `GWeakRef`. It holds a weak
// reference to a `GObject` without keeping it alive.
//
// Mirrors the empty/zeroed default of the Zig `WeakRef(T)` (whose `ref` field
// defaults to `std.mem.zeroes(gobject.WeakRef)`): the zero value is a valid,
// empty weak reference in GLib.
pub struct WeakRef {
mut:
	ref C.GWeakRef
}

// weak_ref_empty returns an empty WeakRef, mirroring `WeakRef(T).empty`.
pub fn weak_ref_empty() WeakRef {
	return WeakRef{}
}

// set points the weak reference at `obj`. This does NOT increase the
// reference count of the object. Passing a nil `obj` clears the reference.
// Mirrors `WeakRef.set`.
pub fn (mut self WeakRef) set(obj GObject) {
	// g_weak_ref_set accepts NULL to clear, so we can forward directly. The
	// weak_ref must have been initialized; a zeroed GWeakRef is a valid empty
	// state that g_weak_ref_set handles.
	C.g_weak_ref_set(&self.ref, obj)
}

// get takes a NEW strong reference to the object, or returns nil if the
// object has been finalized. This increases the reference count by one; the
// caller is responsible for calling `object_unref` on a non-nil result.
// Mirrors `WeakRef.get`.
pub fn (mut self WeakRef) get() GObject {
	return C.g_weak_ref_get(&self.ref)
}

// init initializes the weak reference to point at `obj` (or empty when nil).
// This corresponds to GLib's `g_weak_ref_init`. It is not strictly part of
// the Zig API (which relies on the zeroed default), but is provided so callers
// that need an explicitly-initialized `GWeakRef` at a stable address can do
// so faithfully.
pub fn (mut self WeakRef) init(obj GObject) {
	C.g_weak_ref_init(&self.ref, obj)
}

// clear releases the weak reference, disconnecting it from the object it
// points to. Corresponds to GLib's `g_weak_ref_clear`. Call this before the
// backing `WeakRef` storage is freed.
pub fn (mut self WeakRef) clear() {
	C.g_weak_ref_clear(&self.ref)
}
