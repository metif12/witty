module font

import opentype

// CoreText-based font face implementation for macOS.
//
// A CoreTextFace represents a single font face backed by Apple's CoreText
// framework. It provides glyph lookup, rendering, metrics, and table access.
//
// This is the macOS equivalent of the FreeType-based Face in face.v.
// CoreText calls are isolated in coretext_shims.h so this module also
// compiles on non-Apple targets, where constructors report unsupported data.
//
// Translated from ghostty/src/font/face/coretext.zig

// CoreText helpers implemented in the C shim header (font/coretext_shims.h).
// These are only functional on macOS; on other platforms they return
// null/zero so the module still compiles.
#include "coretext_shims.h"

fn C.witty_coretext_create_font_named(name &char, size f64) voidptr

fn C.witty_coretext_create_font_from_data(data &u8, len usize, size f64) voidptr

fn C.witty_coretext_copy_font_with_size(font_ptr voidptr, size f64) voidptr

fn C.witty_coretext_release(ptr voidptr)

fn C.witty_coretext_copy_family_name(font_ptr voidptr, buf &u8, len usize) int

fn C.witty_coretext_glyph_for_codepoint(font_ptr voidptr, cp u32, glyph_out &u32) int

fn C.witty_coretext_copy_table(font_ptr voidptr, tag4 &char, buffer_out &&u8, len_out &u32) int

fn C.witty_coretext_copy_italic(font_ptr voidptr) voidptr

fn C.witty_coretext_copy_with_variations(font_ptr voidptr, ids &u32, values &f64, count int, size f64) voidptr

fn C.witty_coretext_color_info(font_ptr voidptr, has_sbix &int) int

fn C.witty_coretext_free_buffer(ptr &u8)

fn C.witty_coretext_get_metrics(font_ptr voidptr, px_per_em &f64, cell_width &f64, ascent &f64, descent &f64, line_gap &f64, underline_position &f64, underline_thickness &f64, strikethrough_position &f64, strikethrough_thickness &f64, cap_height &f64, ex_height &f64) int

fn C.witty_coretext_render_glyph(font_ptr voidptr, glyph_id u32, cell_height f64, cell_baseline f64, width_out &u32, height_out &u32, offset_x_out &i32, offset_y_out &i32, buffer_out &&u8) int

fn C.witty_ct_font_from_descriptor(desc voidptr, size f64) voidptr

fn C.witty_ct_font_copy_descriptor(font voidptr) voidptr

fn C.witty_ct_descriptor_path(desc voidptr, buf &u8, len usize) int

fn C.witty_ct_release(ptr voidptr)

fn C.witty_coretext_copy_display_name(font_ptr voidptr, buf &u8, len usize) int

// ============================================================
// CoreTextFace
// ============================================================

// CoreTextFace is a font face backed by Apple's CoreText framework.
pub struct CoreTextFace {
pub mut:
	// Our font face (CoreText CTFont). Stored as voidptr because
	// real CoreText bindings are not yet available.
	ct_font voidptr = unsafe { nil }

	// Harfbuzz font corresponding to this face. We only use this
	// if we're using Harfbuzz.
	hb_font voidptr = unsafe { nil }

	// Set quirks.disableDefaultFontFeatures
	quirks_disable_default_font_features bool

	// True if this font face should be rasterized with a synthetic bold
	// effect. This is used for fonts that don't have a bold variant.
	synthetic_bold ?f64

	// If the face can possibly be colored, then this is the state
	// used to check for color information. This is null if the font
	// can't possibly be colored (i.e. doesn't have SVG, sbix, etc
	// tables).
	color ?ColorState

	// The current size this font is set to.
	size DesiredSize
}

// True if our build is using Harfbuzz. If we're not, we can avoid
// some Harfbuzz-specific code paths.
pub const coretext_harfbuzz_shaper = true

// The matrix applied to a regular font to auto-italicize it.
// This is an affine transform with a shear of approximately tan(15 degrees).
pub const italic_skew_a = f64(1)
pub const italic_skew_b = f64(0)
pub const italic_skew_c = f64(0.267949) // approx. tan(15)
pub const italic_skew_d = f64(1)
pub const italic_skew_tx = f64(0)
pub const italic_skew_ty = f64(0)

// AffineTransform represents a 2D affine transformation matrix.
// Used for synthetic italic skew.
pub struct AffineTransform {
pub:
	a  f64 = 1
	b  f64
	c  f64
	d  f64 = 1
	tx f64
	ty f64
}

// The italic skew transform as a struct.
pub const italic_skew = AffineTransform{
	a: italic_skew_a
	b: italic_skew_b
	c: italic_skew_c
	d: italic_skew_d
	tx: italic_skew_tx
	ty: italic_skew_ty
}

// Initialize a CoreText-based font from a TTF/TTC in memory.
pub fn CoreTextFace.init(lib Library, source []u8, opts FaceOptions) !CoreTextFace {
	// Create a CTFont from the in-memory data at a default size (12); the
	// final size is applied by init_font_copy below.
	_ = lib
	base := C.witty_coretext_create_font_from_data(&u8(source.data), usize(source.len), 12.0)
	if isnil(base) {
		return error('CoreText: failed to create font from data')
	}
	defer {
		C.witty_coretext_release(base)
	}
	return CoreTextFace.init_font_copy(base, opts)!
}

// Initialize a CoreText-based face from another initialized font face
// but with a new size. This is often how CoreText fonts are initialized
// because the font is loaded at a default size during discovery, and then
// adjusted to the final size for final load.
pub fn CoreTextFace.init_font_copy(base voidptr, opts FaceOptions) !CoreTextFace {
	// Create a copy. copyWithAttributes takes a size in points, but we need
	// to scale by the DPI, which is what DesiredSize.pixels() does.
	ct_font := C.witty_coretext_copy_font_with_size(base, opts.size.pixels())
	if isnil(ct_font) {
		return error('CoreText: failed to copy font with size')
	}
	// init_font takes ownership of ct_font.
	return CoreTextFace.init_font(ct_font, opts)!
}

// Initialize a face with a CTFont. This will take ownership over
// the CTFont. This does NOT copy or retain the CTFont.
pub fn CoreTextFace.init_font(ct_font voidptr, opts FaceOptions) !CoreTextFace {
	if isnil(ct_font) {
		return error('CoreText: null font')
	}

	// Determine color state from the font's symbolic traits and tables.
	mut color := ?ColorState(none)
	mut ignored_sbix := int(0)
	is_color := C.witty_coretext_color_info(ct_font, &ignored_sbix) != 0
	if is_color {
		color = ColorState.init(ct_font) or {
			C.witty_coretext_release(ct_font)
			return error(err.msg())
		}
	}

	// BOUNDARY: ghostty also builds a Harfbuzz font here (when using the
	// Harfbuzz shaper) and sets its scale from opts.size.pixels(). The
	// Harfbuzz+CoreText glue isn't wired in this port yet, so hb_font is
	// left null. Variation-axis debug logging is likewise omitted.
	return CoreTextFace{
		ct_font: ct_font
		color: color
		size: opts.size
	}
}

// deinit releases all resources associated with this face.
pub fn (mut self CoreTextFace) deinit() {
	if !isnil(self.ct_font) {
		C.witty_coretext_release(self.ct_font)
		self.ct_font = unsafe { nil }
	}
	if c := self.color {
		c.deinit()
	}
	self.color = none
	// BOUNDARY: destroy the Harfbuzz font once that glue is wired.
	// ColorState holds no owned CoreText data in this port (its SVG data
	// pointer is always null), so there's nothing to release there.
}

// Return a new face that is the same as this but has a transformation
// matrix applied to italicize it.
pub fn (self &CoreTextFace) synthetic_italic(opts FaceOptions) !CoreTextFace {
	// Copy the font with the italic-skew transform applied.
	ct_font := C.witty_coretext_copy_italic(self.ct_font)
	if isnil(ct_font) {
		return error('CoreText: failed to create synthetic italic')
	}
	return CoreTextFace.init_font(ct_font, opts)!
}

// Return a new face that is the same as this but applies a synthetic
// bold effect to it. This is useful for fonts that don't have a bold
// variant.
pub fn (self &CoreTextFace) synthetic_bold(opts FaceOptions) !CoreTextFace {
	// Copy the font without any additional transforms.
	ct_font := C.witty_coretext_copy_font_with_size(self.ct_font, 0.0)
	if isnil(ct_font) {
		return error('CoreText: failed to copy font for synthetic bold')
	}
	mut face := CoreTextFace.init_font(ct_font, opts)!

	// To determine our synthetic bold line width we get a multiplier from the
	// font size in points. This is a heuristic: a line width of 1 looks good
	// at a certain point size, and we scale it up roughly linearly with size.
	points_f64 := f64(opts.size.points)
	line_width := if points_f64 / 14.0 > 1.0 { points_f64 / 14.0 } else { f64(1) }
	face.synthetic_bold = line_width

	return face
}

// Returns the font name. If allocation is required, buf will be used,
// but sometimes allocation isn't required and a static string is
// returned.
pub fn (self &CoreTextFace) name(mut buf []u8) !string {
	// Copy the family name into the caller-provided buffer.
	if buf.len == 0 {
		return error('CoreText: name buffer is empty')
	}
	if C.witty_coretext_copy_family_name(self.ct_font, &u8(buf.data), usize(buf.len)) == 0 {
		return error('CoreText: failed to copy family name')
	}
	return unsafe { cstring_to_vstring(&char(buf.data)) }
}

// Resize the font in-place. If this succeeds, the caller is responsible
// for clearing any glyph caches, font atlas data, etc.
pub fn (mut self CoreTextFace) set_size(opts FaceOptions) ! {
	// We just create a copy at the new size and replace ourself.
	face := CoreTextFace.init_font_copy(self.ct_font, opts)!
	self.deinit()
	self = face
}

// Set the variation axes for this font. This will modify this font
// in-place.
pub fn (mut self CoreTextFace) set_variations(vs []Variation, opts FaceOptions) ! {
	// If we have no variations, we don't need to do anything.
	if vs.len == 0 {
		return
	}

	// Marshal the axis ids/values into parallel arrays for the shim, which
	// builds a variation-carrying descriptor and copies the font with it.
	mut ids := []u32{cap: vs.len}
	mut values := []f64{cap: vs.len}
	for v in vs {
		ids << v.id.value
		values << v.value
	}

	// Preserve our current size so that applying variations doesn't resize.
	ct_font := C.witty_coretext_copy_with_variations(self.ct_font, &u32(ids.data), &f64(values.data), vs.len, self.size.pixels())
	if isnil(ct_font) {
		return error('CoreText: failed to apply variations')
	}

	mut new_opts := opts
	new_opts.size = self.size
	face := CoreTextFace.init_font(ct_font, new_opts)!
	self.deinit()
	self = face
}

// Returns true if the face has any glyphs that are colorized.
// To determine if an individual glyph is colorized you must use
// is_color_glyph.
pub fn (self &CoreTextFace) has_color() bool {
	return self.color != none
}

// Returns true if the given glyph ID is colorized.
pub fn (self &CoreTextFace) is_color_glyph(glyph_id u32) bool {
	c := self.color or { return false }
	return c.is_color_glyph(glyph_id)
}

// Returns the glyph index for the given Unicode code point. If this
// face doesn't support this glyph, null is returned.
pub fn (self CoreTextFace) glyph_index(cp u32) ?u32 {
	// The shim handles UTF-32 -> UTF-16 conversion (including surrogate
	// pairs) and calls CTFontGetGlyphsForCharacters. It returns 0 (and we
	// return none) if the font doesn't contain the codepoint.
	mut glyph := u32(0)
	if C.witty_coretext_glyph_for_codepoint(self.ct_font, cp, &glyph) == 0 {
		return none
	}
	return glyph
}

// Render a glyph using the glyph index. The rendered glyph is stored
// in the given texture atlas.
pub fn (self CoreTextFace) render_glyph(mut atlas Atlas, glyph_index u32, opts RenderOptions) !GlyphInfo {
	// Full algorithm:
	// 1. Get the bounding rect for rendering this glyph:
	//    glyphs = [glyph_index]
	//    rect = self.ct_font.getBoundingRectsForGlyphs(.horizontal, &glyphs, null)
	//    (coordinate space: (0,0) bottom-left, +Y up)
	//
	// 2. Determine whether this is a color glyph:
	//    is_color = self.is_color_glyph(glyph_index)
	//    sbix = is_color && self.color != none && self.color.sbix
	//
	// 3. If we're rendering a synthetic bold then we will gain 50% of
	//    the line width on every edge, which means we should increase
	//    our width and height by the line width and subtract half from
	//    our origin points.
	//    We don't add extra size if it's a sbix color font though,
	//    since bitmaps aren't affected by synthetic bold.
	//    if !sbix { if line_width := self.synthetic_bold {
	//      rect.size.width += line_width
	//      rect.size.height += line_width
	//      rect.origin.x -= line_width / 2
	//      rect.origin.y -= line_width / 2
	//    }}
	//
	// 4. If our rect is smaller than a quarter pixel in either axis
	//    then it has no outlines or they're too small to render.
	//    Return 0-sized glyph.
	//
	// 5. Apply constraints via opts.constraint.constrain() for sizing/positioning.
	//    Add cell_baseline to y before constraining.
	//
	// 6. Center glyph within cell if face_width < cell_width and not stretch:
	//    dx = (cell_width - metrics.face_width) / 2
	//    x += dx
	//    if dx < 0: x -= trunc(dx)
	//
	// 7. If this is a bitmap glyph (sbix), quantize position and size
	//    to align to full pixels.
	//
	// 8. Calculate canvas_padding (1 if thicken and not sbix, else 0).
	//
	// 9. Compute whole-pixel bearings (px_x, px_y) and fractional offsets
	//    (frac_x, frac_y).
	//
	// 10. Compute pixel width and height including fractional offset and
	//     canvas padding.
	//
	// 11. Create appropriate color space and bitmap context:
	//     - Grayscale (A8) for text glyphs
	//     - RGBA (displayP3, premultiplied_first, byte_order_32_little) for color
	//
	// 12. Verify atlas format depth matches font color depth.
	//
	// 13. Allocate buffer, create CGBitmapContext.
	//
	// 14. Configure context:
	//     - Initial fill (transparent)
	//     - Font smoothing (thicken)
	//     - Subpixel positioning enabled
	//     - Subpixel quantization disabled
	//     - Anti-aliasing enabled
	//     - Set fill/stroke color
	//     - If synthetic bold: set text drawing mode to fill_stroke with line_width
	//
	// 15. Translate CTM by (frac_x + canvas_padding, frac_y + canvas_padding).
	//
	// 16. Scale CTM by (width / rect.size.width, height / rect.size.height).
	//
	// 17. Draw glyph at position (-rect.origin.x, -rect.origin.y).
	//
	// 18. Write rasterized glyph to the atlas (atlas.reserve, atlas.set).
	//
	// 19. Compute offset_y = px_y + px_height, offset_x = px_x.
	//
	// 20. Return GlyphInfo with atlas coordinates and offsets.
	if atlas.format != .grayscale {
		return error('CoreText shim currently produces grayscale glyphs')
	}
	mut width := u32(0)
	mut height := u32(0)
	mut offset_x := i32(0)
	mut offset_y := i32(0)
	mut pixels := &u8(unsafe { nil })
	if C.witty_coretext_render_glyph(self.ct_font, glyph_index, f64(opts.grid_metrics.cell_height), f64(opts.grid_metrics.cell_baseline), &width, &height, &offset_x, &offset_y, &pixels) == 0 {
		return error('CoreText: failed to rasterize glyph')
	}
	if width == 0 || height == 0 || pixels == unsafe { nil } {
		return GlyphInfo{}
	}
	defer { C.witty_coretext_free_buffer(pixels) }
	region := atlas.reserve(width, height)!
	atlas.set(region, unsafe { pixels.vbytes(int(width * height)) })
	return GlyphInfo{
		width: width
		height: height
		offset_x: offset_x
		offset_y: offset_y
		atlas_x: region.x
		atlas_y: region.y
	}
}

// Get the FaceMetrics for this face.
pub fn (mut self CoreTextFace) get_metrics() FaceMetrics {
	// Full algorithm:
	//
	// 1. Read the 'head' table out of the font data:
	//    macOS bitmap-only fonts use a 'bhed' tag rather than 'head', but
	//    the table format is byte-identical to the 'head' table, so if we
	//    can't find 'head' we try 'bhed' instead before failing.
	//    ref: https://fontforge.org/docs/techref/bitmaponlysfnt.html
	//    head_tag = FontTableTag.init("head")
	//    bhed_tag = FontTableTag.init("bhed")
	//    data = ct_font.copyTable(head_tag) or ct_font.copyTable(bhed_tag) or null
	//    head = opentype.Head.init(data) or null
	//
	// 2. Read the 'post' table out of the font data:
	//    tag = FontTableTag.init("post")
	//    data = ct_font.copyTable(tag) or null
	//    post = opentype.Post.init(data) or null
	//
	// 3. Read the 'OS/2' table out of the font data if it's available:
	//    tag = FontTableTag.init("OS/2")
	//    data = ct_font.copyTable(tag) or null
	//    os2 = opentype.OS2.init(data) or null
	//
	// 4. Read the 'hhea' table out of the font data:
	//    tag = FontTableTag.init("hhea")
	//    data = ct_font.copyTable(tag) or null
	//    hhea = opentype.Hhea.init(data) or null
	//
	// 5. Calculate units_per_em:
	//    If head table present: head.unitsPerEm
	//    Else: ct_font.getUnitsPerEm()
	//    px_per_em = ct_font.getSize()
	//    px_per_unit = px_per_em / units_per_em
	//
	// 6. Vertical metrics (ascent, descent, line_gap):
	//    If no hhea table: use CoreText metrics:
	//      ascent = ct_font.getAscent()
	//      descent = -ct_font.getDescent()
	//      line_gap = ct_font.getLeading()
	//    Else if no OS/2 table: use hhea metrics * px_per_unit
	//    Else:
	//      If OS/2 fsSelection USE_TYPO_METRICS bit set:
	//        use OS/2 sTypo* metrics * px_per_unit
	//      Else prefer hhea if non-zero, then OS/2 sTypo*, then OS/2 usWin*
	//      (usWinDescent is positive->down, flip sign)
	//
	// 7. Underline (from post table):
	//    Some fonts have degenerate 'post' tables where the underline
	//    thickness (and often position) are 0.
	//    If underlineThickness == 0: broken underline
	//    underline_position = f64(post.underlinePosition) * px_per_unit (if not broken+zero)
	//    underline_thickness = f64(post.underlineThickness) * px_per_unit (if not broken)
	//
	// 8. Strikethrough (from OS/2 table):
	//    Similar logic to the underline above.
	//    If yStrikeoutSize == 0: broken strikethrough
	//    strikethrough_position = f64(os2.yStrikeoutPosition) * px_per_unit
	//    strikethrough_thickness = f64(os2.yStrikeoutSize) * px_per_unit
	//
	// 9. Cap height and ex height:
	//    We fall back to whatever CoreText does if the
	//    OS/2 table doesn't specify a cap or ex height.
	//    If no OS/2: cap_height = ct_font.getCapHeight(), ex_height = ct_font.getXHeight()
	//    Else if OS/2 has sCapHeight: use it * px_per_unit, else ct_font.getCapHeight()
	//    Else if OS/2 has sxHeight: use it * px_per_unit, else ct_font.getXHeight()
	//
	// 10. Cell width:
	//     Build array of all visible ASCII chars (32..127 as u16)
	//     Get glyph IDs via ct_font.getGlyphsForCharacters
	//     Get advances via ct_font.getAdvancesForGlyphs(.horizontal)
	//     cell_width = max advance width
	//     ascii_height = bounding rect height of all ASCII glyphs
	//
	// 11. IC width:
	//     Measure '水' (CJK water ideograph, U+6C34):
	//     glyph = self.glyph_index(0x6C34) or null
	//     advance = ct_font.getAdvancesForGlyphs(.horizontal, &[glyph], null)
	//     bounds = ct_font.getBoundingRectsForGlyphs(.horizontal, &[glyph], null)
	//     If the advance of the glyph is less than the width of the actual
	//     glyph then we just treat it as invalid since it's probably wrong
	//     and using it for size normalization will instead make the font
	//     way too big.
	//     ic_width = advance (if bounds.width <= advance, else null)
	//
	// This V port sources its metrics from CoreText's own font metrics via
	// the shim (px_per_em, cell_width from the widest ASCII advance, ascent,
	// descent, line gap, underline, strikethrough, cap and ex height).
	//
	// BOUNDARY: ghostty refines these from the 'head'/'post'/'OS/2'/'hhea'
	// tables (via the opentype module) and derives ic_width from the '水'
	// ideograph. That table-driven refinement is left as a boundary here; the
	// CoreText-derived metrics are correct for the common case.
	mut px_per_em := f64(0)
	mut cell_width := f64(0)
	mut ascent := f64(0)
	mut descent := f64(0)
	mut line_gap := f64(0)
	mut ul_pos := f64(0)
	mut ul_thick := f64(0)
	mut st_pos := f64(0)
	mut st_thick := f64(0)
	mut cap_height := f64(0)
	mut ex_height := f64(0)

	if C.witty_coretext_get_metrics(self.ct_font, &px_per_em, &cell_width, &ascent, &descent, &line_gap, &ul_pos, &ul_thick, &st_pos, &st_thick, &cap_height, &ex_height) == 0 {
		return FaceMetrics{}
	}

	return FaceMetrics{
		px_per_em: px_per_em
		cell_width: cell_width
		ascent: ascent
		descent: descent
		line_gap: line_gap
		underline_position: ul_pos
		underline_thickness: ul_thick
		strikethrough_position: st_pos
		strikethrough_thickness: st_thick
		cap_height: cap_height
		ex_height: ex_height
	}
}

// Copy the font table data for the given tag.
pub fn (self CoreTextFace) copy_table(tag string) ![]u8 {
	// CTFontCopyTable expects a 4-character tag.
	if tag.len != 4 {
		return error('CoreText: font table tag must be 4 characters')
	}
	mut ptr := &u8(unsafe { nil })
	mut n := u32(0)
	if C.witty_coretext_copy_table(self.ct_font, &char(tag.str), &ptr, &n) == 0 {
		return error('CoreText: font table not found: ${tag}')
	}
	// Copy the C-allocated buffer into a V-owned slice, then free the C one.
	mut buf := []u8{len: int(n)}
	if n > 0 {
		unsafe { vmemcpy(buf.data, ptr, int(n)) }
	}
	C.witty_coretext_free_buffer(ptr)
	return buf
}

// ============================================================
// ColorState
// ============================================================

// The state associated with a font face that may have colorized glyphs.
// This is used to determine if a specific glyph ID is colorized.
pub struct ColorState {
pub mut:
	// True if there is an sbix font table. For now, the mere presence
	// of an sbix font table causes us to assume the glyph is colored.
	// We can improve this later.
	sbix bool

	// The SVG font table data (if any), which we can use to determine
	// if a glyph is present in the SVG table.
	svg ?opentype.SVG

	// Owns the bytes referenced by svg.
	svg_data []u8
}

// init creates a ColorState from a CoreText font by checking for
// sbix and SVG tables.
pub fn ColorState.init(ct_font voidptr) !ColorState {
	// Steps:
	// 1. Check for sbix table:
	//    sbix is true if the table exists in the font data at all.
	//    In the future we probably want to actually parse it and
	//    check for glyphs.
	//    tag = FontTableTag.init("sbix")
	//    data = ct_font.copyTable(tag) or false
	//    sbix = data != null && data.getLength() > 0
	//
	// 2. Read the SVG table out of the font data:
	//    tag = FontTableTag.init("SVG ")
	//    data = ct_font.copyTable(tag) or null
	//    svg = opentype.SVG.init(data.getPointer()[0..data.getLength()]) or null
	//    (On error: EndOfStream or SVGVersionNotSupported -> InvalidSVGTable)
	mut has_sbix := int(0)
	_ = C.witty_coretext_color_info(ct_font, &has_sbix)
	mut svg_data := []u8{}
	mut svg := ?opentype.SVG(none)
	mut ptr := &u8(unsafe { nil })
	mut len := u32(0)
	if C.witty_coretext_copy_table(ct_font, c'SVG ', &ptr, &len) != 0 {
		defer { C.witty_coretext_free_buffer(ptr) }
		svg_data = unsafe { ptr.vbytes(int(len)) }.clone()
		svg = opentype.SVG.init(svg_data)!
	}
	return ColorState{
		sbix: has_sbix != 0
		svg: svg
		svg_data: svg_data
	}
}

// deinit releases resources held by the ColorState.
pub fn (self &ColorState) deinit() {
	// V owns svg_data and releases it with the containing face.
}

// Returns true if the given glyph ID is colored.
pub fn (self &ColorState) is_color_glyph(glyph_id u32) bool {
	// Our font system uses 32-bit glyph IDs for special values but
	// actual fonts only contain 16-bit glyph IDs so if we can't cast
	// into it it must be false.
	if glyph_id > 0xFFFF {
		return false
	}

	// sbix is always true for now
	if self.sbix {
		return true
	}

	// if we have svg data, check it
	if svg := self.svg {
		return svg.has_glyph(u16(glyph_id))
	}

	return false
}

// ============================================================
// CoreText-specific DeferredFace fields
// ============================================================

// CoreTextDeferredFace holds CoreText-specific data for a deferred face.
// This is only present when building with CoreText.
pub struct CoreTextDeferredFace {
pub mut:
	// The initialized font (CTFont pointer, stored as voidptr).
	ct_font voidptr = unsafe { nil }

	// Variations to apply to this font. We apply the variations to the
	// search descriptor but sometimes when the font collection is
	// made the variation axes are reset so we have to reapply them.
	variations []Variation
}

// deinit releases the CoreText deferred face resources.
pub fn (mut self CoreTextDeferredFace) deinit() {
	if self.ct_font != unsafe { nil } {
		C.witty_coretext_release(self.ct_font)
		self.ct_font = unsafe { nil }
	}
	self.variations = []
}

// has_codepoint returns true if this deferred face can render the given
// codepoint with the specified presentation.
pub fn (self CoreTextDeferredFace) has_codepoint(cp u32, p ?Presentation) bool {
	// Steps:
	// 1. This presentation check isn't as detailed as isColorGlyph
	//    because forced presentation modes are only used for emoji and
	//    emoji should always have color glyphs set. This can be
	//    more correct by using the isColorGlyph logic but I'd want
	//    to find a font that actually requires this so we can write
	//    a test for it before changing it.
	//    if p != none:
	//      traits = ct_font.getSymbolicTraits()
	//      actual_p = if traits.color_glyphs { .emoji } else { .text }
	//      if actual_p != p: return false
	//
	// 2. Turn UTF-32 into UTF-16 for CT API:
	//    var unichars [2]u16
	//    pair = stringGetSurrogatePairForLongCharacter(cp, &unichars)
	//    len = if pair { 2 } else { 1 }
	//
	// 3. Get our glyphs:
	//    var glyphs = [2]Glyph{ 0, 0 }
	//    return ct_font.getGlyphsForCharacters(unichars[0..len], glyphs[0..len])
	if presentation := p {
		mut has_sbix := int(0)
		is_color := C.witty_coretext_color_info(self.ct_font, &has_sbix) != 0
		actual := if is_color { Presentation.emoji } else { Presentation.text }
		if actual != presentation {
			return false
		}
	}
	mut glyph := u32(0)
	return C.witty_coretext_glyph_for_codepoint(self.ct_font, cp, &glyph) != 0
}

// family_name returns the family name of the deferred CoreText font.
pub fn (self CoreTextDeferredFace) family_name(mut buf []u8) !string {
	if buf.len == 0 || C.witty_coretext_copy_family_name(self.ct_font, &u8(buf.data), usize(buf.len)) == 0 {
		return error('CoreText: failed to copy family name')
	}
	return unsafe { cstring_to_vstring(&char(buf.data)) }
}

// name returns the display name of the deferred CoreText font.
pub fn (self CoreTextDeferredFace) name(mut buf []u8) !string {
	// display_name = ct_font.copyDisplayName()
	// return display_name.cstringPtr(.utf8) or display_name.cstring(buf, .utf8)
	// "NULL if the internal storage of theString does not allow
	// this to be returned efficiently." In this case, we need
	// to allocate. But we can't return an allocated string because
	// we don't have an allocator. Let's use the stack and log it.
	if buf.len == 0 || C.witty_coretext_copy_display_name(self.ct_font, &u8(buf.data), usize(buf.len)) == 0 {
		return error('CoreText: failed to copy display name')
	}
	return unsafe { cstring_to_vstring(&char(buf.data)) }
}

// load loads this deferred CoreText face into a CoreTextFace.
pub fn (self CoreTextDeferredFace) load(lib Library, opts FaceOptions) !CoreTextFace {
	// Steps:
	// 1. face = CoreTextFace.init_font_copy(self.ct_font, opts)
	// 2. face.set_variations(self.variations, opts)
	// 3. return face
	_ = lib
	mut face := CoreTextFace.init_font_copy(self.ct_font, opts)!
	face.set_variations(self.variations, opts)!
	return face
}

// load_freetype loads a CoreText deferred face through FreeType instead.
// This is for the coretext_freetype backend.
pub fn (self CoreTextDeferredFace) load_freetype(lib Library, opts FaceOptions) !Face {
	// Steps:
	// 1. Get the URL for the font so we can get the filepath:
	//    url = ct_font.copyAttribute(.url) or return error
	//    path = url.copyPath() or return error
	// 2. URL decode the path:
	//    decoded = URL.createStringByReplacingPercentEscapes(path, "")
	// 3. Decode into a null-terminated C string (1024 bytes should be enough).
	// 4. Face index 0 is not always correct. We don't ship this configuration
	//    in a release build. Users should use the pure CoreText builds.
	// 5. face = Face.init_file(lib, path, 0, opts)
	// 6. face.set_variations(self.variations, opts)
	// 7. return face
	desc := C.witty_ct_font_copy_descriptor(self.ct_font)
	if desc == unsafe { nil } {
		return error('CoreText: failed to copy font descriptor')
	}
	defer { C.witty_ct_release(desc) }
	mut path_buf := []u8{len: 4096}
	if C.witty_ct_descriptor_path(desc, &u8(path_buf.data), usize(path_buf.len)) == 0 {
		return error('CoreText: font has no file URL')
	}
	path := unsafe { cstring_to_vstring(&char(path_buf.data)) }
	mut face := Face.init_file(lib, path, 0, opts)!
	face.set_variations(self.variations, opts)!
	return face
}
