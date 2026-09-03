module font

// Tests for Collection (translated from ghostty/src/font/Collection.zig)
//
// XTODO: Most tests require embedded font data and real FreeType
// face initialization to function. They are preserved here for
// completeness and future implementation.

fn test_collection_init() {
	mut c := Collection.init()
	c.deinit()
}

fn test_collection_add_full() {
	// XTODO: needs real font loading. This test is also very slow
	// (fills all 8191 slots).
	//
	// Original test:
	// 1. Fill the collection with index_special_start - 1 faces
	// 2. Verify adding one more returns error.CollectionFull
}

fn test_add_deferred_without_loading_options() {
	mut c := Collection.init()
	defer {
		c.deinit()
	}

	// Adding a deferred face without load options should fail.
	c.add_deferred(DeferredFace{}, AddOptions{
		style: .regular
		fallback: false
		size_adjustment: .none_
	}) or {
		// Expected: deferred loading unavailable
		assert err.msg() == 'deferred loading unavailable'
		return
	}
	assert false, 'expected error'
}

fn test_get_face() {
	// XTODO: needs real font loading.
	//
	// Original test:
	// 1. Add a regular face to the collection
	// 2. Call getFace twice with the same index
	// 3. Verify both calls return the same pointer
}

fn test_get_index() {
	// XTODO: needs real font loading.
	//
	// Original test:
	// 1. Add a regular face to the collection
	// 2. Verify all visible ASCII (32..127) can be found
	// 3. Verify emoji (U+1F978) is not found
}

fn test_complete_styles() {
	// XTODO: needs real font loading and synthetic face creation.
	//
	// Original test:
	// 1. Add a regular face, set load_options
	// 2. Verify bold/italic/bold_italic have no entries
	// 3. Call completeStyles
	// 4. Verify bold/italic/bold_italic now have entries for 'A'
}

fn test_set_size() {
	// XTODO: needs real font loading.
	//
	// Original test:
	// 1. Add a regular face with 12pt, set load_options
	// 2. Verify load_options.size.points == 12
	// 3. Call setSize(24pt)
	// 4. Verify load_options.size.points == 24
}

fn test_has_codepoint() {
	// XTODO: needs real font loading.
	//
	// Original test:
	// 1. Add a regular face
	// 2. Verify hasCodepoint(idx, 'A', .any) == true
	// 3. Verify hasCodepoint(idx, U+1F978, .any) == false
}

fn test_has_codepoint_emoji_default_graphical() {
	// XTODO: needs real font loading with emoji font.
	// Also requires fontconfig_freetype backend.
	//
	// Original test:
	// 1. Add an emoji face
	// 2. Verify hasCodepoint(idx, 'A', .any) == false
	// 3. Verify hasCodepoint(idx, U+1F978, .any) == true
}

fn test_metrics() {
	// XTODO: needs real font loading with Inconsolata.
	//
	// Original test:
	// 1. Add Inconsolata at 12pt 96dpi, call updateMetrics
	// 2. Verify metrics match expected values:
	//    cell_width=8, cell_height=17, cell_baseline=3,
	//    underline_position=17, underline_thickness=1,
	//    strikethrough_position=10, strikethrough_thickness=1,
	//    overline_position=0, overline_thickness=1,
	//    box_thickness=1, cursor_height=17,
	//    icon_height=16.784, icon_height_single=12.24,
	//    face_width=8.0, face_height=16.784, face_y=-0.04
	// 3. Resize to 24pt, verify new metrics:
	//    cell_width=16, cell_height=34, etc.
}

fn test_adjusted_sizes() {
	// XTODO: needs real font loading with Inconsolata, Monaspace Neon,
	// and Symbols Nerd Font.
	//
	// Original test:
	// 1. Add primary face (Inconsolata)
	// 2. Add fallback with ex_height and cap_height adjustments
	// 3. Verify the chosen metric matches between primary and fallback
	//    (within 0.5px tolerance)
	// 4. Verify relationship holds after resize to 37pt
	// 5. Verify "none" adjustment leaves size unchanged
	// 6. Verify symbol font falls back to lineHeight matching
}

fn test_face_metrics() {
	// XTODO: needs real font loading with Cozette and Geist Mono.
	// Also requires non-web_canvas backend.
	//
	// Original test:
	// 1. Add narrow font (Cozette) and wide font (Geist Mono)
	// 2. Verify provided/measured metrics match expected values
	//    (backend-dependent due to hinting)
	// 3. Verify icWidth() estimation:
	//    narrow: 2 * cell_width
	//    wide: ascii_height
}

fn test_index_special() {
	// Verify special index properties.
	idx := Index.init_special(.sprite)
	assert idx.special() != none
	assert idx.special() or { Special.sprite } == .sprite

	// Normal index should not be special.
	normal := Index{}
	assert normal.special() == none
}

fn test_index_packed_layout_matches_ghostty() {
	for style in [FontStyle.regular, .bold, .italic, .bold_italic] {
		for face_index in [u16(0), 1, 42, 0x1ffe, 0x1fff] {
			idx := Index{
				style: style
				idx: face_index
			}
			packed := idx.int_val()
			assert packed == (face_index << 3) | u16(style)
			decoded := Index.from_int(packed)
			assert decoded.style == style
			assert decoded.idx == face_index
		}
	}
}

fn test_presentation_mode() {
	// Test PresentationMode constructors.
	explicit := PresentationMode.explicit(.emoji)
	assert explicit.kind == .explicit_
	assert explicit.presentation == .emoji

	default_ := PresentationMode.default_(.text)
	assert default_.kind == .default_
	assert default_.presentation == .text

	any := PresentationMode.any()
	assert any.kind == .any
}
