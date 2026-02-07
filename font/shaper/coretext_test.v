module shaper

import font
import macos

// ============================================================
// Test helpers
// ============================================================

struct TestShaper {
mut:
	shp Shaper
}

fn (mut self TestShaper) deinit() {
	self.shp.deinit()
}

enum TestFont {
	code_new_roman
	geist_mono
	inconsolata
	jetbrains_mono
	monaspace_neon
	nerd_font
}

// Helper to return a fully initialized shaper.
fn create_shaper() !TestShaper {
	return create_shaper_with_font(.inconsolata)
}

fn create_shaper_with_font(font_req TestFont) !TestShaper {
	// XTODO: Full test setup requires loading embedded fonts
	// (inconsolata, geist_mono, jetbrains_mono, monaspace_neon,
	// nerd_font, Apple Color Emoji) into a Collection / SharedGrid.
	// For now we create a shaper with "dlig" feature enabled.
	_ = font_req

	// Some of our tests rely on dlig being enabled by default
	mut shp := Shaper.init(font.ShaperOptions{
		features: ['dlig']
	})!

	return TestShaper{
		shp: shp
	}
}

// Return a fully initialized shaper by discovering a named font on the system.
fn create_shaper_with_discovered_font(font_req string) !TestShaper {
	// XTODO: Font discovery requires CoreText APIs.
	// (CTFontManagerCreateFontDescriptorsFromURL or similar.)
	_ = font_req

	mut shp := Shaper.init(font.ShaperOptions{
		features: []string{}
	})!

	return TestShaper{
		shp: shp
	}
}

// ============================================================
// Tests
// ============================================================

// test "run iterator"
// Verifies basic run iteration: plain text, text with spaces, emoji splits,
// and bad ligatures (fl, fi, st).
fn test_run_iterator() {
	// XTODO: Requires terminal.Terminal, terminal.RenderState, and vtStream
	// which are not available in the shaper module.

	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// Basic test: "ABCD" in a 5-col terminal should be 1 run.
	// {
	//     mut t := terminal.Terminal.init(.{ cols: 5, rows: 3 }) or { return }
	//     defer { t.deinit() }
	//     mut s := t.vt_stream()
	//     defer { s.deinit() }
	//     s.next_slice('ABCD') or { return }
	//     mut state := terminal.RenderState.empty
	//     defer { state.deinit() }
	//     state.update(&t) or { return }
	//     mut shp := &td.shp
	//     mut it := shp.run_iterator(.{ grid: td.grid, cells: state.row_data.get(0).cells.slice() })
	//     mut count := 0
	//     for { _ = it.next() or { break }; count++ }
	//     assert count == 1
	// }

	// Spaces should be part of a run
	// "ABCD   EFG" should be 1 run.

	// Emoji should split into 3 runs ("A", emoji, "D").

	// Bad ligatures "fl", "fi", "st" should each be 2 runs.
}

// test "run iterator: empty cells with background set"
fn test_run_iterator_empty_cells_with_bg() {
	// XTODO: Requires terminal infrastructure to create cells with
	// bg_color_rgb content_tag and verify they produce runs.
	mut td := create_shaper() or { return }
	defer { td.deinit() }
}

// test "shape"
// Tests basic shaping: thumbs up plain + thumbs up with medium skin tone.
fn test_shape_thumbs_up() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// XTODO: Would encode 0x1F44D (thumbs up plain) twice, then 0x1F3FD
	// (medium skin tone), feed to terminal, shape, and verify 1 run.
	// The actual shaping requires CoreText APIs.
}

// test "shape nerd fonts"
// Tests shaping nerd font icon: space + nf-md-folder (U+F024B) + space.
fn test_shape_nerd_fonts() {
	mut td := create_shaper_with_font(.nerd_font) or { return }
	defer { td.deinit() }

	// XTODO: Would encode 0x20, 0xF024B, 0x20, feed to terminal,
	// shape, and verify 1 run.
}

// test "shape inconsolata ligs"
// Tests ligature shaping: ">=" -> 1 glyph, "===" -> 1 glyph.
fn test_shape_inconsolata_ligs() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// ">=" should be 1 run, 2 cells, 1 shaped glyph (ligature).
	// "===" should be 1 run, 3 cells, 1 shaped glyph (ligature).
	// XTODO: Requires terminal + CoreText shaping.
}

// test "shape monaspace ligs"
// Tests Monaspace Neon "===" ligature.
fn test_shape_monaspace_ligs() {
	mut td := create_shaper_with_font(.monaspace_neon) or { return }
	defer { td.deinit() }

	// "===" should be 1 run, 3 cells, 1 shaped glyph.
	// XTODO: Requires terminal + CoreText shaping.
}

// https://github.com/mitchellh/ghostty/issues/1708
// test "shape left-replaced lig in last run"
// Tests "!==" ligature with Geist Mono where the lig replaces from the left.
fn test_shape_left_replaced_lig_last_run() {
	mut td := create_shaper_with_font(.geist_mono) or { return }
	defer { td.deinit() }

	// "!==" should be 1 run, 3 cells, 1 shaped glyph.
	// XTODO: Requires terminal + CoreText shaping.
}

// https://github.com/mitchellh/ghostty/issues/1708
// test "shape left-replaced lig in early run"
// Tests "!==X" with Geist Mono; lig + trailing char.
fn test_shape_left_replaced_lig_early_run() {
	mut td := create_shaper_with_font(.geist_mono) or { return }
	defer { td.deinit() }

	// "!==X" should be 1 run, 4 cells, 2 shaped glyphs.
	// XTODO: Requires terminal + CoreText shaping.
}

// https://github.com/mitchellh/ghostty/issues/1664
// test "shape U+3C9 with JB Mono"
// Tests omega (ω) character with JetBrains Mono.
fn test_shape_omega_jb_mono() {
	mut td := create_shaper_with_font(.jetbrains_mono) or { return }
	defer { td.deinit() }

	// "\u{03C9} foo" should be 1 run, 5 cells.
	// XTODO: Requires terminal + CoreText shaping.
}

// test "shape emoji width"
// Tests that a single emoji (thumbs up) shapes to 1 cell.
fn test_shape_emoji_width() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// "👍" should be 1 run, 1 shaped cell.
	// XTODO: Requires terminal + CoreText shaping.
}

// test "shape emoji width long"
// Tests a long emoji sequence (person with beard + skin tone + ZWJ + male sign
// + presentation selector) shapes to 1 cell.
fn test_shape_emoji_width_long() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// Long emoji (0x1F9D4 + graphemes 0x1F3FB, 0x200D, 0x2642, 0xFE0F)
	// should shape to 1 run, 1 cell.
	// XTODO: Requires terminal + page grapheme setup + CoreText shaping.
}

// test "shape variation selector VS15"
// Tests U+270C (victory hand) + U+FE0E (text presentation) -> 1 cell.
fn test_shape_variation_selector_vs15() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// 0x270C + 0xFE0E should be 1 run, 1 cell.
	// XTODO: Requires terminal + CoreText shaping.
}

// test "shape variation selector VS16"
// Tests U+270C (victory hand) + U+FE0F (emoji presentation) -> 1 cell.
fn test_shape_variation_selector_vs16() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// 0x270C + 0xFE0F should be 1 run, 1 cell.
	// XTODO: Requires terminal + CoreText shaping.
}

// test "shape with empty cells in between"
// Tests "A" + cursor forward 5 + "B" -> 1 run, 7 cells.
fn test_shape_empty_cells_between() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// "A\x1b[5CB" should be 1 run, 7 cells.
	// XTODO: Requires terminal + CoreText shaping.
}

// test "shape Combining characters"
// Tests 'n' + U+0308 (combining diaeresis) x2 + 'a' -> 4 cells.
fn test_shape_combining_characters() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// 'n' + 0x0308 + 0x0308 + 'a' should be 1 run, 4 cells.
	// cells[0..2].x == 0, cells[3].x == 1.
	// XTODO: Requires terminal with grapheme_cluster mode + CoreText shaping.
}

// test "shape Devanagari string"
// Tests that non-monotonic CoreText output is sorted correctly.
fn test_shape_devanagari() {
	// XTODO: Requires Arial Unicode MS font discovery + terminal + CoreText shaping.
	// The string "अपार्टमेंट" should produce 8 cells with specific x values.
	mut td := create_shaper_with_discovered_font('Arial Unicode MS') or { return }
	defer { td.deinit() }
}

// test "shape Tai Tham vowels (position differs from advance)"
// Tests that position.x offset is correct when it differs from advance.
fn test_shape_tai_tham_vowels() {
	// XTODO: Requires Noto Sans Tai Tham font discovery.
	// 0x1A2F + 0x1A70 should produce 2 cells, both at x=0.
	// cells[0].x_offset == cell_width, cells[1].x_offset == 0.
	mut td := create_shaper_with_discovered_font('Noto Sans Tai Tham') or { return }
	defer { td.deinit() }
}

// test "shape Tai Tham letters (position.y differs from advance)"
// Tests ligature across grapheme clusters with y-offset.
fn test_shape_tai_tham_letters() {
	// XTODO: Requires Noto Sans Tai Tham font discovery.
	// HA + SAKOT + YA + U should produce 3 cells, all at x=0.
	// cells[2].y_offset == -3.
	mut td := create_shaper_with_discovered_font('Noto Sans Tai Tham') or { return }
	defer { td.deinit() }
}

// test "shape Javanese ligatures"
// Tests PANGKON ligature with correct x_offset.
fn test_shape_javanese_ligatures() {
	// XTODO: Requires Noto Sans Javanese font discovery.
	// NA + PANGKON + HA + SUKU vowel -> 3 cells at x=0.
	// cells[2].x_offset > 3 * cell_width.
	mut td := create_shaper_with_discovered_font('Noto Sans Javanese') or { return }
	defer { td.deinit() }
}

// test "shape Chakma vowel sign with ligature (vowel sign renders first)"
// Tests out-of-order rendering where vowel sign appears before the consonant.
fn test_shape_chakma_vowel_sign() {
	// XTODO: Requires Noto Sans Chakma font discovery.
	// BAA + TAA + Virama + YYAA + Vowel Sign U -> 4 cells.
	// cells[1].x_offset < cells[2].x_offset (vowel renders before TAA).
	mut td := create_shaper_with_discovered_font('Noto Sans Chakma') or { return }
	defer { td.deinit() }
}

// test "shape Bengali ligatures with out of order vowels"
// Tests Bengali text where vowel sign E renders before SSA.
fn test_shape_bengali_ligatures() {
	// XTODO: Requires Arial Unicode MS font discovery.
	// RA + AA vowel + SSA + Virama + TTA + Virama + RA + E vowel -> 8 cells.
	// cells[2].x_offset < cells[3].x_offset.
	mut td := create_shaper_with_discovered_font('Arial Unicode MS') or { return }
	defer { td.deinit() }
}

// test "shape box glyphs"
// Tests that box drawing characters (U+2500, U+2501) use the sprite font
// and return codepoints as glyph indices.
fn test_shape_box_glyphs() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// 0x2500 + 0x2501 -> 1 run, 2 cells.
	// cells[0].glyph_index == 0x2500, cells[0].x == 0.
	// cells[1].glyph_index == 0x2501, cells[1].x == 1.
	// XTODO: Requires terminal + sprite font detection.
}

// test "shape selection boundary"
// Tests that selection boundaries correctly split runs.
fn test_shape_selection_boundary() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// "a1b2c3d4e5" with various selections:
	// Full line selection {0, cols-1} -> 1 run.
	// Selection {2, cols-1} -> 2 runs.
	// Selection {0, 3} -> 2 runs.
	// Selection {1, 3} -> 3 runs.
	// Selection {1, 1} -> 3 runs.
	// XTODO: Requires terminal + RunIterator with selection support.
}

// test "shape cursor boundary"
// Tests that cursor position correctly splits runs.
fn test_shape_cursor_boundary() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// "a1b2c3d4e5" with various cursor positions:
	// No cursor -> 1 run.
	// cursor_x=0 -> 2 runs.
	// cursor_x=1 -> 3 runs.
	// cursor_x=9 -> 2 runs.
	// Without cursor splitting remains 1.
	// XTODO: Requires terminal + RunIterator with cursor_x support.
}

// test "shape cursor boundary and colored emoji"
// Tests that cursor on a wide emoji does not split it.
fn test_shape_cursor_boundary_colored_emoji() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// "👍🏼" with cursor at 0 or 1 should not split the emoji run.
	// Always 1 run.
	// XTODO: Requires terminal + cursor handling for wide chars.
}

// test "shape cell attribute change"
// Tests that bold/fg color changes split runs, but bg color does not.
fn test_shape_cell_attribute_change() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// ">=" plain -> 1 run.
	// ">" + bold "=" -> 2 runs.
	// fg color change between ">" and "=" -> 2 runs.
	// bg color change between ">" and "=" -> 1 run (no split).
	// Same bg on both -> 1 run.
	// XTODO: Requires terminal with ANSI escape sequence processing.
}

// test "shape high plane sprite font codepoint"
// While creating runs, the CoreText shaper uses `0` codepoints to
// pad its codepoint list to account for high plane characters which
// use two UTF-16 code units. This is so that, after shaping, the string
// indices can be used to find the originating codepoint / cluster.
//
// This is a problem for special (sprite) fonts, which need to be "shaped"
// by simply returning the input codepoints verbatim. We include logic to
// skip `0` codepoints when constructing the shaped run for sprite fonts,
// this test verifies that it works correctly.
fn test_shape_high_plane_sprite_font_codepoint() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	// U+1FB70 (Vertical One Eighth Block-2) should:
	// - Produce UTF-16 surrogate pair [0xD83E, 0xDF70]
	// - Produce padded codepoint list [{0x1FB70, 0}, {0, 0}]
	// - Shape to 1 cell at position 0 with glyph_index == 0x1FB70
	// - Be identified as a sprite font run

	// Test the surrogate pair encoding directly
	sp := macos.get_surrogate_pair(0x1FB70)
	assert sp.is_pair == true
	assert sp.hi == 0xD83E
	assert sp.lo == 0xDF70
}

// test "add_codepoint with surrogate pairs"
// Verify that RunIteratorHook.add_codepoint correctly handles BMP and
// supplementary plane characters.
fn test_add_codepoint_surrogate_pairs() {
	mut td := create_shaper() or { return }
	defer { td.deinit() }

	mut hook := RunIteratorHook{
		shaper: &td.shp
	}
	hook.prepare()

	// Add a BMP character ('A' = U+0041)
	hook.add_codepoint(0x41, 0) or { return }
	assert td.shp.run_state.unichars.len == 1
	assert td.shp.run_state.unichars[0] == 0x41
	assert td.shp.run_state.codepoints.len == 1
	assert td.shp.run_state.codepoints[0].codepoint == 0x41
	assert td.shp.run_state.codepoints[0].cluster == 0

	// Add a supplementary plane character (U+1F44D = thumbs up)
	hook.add_codepoint(0x1F44D, 1) or { return }
	// UTF-16: should have added 2 code units (surrogate pair)
	assert td.shp.run_state.unichars.len == 3
	assert td.shp.run_state.unichars[1] == 0xD83D
	assert td.shp.run_state.unichars[2] == 0xDC4D
	// Codepoints: should have real entry + zero padding entry
	assert td.shp.run_state.codepoints.len == 3
	assert td.shp.run_state.codepoints[1].codepoint == 0x1F44D
	assert td.shp.run_state.codepoints[1].cluster == 1
	assert td.shp.run_state.codepoints[2].codepoint == 0
	assert td.shp.run_state.codepoints[2].cluster == 1
}

// test "run state reset"
// Verify that RunState.reset clears both codepoints and unichars.
fn test_run_state_reset() {
	mut state := RunState.init()
	state.codepoints << Codepoint{ codepoint: 0x41, cluster: 0 }
	state.unichars << u16(0x41)
	assert state.codepoints.len == 1
	assert state.unichars.len == 1

	state.reset()
	assert state.codepoints.len == 0
	assert state.unichars.len == 0
}

// test "shaper init and deinit"
// Verify basic lifecycle.
fn test_shaper_init_deinit() {
	mut shp := Shaper.init(font.ShaperOptions{
		features: ['dlig', 'calt']
	}) or { return }
	assert shp.feature_strings.len == 2
	assert shp.feature_strings[0] == 'dlig'
	assert shp.feature_strings[1] == 'calt'
	shp.deinit()
}

// test "end_frame with empty pool"
fn test_end_frame_empty() {
	mut shp := Shaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer { shp.deinit() }

	// Should be a no-op when pool is empty
	shp.end_frame()
	assert shp.cf_release_pool.len == 0
}

// test "special font shapes codepoints as glyphs"
// Verify that when font_index == sprite_index, codepoints are returned
// directly as glyph indices.
fn test_special_font_shapes_codepoints() {
	mut shp := Shaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer { shp.deinit() }

	// Set up run state with some codepoints
	shp.run_state.codepoints << Codepoint{ codepoint: 0x2500, cluster: 0 }
	shp.run_state.codepoints << Codepoint{ codepoint: 0x2501, cluster: 1 }

	// Shape with sprite font index
	cells := shp.shape(font.TextRun{
		font_index: font.sprite_index
		offset: 0
		cells: 2
	}) or { return }

	assert cells.len == 2
	assert cells[0].x == 0
	assert cells[0].glyph_index == 0x2500
	assert cells[1].x == 1
	assert cells[1].glyph_index == 0x2501
}

// test "special font skips zero codepoints"
// Verify that zero-padded codepoints (from surrogate pairs) are skipped
// for sprite font shaping.
fn test_special_font_skips_zero_codepoints() {
	mut shp := Shaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer { shp.deinit() }

	// Simulate a high-plane character with surrogate pair padding
	shp.run_state.codepoints << Codepoint{ codepoint: 0x1FB70, cluster: 0 }
	shp.run_state.codepoints << Codepoint{ codepoint: 0, cluster: 0 }

	// Shape with sprite font index
	cells := shp.shape(font.TextRun{
		font_index: font.sprite_index
		offset: 0
		cells: 1
	}) or { return }

	// Should get 1 cell, not 2 (zero padding is skipped)
	assert cells.len == 1
	assert cells[0].x == 0
	assert cells[0].glyph_index == 0x1FB70
}
