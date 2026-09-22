module font

// Web Canvas-based font face implementation for browser/WASM targets.
//
// A WebCanvasFace represents a single font face backed by the HTML5
// Canvas 2D API. It provides glyph lookup, rendering, metrics, and
// grapheme cluster support for browser-based terminal rendering.
//
// This is used when Ghostty runs in the browser via WebAssembly.
//
// Translated from ghostty/src/font/face/web_canvas.zig

// ============================================================
// WebCanvasFace
// ============================================================

// WebCanvasFace is a font face backed by the HTML5 Canvas 2D API.
pub struct WebCanvasFace {
pub mut:
	// The CSS "font" attribute, excluding size.
	font_str string

	// The size we currently have set.
	size DesiredSize

	// The presentation for this font.
	presentation Presentation

	// Metrics for this font face. These are useful for renderers.
	metrics Metrics

	// The canvas element that we will reuse to render glyphs.
	// Stored as voidptr because it needs JS interop (js.Object).
	canvas voidptr = unsafe { nil }

	// The map to store multi-codepoint grapheme clusters that are rendered.
	// We use 1 above the maximum unicode codepoint up to the max 32-bit
	// unsigned integer to store the "glyph index" for graphemes.
	grapheme_to_glyph map[string]u32
	glyph_to_grapheme map[u32][]u8
	grapheme_next     u32 = web_canvas_grapheme_start
}

// See graphemes field for more details.
pub const web_canvas_grapheme_start = u32(0x10FFFF + 1)
pub const web_canvas_grapheme_end = u32(0xFFFFFFFF)

// Initialize a web canvas font with a "raw" value. The "raw" value can
// be any valid value for a CSS "font" property EXCLUDING the size. The
// size is always added via the `size` parameter.
//
// The raw value is copied so the caller can free it after it is gone.
//
// The presentation is given here directly because the browser gives
// us no easy way to determine the presentation we want for this font.
// Callers should just tell us what to expect.
pub fn WebCanvasFace.init_named(raw string, size DesiredSize, presentation Presentation) !WebCanvasFace {
	canvas := web_canvas_platform_create()!
	mut result := WebCanvasFace{
		font_str: raw.clone()
		size: size
		presentation: presentation
		canvas: canvas
	}
	result.calc_metrics() or {
		web_canvas_platform_destroy(canvas)
		return err
	}
	return result
}

// deinit releases all resources associated with this face.
pub fn (mut self WebCanvasFace) deinit() {
	if !isnil(self.canvas) {
		web_canvas_platform_destroy(self.canvas)
		self.canvas = unsafe { nil }
	}
	self.font_str = ''
	self.grapheme_to_glyph = map[string]u32{}
	self.glyph_to_grapheme = map[u32][]u8{}
}

// Resize the font in-place. If this succeeds, the caller is responsible
// for clearing any glyph caches, font atlas data, etc.
pub fn (mut self WebCanvasFace) set_size(size DesiredSize) ! {
	old := self.size
	self.size = size
	self.calc_metrics() or {
		self.size = old
		return err
	}
}

// Returns the glyph index for the given Unicode code point. For canvas,
// we support every glyph and the ID is just the codepoint since we don't
// have access to the underlying tables anyways. We let the browser deal
// with bad codepoints.
pub fn (self WebCanvasFace) glyph_index(cp u32) ?u32 {
	if cp >= web_canvas_grapheme_start && cp !in self.glyph_to_grapheme {
		return none
	}
	p := if cp <= 255 { Presentation.text } else { self.glyph_presentation(cp) or { return none } }
	if p != self.presentation {
		return none
	}
	return cp
}

// This determines the presentation of the glyph by literally
// inspecting the image data to look for any color. This isn't
// super performant but we don't have a better choice given the
// canvas APIs.
fn (self WebCanvasFace) glyph_presentation(cp u32) !Presentation {
	mut render := self.render_glyph_internal(cp)!
	defer { render.deinit() }
	for i := 0; i + 3 < render.bitmap.len; i += 4 {
		if render.bitmap[i] > 0 || render.bitmap[i + 1] > 0 || render.bitmap[i + 2] > 0 {
			return .emoji
		}
	}
	return .text
}

// Returns the glyph index for the given grapheme cluster. The same
// cluster will always map to the same glyph index. This does not render
// the grapheme at this time, only reserves the index.
pub fn (mut self WebCanvasFace) grapheme_glyph_index(cluster []u8) !u32 {
	key := cluster.bytestr()
	if key in self.grapheme_to_glyph {
		return self.grapheme_to_glyph[key]
	}

	if self.grapheme_next == 0 {
		return error('out of grapheme glyph indices')
	}

	self.grapheme_to_glyph[key] = self.grapheme_next
	self.glyph_to_grapheme[self.grapheme_next] = cluster.clone()

	idx := self.grapheme_next
	self.grapheme_next++
	return idx
}

// Render a glyph using the glyph index. The rendered glyph is stored
// in the given texture atlas.
pub fn (self WebCanvasFace) render_glyph(mut atlas Atlas, glyph_index u32, opts RenderOptions) !Glyph {
	_ = opts
	mut render := self.render_glyph_internal(glyph_index)!
	defer { render.deinit() }

	mut bitmap := []u8{}
	match atlas.format {
		.grayscale {
			if render.bitmap.len % 4 != 0 {
				return error('invalid Canvas RGBA bitmap')
			}
			bitmap = []u8{len: render.bitmap.len / 4}
			for i in 0 .. bitmap.len {
				bitmap[i] = render.bitmap[i * 4 + 3]
			}
		}
		.bgra {
			bitmap = render.bitmap.clone()
			for i := 0; i + 3 < bitmap.len; i += 4 {
				bitmap[i], bitmap[i + 2] = bitmap[i + 2], bitmap[i]
			}
		}
		.bgr {
			return error('WebCanvas does not support a three-channel atlas')
		}
	}
	region := atlas.reserve(render.width, render.height)!
	if region.width > 0 && region.height > 0 {
		atlas.set(region, bitmap)
	}
	return Glyph{
		width: render.width
		height: render.height
		offset_x: 0
		offset_y: 0
		atlas_x: region.x
		atlas_y: region.y
	}
}

// Calculate the metrics associated with a given face.
fn (mut self WebCanvasFace) calc_metrics() ! {
	font_value := '${self.size.points}px ${self.font_str}'
	width_metrics := web_canvas_platform_measure(self.canvas, font_value, 'M')!
	height_metrics := web_canvas_platform_measure(self.canvas, font_value, 'M_')!
	cell_width := if width_metrics.right > 0 { width_metrics.right } else { width_metrics.width }
	cell_height := height_metrics.ascent + height_metrics.descent
	if cell_width <= 0 || cell_height <= 0 {
		return error('Canvas returned invalid font metrics')
	}
	underline_position := cell_height - 1
	self.metrics = Metrics{
		cell_width: u32(cell_width)
		cell_height: u32(cell_height)
		cell_baseline: u32(height_metrics.descent)
		underline_position: u32(underline_position)
		underline_thickness: 1
		strikethrough_position: u32(underline_position)
		strikethrough_thickness: 1
	}
}

// ============================================================
// RenderedGlyph (internal)
// ============================================================

// An internal (web-canvas-only) format for rendered glyphs
// since we do render passes in multiple different situations.
struct RenderedGlyph {
mut:
	width  u32
	height u32
	bitmap []u8
}

// deinit releases the rendered glyph resources.
fn (mut self RenderedGlyph) deinit() {
	self.bitmap = []
}

// Shared logic for rendering a glyph.
fn (self WebCanvasFace) render_glyph_internal(glyph_index u32) !RenderedGlyph {
	glyph := if glyph_index < web_canvas_grapheme_start {
		if glyph_index > 0x10ffff || (glyph_index >= 0xd800 && glyph_index <= 0xdfff) {
			return error('invalid WebCanvas glyph codepoint')
		}
		rune(glyph_index).str()
	} else {
		self.glyph_to_grapheme[glyph_index] or { return error('unknown grapheme cluster') }.bytestr()
	}
	font_value := '${self.size.points}px ${self.font_str}'
	measurement := web_canvas_platform_measure(self.canvas, font_value, glyph)!
	width_value := if measurement.right > 0 { measurement.right } else { measurement.width }
	width := u32(ceil_f64(width_value)) + 1
	broken_bbox := measurement.ascent + measurement.descent < 0.001
	height := if broken_bbox {
		width
	} else {
		u32(ceil_f64(measurement.ascent + measurement.descent)) + 1
	}
	bitmap := web_canvas_platform_render(self.canvas, font_value, glyph, width, height, measurement.left, measurement.ascent, broken_bbox)!
	if bitmap.len != int(width * height * 4) {
		return error('Canvas returned an invalid bitmap length')
	}
	return RenderedGlyph{
		width: width
		height: height
		bitmap: bitmap
	}
}

fn ceil_f64(value f64) f64 {
	whole := i64(value)
	return if f64(whole) < value { f64(whole + 1) } else { f64(whole) }
}

struct WebCanvasMeasurement {
mut:
	width   f64
	right   f64
	left    f64
	ascent  f64
	descent f64
}

// ============================================================
// WebCanvas-specific DeferredFace fields
// ============================================================

// WebCanvasDeferredFace holds WebCanvas-specific data for a deferred face.
// This is only present when building with canvas.
pub struct WebCanvasDeferredFace {
pub mut:
	// The string to use for the "font" attribute for the canvas.
	font_str string

	// The presentation for this font.
	presentation Presentation
}

// deinit releases the WebCanvas deferred face resources.
pub fn (mut self WebCanvasDeferredFace) deinit() {
	self.font_str = ''
}

// has_codepoint returns true if this deferred face can render the given
// codepoint with the specified presentation.
// Canvas always has the codepoint because we have no way of
// really checking and we let the browser handle it.
pub fn (self WebCanvasDeferredFace) has_codepoint(cp u32, p ?Presentation) bool {
	if requested := p {
		if self.presentation != requested {
			return false
		}
	}
	mut face := WebCanvasFace.init_named(self.font_str, DesiredSize{
		points: 12
	}, self.presentation) or { return false }
	defer { face.deinit() }
	return face.glyph_index(cp) != none
}

// load loads this deferred WebCanvas face into a WebCanvasFace.
pub fn (self WebCanvasDeferredFace) load(opts FaceOptions) !WebCanvasFace {
	return WebCanvasFace.init_named(self.font_str, opts.size, self.presentation)
}

// ============================================================
// Wasm API
// ============================================================

// The wasm-compatible API for WebCanvasFace.
// These are exported functions that the browser can call.

pub fn deferred_face_new(ptr &u8, len usize, presentation_val u16) ?&WebCanvasDeferredFace {
	font_str := unsafe { tos(ptr, int(len)) }.clone()
	presentation := unsafe { Presentation(presentation_val) }
	return &WebCanvasDeferredFace{
		font_str: font_str
		presentation: presentation
	}
}

pub fn deferred_face_free(ptr ?&WebCanvasDeferredFace) {
	if mut value := ptr {
		value.deinit()
		unsafe {
			free(value)
		}
	}
}

pub fn deferred_face_load(self &WebCanvasDeferredFace, pts f32) {
	_ := self.load(FaceOptions{
		size: DesiredSize{
			points: pts
		}
	}) or { return }
}

// face_new creates a new WebCanvasFace from a font string.
// Returns a pointer to the face, or null on error.
pub fn face_new(ptr &u8, len usize, pts u16, presentation_val u16) ?&WebCanvasFace {
	font_str := unsafe { tos(ptr, int(len)) }
	presentation := unsafe { Presentation(presentation_val) }
	face := WebCanvasFace.init_named(font_str, DesiredSize{
		points: f32(pts)
	}, presentation) or { return none }
	mut result := &WebCanvasFace{}
	unsafe { *result = face }
	return result
}

// face_free frees a WebCanvasFace created by face_new.
pub fn face_free(face ?&WebCanvasFace) {
	if mut value := face {
		value.deinit()
		unsafe { free(value) }
	}
}

// face_render_glyph renders a glyph and returns the result.
// Resulting pointer must be freed using the global "free".
pub fn face_render_glyph(face &WebCanvasFace, mut atlas Atlas, codepoint u32) ?&Glyph {
	glyph := face.render_glyph(mut atlas, codepoint, RenderOptions{}) or { return none }
	mut result := &Glyph{}
	unsafe { *result = glyph }
	return result
}

// face_debug_canvas appends the face's canvas to a debug element.
pub fn face_debug_canvas(face &WebCanvasFace) {
	web_canvas_platform_debug(face.canvas)
}
