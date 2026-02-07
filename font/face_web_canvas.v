module font

// Web Canvas-based font face implementation for browser/WASM targets.
//
// A WebCanvasFace represents a single font face backed by the HTML5
// Canvas 2D API. It provides glyph lookup, rendering, metrics, and
// grapheme cluster support for browser-based terminal rendering.
//
// This is used when Ghostty runs in the browser via WebAssembly.
// Most method bodies are marked XTODO since they require JS/WASM interop.
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
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. Copy our font string because we're going to have to reuse it:
	//    font_str = raw.clone()
	//
	// 2. Create our canvas that we're going to continue to reuse:
	//    doc = js.global.get(js.Object, "document")
	//    canvas = doc.call(js.Object, "createElement", "canvas")
	//
	// 3. Build the face with undefined metrics (calculated next):
	//    result = WebCanvasFace{
	//      font_str: font_str,
	//      size: size,
	//      presentation: presentation,
	//      canvas: canvas,
	//    }
	//
	// 4. Calculate metrics:
	//    result.calc_metrics()
	//
	// 5. log.debug("face initialized: {s}", raw)
	//
	// 6. return result
	return WebCanvasFace{
		font_str:     raw.clone()
		size:         size
		presentation: presentation
	}
}

// deinit releases all resources associated with this face.
pub fn (mut self WebCanvasFace) deinit() {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. Free font_str
	// 2. Deinit grapheme_to_glyph map
	// 3. Free all values in glyph_to_grapheme, then deinit the map
	// 4. Deinit canvas (release JS object)
	self.font_str = ''
	self.grapheme_to_glyph = map[string]u32{}
	self.glyph_to_grapheme = map[u32][]u8{}
}

// Resize the font in-place. If this succeeds, the caller is responsible
// for clearing any glyph caches, font atlas data, etc.
pub fn (mut self WebCanvasFace) set_size(size DesiredSize) ! {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. Save old size for error recovery:
	//    old = self.size
	// 2. Set new size:
	//    self.size = size
	// 3. Recalculate metrics:
	//    self.calc_metrics()!
	//    (on error: self.size = old)
	self.size = size
}

// Returns the glyph index for the given Unicode code point. For canvas,
// we support every glyph and the ID is just the codepoint since we don't
// have access to the underlying tables anyways. We let the browser deal
// with bad codepoints.
pub fn (self WebCanvasFace) glyph_index(cp u32) ?u32 {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. If this is a multi-codepoint grapheme then we only check if
	//    we actually know about it:
	//    if cp >= web_canvas_grapheme_start:
	//      if cp not in self.glyph_to_grapheme: return none
	//
	// 2. Render the glyph to determine if it is colored or not. We
	//    have to do this because the browser will always try to render
	//    whatever we give it and we have no API to determine color.
	//    We don't want to say yes to the wrong presentation because
	//    it will go into the wrong Atlas.
	//    p = if cp <= 255 { .text } else { self.glyph_presentation(cp) or { return none } }
	//    if p != self.presentation: return none
	//
	// 3. return cp
	_ = cp
	return none
}

// This determines the presentation of the glyph by literally
// inspecting the image data to look for any color. This isn't
// super performant but we don't have a better choice given the
// canvas APIs.
fn (self WebCanvasFace) glyph_presentation(cp u32) !Presentation {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. Render the glyph:
	//    render = self.render_glyph_internal(cp)
	// 2. Inspect the image data for any non-zeros in the RGB value.
	//    NOTE(perf): this is an easy candidate for SIMD.
	//    i = 0
	//    while i < render.bitmap.len: i += 4:
	//      if render.bitmap[i] > 0 or
	//         render.bitmap[i + 1] > 0 or
	//         render.bitmap[i + 2] > 0:
	//        return .emoji
	// 3. return .text
	_ = cp
	return .text
}

// Returns the glyph index for the given grapheme cluster. The same
// cluster will always map to the same glyph index. This does not render
// the grapheme at this time, only reserves the index.
pub fn (mut self WebCanvasFace) grapheme_glyph_index(cluster []u8) !u32 {
	// XTODO: needs proper implementation
	// Steps:
	// 1. If we already have this stored then return it:
	//    key = cluster.bytestr()
	//    if key in self.grapheme_to_glyph: return self.grapheme_to_glyph[key]
	//
	// 2. We don't have it stored. Ensure we have space to store. The
	//    next will be "0" if we're out of space due to unsigned int wrapping:
	//    if self.grapheme_next == 0: return error('out of memory')
	//
	// 3. Copy the cluster for our reverse mapping:
	//    copy = cluster.clone()
	//
	// 4. Store it:
	//    self.grapheme_to_glyph[key] = self.grapheme_next
	//    self.glyph_to_grapheme[self.grapheme_next] = copy
	//
	// 5. Increment and return:
	//    idx = self.grapheme_next
	//    self.grapheme_next++
	//    return idx
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
pub fn (self WebCanvasFace) render_glyph(mut atlas Atlas, glyph_index u32, opts RenderOptions) !GlyphInfo {
	// XTODO: needs JS/WASM interop
	// Full algorithm:
	// 1. Render the glyph internally:
	//    render = self.render_glyph_internal(glyph_index)
	//
	// 2. Convert the format of the bitmap if necessary:
	//    - If atlas format is RGBA: bitmap is already in RGBA
	//    - If atlas format is grayscale (A8): convert down from RGBA
	//      by extracting every 4th byte (alpha channel):
	//      bitmap_a8[i] = render.bitmap[(i * 4) + 3]
	//    - Otherwise: return error (unsupported atlas format)
	//
	// 3. Put it in our atlas:
	//    region = atlas.reserve(render.width, render.height)
	//    if region.width > 0 and region.height > 0:
	//      atlas.set(region, bitmap_formatted)
	//
	// 4. Return glyph info:
	//    return GlyphInfo{
	//      width: render.width,
	//      height: render.height,
	//      // TODO: this can't be right
	//      offset_x: 0,
	//      offset_y: 0,
	//      atlas_x: region.x,
	//      atlas_y: region.y,
	//    }
	_ = atlas
	_ = glyph_index
	_ = opts
	return GlyphInfo{
		width:    0
		height:   0
		offset_x: 0
		offset_y: 0
		atlas_x:  0
		atlas_y:  0
	}
}

// Calculate the metrics associated with a given face.
fn (mut self WebCanvasFace) calc_metrics() ! {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. Get 2D context:
	//    ctx = self.context()
	//
	// 2. Cell width is the width of our M text:
	//    metrics = ctx.call("measureText", "M")
	//    We prefer the bounding box since it is tighter but certain
	//    text such as emoji do not have a bounding box set so we use
	//    the full run width instead.
	//    bounding_right = metrics.get(f32, "actualBoundingBoxRight")
	//    cell_width = if bounding_right > 0 { bounding_right } else { metrics.get(f32, "width") }
	//
	// 3. To get the cell height we render a high and low character and get
	//    the total of the ascent and descent. This should equal our
	//    pixel height but this is a more surefire way to get it.
	//    height_metrics = ctx.call("measureText", "M_")
	//    asc = height_metrics.get(f32, "actualBoundingBoxAscent")
	//    desc = height_metrics.get(f32, "actualBoundingBoxDescent")
	//    cell_height = asc + desc
	//    cell_baseline = desc
	//
	// 4. There isn't a declared underline position for canvas measurements
	//    so we just go 1 under the cell height to match freetype logic
	//    at this time (our freetype logic).
	//    underline_position = cell_height - 1
	//    underline_thickness = 1
	//
	// 5. Build metrics:
	//    self.metrics = Metrics{
	//      cell_width: u32(cell_width),
	//      cell_height: u32(cell_height),
	//      cell_baseline: u32(cell_baseline),
	//      underline_position: u32(underline_position),
	//      underline_thickness: u32(underline_thickness),
	//      strikethrough_position: u32(underline_position),
	//      strikethrough_thickness: u32(underline_thickness),
	//    }
}

// Returns the 2d context configured for drawing.
fn (self WebCanvasFace) context() !voidptr {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. This will return the same context on subsequent calls so it
	//    is important to reset it.
	//    ctx = self.canvas.call("getContext", "2d")
	//
	// 2. Clear the canvas:
	//    width = self.canvas.get(f64, "width")
	//    height = self.canvas.get(f64, "height")
	//    ctx.call("clearRect", 0, 0, width, height)
	//
	// 3. Set our context font:
	//    font_val = "${self.size.points}px ${self.font_str}"
	//    ctx.set("font", font_val)
	//
	// 4. If the font property didn't change, then the font set didn't work.
	//    We do this check because it is very easy to put an invalid font
	//    in and this at least makes it show up in the logs.
	//    check = ctx.get("font")
	//    if font_val != check:
	//      log.warn("canvas font didn't set, fonts may be broken")
	//
	// 5. return ctx
	return unsafe { nil }
}

// ============================================================
// RenderedGlyph (internal)
// ============================================================

// An internal (web-canvas-only) format for rendered glyphs
// since we do render passes in multiple different situations.
struct RenderedGlyph {
mut:
	// The JS metrics object.
	metrics voidptr = unsafe { nil }
	width   u32
	height  u32
	bitmap  []u8
}

// deinit releases the rendered glyph resources.
fn (mut self RenderedGlyph) deinit() {
	// XTODO: needs JS/WASM interop
	// self.metrics.deinit() (release JS object)
	self.bitmap = []
}

// Shared logic for rendering a glyph.
fn (self WebCanvasFace) render_glyph_internal(glyph_index u32) !RenderedGlyph {
	// XTODO: needs JS/WASM interop
	// Full algorithm:
	// 1. Encode our glyph to UTF-8 so we can build a JS string out of it:
	//    If we are a normal glyph (< grapheme_start) then we are a single
	//    codepoint and we just UTF8 encode it as-is.
	//    If we are a multi-codepoint glyph then we have to read the glyph
	//    from the map and it is already utf8 encoded.
	//
	// 2. Get our drawing context:
	//    measure_ctx = self.context()
	//
	// 3. Get the width and height of the render:
	//    metrics = measure_ctx.call("measureText", glyph_str)
	//    We prefer the bounding box since it is tighter but certain
	//    text such as emoji do not have a bounding box set so we use
	//    the full run width instead.
	//    width = u32(ceil(bounding_right or width)) + 1
	//    left = metrics.get("actualBoundingBoxLeft")
	//    asc = metrics.get("actualBoundingBoxAscent")
	//    desc = metrics.get("actualBoundingBoxDescent")
	//
	// 4. On Firefox on Linux, the bounding box is broken in some cases for
	//    ideographic glyphs (such as emoji). We detect this and behave
	//    differently.
	//    broken_bbox = asc + desc < 0.001
	//
	// 5. Height is our ascender + descender for this char:
	//    height = if !broken_bbox { u32(ceil(asc + desc)) + 1 } else { width }
	//
	// 6. Note: width and height both get "+ 1" added to them above. This
	//    is important so that there is a 1px border around the glyph to avoid
	//    any clipping in the atlas.
	//
	// 7. Resize canvas to match the glyph size exactly:
	//    self.canvas.set("width", width)
	//    self.canvas.set("height", height)
	//    style.set("width", "${width}px")
	//    style.set("height", "${height}px")
	//
	// 8. Reload our context since we resized the canvas:
	//    ctx = self.context()
	//
	// 9. For the broken bounding box case we render ideographic baselines
	//    so that we just render the glyph fully in the box with no offsets.
	//    if broken_bbox: ctx.set("textBaseline", "ideographic")
	//
	// 10. Draw background:
	//     ctx.set("fillStyle", "transparent")
	//     ctx.call("fillRect", 0, 0, width, height)
	//
	// 11. Draw glyph:
	//     ctx.set("fillStyle", "black")
	//     ctx.call("fillText", glyph_str, left + 1,
	//       if !broken_bbox { asc + 1 } else { f32(height) })
	//
	// 12. Read the image data and get it into a []u8 on our side:
	//     data = ctx.call("getImageData", 0, 0, width, height)
	//     src_array = data.get("data") // Uint8ClampedArray
	//     len = src_array.get("length")
	//     bitmap = alloc(u8, len)
	//     // Copy from JS memory to WASM memory via Uint8Array view
	//
	// 13. return RenderedGlyph{
	//       metrics: metrics,
	//       width: width,
	//       height: height,
	//       bitmap: bitmap,
	//     }
	_ = glyph_index
	return RenderedGlyph{}
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
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. Fast-path if we have a specific presentation and we
	//    don't match, then it is definitely not this face:
	//    if p != none: if self.presentation != p: return false
	//
	// 2. Slow-path: we initialize the font, render it, and check
	//    if it works and the presentation matches:
	//    face = WebCanvasFace.init_named(self.font_str, DesiredSize{ points: 12 }, self.presentation)
	//    return face.glyph_index(cp) != none
	_ = cp
	_ = p
	return false
}

// load loads this deferred WebCanvas face into a WebCanvasFace.
pub fn (self WebCanvasDeferredFace) load(opts FaceOptions) !WebCanvasFace {
	// XTODO: needs JS/WASM interop
	// return WebCanvasFace.init_named(self.font_str, opts.size, self.presentation)
	_ = opts
	return error('WebCanvas deferred loading not implemented')
}

// ============================================================
// Wasm API
// ============================================================

// The wasm-compatible API for WebCanvasFace.
// These are exported functions that the browser can call.

// wasm_face_new creates a new WebCanvasFace from a font string.
// Returns a pointer to the face, or null on error.
pub fn wasm_face_new(font_str string, pts f32, presentation_val u16) ?&WebCanvasFace {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. face = WebCanvasFace.init_named(font_str, DesiredSize{ points: pts },
	//    Presentation(presentation_val))
	// 2. Allocate on heap and return pointer
	_ = font_str
	_ = pts
	_ = presentation_val
	return none
}

// wasm_face_free frees a WebCanvasFace created by wasm_face_new.
pub fn wasm_face_free(face ?&WebCanvasFace) {
	// XTODO: needs JS/WASM interop
	// if face != none: face.deinit(); free(face)
	_ = face
}

// wasm_face_render_glyph renders a glyph and returns the result.
// Resulting pointer must be freed using the global "free".
pub fn wasm_face_render_glyph(face &WebCanvasFace, mut atlas Atlas, codepoint u32) ?&GlyphInfo {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. glyph = face.render_glyph(atlas, codepoint, RenderOptions{})
	// 2. Allocate on heap, copy glyph info, return pointer
	_ = face
	_ = atlas
	_ = codepoint
	return none
}

// wasm_face_debug_canvas appends the face's canvas to a debug element.
pub fn wasm_face_debug_canvas(face &WebCanvasFace) {
	// XTODO: needs JS/WASM interop
	// Steps:
	// 1. doc = js.global.get("document")
	// 2. elem = doc.call("getElementById", "face-canvas") or return
	// 3. elem.call("append", face.canvas)
	_ = face
}
