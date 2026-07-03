module font

// Tests for CodepointResolver (translated from ghostty/src/font/CodepointResolver.zig)
//
// XTODO: Most tests require embedded font data and real FreeType/CoreText
// face initialization to function. They are preserved here as stubs for
// completeness and future implementation.

fn test_style_status_defaults() {
	s := StyleStatus{}
	assert s.get(.regular) == true
	assert s.get(.bold) == true
	assert s.get(.italic) == true
	assert s.get(.bold_italic) == true
}

fn test_style_status_init_fill_false() {
	s := StyleStatus.init_fill(false)
	// Regular is always enabled regardless of init_fill.
	assert s.get(.regular) == true
	assert s.get(.bold) == false
	assert s.get(.italic) == false
	assert s.get(.bold_italic) == false
}

fn test_style_status_set() {
	mut s := StyleStatus{}
	s.set(.bold, false)
	assert s.get(.bold) == false
	assert s.get(.italic) == true

	s.set(.italic, false)
	assert s.get(.italic) == false

	// Setting regular is a no-op.
	s.set(.regular, false)
	assert s.get(.regular) == true
}

fn test_descriptor_cache_basic() {
	mut dc := DescriptorCache{}
	defer {
		dc.deinit()
	}

	desc := Descriptor{ family: 'TestFont' }
	idx := Index{ style: .regular, idx: 0 }

	// Initially not cached.
	assert dc.get(desc) == none

	// Add to cache.
	dc.put(desc, idx)

	// Should now be found.
	entry := dc.get(desc) or {
		assert false, 'expected cache hit'
		return
	}
	assert entry.has_index == true
	assert entry.index.style == .regular
	assert entry.index.idx == 0
}

fn test_descriptor_cache_negative() {
	mut dc := DescriptorCache{}
	defer {
		dc.deinit()
	}

	desc := Descriptor{ family: 'NotFound' }

	// Add negative entry (font not found).
	dc.put(desc, none)

	// Should be found but with has_index == false.
	entry := dc.get(desc) or {
		assert false, 'expected cache hit for negative entry'
		return
	}
	assert entry.has_index == false
}

fn test_sprite_face_has_codepoint() {
	sf := SpriteFace{
		metrics: Metrics{ cell_width: 10, cell_height: 20 }
	}

	// Box drawing characters should be handled.
	assert sf.has_codepoint(0x2500, none) == true // BOX DRAWINGS LIGHT HORIZONTAL
	assert sf.has_codepoint(0x2502, none) == true // BOX DRAWINGS LIGHT VERTICAL
	assert sf.has_codepoint(0x257F, none) == true // End of box drawing range

	// Block elements should be handled.
	assert sf.has_codepoint(0x2580, none) == true // UPPER HALF BLOCK
	assert sf.has_codepoint(0x2588, none) == true // FULL BLOCK

	// Braille should be handled.
	assert sf.has_codepoint(0x2800, none) == true

	// Legacy computing symbols should be handled.
	assert sf.has_codepoint(0x1FB00, none) == true

	// Regular ASCII should not be handled.
	assert sf.has_codepoint(0x41, none) == false // 'A'

	// Random high codepoint should not be handled.
	assert sf.has_codepoint(0x1F978, none) == false // disguised face emoji
}

fn test_codepoint_resolver_init_deinit() {
	mut r := CodepointResolver{
		collection: Collection.init()
	}
	r.deinit()
}

fn test_get_index_basic() {
	// XTODO: needs embedded font data (regular, emoji, emoji_text)
	// and real FreeType face initialization.
	//
	// Original test:
	// 1. Init library and collection with regular font, emoji font,
	//    and emoji text font
	// 2. Create resolver wrapping the collection
	// 3. Should find all visible ASCII (32..127) at index 0
	// 4. Should find emoji (U+1F978) at index 1
	// 5. Should find text emoji (U+270C) with .text at index 2
	// 6. Should find text emoji (U+270C) with .emoji at index 1
	// 7. Box glyph (U+1FB00) should be none since no sprite face set
}

fn test_get_index_disabled_font_style() {
	// XTODO: needs embedded font data and real FreeType face initialization.
	//
	// Original test:
	// 1. Init library and collection with regular, bold, italic faces
	// 2. Create resolver, disable bold style
	// 3. Regular 'A' should find regular face (style=regular, idx=0)
	// 4. Bold 'A' should fall back to regular (style=regular, idx=0)
	// 5. Italic 'A' should still find italic face (style=italic, idx=0)
}

fn test_get_index_box_glyph() {
	// Translated from ghostty CodepointResolver.zig "getIndex box glyph".
	// An empty collection plus a sprite face whose metrics are computed via
	// Metrics.calc. The box glyph U+2500 must resolve to the sprite index.
	// This path does not require any real font face to be loaded.
	c := Collection.init()
	mut r := CodepointResolver{
		collection: c
		sprite:     SpriteFace{
			metrics: Metrics.calc(FaceMetrics{
				px_per_em:  30.0
				cell_width: 18.0
				ascent:     30.0
				descent:    -6.0
				line_gap:   0.0
			})
		}
	}
	defer {
		r.deinit()
	}

	// Should find a box glyph.
	idx := r.get_index(0x2500, .regular, none) or {
		assert false, 'expected to find box glyph U+2500'
		return
	}
	assert idx.style == .regular
	// Special.sprite has integer value index_special_start (8191).
	assert idx.idx == u16(Special.sprite)
	assert idx.special() or { return } == .sprite
}

fn test_get_index_with_sprite() {
	// Test that sprite face is used for box drawing characters.
	mut r := CodepointResolver{
		collection: Collection.init()
		sprite:     SpriteFace{
			metrics: Metrics{
				cell_width:  10
				cell_height: 20
			}
		}
	}
	defer {
		r.deinit()
	}

	// Box drawing should return sprite index.
	idx := r.get_index(0x2500, .regular, none) or {
		assert false, 'expected to find box drawing character'
		return
	}
	assert idx.special() != none
	sp := idx.special() or { return }
	assert sp == .sprite
}

fn test_get_index_style_fallback() {
	// XTODO: needs embedded font data and real FreeType face initialization.
	//
	// Original test:
	// 1. Create collection with only regular face
	// 2. Request bold style for 'A'
	// 3. Should fall back to regular style since bold is not available
}

fn test_get_presentation() {
	// XTODO: needs embedded font data and real FreeType face initialization.
	//
	// Original test:
	// 1. Create resolver with regular and emoji faces
	// 2. getPresentation for sprite index should return .text
	// 3. getPresentation for regular face with non-color glyph should return .text
	// 4. getPresentation for emoji face with color glyph should return .emoji
}

fn test_render_glyph() {
	// XTODO: needs embedded font data, real FreeType rendering, and Atlas.
	//
	// Original test:
	// 1. Create resolver with regular face
	// 2. Create grayscale atlas
	// 3. Render glyph for 'A' using renderGlyph
	// 4. Verify glyph has non-zero dimensions
}
