module main

import lib_allocator
import terminal_c

@[export: 'ghostty_wasm_alloc_opaque']
fn ghostty_wasm_alloc_opaque_export() voidptr {
	return voidptr(lib_allocator.alloc_opaque())
}

@[export: 'ghostty_wasm_free_opaque']
fn ghostty_wasm_free_opaque_export(raw voidptr) {
	lib_allocator.free_opaque(unsafe { &lib_allocator.Opaque(raw) })
}

@[export: 'ghostty_wasm_alloc_u8_array']
fn ghostty_wasm_alloc_u8_array_export(len usize) voidptr {
	return voidptr(lib_allocator.alloc_u8_array(len))
}

@[export: 'ghostty_wasm_free_u8_array']
fn ghostty_wasm_free_u8_array_export(raw voidptr, len usize) {
	lib_allocator.free_u8_array(unsafe { &u8(raw) }, len)
}

@[export: 'ghostty_wasm_alloc_u16_array']
fn ghostty_wasm_alloc_u16_array_export(len usize) voidptr {
	return voidptr(lib_allocator.alloc_u16_array(len))
}

@[export: 'ghostty_wasm_free_u16_array']
fn ghostty_wasm_free_u16_array_export(raw voidptr, len usize) {
	lib_allocator.free_u16_array(unsafe { &u16(raw) }, len)
}

@[export: 'ghostty_wasm_alloc_u8']
fn ghostty_wasm_alloc_u8_export() voidptr {
	return voidptr(lib_allocator.alloc_u8())
}

@[export: 'ghostty_wasm_free_u8']
fn ghostty_wasm_free_u8_export(raw voidptr) {
	lib_allocator.free_u8(unsafe { &u8(raw) })
}

@[export: 'ghostty_wasm_alloc_usize']
fn ghostty_wasm_alloc_usize_export() voidptr {
	return voidptr(lib_allocator.alloc_usize())
}

@[export: 'ghostty_wasm_free_usize']
fn ghostty_wasm_free_usize_export(raw voidptr) {
	lib_allocator.free_usize(unsafe { &usize(raw) })
}

@[export: 'ghostty_wasm_alloc_sgr_attribute']
fn ghostty_wasm_alloc_sgr_attribute_export() voidptr {
	return voidptr(terminal_c.wasm_alloc_attribute())
}

@[export: 'ghostty_wasm_free_sgr_attribute']
fn ghostty_wasm_free_sgr_attribute_export(raw voidptr) {
	terminal_c.wasm_free_attribute(unsafe { &terminal_c.SgrAttributeC(raw) })
}
