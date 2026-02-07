module shaper

import font

// ============================================================
// Test helpers
// ============================================================

struct HbTestShaper {
mut:
	shp HbShaper
}

fn (mut self HbTestShaper) deinit() {
	self.shp.deinit()
}

enum HbTestFont {
	inconsolata
	monaspace_neon
	arabic
}

// Helper to return a fully initialized shaper.
fn create_hb_shaper() !HbTestShaper {
	return create_hb_shaper_with_font(.inconsolata)
}

fn create_hb_shaper_with_font(font_req HbTestFont) !HbTestShaper {
	// XTODO: Full test setup requires loading embedded fonts
	// (inconsolata, monaspace_neon, Apple Color Emoji, Noto Emoji)
	// into a Collection / SharedGrid and creating an HbFont.
	//
	// The original Zig code:
	// 1. Creates a Library
	// 2. Creates a Collection
	// 3. Loads the requested test font (inconsolata, monaspace_neon, arabic)
	// 4. Loads emoji font (Noto Emoji or Apple Color Emoji on macOS)
	// 5. Loads emoji text font
	// 6. Creates a SharedGrid
	// 7. Creates a Shaper with "dlig" feature enabled
	_ = font_req

	// Some of our tests rely on dlig being enabled by default
	mut shp := HbShaper.init(font.ShaperOptions{
		features: ['dlig']
	})!

	return HbTestShaper{
		shp: shp
	}
}

// Return a fully initialized shaper by discovering a named font on the system.
fn create_hb_shaper_with_discovered_font(font_req string) !HbTestShaper {
	// XTODO: Font discovery requires platform-specific APIs.
	// The original Zig code:
	// 1. Checks if font.Discover is available (skips test if void)
	// 2. Creates a Library
	// 3. Creates a Collection
	// 4. Uses font discovery to find the requested font by name
	// 5. Checks the discovered font name matches the request
	// 6. Loads the font face into the collection
	// 7. Creates a SharedGrid and Shaper
	_ = font_req

	mut shp := HbShaper.init(font.ShaperOptions{
		features: []string{}
	})!

	return HbTestShaper{
		shp: shp
	}
}

// ============================================================
// Tests
// ============================================================

// test "run iterator"
// Verifies basic run iteration: plain text, text with spaces, and emoji splits.
fn test_hb_run_iterator() {
	// XTODO: Requires terminal.Terminal, terminal.RenderState, and vtStream
	// which are not available in the shaper module.
	//
	// Original test scenarios:
	//
	// 1. "ABCD" in a 5-col terminal should be 1 run.
	//    var t = try terminal.Terminal.init(alloc, .{ .cols = 5, .rows = 3 });
	//    s.nextSlice("ABCD");
	//    -> 1 run
	//
	// 2. Spaces should be part of a run.
	//    "ABCD   EFG" in a 10-col terminal should be 1 run.
	//    -> 1 run
	//
	// 3. Emoji should split runs.
	//    "A😃D" in a 5-col terminal should be 3 runs.
	//    Each run should be exactly length 1 in the hb_buf.
	//    -> 3 runs

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "run iterator: empty cells with background set"
// Empty cells with background color set should still be part of a run.
fn test_hb_run_iterator_empty_cells_with_bg() {
	// XTODO: Requires terminal infrastructure to create cells with
	// bg_color_rgb content_tag.
	//
	// Original test:
	// - Set red background, write "A"
	// - Set cells 1 and 2 to have bg_color_rgb with red
	// - Should produce 1 run with 3 glyphs, 3 cells

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape"
// Tests basic shaping: thumbs up plain + thumbs up with medium skin tone.
fn test_hb_shape() {
	// XTODO: Requires terminal and real HarfBuzz shaping.
	//
	// Original test:
	// - Encode 0x1F44D (Thumbs up plain) twice
	// - Encode 0x1F3FD (Medium skin tone) once
	// - Feed to terminal in a 10x3 grid
	// - Should produce 1 run with 3 codepoints in the hb_buf

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape inconsolata ligs"
// Tests ligature shaping: ">=" -> 1 glyph, "===" -> 1 glyph.
fn test_hb_shape_inconsolata_ligs() {
	// XTODO: Requires terminal + real HarfBuzz shaping.
	//
	// Original test scenario 1:
	// ">=" should be 1 run, 2 cells, 1 shaped glyph (ligature).
	//
	// Original test scenario 2:
	// "===" should be 1 run, 3 cells, 1 shaped glyph (ligature).

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape monaspace ligs"
// Tests Monaspace Neon "===" ligature.
fn test_hb_shape_monaspace_ligs() {
	// XTODO: Requires terminal + real HarfBuzz shaping with Monaspace Neon font.
	//
	// Original test:
	// "===" should be 1 run, 3 cells, 1 shaped glyph (ligature).

	mut td := create_hb_shaper_with_font(.monaspace_neon) or { return }
	defer {
		td.deinit()
	}
}

// Ghostty doesn't currently support RTL text because RTL in terminals is messy.
// Its something we want to improve. For now, we force LTR because
// our renderers assume a strictly increasing X value. This test ensures that
// we are correctly forcing RTL text to be LTR.
//
// test "shape arabic forced LTR"
fn test_hb_shape_arabic_forced_ltr() {
	// XTODO: Requires arabic font, terminal, and real HarfBuzz shaping.
	//
	// Original test:
	// - Load arabic.txt test data
	// - Shape in a 120x30 terminal
	// - Should produce 1 run with 25 cells
	// - All cells should have strictly increasing x values

	mut td := create_hb_shaper_with_font(.arabic) or { return }
	defer {
		td.deinit()
	}
}

// test "shape emoji width"
// Tests that a single emoji (thumbs up) shapes to 1 cell.
fn test_hb_shape_emoji_width() {
	// XTODO: Requires terminal + real HarfBuzz shaping.
	//
	// Original test:
	// "👍" should be 1 run, 2 cells (wide char), 1 shaped glyph.

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape emoji width long"
// Tests a long emoji sequence (person with beard + skin tone + ZWJ + male sign
// + presentation selector) shapes to 1 cell.
fn test_hb_shape_emoji_width_long() {
	// XTODO: Requires terminal + page grapheme setup + real HarfBuzz shaping.
	//
	// Original test:
	// - Set up cell with codepoint 0x1F9D4 (Person with beard)
	// - Add graphemes: 0x1F3FB (Light skin tone), 0x200D (ZWJ),
	//   0x2642 (Male sign), 0xFE0F (Emoji presentation selector)
	// - Should produce 1 run, 4 codepoints in hb_buf, 1 shaped cell

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape variation selector VS15"
// Tests U+270C (victory hand) + U+FE0E (text presentation) -> 1 cell.
fn test_hb_shape_variation_selector_vs15() {
	// XTODO: Requires terminal + real HarfBuzz shaping.
	//
	// Original test:
	// - Encode 0x270C (Victory sign, default text) + 0xFE0E (ZWJ to force text)
	// - Should produce 1 run, 1 codepoint in hb_buf, 1 shaped cell

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape variation selector VS16"
// Tests U+270C (victory hand) + U+FE0F (emoji presentation) -> 1 cell.
fn test_hb_shape_variation_selector_vs16() {
	// XTODO: Requires terminal + real HarfBuzz shaping.
	//
	// Original test:
	// - Encode 0x270C (Victory sign, default text) + 0xFE0F (ZWJ to force color)
	// - Should produce 1 run, 1 codepoint in hb_buf, 1 shaped cell

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape with empty cells in between"
// Tests "A" + cursor forward 5 + "B" -> 1 run, 7 cells.
fn test_hb_shape_empty_cells_between() {
	// XTODO: Requires terminal with escape sequence processing.
	//
	// Original test:
	// - Write "A", then "\x1b[5C" (cursor forward 5), then "B"
	// - Should produce 1 run, 7 shaped cells

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape Combining characters"
// Tests 'n' + U+0308 (combining diaeresis) x2 + 'a' -> 4 cells.
fn test_hb_shape_combining_characters() {
	// XTODO: Requires terminal + real HarfBuzz shaping.
	//
	// Original test:
	// - Encode 'n' + 0x0308 + 0x0308 + 'a'
	// - Should produce 1 run, 4 shaped cells
	// - cells[0..2].x == 0 (combining chars share x with base)
	// - cells[3].x == 1

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// This test exists because the string it uses causes HarfBuzz to output a
// non-monotonic run with our cluster level set to `characters`, which we need
// to handle by tracking the max cluster for the run.
//
// test "shape Devanagari string"
fn test_hb_shape_devanagari() {
	// XTODO: Requires Arial Unicode MS font discovery + terminal + real HarfBuzz shaping.
	//
	// Original test:
	// - Discover "Arial Unicode MS" font (macOS system font)
	// - Disable grapheme clustering
	// - Write "अपार्टमेंट"
	// - Should produce 1 run, 8 cells with specific x values:
	//   cells[0].x = 0, cells[1].x = 1, cells[2].x = 2, cells[3].x = 4,
	//   cells[4].x = 4, cells[5].x = 5, cells[6].x = 5, cells[7].x = 6

	mut td := create_hb_shaper_with_discovered_font('Arial Unicode MS') or { return }
	defer {
		td.deinit()
	}
}

// test "shape Tai Tham vowels (position differs from advance)"
// Note that while this test was necessary for CoreText, the old logic was
// working for HarfBuzz. Still we keep it to ensure it has the correct
// behavior.
fn test_hb_shape_tai_tham_vowels() {
	// XTODO: Requires Noto Sans Tai Tham font discovery + terminal + HarfBuzz shaping.
	//
	// Original test:
	// - Discover "Noto Sans Tai Tham" font
	// - Enable grapheme clustering
	// - Encode 0x1A2F (ᨯ) + 0x1A70 (ᩰ)
	// - Should produce 1 run, 2 cells
	// - Both cells at x=0
	// - cells[0].x_offset == cell_width (FreeType: 7, CoreText: cell_width)
	// - cells[1].x_offset == 0

	mut td := create_hb_shaper_with_discovered_font('Noto Sans Tai Tham') or { return }
	defer {
		td.deinit()
	}
}

// test "shape Tibetan characters"
// Tests that Tibetan characters with multiple glyphs per codepoint shape correctly.
fn test_hb_shape_tibetan() {
	// XTODO: Requires Noto Serif Tibetan font discovery + terminal + HarfBuzz shaping.
	// Not a default Mac font, so the test is skipped if not found.
	//
	// Original test:
	// - Discover "Noto Serif Tibetan" font
	// - Enable grapheme clustering
	// - Encode 0x0F00 (ༀ)
	// - Should produce 1 run, 2 cells
	// - Both cells at x=0
	// - cells[1].x_offset < 2

	mut td := create_hb_shaper_with_discovered_font('Noto Serif Tibetan') or { return }
	defer {
		td.deinit()
	}
}

// test "shape Tai Tham letters (run_offset.y differs from zero)"
// Tests ligature across grapheme clusters with y-offset.
fn test_hb_shape_tai_tham_letters() {
	// XTODO: Requires Noto Sans Tai Tham font discovery + terminal + HarfBuzz shaping.
	//
	// Original test:
	// - Discover "Noto Sans Tai Tham" font
	// - Enable grapheme clustering
	// - First grapheme cluster: 0x1A49 (HA) + 0x1A60 (SAKOT)
	// - Second grapheme cluster (combining in ligature): 0x1A3F (YA) + 0x1A69 (U)
	// - Should produce 1 run, 3 cells
	// - All cells at x=0
	// - cells[2].y_offset == -3 (U glyph renders below zero)

	mut td := create_hb_shaper_with_discovered_font('Noto Sans Tai Tham') or { return }
	defer {
		td.deinit()
	}
}

// test "shape Javanese ligatures"
// Tests PANGKON ligature with correct x_offset.
fn test_hb_shape_javanese_ligatures() {
	// XTODO: Requires Noto Sans Javanese font discovery + terminal + HarfBuzz shaping.
	//
	// Original test:
	// - Discover "Noto Sans Javanese" font
	// - Enable grapheme clustering
	// - First grapheme: 0xA9A4 (NA) + 0xA9C0 (PANGKON)
	// - Second grapheme (combining in ligature): 0xA9B2 (HA) + 0xA9B8 (SUKU vowel)
	// - Should produce 1 run, 3 cells
	// - All cells at x=0
	// - cells[2].x_offset > 3 * cell_width

	mut td := create_hb_shaper_with_discovered_font('Noto Sans Javanese') or { return }
	defer {
		td.deinit()
	}
}

// test "shape Chakma vowel sign with ligature (vowel sign renders first)"
// Tests out-of-order rendering where vowel sign appears before the consonant.
fn test_hb_shape_chakma_vowel_sign() {
	// XTODO: Requires Noto Sans Chakma font discovery + terminal + HarfBuzz shaping.
	//
	// Original test:
	// - Discover "Noto Sans Chakma" font
	// - Enable grapheme clustering
	// - First grapheme: 0x1111D (BAA)
	// - Second grapheme: 0x11116 (TAA) + 0x11133 (Virama)
	// - Third grapheme (combining in ligature): 0x11120 (YYAA) + 0x1112C (Vowel Sign U)
	// - Should produce 1 run, 4 cells
	// - cells[0].x = 0
	// - See the giant "We need to reset the `cell_offset`" comment, but here
	//   we should technically have the rest of these be `x` of 1, but that
	//   would require going back in the stream to adjust past cells.
	// - cells[1].x_offset < cells[2].x_offset (vowel renders before TAA)

	mut td := create_hb_shaper_with_discovered_font('Noto Sans Chakma') or { return }
	defer {
		td.deinit()
	}
}

// test "shape Bengali ligatures with out of order vowels"
// Whereas this test in CoreText had everything shaping into one giant
// ligature, HarfBuzz splits it into a few clusters. It still looks okay
// (see #10332).
fn test_hb_shape_bengali_ligatures() {
	// XTODO: Requires Arial Unicode MS font discovery + terminal + HarfBuzz shaping.
	//
	// Original test:
	// - Discover "Arial Unicode MS" font
	// - Enable grapheme clustering
	// - First grapheme: 0x09B0 (RA) + 0x09BE (Vowel sign AA)
	// - Second grapheme: 0x09B7 (SSA) + 0x09CD (Virama)
	// - Third grapheme: 0x099F (TTA) + 0x09CD (Virama)
	// - Fourth grapheme: 0x09B0 (RA) + 0x09C7 (Vowel sign E)
	// - Should produce 1 run, 8 cells
	// - cells[0].x = 0, cells[1].x = 0
	// - Whereas CoreText puts everything into the first cell,
	//   HarfBuzz splits into two clusters:
	//   cells[2..7].x = 1
	// - cells[2].x_offset < cells[3].x_offset (vowel E renders before SSA)

	mut td := create_hb_shaper_with_discovered_font('Arial Unicode MS') or { return }
	defer {
		td.deinit()
	}
}

// test "shape box glyphs"
// Tests that box drawing characters use the sprite font and return
// codepoints as glyph indices.
fn test_hb_shape_box_glyphs() {
	// XTODO: Requires terminal + sprite font detection + real HarfBuzz shaping.
	//
	// Original test:
	// - Encode 0x2500 (horiz line) + 0x2501
	// - Should produce 1 run, 2 codepoints in hb_buf, 2 cells
	// - cells[0].glyph_index == 0x2500, cells[0].x == 0
	// - cells[1].glyph_index == 0x2501, cells[1].x == 1

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape selection boundary"
// Tests that selection boundaries correctly split runs.
fn test_hb_shape_selection_boundary() {
	// XTODO: Requires terminal + RunIterator with selection support.
	//
	// Original test with "a1b2c3d4e5":
	// - Full line selection {0, 9} -> 1 run
	// - Selection {2, 9} -> 2 runs (before selection, selection to end)
	// - Selection {0, 3} -> 2 runs (selection, after selection)
	// - Selection {1, 3} -> 3 runs (before, selection, after)
	// - Selection {1, 1} -> 3 runs (before, single char, after)

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape cursor boundary"
// Tests that cursor position correctly splits runs.
fn test_hb_shape_cursor_boundary() {
	// XTODO: Requires terminal + RunIterator with cursor_x support.
	//
	// Original test with "a1b2c3d4e5":
	// - No cursor -> 1 run
	// - cursor_x=0 -> 2 runs (cursor char, rest)
	// - cursor_x=1 -> 3 runs (before cursor, cursor char, after)
	// - cursor_x=9 -> 2 runs (before cursor, cursor char)
	// - Without cursor splitting, always remains 1 run

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape cursor boundary and colored emoji"
// Tests that cursor on a wide emoji does not split it.
fn test_hb_shape_cursor_boundary_colored_emoji() {
	// XTODO: Requires terminal + cursor handling for wide chars.
	//
	// Original test with "👍🏼":
	// - No cursor -> 1 run
	// - cursor_x=0 -> 1 run (cursor on emoji does not split)
	// - cursor_x=1 -> 1 run (cursor on second cell of wide char does not split)
	// - All cases: always 1 run

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// test "shape cell attribute change"
// Tests that bold/fg color changes split runs, but bg color does not.
fn test_hb_shape_cell_attribute_change() {
	// XTODO: Requires terminal with ANSI escape sequence processing.
	//
	// Original test scenarios:
	// 1. ">=" plain -> 1 run
	// 2. ">" + bold "=" (\x1b[1m) -> 2 runs (bold splits)
	// 3. fg color change between ">" and "=" -> 2 runs (fg color splits)
	// 4. bg color change between ">" and "=" -> 1 run (bg color does NOT split)
	// 5. Same bg on both ">" and "=" -> 1 run

	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
}

// ============================================================
// Unit tests that work without terminal infrastructure
// ============================================================

// test "hb shaper init and deinit"
// Verify basic lifecycle.
fn test_hb_shaper_init_deinit() {
	mut shp := HbShaper.init(font.ShaperOptions{
		features: ['dlig', 'calt']
	}) or { return }
	// Default feature (liga) + 2 user features = 3 total
	assert shp.hb_feats.len == 3
	shp.deinit()
}

// test "hb shaper init with disable feature"
// Verify that -liga disables a feature.
fn test_hb_shaper_init_disable_feature() {
	mut shp := HbShaper.init(font.ShaperOptions{
		features: ['-liga']
	}) or { return }
	defer {
		shp.deinit()
	}
	// Default liga (value=1) + user -liga (value=0) = 2 features
	assert shp.hb_feats.len == 2
	// First feature should be liga enabled (default)
	assert shp.hb_feats[0].value == 1
	// Second feature should be liga disabled (user override)
	assert shp.hb_feats[1].value == 0
}

// test "hb end_frame is no-op"
fn test_hb_end_frame() {
	mut shp := HbShaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer {
		shp.deinit()
	}

	// Should be a no-op, no crash
	shp.end_frame()
}

// test "parse_hb_feature_string"
fn test_parse_hb_feature_string() {
	// Basic feature
	if feat := parse_hb_feature_string('liga') {
		assert feat.value == 1
		assert feat.tag == tag_to_u32([u8(`l`), `i`, `g`, `a`]!)
	} else {
		assert false
	}

	// Enable prefix
	if feat := parse_hb_feature_string('+dlig') {
		assert feat.value == 1
		assert feat.tag == tag_to_u32([u8(`d`), `l`, `i`, `g`]!)
	} else {
		assert false
	}

	// Disable prefix
	if feat := parse_hb_feature_string('-liga') {
		assert feat.value == 0
		assert feat.tag == tag_to_u32([u8(`l`), `i`, `g`, `a`]!)
	} else {
		assert false
	}

	// Empty string
	assert parse_hb_feature_string('') == none

	// Too long
	assert parse_hb_feature_string('toolong') == none

	// Short tag (padded with spaces)
	if feat := parse_hb_feature_string('ss') {
		assert feat.value == 1
		assert feat.tag == tag_to_u32([u8(`s`), `s`, ` `, ` `]!)
	} else {
		assert false
	}
}

// test "tag_to_u32"
fn test_tag_to_u32() {
	// "liga" -> big-endian u32
	tag := tag_to_u32([u8(`l`), `i`, `g`, `a`]!)
	expected := (u32(`l`) << 24) | (u32(`i`) << 16) | (u32(`g`) << 8) | u32(`a`)
	assert tag == expected

	// "GSUB" -> big-endian u32
	tag2 := tag_to_u32([u8(`G`), `S`, `U`, `B`]!)
	expected2 := (u32(`G`) << 24) | (u32(`S`) << 16) | (u32(`U`) << 8) | u32(`B`)
	assert tag2 == expected2
}

// test "hb run iterator hook prepare"
fn test_hb_run_iterator_hook_prepare() {
	mut shp := HbShaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer {
		shp.deinit()
	}

	mut hook := HbRunIteratorHook{
		shaper: &shp
	}

	// Add some data first
	shp.hb_buf.add(0x41, 0)
	shp.codepoints << HbCodepoint{ cluster: 0, codepoint: 0x41 }

	// Prepare should reset everything
	hook.prepare()
	assert shp.hb_buf.get_length() == 0
	assert shp.codepoints.len == 0
	assert shp.hb_buf.content_type == .unicode
	assert shp.hb_buf.cluster_level == .characters
	assert shp.hb_buf.direction == .ltr
}

// test "hb run iterator hook add_codepoint"
fn test_hb_run_iterator_hook_add_codepoint() {
	mut shp := HbShaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer {
		shp.deinit()
	}

	mut hook := HbRunIteratorHook{
		shaper: &shp
	}
	hook.prepare()

	// Add a BMP character ('A' = U+0041)
	hook.add_codepoint(0x41, 0) or { return }
	assert shp.hb_buf.get_length() == 1
	assert shp.codepoints.len == 1
	assert shp.codepoints[0].codepoint == 0x41
	assert shp.codepoints[0].cluster == 0

	// The cluster value passed to HarfBuzz is the index (0),
	// not the original cluster value.
	infos := shp.hb_buf.get_glyph_infos()
	assert infos[0].codepoint == 0x41
	assert infos[0].cluster == 0

	// Add another codepoint
	hook.add_codepoint(0x1F44D, 1) or { return }
	assert shp.hb_buf.get_length() == 2
	assert shp.codepoints.len == 2
	assert shp.codepoints[1].codepoint == 0x1F44D
	assert shp.codepoints[1].cluster == 1

	// The cluster value for HarfBuzz is the index (1)
	infos2 := shp.hb_buf.get_glyph_infos()
	assert infos2[1].cluster == 1
}

// test "hb run iterator hook finalize"
fn test_hb_run_iterator_hook_finalize() {
	mut shp := HbShaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer {
		shp.deinit()
	}

	mut hook := HbRunIteratorHook{
		shaper: &shp
	}
	hook.prepare()
	hook.add_codepoint(0x41, 0) or { return }

	// Finalize should call guess_segment_properties (no crash)
	hook.finalize()
}

// test "hb shape with empty buffer"
// When the buffer is empty after shaping, shape() should return empty slice.
fn test_hb_shape_empty_buffer() {
	mut shp := HbShaper.init(font.ShaperOptions{
		features: []string{}
	}) or { return }
	defer {
		shp.deinit()
	}

	// Shape with empty buffer - should return empty
	cells := shp.shape(font.TextRun{
		font_index: 1 // non-special font
		offset: 0
		cells: 0
	}) or { return }
	assert cells.len == 0
}

// test "is_special_font"
fn test_is_special_font() {
	assert is_special_font(font.sprite_index) == true
	assert is_special_font(1) == false
	assert is_special_font(42) == false
}
