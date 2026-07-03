module font

// Tests for Face (translated from ghostty/src/font/face/freetype.zig)
//
// XTODO: All tests require embedded font data and real FreeType
// rendering to function. They are preserved here for completeness
// and future implementation.

fn test_face_name() {
	// XTODO: needs embedded font data (variable, inconsolata)
	// and real FreeType face initialization.
	//
	// Original test:
	// 1. Init library and two faces (JetBrains Mono variable, Inconsolata)
	// 2. Verify face.name() returns "JetBrains Mono" and "Inconsolata"
}

fn test_render_all_ascii() {
	// XTODO: needs embedded font data (inconsolata) and real
	// FreeType rendering with Atlas allocation.
	//
	// Original test:
	// 1. Init library, atlas (512, grayscale), and face at 12pt 96dpi
	// 2. Render all visible ASCII (32..127) via renderGlyph
	// 3. Test resizing: render 'A' at 12pt (expect height=11),
	//    resize to 24pt, render 'A' again (expect height=21)
}

fn test_color_emoji() {
	// XTODO: needs embedded emoji font and real FreeType rendering.
	//
	// Original test:
	// 1. Init library, atlas (512, bgra), face with emoji font at 12pt
	// 2. Render disguised face emoji (U+1F978)
	// 3. Verify face.hasColor() == true
	// 4. Verify face.isColorGlyph(glyphIndex) == true
}

fn test_mono_to_bgra() {
	// XTODO: needs embedded emoji font and real FreeType rendering.
	//
	// Original test:
	// 1. Init library, atlas (512, bgra), face with emoji font at 12pt 72dpi
	// 2. Render glyph 3 (which is mono in Noto) to bgra atlas
}

fn test_svg_font_table() {
	// XTODO: needs embedded JuliaMono font and real FreeType table loading.
	//
	// Original test:
	// 1. Init library, face with JuliaMono at 12pt 72dpi
	// 2. Load "SVG " table via copyTable
	// 3. Verify table length == 430
}

fn test_bitmap_glyph() {
	// XTODO: needs embedded Terminus TTF and real FreeType rendering.
	//
	// Original test:
	// 1. Init library, atlas (512, grayscale), Terminus face at 12pt 96dpi
	// 2. Render glyph 77 ('i')
	// 3. Verify dimensions: 8x16
	// 4. Verify pixel-perfect rendering against terminus_i pattern

	// Expected pixel pattern for Terminus 'i':
	// ........
	// ........
	// ...#....
	// ...#....
	// ........
	// ..##....
	// ...#....
	// ...#....
	// ...#....
	// ...#....
	// ...#....
	// ..###...
	// ........
	// ........
	// ........
	// ........
}

fn test_bitmap_glyph_bdf() {
	// XTODO: needs embedded Spleen BDF font and real FreeType rendering.
	//
	// Original test:
	// 1. Init library, atlas (512, grayscale), Spleen BDF face at 12pt 96dpi
	// 2. Render glyph for 'A'
	// 3. Verify 8x16 dimensions
	// 4. Verify pixel-perfect against spleen_A pattern
}

fn test_bitmap_glyph_pcf() {
	// XTODO: needs embedded Spleen PCF font and real FreeType rendering.
	//
	// Same as BDF test but with PCF format.
}

fn test_bitmap_glyph_otb() {
	// XTODO: needs embedded Spleen OTB font and real FreeType rendering.
	//
	// Same as BDF test but with OTB (OpenType Bitmap) format.
}

// ============================================================
// Pure/portable tests translated from ghostty/src/font/face.zig
// ============================================================

// approx_eq_rel mirrors std.math.approxEqRel: |a-b| <= max(|a|,|b|) * tol.
// The ghostty tests use expectApproxEqual with tol = sqrt(eps(f64)).
fn approx_eq_rel(a f64, b f64) bool {
	if a == b {
		return true
	}
	tol := 1.4901161193847656e-08 // sqrt(eps(f64))
	diff := if a > b { a - b } else { b - a }
	aa := if a < 0 { -a } else { a }
	ab := if b < 0 { -b } else { b }
	max := if aa > ab { aa } else { ab }
	return diff <= max * tol
}

fn assert_glyph_approx(expected GlyphSize, actual GlyphSize) {
	assert approx_eq_rel(expected.x, actual.x), 'x: expected ${expected.x}, got ${actual.x}'
	assert approx_eq_rel(expected.y, actual.y), 'y: expected ${expected.y}, got ${actual.y}'
	assert approx_eq_rel(expected.width, actual.width), 'width: expected ${expected.width}, got ${actual.width}'
	assert approx_eq_rel(expected.height, actual.height), 'height: expected ${expected.height}, got ${actual.height}'
}

fn test_variation_id_wght() {
	// ghostty: Variation.Id.init("wght") bitcasts to 2003265652 and str() == "wght".
	id := VariationId.init('wght')
	assert id.value == u32(2003265652)
	assert id.str() == 'wght'
}

fn test_variation_id_slnt() {
	// ghostty: {'s','l','n','t'} bitcasts to 1936486004 and str() == "slnt".
	id := VariationId.init('slnt')
	assert id.value == u32(1936486004)
	assert id.str() == 'slnt'
}

fn test_constraints() {
	// Hardcoded data matches metrics from CoreText at size 12 and DPI 96.
	// Grid metrics matching font-family = JetBrains Mono.
	metrics := Metrics{
		cell_width:              10
		cell_height:             22
		cell_baseline:           5
		underline_position:      19
		underline_thickness:     1
		strikethrough_position:  12
		strikethrough_thickness: 1
		overline_position:       0
		overline_thickness:      1
		box_thickness:           1
		cursor_thickness:        1
		cursor_height:           22
		icon_height:             21.12
		icon_height_single:      44.48 / 3.0
		face_width:              9.6
		face_height:             21.12
		face_y:                  0.2
	}

	// ASCII (no constraint): do nothing for any constraint width.
	{
		constraint := Constraint{}
		glyph_x := GlyphSize{
			width:  6.784
			height: 15.28
			x:      1.408
			y:      4.84
		}
		assert_glyph_approx(glyph_x, constraint.constrain(glyph_x, metrics, 1))
		assert_glyph_approx(glyph_x, constraint.constrain(glyph_x, metrics, 2))
	}

	// Symbol (same constraint as hardcoded in Renderer.addGlyph).
	{
		constraint := Constraint{
			size: .fit
		}
		// BBox of '■' (0x25A0 black square) from Iosevka.
		glyph_25a0 := GlyphSize{
			width:  10.272
			height: 10.272
			x:      2.864
			y:      5.304
		}
		// Constraint width 1: scale down and shift to fit a single cell.
		assert_glyph_approx(GlyphSize{
			width:  metrics.face_width
			height: metrics.face_width
			x:      0
			y:      5.64
		}, constraint.constrain(glyph_25a0, metrics, 1))
		// Constraint width 2: do nothing.
		assert_glyph_approx(glyph_25a0, constraint.constrain(glyph_25a0, metrics, 2))
	}

	// Emoji (same constraint as hardcoded in SharedGrid.renderGlyph).
	{
		constraint := Constraint{
			size:             .cover
			align_horizontal: .center
			align_vertical:   .center
			pad_left:         0.025
			pad_right:        0.025
		}
		// BBox of '🥸' (0x1F978) from Apple Color Emoji.
		glyph_1f978 := GlyphSize{
			width:  20
			height: 20
			x:      0.46
			y:      1
		}
		// Constraint width 2: scale to cover two cells with padding, center.
		assert_glyph_approx(GlyphSize{
			width:  18.72
			height: 18.72
			x:      0.44
			y:      1.4
		}, constraint.constrain(glyph_1f978, metrics, 2))
	}

	// Nerd Font default (0xEA61 nf-cod-lightbulb).
	{
		constraint := get_constraint(0xea61) or {
			assert false, 'expected constraint for 0xea61'
			return
		}
		// Verify that this is the constraint we expect.
		assert constraint.size == .fit_cover1
		assert constraint.height == .icon
		assert constraint.align_horizontal == .center1
		assert constraint.align_vertical == .center1

		// BBox of the icon (part of a group, so the constraint applies to
		// a larger bounding box via relative_* fields).
		glyph_ea61 := GlyphSize{
			width:  9.015625
			height: 13.015625
			x:      3.015625
			y:      3.76525
		}
		// Constraint width 1: scale and shift group to fit a single cell.
		assert_glyph_approx(GlyphSize{
			width:  7.2125
			height: 10.4125
			x:      0.8125
			y:      5.950695224719102
		}, constraint.constrain(glyph_ea61, metrics, 1))
		// Constraint width 2: no scaling; left-align and vertically center group.
		assert_glyph_approx(GlyphSize{
			width:  glyph_ea61.width
			height: glyph_ea61.height
			x:      1.015625
			y:      4.7483690308988775
		}, constraint.constrain(glyph_ea61, metrics, 2))
	}

	// Nerd Font stretch (0xE0C0 nf-ple-flame_thick).
	{
		constraint := get_constraint(0xe0c0) or {
			assert false, 'expected constraint for 0xe0c0'
			return
		}
		// Verify that this is the constraint we expect.
		assert constraint.size == .stretch
		assert constraint.height == .cell
		assert constraint.align_horizontal == .start
		assert constraint.align_vertical == .center1

		glyph_e0c0 := GlyphSize{
			width:  16.796875
			height: 16.46875
			x:      -0.796875
			y:      1.7109375
		}
		// Constraint width 1: stretch and position to exactly cover one cell.
		assert_glyph_approx(GlyphSize{
			width:  f64(metrics.cell_width)
			height: f64(metrics.cell_height)
			x:      0
			y:      0
		}, constraint.constrain(glyph_e0c0, metrics, 1))
		// Constraint width 2: stretch and position to exactly cover two cells.
		assert_glyph_approx(GlyphSize{
			width:  f64(2 * metrics.cell_width)
			height: f64(metrics.cell_height)
			x:      0
			y:      0
		}, constraint.constrain(glyph_e0c0, metrics, 2))
	}
}
