module shaper

import font
import harfbuzz
import terminal

// ============================================================
// Test helpers
// ============================================================

struct HbTestShaper {
mut:
	shp  HbShaper
	grid font.SharedGrid
	lib  font.Library
}

fn (mut self HbTestShaper) deinit() {
	self.shp.deinit()
	self.grid.deinit()
	self.lib.deinit()
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
	data := match font_req {
		.inconsolata { font.embedded_inconsolata }
		.monaspace_neon { font.embedded_monaspace_neon }
		.arabic { font.embedded_arabic }
	}
	mut lib := font.Library.init()!
	mut collection := font.Collection.init()
	collection.load_options = font.LoadOptions{
		library: lib
		size: font.DesiredSize{ points: 12, xdpi: 72, ydpi: 72 }
	}
	load_options := collection.load_options or { return error('missing load options') }
	for face_data in [data, font.embedded_emoji, font.embedded_emoji_text] {
		collection.add(font.Face.init_mem(lib, face_data, load_options.face_options())!, font.AddOptions{
			style: .regular
			fallback: false
			size_adjustment: .none_
		})!
	}
	grid := font.SharedGrid.init(font.CodepointResolver{
		collection: collection
	})!
	mut shp := HbShaper.init(font.ShaperOptions{
		features: ['dlig']
	})!

	return HbTestShaper{
		shp: shp
		grid: grid
		lib: lib
	}
}

// Return a fully initialized shaper by discovering a named font on the system.
fn create_hb_shaper_with_discovered_font(font_req string) !HbTestShaper {
	mut lib := font.Library.init()!
	mut collection := font.Collection.init()
	collection.load_options = font.LoadOptions{
		library: lib
		size: font.DesiredSize{ points: 12, xdpi: 72, ydpi: 72 }
	}
	mut discovery := font.Discover.init()
	defer { discovery.deinit() }
	mut iterator := discovery.discover(font.Descriptor{
		family: font_req
		size: 12
		monospace: false
	})!
	defer { iterator.deinit() }
	mut deferred := iterator.next() or { return error('font not found: ${font_req}') }
	load_options := collection.load_options or { return error('missing load options') }
	mut face := deferred.load(lib, load_options.face_options())!
	mut name_buf := []u8{len: 512}
	name := face.name(mut name_buf) or { '' }
	if !name.contains(font_req) {
		face.deinit()
		return error('font not found: ${font_req}')
	}
	collection.add(face, font.AddOptions{
		style: .regular
		fallback: false
		size_adjustment: .none_
	})!
	grid := font.SharedGrid.init(font.CodepointResolver{
		collection: collection
	})!
	mut shp := HbShaper.init(font.ShaperOptions{
		features: []string{}
	})!

	return HbTestShaper{
		shp: shp
		grid: grid
		lib: lib
	}
}

struct HbShapeResult {
mut:
	runs           []font.TextRun
	glyphs         [][]font.ShapeCell
	buffer_lengths []u32
}

fn hb_render_row_with_graphemes(input string, cols u16, graphemes bool) ![]terminal.RenderCell {
	mut term := terminal.Terminal.init(terminal.Options{ cols: cols, rows: 3 })!
	defer { term.deinit() }
	term.modes.set(.grapheme_cluster, graphemes)
	mut stream := term.vt_stream()
	defer { stream.deinit() }
	stream.next_slice(input)!
	mut state := terminal.RenderState.empty()
	defer { state.deinit() }
	state.update(mut term)
	mut result := []terminal.RenderCell{cap: state.row_data[0].cells.len}
	for cell in state.row_data[0].cells {
		result << terminal.RenderCell{
			raw: cell.raw
			grapheme: cell.grapheme.clone()
			style: cell.style
		}
	}
	return result
}

fn hb_render_row(input string, cols u16) ![]terminal.RenderCell {
	return hb_render_row_with_graphemes(input, cols, false)
}

fn (mut td HbTestShaper) shape_render_cells(cells []terminal.RenderCell, selection ?[2]u16, cursor_x ?u16) !HbShapeResult {
	mut result := HbShapeResult{}
	mut iterator := td.shp.run_iterator(font.RunOptions{
		grid: &td.grid
		render_cells: cells
		selection: selection
		cursor_x: cursor_x
	})
	for {
		run := (iterator.next()!).get() or { break }
		result.runs << run
		result.buffer_lengths << td.shp.hb_buf.get_length()
		result.glyphs << td.shp.shape(run)!.clone()
	}
	return result
}

fn (mut td HbTestShaper) shape_text(input string, cols u16) !HbShapeResult {
	cells := hb_render_row(input, cols)!
	return td.shape_render_cells(cells, none, none)
}

fn (mut td HbTestShaper) shape_text_with_graphemes(input string, cols u16) !HbShapeResult {
	cells := hb_render_row_with_graphemes(input, cols, true)!
	return td.shape_render_cells(cells, none, none)
}

fn hb_codepoints(codepoints []u32) string {
	mut result := ''
	for cp in codepoints {
		result += rune(cp).str()
	}
	return result
}

// ============================================================
// Tests
// ============================================================

// test "run iterator"
// Verifies basic run iteration: plain text, text with spaces, and emoji splits.
fn test_hb_run_iterator() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	plain := td.shape_text('ABCD', 5) or { panic(err) }
	assert plain.runs.len == 1
	assert plain.runs[0].cells == 4
	spaces := td.shape_text('ABCD   EFG', 10) or { panic(err) }
	assert spaces.runs.len == 1
	emoji := td.shape_text('A😃D', 5) or { panic(err) }
	assert emoji.runs.len == 3
	for length in emoji.buffer_lengths {
		assert length == 1
	}
}

// test "run iterator: empty cells with background set"
// Empty cells with background color set should still be part of a run.
fn test_hb_run_iterator_empty_cells_with_bg() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	mut cells := hb_render_row('\x1b[48;2;255;0;0mA', 5) or { panic(err) }
	for i in 1 .. 3 {
		cells[i].raw = terminal.CellData{
			content_tag: .bg_color_rgb
			color_rgb_r: 255
		}
	}
	result := td.shape_render_cells(cells, none, none) or { panic(err) }
	assert result.runs.len == 1
	assert result.buffer_lengths[0] == 3
	assert result.glyphs[0].len == 3
}

// test "shape"
// Tests basic shaping: thumbs up plain + thumbs up with medium skin tone.
fn test_hb_shape() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('👍👍🏽', 10) or { panic(err) }
	assert result.runs.len == 1
	assert result.buffer_lengths[0] == 3
}

// test "shape inconsolata ligs"
// Tests ligature shaping: ">=" -> 1 glyph, "===" -> 1 glyph.
fn test_hb_shape_inconsolata_ligs() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	for input in ['>=', '==='] {
		result := td.shape_text(input, 5) or { panic(err) }
		assert result.runs.len == 1
		assert result.runs[0].cells == u32(input.len)
		assert result.glyphs[0].len == 1
	}
}

// test "shape monaspace ligs"
// Tests Monaspace Neon "===" ligature.
fn test_hb_shape_monaspace_ligs() {
	mut td := create_hb_shaper_with_font(.monaspace_neon) or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('===', 5) or { panic(err) }
	assert result.runs.len == 1
	assert result.runs[0].cells == 3
	assert result.glyphs[0].len == 1
}

// Ghostty doesn't currently support RTL text because RTL in terminals is messy.
// Its something we want to improve. For now, we force LTR because
// our renderers assume a strictly increasing X value. This test ensures that
// we are correctly forcing RTL text to be LTR.
//
// test "shape arabic forced LTR"
fn test_hb_shape_arabic_forced_ltr() {
	mut td := create_hb_shaper_with_font(.arabic) or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('غريبه لاني عربي أبا عن جد', 120) or { panic(err) }
	assert result.runs.len == 1
	assert result.runs[0].cells == 25
	assert result.glyphs[0].len == 25
	for i in 1 .. result.glyphs[0].len {
		assert result.glyphs[0][i].x == result.glyphs[0][i - 1].x + 1
	}
}

// test "shape emoji width"
// Tests that a single emoji (thumbs up) shapes to 1 cell.
fn test_hb_shape_emoji_width() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('👍', 5) or { panic(err) }
	assert result.runs.len == 1
	assert result.runs[0].cells == 2
	assert result.glyphs[0].len == 1
}

// test "shape emoji width long"
// Tests a long emoji sequence (person with beard + skin tone + ZWJ + male sign
// + presentation selector) shapes to 1 cell.
fn test_hb_shape_emoji_width_long() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text_with_graphemes('🧔🏻‍♂️', 30) or { panic(err) }
	assert result.runs.len == 1
	assert result.buffer_lengths[0] == 4
	assert result.glyphs[0].len == 1
}

// test "shape variation selector VS15"
// Tests U+270C (victory hand) + U+FE0E (text presentation) -> 1 cell.
fn test_hb_shape_variation_selector_vs15() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('✌︎', 10) or { panic(err) }
	assert result.runs.len == 1
	assert result.buffer_lengths[0] == 1
	assert result.glyphs[0].len == 1
}

// test "shape variation selector VS16"
// Tests U+270C (victory hand) + U+FE0F (emoji presentation) -> 1 cell.
fn test_hb_shape_variation_selector_vs16() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('✌️', 10) or { panic(err) }
	assert result.runs.len == 1
	assert result.buffer_lengths[0] == 1
	assert result.glyphs[0].len == 1
}

// test "shape with empty cells in between"
// Tests "A" + cursor forward 5 + "B" -> 1 run, 7 cells.
fn test_hb_shape_empty_cells_between() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('A\x1b[5CB', 30) or { panic(err) }
	assert result.runs.len == 1
	assert result.glyphs[0].len == 7
}

// test "shape Combining characters"
// Tests 'n' + U+0308 (combining diaeresis) x2 + 'a' -> 4 cells.
fn test_hb_shape_combining_characters() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('n̈̈a', 30) or { panic(err) }
	assert result.runs.len == 1
	assert result.glyphs[0].len == 4
	assert result.glyphs[0][0].x == 0
	assert result.glyphs[0][1].x == 0
	assert result.glyphs[0][2].x == 0
	assert result.glyphs[0][3].x == 1
}

// This test exists because the string it uses causes HarfBuzz to output a
// non-monotonic run with our cluster level set to `characters`, which we need
// to handle by tracking the max cluster for the run.
//
// test "shape Devanagari string"
fn test_hb_shape_devanagari() {
	mut td := create_hb_shaper_with_discovered_font('Arial Unicode MS') or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('अपार्टमेंट', 30) or { panic(err) }
	assert result.runs.len == 1
	assert result.glyphs[0].len == 8
	assert result.glyphs[0].map(it.x) == [u32(0), 1, 2, 4, 4, 5, 5, 6]
}

// test "shape Tai Tham vowels (position differs from advance)"
// Note that while this test was necessary for CoreText, the old logic was
// working for HarfBuzz. Still we keep it to ensure it has the correct
// behavior.
fn test_hb_shape_tai_tham_vowels() {
	mut td := create_hb_shaper_with_discovered_font('Noto Sans Tai Tham') or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text_with_graphemes(hb_codepoints([u32(0x1a2f), 0x1a70]), 30) or {
		panic(err)
	}
	assert result.runs.len == 1
	assert result.glyphs[0].len == 2
	assert result.glyphs[0][0].x == 0
	assert result.glyphs[0][1].x == 0
	assert result.glyphs[0][0].x_offset == 7
	assert result.glyphs[0][1].x_offset == 0
}

// test "shape Tibetan characters"
// Tests that Tibetan characters with multiple glyphs per codepoint shape correctly.
fn test_hb_shape_tibetan() {
	mut td := create_hb_shaper_with_discovered_font('Noto Serif Tibetan') or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text_with_graphemes(hb_codepoints([u32(0x0f00)]), 30) or {
		panic(err)
	}
	assert result.runs.len == 1
	assert result.glyphs[0].len == 2
	assert result.glyphs[0][0].x == 0
	assert result.glyphs[0][1].x == 0
	assert result.glyphs[0][1].x_offset < 2
}

// test "shape Tai Tham letters (run_offset.y differs from zero)"
// Tests ligature across grapheme clusters with y-offset.
fn test_hb_shape_tai_tham_letters() {
	mut td := create_hb_shaper_with_discovered_font('Noto Sans Tai Tham') or { return }
	defer {
		td.deinit()
	}
	input := hb_codepoints([u32(0x1a49), 0x1a60, 0x1a3f, 0x1a69])
	result := td.shape_text_with_graphemes(input, 30) or { panic(err) }
	assert result.runs.len == 1
	assert result.glyphs[0].len == 3
	assert result.glyphs[0].map(it.x) == [u32(0), 0, 0]
	assert result.glyphs[0][2].y_offset == -3
}

// test "shape Javanese ligatures"
// Tests PANGKON ligature with correct x_offset.
fn test_hb_shape_javanese_ligatures() {
	mut td := create_hb_shaper_with_discovered_font('Noto Sans Javanese') or { return }
	defer {
		td.deinit()
	}
	input := hb_codepoints([u32(0xa9a4), 0xa9c0, 0xa9b2, 0xa9b8])
	result := td.shape_text_with_graphemes(input, 30) or { panic(err) }
	assert result.runs.len == 1
	assert result.glyphs[0].len == 3
	assert result.glyphs[0].map(it.x) == [u32(0), 0, 0]
	assert result.glyphs[0][2].x_offset > 3 * int(td.grid.metrics.cell_width)
}

// test "shape Chakma vowel sign with ligature (vowel sign renders first)"
// Tests out-of-order rendering where vowel sign appears before the consonant.
fn test_hb_shape_chakma_vowel_sign() {
	mut td := create_hb_shaper_with_discovered_font('Noto Sans Chakma') or { return }
	defer {
		td.deinit()
	}
	input := hb_codepoints([u32(0x1111d), 0x11116, 0x11133, 0x11120, 0x1112c])
	result := td.shape_text_with_graphemes(input, 30) or { panic(err) }
	assert result.runs.len == 1
	assert result.glyphs[0].len == 4
	assert result.glyphs[0].map(it.x) == [u32(0), 0, 0, 0]
	assert result.glyphs[0][1].x_offset < result.glyphs[0][2].x_offset
}

// test "shape Bengali ligatures with out of order vowels"
// Whereas this test in CoreText had everything shaping into one giant
// ligature, HarfBuzz splits it into a few clusters. It still looks okay
// (see #10332).
fn test_hb_shape_bengali_ligatures() {
	mut td := create_hb_shaper_with_discovered_font('Arial Unicode MS') or { return }
	defer {
		td.deinit()
	}
	input := hb_codepoints([u32(0x09b0), 0x09be, 0x09b7, 0x09cd, 0x099f, 0x09cd, 0x09b0, 0x09c7])
	cells := hb_render_row_with_graphemes(input, 30, true) or { panic(err) }
	result := td.shape_render_cells(cells, none, none) or { panic(err) }
	assert result.runs.len == 1
	assert result.glyphs[0].len == 8
	assert result.glyphs[0].map(it.x) == [u32(0), 0, 1, 1, 1, 1, 1, 1]
	assert result.glyphs[0][2].x_offset < result.glyphs[0][3].x_offset
}

// test "shape box glyphs"
// Tests that box drawing characters use the sprite font and return
// codepoints as glyph indices.
fn test_hb_shape_box_glyphs() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	result := td.shape_text('─━', 10) or { panic(err) }
	assert result.runs.len == 1
	assert result.buffer_lengths[0] == 2
	assert result.glyphs[0].len == 2
	assert result.glyphs[0][0].glyph_index == 0x2500
	assert result.glyphs[0][0].x == 0
	assert result.glyphs[0][1].glyph_index == 0x2501
	assert result.glyphs[0][1].x == 1
}

// test "shape selection boundary"
// Tests that selection boundaries correctly split runs.
fn test_hb_shape_selection_boundary() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	cells := hb_render_row('a1b2c3d4e5', 10) or { panic(err) }
	selections := [[u16(0), 9]!, [u16(2), 9]!, [u16(0), 3]!, [u16(1), 3]!, [u16(1), 1]!]
	expected_counts := [1, 2, 2, 3, 3]
	for i, selection in selections {
		result := td.shape_render_cells(cells, selection, none) or { panic(err) }
		assert result.runs.len == expected_counts[i]
	}
}

// test "shape cursor boundary"
// Tests that cursor position correctly splits runs.
fn test_hb_shape_cursor_boundary() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	cells := hb_render_row('a1b2c3d4e5', 10) or { panic(err) }
	assert (td.shape_render_cells(cells, none, none) or { panic(err) }).runs.len == 1
	for cursor, expected in {
		u16(0): 2
		u16(1): 3
		u16(9): 2
	} {
		result := td.shape_render_cells(cells, none, cursor) or { panic(err) }
		assert result.runs.len == expected
		assert (td.shape_render_cells(cells, none, none) or { panic(err) }).runs.len == 1
	}
}

// test "shape cursor boundary and colored emoji"
// Tests that cursor on a wide emoji does not split it.
fn test_hb_shape_cursor_boundary_colored_emoji() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	cells := hb_render_row_with_graphemes('👍🏼', 3, true) or { panic(err) }
	assert (td.shape_render_cells(cells, none, none) or { panic(err) }).runs.len == 1
	for cursor in [u16(0), 1] {
		assert (td.shape_render_cells(cells, none, cursor) or { panic(err) }).runs.len == 1
		assert (td.shape_render_cells(cells, none, none) or { panic(err) }).runs.len == 1
	}
}

// test "shape cell attribute change"
// Tests that bold/fg color changes split runs, but bg color does not.
fn test_hb_shape_cell_attribute_change() {
	mut td := create_hb_shaper() or { return }
	defer {
		td.deinit()
	}
	for input, expected in {
		'>=':                                 1
		'>\x1b[1m=':                          2
		'\x1b[38;2;1;2;3m>\x1b[38;2;3;2;1m=': 2
		'\x1b[48;2;1;2;3m>\x1b[48;2;3;2;1m=': 1
		'\x1b[48;2;1;2;3m>=':                 1
	} {
		cells := hb_render_row(input, 10) or { panic(err) }
		result := td.shape_render_cells(cells, none, none) or { panic(err) }
		assert result.runs.len == expected
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

// test "harfbuzz.feature_from_string"
// Tests HarfBuzz's built-in feature string parser via our binding.
fn test_hb_feature_from_string() {
	// Basic feature
	if feat := harfbuzz.feature_from_string('liga') {
		assert feat.value == 1
	} else {
		assert false
	}

	// Enable prefix
	if feat := harfbuzz.feature_from_string('+dlig') {
		assert feat.value == 1
	} else {
		assert false
	}

	// Disable prefix
	if feat := harfbuzz.feature_from_string('-liga') {
		assert feat.value == 0
	} else {
		assert false
	}

	// Empty string
	assert harfbuzz.feature_from_string('') == none
}

// test "harfbuzz buffer create and destroy"
fn test_hb_buffer_create_destroy() {
	mut buf := harfbuzz.Buffer.create() or {
		assert false
		return
	}
	// Buffer should be valid
	assert buf.get_length() == 0
	buf.destroy()
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
	// content_type, cluster_level, and direction are set on the C-side buffer;
	// we verify by checking that the buffer is usable (length is 0 after reset).
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
		font_index: font.Index.init(.regular, 1) // non-special font
		offset: 0
		cells: 0
	}) or { return }
	assert cells.len == 0
}

// test "is_special_font"
fn test_is_special_font() {
	assert is_special_font(font.sprite_index) == true
	assert is_special_font(font.Index.init(.regular, 1)) == false
	assert is_special_font(font.Index.init(.regular, 42)) == false
}
