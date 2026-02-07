module font

// Face represents a single font face. A single font face has a single set
// of properties associated with it such as style, weight, etc.
//
// A Face isn't typically meant to be used directly. It is usually used
// via a Collection in order to store it in an Atlas.
//
// Translated from ghostty/src/font/face/freetype.zig

import freetype

// ============================================================
// Library
// ============================================================

// Library wraps the FreeType library with a mutex for thread safety.
// A Library can be shared across multiple faces and surfaces.
pub struct Library {
pub mut:
	lib freetype.Library
	// XTODO: add sync.Mutex when thread-safe access is needed
}

// init creates a new font Library.
pub fn Library.init() !Library {
	return Library{
		lib: freetype.Library.init()!
	}
}

// deinit destroys the library and releases resources.
pub fn (mut l Library) deinit() {
	l.lib.deinit()
}

// ============================================================
// FreetypeLoadFlags
// ============================================================

// FreetypeLoadFlags controls operations performed during glyph loading.
// Only a subset is exposed for configuration; for the whole set of flags
// see freetype.LoadFlags.
pub struct FreetypeLoadFlags {
pub:
	// Whether to enable hinting.
	hinting        bool = true
	// Whether to force the auto-hinter.
	force_autohint bool
	// Whether to enable the auto-hinter.
	autohint       bool = true
	// Whether to render glyphs in monochrome.
	monochrome     bool
	// Whether to use light hinting mode.
	light          bool
}

// Default load flags.
pub const freetype_load_flags_default = FreetypeLoadFlags{}

// ============================================================
// FaceOptions
// ============================================================

// FaceOptions holds options for creating or resizing a font face.
pub struct FaceOptions {
pub mut:
	// The desired font size.
	size                DesiredSize
	// Freetype load flags to use when loading glyphs.
	freetype_load_flags FreetypeLoadFlags = freetype_load_flags_default
}

// ============================================================
// Variation
// ============================================================

// VariationId is a 4-byte OpenType variation axis identifier.
pub struct VariationId {
pub:
	value u32
}

// str returns the 4-character tag representation.
pub fn (id VariationId) str() string {
	bytes := [u8((id.value >> 24) & 0xFF), u8((id.value >> 16) & 0xFF),
		u8((id.value >> 8) & 0xFF), u8(id.value & 0xFF)]
	return bytes.bytestr()
}

// Variation describes a setting for a font variation axis.
pub struct Variation {
pub:
	// The 4-byte axis identifier (e.g., 'wght', 'wdth').
	id    VariationId
	// The value for this axis.
	value f64
}

// ============================================================
// GlyphSize
// ============================================================

// GlyphSize holds the position and size of a glyph bounding box
// as f64 values.
pub struct GlyphSize {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

// ============================================================
// FaceMetrics
// ============================================================

// FaceMetrics holds per-face measurement data extracted from font tables.
// These are used to calculate grid-level Metrics via Metrics.calc().
pub struct FaceMetrics {
pub mut:
	// Pixels per em unit.
	px_per_em               f64
	// Width of the widest visible ASCII character.
	cell_width              f64
	// Ascent from baseline to top of em square (positive).
	ascent                  f64
	// Descent from baseline to bottom (negative).
	descent                 f64
	// Line gap (additional leading between lines).
	line_gap                f64
	// Underline position (from baseline, negative = below).
	underline_position      ?f64
	// Underline thickness.
	underline_thickness     ?f64
	// Strikethrough position (from baseline).
	strikethrough_position  ?f64
	// Strikethrough thickness.
	strikethrough_thickness ?f64
	// Cap height (height of capital letters like 'H').
	cap_height              ?f64
	// x-height (height of lowercase letters like 'x').
	ex_height               ?f64
	// Height of the bounding box of visible ASCII characters.
	ascii_height            ?f64
	// Advance width of '水' (CJK ideograph), for ic-width sizing.
	ic_width                ?f64
}

// line_height returns the total line height (ascent - descent + gap).
pub fn (m FaceMetrics) line_height() f64 {
	return m.ascent - m.descent + m.line_gap
}

// cap_height_val returns cap_height if available, or estimates it
// as 70% of ascent.
pub fn (m FaceMetrics) cap_height_val() f64 {
	return m.cap_height or { m.ascent * 0.7 }
}

// ex_height_val returns ex_height if available, or estimates it
// as 50% of ascent.
pub fn (m FaceMetrics) ex_height_val() f64 {
	return m.ex_height or { m.ascent * 0.5 }
}

// ic_width_val returns ic_width if available, or estimates it
// as min(2 * cell_width, ascii_height).
pub fn (m FaceMetrics) ic_width_val() f64 {
	if w := m.ic_width {
		return w
	}
	two_cell := 2.0 * m.cell_width
	if h := m.ascii_height {
		if h < two_cell {
			return h
		}
	}
	return two_cell
}

// ============================================================
// DeferredFace
// ============================================================

// DeferredFace is a font face that hasn't been fully loaded yet.
// It stores enough information (codepoint coverage, presentation)
// to search for fallback fonts without the overhead of full loading.
pub struct DeferredFace {
pub mut:
	// The path to the font file, if file-based.
	path       string
	// The face index within the font file.
	face_index i32
	// XTODO: codepoint coverage bitmap for has_codepoint()
}

// deinit releases deferred face resources.
pub fn (mut d DeferredFace) deinit() {
	// XTODO: free codepoint coverage data
}

// load fully loads this deferred face into a Face.
pub fn (d DeferredFace) load(lib Library, opts FaceOptions) !Face {
	// XTODO: actually load the face from d.path / d.face_index
	// using lib.lib.init_face()
	return error('deferred loading not implemented')
}

// has_codepoint returns true if this deferred face contains the given
// codepoint with the specified presentation (or any if presentation is none).
pub fn (d DeferredFace) has_codepoint(cp u32, presentation ?Presentation) bool {
	// XTODO: check codepoint coverage bitmap
	_ = cp
	_ = presentation
	return false
}

// ============================================================
// Face
// ============================================================

// Face represents a single font face backed by FreeType.
pub struct Face {
pub mut:
	// Our Library.
	lib                                 Library
	// Our font face.
	face                                freetype.Face
	// Harfbuzz font corresponding to this face.
	// XTODO: use harfbuzz.Font when integrated
	hb_font                             voidptr
	// Freetype load flags for this font face.
	load_flags                          FreetypeLoadFlags
	// Set quirks.disableDefaultFontFeatures.
	quirks_disable_default_font_features bool
	// Set to true to apply a synthetic italic to the face.
	synthetic_italic                    bool
	// Set to true to apply a synthetic bold to the face.
	synthetic_bold                      bool
	// The current size this font is set to.
	size                                DesiredSize
}

// init_file initializes a new font face from a file path.
pub fn Face.init_file(lib Library, path string, index i32, opts FaceOptions) !Face {
	// XTODO: needs real FreeType face loading
	// Steps:
	// 1. lib.lib.init_face(path, index) to get freetype.Face
	// 2. face.select_charmap(.unicode) to set Unicode charmap
	// 3. set_size_(face, opts.size) to set initial size
	// 4. harfbuzz.freetype.createFont(face.handle) to create HB font
	// 5. Create mutex for glyph slot access
	// 6. Check quirks.disableDefaultFontFeatures
	// 7. In debug mode, output variation axes info
	return Face{
		lib: lib
		load_flags: opts.freetype_load_flags
		size: opts.size
	}
}

// init_mem initializes a new font face from in-memory data.
pub fn Face.init_mem(lib Library, source []u8, opts FaceOptions) !Face {
	// XTODO: needs real FreeType face loading from memory
	// Similar to init_file but uses lib.lib.init_memory_face(source, 0)
	_ = source
	return Face{
		lib: lib
		load_flags: opts.freetype_load_flags
		size: opts.size
	}
}

// deinit destroys this face and releases all resources.
pub fn (mut self Face) deinit() {
	// XTODO: needs real FreeType/HarfBuzz cleanup
	// 1. Destroy ft_mutex
	// 2. Lock library mutex, deinit freetype face, unlock
	// 3. Destroy harfbuzz font
	self.face.deinit()
}

// name returns the font name. Reads the SFNT name table to find
// the font family entry.
//
// If allocation is required, buf will be used, but sometimes
// allocation isn't required and a static string is returned.
pub fn (self &Face) name(mut buf []u8) !string {
	// XTODO: needs real FreeType SFNT name table access
	// Reads the font family entry from the name table.
	// For Microsoft platform with Unicode encoding, performs
	// byte-swapped UTF-16LE to UTF-8 conversion.
	count := self.face.get_sfnt_name_count()

	// We look for the font family entry.
	for i in 0 .. count {
		entry := self.face.get_sfnt_name(i) or { continue }
		if entry.name_id == freetype.tt_name_id_font_family {
			str_data := entry.string_data
			// There are other encodings that are something other than UTF-8
			// but this is one we've seen "in the wild" so far.
			if entry.platform_id == freetype.tt_platform_microsoft
				&& entry.encoding_id == freetype.tt_ms_id_unicode_cs {
				if str_data.len % 2 != 0 || str_data.len > 1024 {
					return str_data.bytestr()
				}
				// XTODO: byte-swap UTF-16LE and convert to UTF-8
				// Need to swap each u16 pair and decode as UTF-16LE
				return str_data.bytestr()
			}
			return str_data.bytestr()
		}
	}

	return ''
}

// synthetic_bold_face returns a new face that is the same as this but
// also has synthetic bold applied.
pub fn (self &Face) synthetic_bold_face(opts FaceOptions) !Face {
	// XTODO: needs real FreeType face ref-counting
	// Increase face ref count.
	self.face.ref()

	mut f := Face.init_file(self.lib, '', 0, opts)!
	f.synthetic_italic = self.synthetic_italic
	f.synthetic_bold = true
	return f
}

// synthetic_italic_face returns a new face that is the same as this but
// has a transformation matrix applied to italicize it.
pub fn (self &Face) synthetic_italic_face(opts FaceOptions) !Face {
	// XTODO: needs real FreeType face ref-counting
	// Increase face ref count.
	self.face.ref()

	mut f := Face.init_file(self.lib, '', 0, opts)!
	f.synthetic_italic = true
	f.synthetic_bold = self.synthetic_bold
	return f
}

// set_face_size resizes the font in-place. If this succeeds, the caller
// is responsible for clearing any glyph caches, font atlas data, etc.
pub fn (mut self Face) set_face_size(opts FaceOptions) ! {
	// XTODO: needs real FreeType sizing
	// If scalable: face.set_char_size(0, size_26dot6, xdpi, ydpi)
	// If bitmap: select_size_nearest(face, round(size.pixels()))
	self.size = opts.size
}

// set_variations sets the variation axes for this font.
// This will modify this font in-place.
pub fn (mut self Face) set_variations(vs []Variation, opts FaceOptions) ! {
	_ = opts

	// If this font doesn't support variations, we can't do anything.
	if !self.face.has_multiple_masters() || vs.len == 0 {
		return
	}

	// Freetype requires that we send ALL coordinates in at once so the
	// first thing we have to do is get all the vars and put them into
	// an array.
	mm := self.face.get_mm_var() or { return }

	// To avoid allocations, we cap the number of variation axes we can
	// support. This is arbitrary but Firefox caps this at 16 so I
	// feel like that's probably safe... and we do double cause its
	// cheap.
	max_axes := if mm.num_axis < 32 { mm.num_axis } else { u32(32) }
	mut coords := []i64{len: int(max_axes)}
	self.face.get_var_design_coordinates(mut coords) or { return }

	// Now we go through each axis and see if its set. This is slow
	// but there usually aren't many axes and usually not many set
	// variations, either.
	for i in 0 .. max_axes {
		axis := mm.axis[i]
		for v in vs {
			if u32(axis.tag) == v.id.value {
				coords[i] = i64(v.value * 65536)
				break
			}
		}
	}

	// Set them!
	self.face.set_var_design_coordinates(coords) or { return }
}

// glyph_index returns the glyph index for the given Unicode code point.
// If this face doesn't support this glyph, none is returned.
pub fn (self Face) glyph_index(cp u32) ?u32 {
	return self.face.get_char_index(cp)
}

// has_color returns true if this font is colored. This can be used by
// callers to determine what kind of atlas to pass in.
pub fn (self Face) has_color() bool {
	return self.face.has_color()
}

// is_color_glyph returns true if the given glyph ID is colorized.
pub fn (self &Face) is_color_glyph(glyph_id u32) bool {
	// XTODO: needs real FreeType glyph loading with mutex lock
	// Load the glyph and see what pixel mode it renders with.
	// All modes other than BGRA are non-color.
	// If the glyph fails to load, just return false.
	self.face.load_glyph(glyph_id, freetype.LoadFlags{
		render: true
		color:  self.face.has_color()
		// NO_SVG set to true because we don't currently support rendering
		// SVG glyphs under FreeType, since that requires bundling another
		// dependency to handle rendering the SVG.
		no_svg: true
	}) or { return false }

	glyph := self.face.handle
	if glyph == unsafe { nil } {
		return false
	}
	glyph_slot := glyph.glyph
	if glyph_slot == unsafe { nil } {
		return false
	}
	return glyph_slot.bitmap.pixel_mode == freetype.pixel_mode_bgra
}

// glyph_load_flags returns the LoadFlags to use when loading a glyph
// for measurement or rendering.
//
// Hinting should only be enabled if the configured load flags specify
// it and the provided constraint doesn't actually do anything, since
// if it does, then it'll mess up the hinting anyway when it moves or
// resizes the glyph.
fn (self Face) glyph_load_flags(constrained bool) freetype.LoadFlags {
	do_hinting := self.load_flags.hinting && !constrained

	return freetype.LoadFlags{
		// If our glyph has color, we want to render the color.
		color:          self.face.has_color()
		// We don't render, because we'll invoke the render
		// manually after applying constraints further down.
		render:         false
		// Use options from config.
		no_hinting:     !do_hinting
		force_autohint: self.load_flags.force_autohint
		no_autohint:    !self.load_flags.autohint
		// If we're gonna be rendering this glyph in monochrome,
		// then we should use the monochrome hinter as well, or
		// else it won't look very good at all.
		//
		// Otherwise if the user asked for light hinting we
		// use that, otherwise we just use the normal target.
		target:         if self.load_flags.monochrome {
			.mono
		} else if self.load_flags.light {
			.light
		} else {
			.normal
		}
		// NO_SVG set to true because we don't currently support rendering
		// SVG glyphs under FreeType.
		no_svg:         true
	}
}

// get_glyph_size returns a rect representing the position and size
// of the loaded glyph.
fn get_glyph_size(glyph &freetype.GlyphSlotRec) GlyphSize {
	// If we're dealing with an outline glyph then we get the
	// outline's bounding box instead of using the built-in
	// metrics, since that's more precise and allows better
	// cell-fitting.
	if glyph.format == freetype.glyph_format_outline {
		// Get the glyph's bounding box before we transform it at all.
		// We use this rather than the metrics, since it's more precise.
		mut bbox := freetype.BBox{}
		freetype.outline_get_bbox(&glyph.outline, mut bbox)

		return GlyphSize{
			x:      freetype.f26dot6_to_f64(bbox.x_min)
			y:      freetype.f26dot6_to_f64(bbox.y_min)
			width:  freetype.f26dot6_to_f64(bbox.x_max - bbox.x_min)
			height: freetype.f26dot6_to_f64(bbox.y_max - bbox.y_min)
		}
	}

	return GlyphSize{
		x:      freetype.f26dot6_to_f64(glyph.metrics.hori_bearing_x)
		y:      freetype.f26dot6_to_f64(glyph.metrics.hori_bearing_y - glyph.metrics.height)
		width:  freetype.f26dot6_to_f64(glyph.metrics.width)
		height: freetype.f26dot6_to_f64(glyph.metrics.height)
	}
}

// render_glyph renders a glyph using the glyph index. The rendered glyph
// is stored in the given texture atlas.
pub fn (self Face) render_glyph(mut atlas Atlas, glyph_index u32, opts RenderOptions) !GlyphInfo {
	// XTODO: needs real FreeType glyph loading, outline manipulation,
	// bitmap conversion, synthetic bold/italic, constraint application,
	// and atlas allocation.
	//
	// Full algorithm:
	// 1. Lock ft_mutex, load glyph with glyph_load_flags(constrained).
	// 2. For synthetic bold: embolden outline based on font height heuristic.
	// 3. Get glyph bounding box via get_glyph_size().
	// 4. If glyph < 0.25px in either axis, return zero-size glyph.
	// 5. Apply constraint.constrain() for sizing/positioning.
	// 6. Center glyph within cell if face_width < cell_width and no stretch.
	// 7. For bitmap glyphs, quantize to full pixel boundaries.
	// 8. Render:
	//    - Outline: transform outline points (scale, translate, skew for
	//      synthetic italic at 12 degrees), rasterize, bitmap_convert.
	//    - Bitmap: convert to 8bpp if needed, resize with stb_image_resize,
	//      bitmap_copy.
	// 9. Verify pixel mode matches atlas format (grayscale/bgra).
	// 10. Normalize grayscale pixel values if num_grays < 256.
	// 11. Reserve atlas region and copy bitmap data.
	// 12. Calculate offsets (px_x = bitmap_left, px_y = bitmap_top +
	//     cell_baseline - rows).
	// 13. Return Glyph with atlas coordinates and offsets.
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

// units_to_px_y converts font design units to pixels based on the
// y-scale factor of the current font size.
fn (self Face) units_to_px_y(units i32) i32 {
	if self.face.handle == unsafe { nil } || self.face.handle.size == unsafe { nil } {
		return 0
	}
	return i32(freetype.mul_fix(
		i64(units),
		self.face.handle.size.metrics.y_scale,
	) >> 6)
}

// get_metrics returns the FaceMetrics for this face.
//
// This reads metrics from multiple sources:
// - FreeType size metrics (ascender, descender, height, max_advance)
// - 'head' table (Units_Per_EM)
// - 'post' table (underlinePosition, underlineThickness)
// - 'OS/2' table (sTypoAscender/Descender/LineGap, fsSelection,
//   usWinAscent/Descent, sCapHeight, sxHeight, yStrikeoutSize/Position)
// - 'hhea' table (Ascender, Descender, Line_Gap)
//
// Cell width is calculated by measuring all visible ASCII characters
// and taking the widest advance width.
//
// Cap height and ex height are either from OS/2 (v2+) or measured
// from the 'H' and 'x' glyphs respectively.
//
// IC width is measured from '水' (U+6C34).
pub fn (mut self Face) get_metrics() FaceMetrics {
	// XTODO: needs real FreeType table access for full metric extraction.
	// The stub below returns basic metrics from the FreeType size metrics.
	// Full implementation requires reading head, post, OS/2, hhea tables
	// and measuring individual glyphs.

	face := self.face
	if face.handle == unsafe { nil } || face.handle.size == unsafe { nil } {
		return FaceMetrics{}
	}

	size_metrics := face.handle.size.metrics

	// This code relies on this assumption, and it should always be
	// true since we don't do any non-uniform scaling on the font ever.
	// assert(size_metrics.x_ppem == size_metrics.y_ppem)

	// Whether the font is in a scalable format.
	is_scalable := face.handle.face_flags & freetype.face_flag_scalable != 0

	// We get the UPM from the head table.
	// If we have no head, but it is a scalable face, take the UPM from
	// FreeType's units_per_EM, otherwise we'll assume that UPM == PPEM.
	head := face.get_sfnt_table_head()
	units_per_em := if h := head {
		h.units_per_em
	} else if is_scalable {
		face.handle.units_per_em
	} else {
		size_metrics.y_ppem
	}
	px_per_em := f64(size_metrics.y_ppem)
	px_per_unit := px_per_em / f64(units_per_em)

	// Read the 'post' table.
	post := face.get_sfnt_table_post()
	// Read the 'OS/2' table.
	os2_raw := face.get_sfnt_table_os2()
	os2 := if o := os2_raw {
		if o.version != 0xFFFF { os2_raw } else { ?&freetype.TT_OS2(none) }
	} else {
		?&freetype.TT_OS2(none)
	}
	// Read the 'hhea' table.
	hhea := face.get_sfnt_table_hhea()

	// --- Vertical metrics ---
	mut ascent := f64(0)
	mut descent := f64(0)
	mut line_gap := f64(0)

	if h := hhea {
		hhea_ascent := f64(h.ascender)
		hhea_descent := f64(h.descender)
		hhea_line_gap := f64(h.line_gap)

		if o := os2 {
			os2_ascent := f64(o.s_typo_ascender)
			os2_descent := f64(o.s_typo_descender)
			os2_line_gap := f64(o.s_typo_line_gap)

			// If the font says to use typo metrics, trust it.
			// (The USE_TYPO_METRICS bit is bit 7)
			if o.fs_selection & (1 << 7) != 0 {
				ascent = os2_ascent * px_per_unit
				descent = os2_descent * px_per_unit
				line_gap = os2_line_gap * px_per_unit
			} else if h.ascender != 0 || h.descender != 0 {
				// Otherwise prefer hhea metrics if available.
				ascent = hhea_ascent * px_per_unit
				descent = hhea_descent * px_per_unit
				line_gap = hhea_line_gap * px_per_unit
			} else if os2_ascent != 0 || os2_descent != 0 {
				ascent = os2_ascent * px_per_unit
				descent = os2_descent * px_per_unit
				line_gap = os2_line_gap * px_per_unit
			} else {
				win_ascent := f64(o.us_win_ascent)
				win_descent := f64(o.us_win_descent)
				ascent = win_ascent * px_per_unit
				// usWinDescent is *positive* -> down, so flip sign.
				descent = -win_descent * px_per_unit
				line_gap = 0.0
			}
		} else {
			// No OS/2, use hhea blindly.
			ascent = hhea_ascent * px_per_unit
			descent = hhea_descent * px_per_unit
			line_gap = hhea_line_gap * px_per_unit
		}
	} else {
		// No hhea table, rely on FreeType metrics.
		ascent = freetype.f26dot6_to_f64(size_metrics.ascender)
		descent = freetype.f26dot6_to_f64(size_metrics.descender)
		h := freetype.f26dot6_to_f64(size_metrics.height)
		// line_gap = height + descender - ascender
		line_gap = h + descent - ascent
	}

	// --- Underline ---
	mut underline_position := ?f64(none)
	mut underline_thickness := ?f64(none)
	if p := post {
		has_broken_underline := p.underline_thickness == 0
		if !(has_broken_underline && p.underline_position == 0) {
			underline_position = f64(p.underline_position) * px_per_unit
		}
		if !has_broken_underline {
			underline_thickness = f64(p.underline_thickness) * px_per_unit
		}
	}

	// --- Strikethrough ---
	mut strikethrough_position := ?f64(none)
	mut strikethrough_thickness := ?f64(none)
	if o := os2 {
		has_broken_st := o.y_strikeout_size == 0
		if !(has_broken_st && o.y_strikeout_position == 0) {
			strikethrough_position = f64(o.y_strikeout_position) * px_per_unit
		}
		if !has_broken_st {
			strikethrough_thickness = f64(o.y_strikeout_size) * px_per_unit
		}
	}

	// --- Cell width ---
	// XTODO: measure all visible ASCII chars and take widest advance.
	// For now, use max_advance from FreeType.
	cell_width := freetype.f26dot6_to_f64(size_metrics.max_advance)

	// --- Cap height / ex height ---
	mut cap_height := ?f64(none)
	mut ex_height := ?f64(none)
	if o := os2 {
		if o.version >= 2 {
			cap_height = f64(o.s_cap_height) * px_per_unit
			ex_height = f64(o.sx_height) * px_per_unit
		}
	}
	// XTODO: if OS/2 v2 not available, measure 'H' and 'x' glyphs.

	// XTODO: measure '水' for ic_width.

	return FaceMetrics{
		px_per_em:               px_per_em
		cell_width:              cell_width
		ascent:                  ascent
		descent:                 descent
		line_gap:                line_gap
		underline_position:      underline_position
		underline_thickness:     underline_thickness
		strikethrough_position:  strikethrough_position
		strikethrough_thickness: strikethrough_thickness
		cap_height:              cap_height
		ex_height:               ex_height
	}
}

// copy_table copies the font table data for the given tag.
pub fn (self Face) copy_table(tag string) ![]u8 {
	return self.face.load_sfnt_table(freetype.Tag.init(tag))
}
