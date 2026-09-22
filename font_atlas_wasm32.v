// Translated from Ghostty's src/font/Atlas.zig Wasm namespace.

module main

import font

@[export: 'atlas_new']
fn atlas_new_wasm_export(size u32, format u8) voidptr {
	result := font.atlas_new(size, format) or { return unsafe { nil } }
	return voidptr(result)
}

@[export: 'atlas_free']
fn atlas_free_wasm_export(raw voidptr) {
	if isnil(raw) {
		font.atlas_free(none)
		return
	}
	font.atlas_free(unsafe { &font.Atlas(raw) })
}

@[export: 'atlas_reserve']
fn atlas_reserve_wasm_export(raw voidptr, width u32, height u32) voidptr {
	mut atlas := unsafe { &font.Atlas(raw) }
	result := font.atlas_reserve(mut atlas, width, height) or { return unsafe { nil } }
	return voidptr(result)
}

@[export: 'atlas_set']
fn atlas_set_wasm_export(raw voidptr, region_raw voidptr, data &u8, len usize) {
	mut atlas := unsafe { &font.Atlas(raw) }
	region := unsafe { &font.AtlasRegion(region_raw) }
	font.atlas_set(mut atlas, region, data, len)
}

@[export: 'atlas_grow']
fn atlas_grow_wasm_export(raw voidptr, size_new u32) bool {
	mut atlas := unsafe { &font.Atlas(raw) }
	return font.atlas_grow(mut atlas, size_new)
}

@[export: 'atlas_clear']
fn atlas_clear_wasm_export(raw voidptr) {
	mut atlas := unsafe { &font.Atlas(raw) }
	font.atlas_clear(mut atlas)
}
