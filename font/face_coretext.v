module font

// CoreText-based font face implementation for macOS.
//
// A CoreTextFace represents a single font face backed by Apple's CoreText
// framework. It provides glyph lookup, rendering, metrics, and table access.
//
// This is the macOS equivalent of the FreeType-based Face in face.v.
// Most method bodies are marked XTODO since they require real CoreText
// (macOS framework) bindings.
//
// Translated from ghostty/src/font/face/coretext.zig

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
	a:  italic_skew_a
	b:  italic_skew_b
	c:  italic_skew_c
	d:  italic_skew_d
	tx: italic_skew_tx
	ty: italic_skew_ty
}

// Initialize a CoreText-based font from a TTF/TTC in memory.
pub fn CoreTextFace.init(lib Library, source []u8, opts FaceOptions) !CoreTextFace {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Create CFData from source bytes (createWithBytesNoCopy)
	// 2. Create CTFontDescriptor from the data (createFontDescriptorFromData)
	// 3. Create CTFont from the descriptor at default size 12
	// 4. Call init_font_copy to create the final face at the desired size
	_ = lib
	_ = source
	return CoreTextFace.init_font_copy(unsafe { nil }, opts)!
}

// Initialize a CoreText-based face from another initialized font face
// but with a new size. This is often how CoreText fonts are initialized
// because the font is loaded at a default size during discovery, and then
// adjusted to the final size for final load.
pub fn CoreTextFace.init_font_copy(base voidptr, opts FaceOptions) !CoreTextFace {
	// XTODO: needs real CoreText bindings
	// Create a copy. The copyWithAttributes docs say the size is in points,
	// but we need to scale the points by the DPI and to do that we use our
	// function called "pixels".
	// Steps:
	// 1. base.copyWithAttributes(opts.size.pixels(), null, null)
	// 2. Call init_font with the new ct_font
	_ = base
	return CoreTextFace.init_font(unsafe { nil }, opts)!
}

// Initialize a face with a CTFont. This will take ownership over
// the CTFont. This does NOT copy or retain the CTFont.
pub fn CoreTextFace.init_font(ct_font voidptr, opts FaceOptions) !CoreTextFace {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Get symbolic traits from ct_font
	// 2. If using harfbuzz shaper:
	//    a. Create harfbuzz font from CoreText font (harfbuzz.coretext.createFont)
	//    b. Set scale from opts.size.pixels() as F26Dot6
	// 3. If traits indicate color_glyphs, initialize ColorState
	// 4. Build the Face struct
	// 5. Check quirks.disableDefaultFontFeatures
	// 6. In debug mode, output information about available variation axes,
	//    if they exist. For each axis, log:
	//    - name (from kCTFontVariationAxisNameKey)
	//    - identifier (from kCTFontVariationAxisIdentifierKey)
	//    - minimum value
	//    - maximum value
	//    - default value
	_ = ct_font
	return CoreTextFace{
		size: opts.size
	}
}

// deinit releases all resources associated with this face.
pub fn (mut self CoreTextFace) deinit() {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Release the CTFont (self.ct_font.release())
	// 2. If using harfbuzz shaper, destroy harfbuzz font (self.hb_font.destroy())
	// 3. If we have color state, deinit it (self.color.deinit())
}

// Return a new face that is the same as this but has a transformation
// matrix applied to italicize it.
pub fn (self &CoreTextFace) synthetic_italic(opts FaceOptions) !CoreTextFace {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Copy the font with the italic_skew transform applied:
	//    ct_font = self.ct_font.copyWithAttributes(0.0, &italic_skew, null)
	// 2. Initialize a new face from the copied font:
	//    return init_font(ct_font, opts)
	_ = opts
	return CoreTextFace{
		size: self.size
	}
}

// Return a new face that is the same as this but applies a synthetic
// bold effect to it. This is useful for fonts that don't have a bold
// variant.
pub fn (self &CoreTextFace) synthetic_bold(opts FaceOptions) !CoreTextFace {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Copy the font without any additional transforms:
	//    ct_font = self.ct_font.copyWithAttributes(0.0, null, null)
	// 2. Initialize a new face from the copied font:
	//    face = init_font(ct_font, opts)
	// 3. To determine our synthetic bold line width we get a multiplier
	//    from the font size in points. This is a heuristic that is based
	//    on the fact that a line width of 1 looks good to me at a certain
	//    point size. We want to scale that up roughly linearly with the
	//    font size.
	//    points_f64 = f64(opts.size.points)
	//    line_width = max(points_f64 / 14.0, 1)
	//    face.synthetic_bold = line_width
	_ = opts
	return CoreTextFace{
		size: self.size
	}
}

// Returns the font name. If allocation is required, buf will be used,
// but sometimes allocation isn't required and a static string is
// returned.
pub fn (self &CoreTextFace) name(mut buf []u8) !string {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Get the family name: family_name = self.ct_font.copyFamilyName()
	// 2. Try to get a C string pointer directly:
	//    if family_name.cstringPtr(.utf8) returns a pointer, return it.
	// 3. "NULL if the internal storage of theString does not allow
	//    this to be returned efficiently." In this case, we need
	//    to allocate.
	//    return family_name.cstring(buf, .utf8) or return error
	_ = buf
	return ''
}

// Resize the font in-place. If this succeeds, the caller is responsible
// for clearing any glyph caches, font atlas data, etc.
pub fn (mut self CoreTextFace) set_size(opts FaceOptions) ! {
	// XTODO: needs real CoreText bindings
	// We just create a copy and replace ourself:
	// 1. face = init_font_copy(self.ct_font, opts)
	// 2. self.deinit()
	// 3. self = face
	self.size = opts.size
}

// Set the variation axes for this font. This will modify this font
// in-place.
pub fn (mut self CoreTextFace) set_variations(vs []Variation, opts FaceOptions) ! {
	// XTODO: needs real CoreText bindings
	// If we have no variations, we don't need to do anything.
	if vs.len == 0 {
		return
	}

	// Steps:
	// 1. Create a new font descriptor with all the variations set:
	//    desc = self.ct_font.copyDescriptor()
	//    for v in vs:
	//      id = Number.create(.int, &v.id)
	//      next = desc.createCopyWithVariation(id, v.value)
	//      desc.release()
	//      desc = next
	// 2. Put our current size in the opts so that we don't change size:
	//    new_opts = opts
	//    new_opts.size = self.size
	// 3. Initialize a font based on these attributes:
	//    ct_font = self.ct_font.copyWithAttributes(0, null, desc)
	//    face = init_font(ct_font, new_opts)
	// 4. Replace self:
	//    self.deinit()
	//    self = face
	_ = vs
	_ = opts
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
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Turn UTF-32 into UTF-16 for CT API:
	//    var unichars [2]u16
	//    pair = stringGetSurrogatePairForLongCharacter(cp, &unichars)
	//    len = if pair { 2 } else { 1 }
	// 2. Get our glyphs:
	//    var glyphs = [2]Glyph{ 0, 0 }
	//    if !self.ct_font.getGlyphsForCharacters(unichars[0..len], glyphs[0..len]):
	//      return none
	// 3. We can have pairs due to chars like emoji but we expect all of them
	//    to decode down into exactly one glyph ID:
	//    if pair: assert(glyphs[1] == 0)
	// 4. return u32(glyphs[0])
	_ = cp
	return none
}

// Render a glyph using the glyph index. The rendered glyph is stored
// in the given texture atlas.
pub fn (self CoreTextFace) render_glyph(mut atlas Atlas, glyph_index u32, opts RenderOptions) !GlyphInfo {
	// XTODO: needs real CoreText bindings
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

// Get the FaceMetrics for this face.
pub fn (mut self CoreTextFace) get_metrics() FaceMetrics {
	// XTODO: needs real CoreText bindings
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

	return FaceMetrics{}
}

// Copy the font table data for the given tag.
pub fn (self CoreTextFace) copy_table(tag string) ![]u8 {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. data = self.ct_font.copyTable(FontTableTag.init(tag)) or return none
	// 2. ptr = data.getPointer()
	// 3. len = data.getLength()
	// 4. buf = alloc(u8, len)
	// 5. memcpy(buf, ptr[0..len])
	// 6. return buf
	_ = tag
	return error('copy_table not implemented')
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
	// Stored as voidptr because opentype.SVG needs real bindings.
	svg     voidptr = unsafe { nil }
	has_svg bool

	// The SVG font table data reference (retained CoreFoundation data).
	// Stored as voidptr because it needs real CoreText bindings.
	svg_data voidptr = unsafe { nil }
}

// init creates a ColorState from a CoreText font by checking for
// sbix and SVG tables.
pub fn ColorState.init(ct_font voidptr) !ColorState {
	// XTODO: needs real CoreText bindings
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
	_ = ct_font
	return ColorState{}
}

// deinit releases resources held by the ColorState.
pub fn (self &ColorState) deinit() {
	// XTODO: needs real CoreText bindings
	// if self.svg_data != nil: svg_data.release()
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
	if self.has_svg {
		// XTODO: check if glyph is in SVG table
		// svg.hasGlyph(u16(glyph_id))
		return false
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
	// XTODO: release the CTFont
	// self.ct_font.release()
}

// has_codepoint returns true if this deferred face can render the given
// codepoint with the specified presentation.
pub fn (self CoreTextDeferredFace) has_codepoint(cp u32, p ?Presentation) bool {
	// XTODO: needs real CoreText bindings
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
	_ = cp
	_ = p
	return false
}

// family_name returns the family name of the deferred CoreText font.
pub fn (self CoreTextDeferredFace) family_name(mut buf []u8) !string {
	// XTODO: needs real CoreText bindings
	// family_name = ct_font.copyAttribute(.family_name) or return "unknown"
	// return family_name.cstringPtr(.utf8) or family_name.cstring(buf, .utf8)
	_ = buf
	return ''
}

// name returns the display name of the deferred CoreText font.
pub fn (self CoreTextDeferredFace) name(mut buf []u8) !string {
	// XTODO: needs real CoreText bindings
	// display_name = ct_font.copyDisplayName()
	// return display_name.cstringPtr(.utf8) or display_name.cstring(buf, .utf8)
	// "NULL if the internal storage of theString does not allow
	// this to be returned efficiently." In this case, we need
	// to allocate. But we can't return an allocated string because
	// we don't have an allocator. Let's use the stack and log it.
	_ = buf
	return ''
}

// load loads this deferred CoreText face into a CoreTextFace.
pub fn (self CoreTextDeferredFace) load(lib Library, opts FaceOptions) !CoreTextFace {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. face = CoreTextFace.init_font_copy(self.ct_font, opts)
	// 2. face.set_variations(self.variations, opts)
	// 3. return face
	_ = lib
	_ = opts
	return error('CoreText deferred loading not implemented')
}

// load_freetype loads a CoreText deferred face through FreeType instead.
// This is for the coretext_freetype backend.
pub fn (self CoreTextDeferredFace) load_freetype(lib Library, opts FaceOptions) !Face {
	// XTODO: needs real CoreText bindings
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
	_ = lib
	_ = opts
	return error('CoreText+FreeType deferred loading not implemented')
}
