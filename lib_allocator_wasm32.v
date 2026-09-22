module main

import lib_allocator

@[export: 'ghostty_wasm_alloc_opaque']
fn ghostty_wasm_alloc_opaque_export() voidptr {
	return voidptr(lib_allocator.alloc_opaque() or { return unsafe { nil } })
}

@[export: 'ghostty_wasm_free_opaque']
fn ghostty_wasm_free_opaque_export(raw voidptr) {
	lib_allocator.free_opaque(if isnil(raw) { none } else { unsafe { &lib_allocator.Opaque(raw) } })
}

@[export: 'ghostty_wasm_alloc_u8_array']
fn ghostty_wasm_alloc_u8_array_export(len usize) voidptr {
	return voidptr(lib_allocator.alloc_u8_array(len) or { return unsafe { nil } })
}

@[export: 'ghostty_wasm_free_u8_array']
fn ghostty_wasm_free_u8_array_export(raw voidptr, len usize) {
	lib_allocator.free_u8_array(if isnil(raw) { none } else { unsafe { &u8(raw) } }, len)
}

@[export: 'ghostty_wasm_alloc_u16_array']
fn ghostty_wasm_alloc_u16_array_export(len usize) voidptr {
	return voidptr(lib_allocator.alloc_u16_array(len) or { return unsafe { nil } })
}

@[export: 'ghostty_wasm_free_u16_array']
fn ghostty_wasm_free_u16_array_export(raw voidptr, len usize) {
	lib_allocator.free_u16_array(if isnil(raw) { none } else { unsafe { &u16(raw) } }, len)
}

@[export: 'ghostty_wasm_alloc_u8']
fn ghostty_wasm_alloc_u8_export() voidptr {
	return voidptr(lib_allocator.alloc_u8() or { return unsafe { nil } })
}

@[export: 'ghostty_wasm_free_u8']
fn ghostty_wasm_free_u8_export(raw voidptr) {
	lib_allocator.free_u8(if isnil(raw) { none } else { unsafe { &u8(raw) } })
}

@[export: 'ghostty_wasm_alloc_usize']
fn ghostty_wasm_alloc_usize_export() voidptr {
	return voidptr(lib_allocator.alloc_usize() or { return unsafe { nil } })
}

@[export: 'ghostty_wasm_free_usize']
fn ghostty_wasm_free_usize_export(raw voidptr) {
	lib_allocator.free_usize(if isnil(raw) { none } else { unsafe { &usize(raw) } })
}
