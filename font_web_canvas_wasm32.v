// Translated from Ghostty's WebCanvas face and shaper Wasm namespaces.

module main

import font
import font.shaper

@[export: 'face_new']
fn face_new_wasm_export(ptr &u8, len usize, pts u16, presentation u16) voidptr {
	result := font.face_new(ptr, len, pts, presentation) or { return unsafe { nil } }
	return voidptr(result)
}

@[export: 'face_free']
fn face_free_wasm_export(raw voidptr) {
	if isnil(raw) {
		font.face_free(none)
		return
	}
	font.face_free(unsafe { &font.WebCanvasFace(raw) })
}

@[export: 'face_render_glyph']
fn face_render_glyph_wasm_export(face_raw voidptr, atlas_raw voidptr, codepoint u32) voidptr {
	face := unsafe { &font.WebCanvasFace(face_raw) }
	mut atlas := unsafe { &font.Atlas(atlas_raw) }
	result := font.face_render_glyph(face, mut atlas, codepoint) or { return unsafe { nil } }
	return voidptr(result)
}

@[export: 'face_debug_canvas']
fn face_debug_canvas_wasm_export(raw voidptr) {
	font.face_debug_canvas(unsafe { &font.WebCanvasFace(raw) })
}

@[export: 'shaper_new']
fn shaper_new_wasm_export(cap usize) voidptr {
	result := shaper.shaper_new(cap) or { return unsafe { nil } }
	return voidptr(result)
}

@[export: 'shaper_free']
fn shaper_free_wasm_export(raw voidptr) {
	if isnil(raw) {
		shaper.shaper_free(none)
		return
	}
	shaper.shaper_free(unsafe { &shaper.WebCanvasShaper(raw) })
}
