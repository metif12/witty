module font

// Tests for CoreTextFace (coretext.zig tests).
//
// All tests are marked XTODO because they require real CoreText bindings
// (macOS framework), embedded test fonts, and a working Atlas implementation.
//
// Translated from ghostty/src/font/face/coretext.zig tests

// test: basic ASCII glyph rendering
// Initialize a face from Monaco at 12pt, render all visible ASCII (32..127).
// Verify each codepoint has a glyph index and can be rendered to an atlas.
fn test_basic_ascii_rendering() {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Create a 512x512 grayscale Atlas
	// 2. Create a CTFont for "Monaco" at size 12
	// 3. Initialize CoreTextFace via init_font_copy with size 12pt
	// 4. For each visible ASCII char (32..127):
	//    a. assert glyph_index(i) != none
	//    b. render_glyph(atlas, glyph_index, grid_metrics from face.get_metrics())
}

// test: font name
// Initialize a face from Menlo, verify name() returns "Menlo".
fn test_name() {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Create a CTFont for "Menlo" at size 12
	// 2. Initialize CoreTextFace via init_font_copy with size 12pt
	// 3. mut buf := []u8{len: 1024}
	// 4. font_name := face.name(mut buf)!
	// 5. assert font_name == 'Menlo'
}

// test: emoji (color glyph detection)
// Initialize a face from "Apple Color Emoji", verify color glyph detection.
fn test_emoji() {
	// XTODO: needs real CoreText bindings
	// Steps:
	// 1. Create a CTFont for "Apple Color Emoji" at size 12
	// 2. Initialize CoreTextFace via init_font_copy with size 18pt
	// 3. Glyph index check:
	//    id := face.glyph_index(0x1F978) // '🥸'
	//    assert id != none
	//    assert face.is_color_glyph(id)
}

// test: in-memory font loading
// Load an embedded test font from memory, render all visible ASCII.
fn test_in_memory() {
	// XTODO: needs real CoreText bindings and embedded test fonts
	// Steps:
	// 1. Create a 512x512 grayscale Atlas
	// 2. Create a Library
	// 3. Initialize CoreTextFace via init() with embedded regular font, size 12pt
	// 4. For each visible ASCII char (32..127):
	//    a. assert glyph_index(i) != none
	//    b. render_glyph(atlas, glyph_index, grid_metrics from face.get_metrics())
}

// test: variable font loading
// Load an embedded variable test font from memory, render all visible ASCII.
fn test_variable() {
	// XTODO: needs real CoreText bindings and embedded test fonts
	// Steps:
	// 1. Create a 512x512 grayscale Atlas
	// 2. Create a Library
	// 3. Initialize CoreTextFace via init() with embedded variable font, size 12pt
	// 4. For each visible ASCII char (32..127):
	//    a. assert glyph_index(i) != none
	//    b. render_glyph(atlas, glyph_index, grid_metrics from face.get_metrics())
}

// test: variable font set variation
// Load an embedded variable test font, set wght=400, render all visible ASCII.
fn test_variable_set_variation() {
	// XTODO: needs real CoreText bindings and embedded test fonts
	// Steps:
	// 1. Create a 512x512 grayscale Atlas
	// 2. Create a Library
	// 3. Initialize CoreTextFace via init() with embedded variable font, size 12pt
	// 4. Set variations: [Variation{ id: VariationId.init("wght"), value: 400 }]
	// 5. For each visible ASCII char (32..127):
	//    a. assert glyph_index(i) != none
	//    b. render_glyph(atlas, glyph_index, grid_metrics from face.get_metrics())
}

// test: SVG font table
// Load an embedded font with an SVG table, verify copyTable returns data.
fn test_svg_font_table() {
	// XTODO: needs real CoreText bindings and embedded test fonts (JuliaMono)
	// Steps:
	// 1. Create a Library
	// 2. Initialize CoreTextFace via init() with embedded julia_mono font, size 12pt
	// 3. table := face.copy_table("SVG ")!
	// 4. assert table.len > 0
}

// test: glyph index colored vs text
// Load a font with both text and color glyphs, verify distinction.
fn test_glyph_index_colored_vs_text() {
	// XTODO: needs real CoreText bindings and embedded test fonts (JuliaMono)
	// Steps:
	// 1. Create a Library
	// 2. Initialize CoreTextFace via init() with embedded julia_mono font, size 12pt
	// 3. Text glyph check:
	//    glyph := face.glyph_index(u32(`A`))
	//    assert glyph == 4
	//    assert !face.is_color_glyph(glyph)
	// 4. Color glyph check:
	//    glyph := face.glyph_index(0xE800)
	//    assert glyph == 11482
	//    assert face.is_color_glyph(glyph)
}
