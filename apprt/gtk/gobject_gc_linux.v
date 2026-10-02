module gtk

// Zig private fields live inside the native GObject allocation. V stores its
// translated fields in a heap wrapper, so the native owner must retain a GC
// root until GObject releases that private storage.
fn C.g_object_set_data_full(GObject, &char, voidptr, voidptr)
fn C.GC_add_roots(voidptr, voidptr)
fn C.GC_remove_roots(voidptr, voidptr)

fn native_wrapper_release(slot voidptr) {
	$if gcboehm ? {
		C.GC_remove_roots(slot, unsafe { &u8(slot) + sizeof(voidptr) })
	}
	C.g_free(slot)
}

fn native_wrapper_set(obj GObject, key string, wrapper voidptr) {
	if isnil(wrapper) {
		C.g_object_set_data(obj, &char(key.str), unsafe { nil })
		return
	}
	slot := C.g_malloc0(sizeof(voidptr))
	unsafe {
		*(&voidptr(slot)) = wrapper
	}
	$if gcboehm ? {
		C.GC_add_roots(slot, unsafe { &u8(slot) + sizeof(voidptr) })
	}
	C.g_object_set_data_full(obj, &char(key.str), slot, voidptr(native_wrapper_release))
}

fn native_wrapper_get(obj GObject, key string) voidptr {
	slot := C.g_object_get_data(obj, &char(key.str))
	if isnil(slot) { return unsafe { nil } }
	return unsafe { *(&voidptr(slot)) }
}
