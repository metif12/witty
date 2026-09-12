module font

// Tests for CodepointResolver (translated from ghostty/src/font/CodepointResolver.zig)
//
fn make_regular_collection() !Collection {
	mut c := Collection.init()
	c.load_options = LoadOptions{
		library: Library.init()!
		size: DesiredSize{
			points: 12
			xdpi: 96
			ydpi: 96
		}
	}
	lo := c.load_options or { return error('missing load options') }
	c.add(Face.init_mem(lo.library, embedded_regular, lo.face_options())!, AddOptions{
		style: .regular
		size_adjustment: .none_
	})!
	return c
}

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
	mut c := make_regular_collection() or { panic(err) }
	lo := c.load_options or { panic('missing load options') }
	c.add(Face.init_mem(lo.library, embedded_emoji, lo.face_options()) or { panic(err) }, AddOptions{
		style: .regular
		size_adjustment: .none_
	}) or { panic(err) }
	c.add(Face.init_mem(lo.library, embedded_emoji_text, lo.face_options()) or { panic(err) }, AddOptions{
		style: .regular
		size_adjustment: .none_
	}) or { panic(err) }

	mut r := CodepointResolver{ collection: c }
	defer { r.deinit() }
	for cp := u32(32); cp < 127; cp++ {
		idx := r.get_index(cp, .regular, none) or { panic('missing ASCII U+${cp:04X}') }
		assert idx.style == .regular
		assert idx.idx == 0
	}
	emoji := r.get_index(0x1f978, .regular, none) or { panic('missing emoji face') }
	assert emoji.idx == 1
	text := r.get_index(0x270c, .regular, Presentation.text) or { panic('missing text emoji') }
	assert text.idx == 2
	graphical := r.get_index(0x270c, .regular, Presentation.emoji) or {
		panic('missing graphical emoji')
	}
	assert graphical.idx == 1
	assert r.get_index(0x1fb00, .regular, none) == none
}

fn test_get_index_disabled_font_style() {
	mut c := make_regular_collection() or { panic(err) }
	lo := c.load_options or { panic('missing load options') }
	for style in [FontStyle.bold, .italic] {
		c.add(Face.init_mem(lo.library, embedded_regular, lo.face_options()) or { panic(err) }, AddOptions{
			style: style
			size_adjustment: .none_
		}) or { panic(err) }
	}
	mut r := CodepointResolver{ collection: c }
	defer { r.deinit() }
	r.styles.set(.bold, false)

	regular := r.get_index(0x41, .regular, none) or { panic('missing regular A') }
	assert regular.style == .regular && regular.idx == 0
	bold := r.get_index(0x41, .bold, none) or { panic('missing bold fallback A') }
	assert bold.style == .regular && bold.idx == 0
	italic := r.get_index(0x41, .italic, none) or { panic('missing italic A') }
	assert italic.style == .italic && italic.idx == 0
}

fn test_get_index_box_glyph() {
	// Translated from ghostty CodepointResolver.zig "getIndex box glyph".
	// An empty collection plus a sprite face whose metrics are computed via
	// Metrics.calc. The box glyph U+2500 must resolve to the sprite index.
	// This path does not require any real font face to be loaded.
	c := Collection.init()
	mut r := CodepointResolver{
		collection: c
		sprite: SpriteFace{
			metrics: Metrics.calc(FaceMetrics{
				px_per_em: 30.0
				cell_width: 18.0
				ascent: 30.0
				descent: -6.0
				line_gap: 0.0
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
		sprite: SpriteFace{
			metrics: Metrics{
				cell_width: 10
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
	c := make_regular_collection() or { panic(err) }
	mut r := CodepointResolver{ collection: c }
	defer { r.deinit() }
	idx := r.get_index(0x41, .bold, none) or { panic('missing regular style fallback') }
	assert idx.style == .regular
	assert idx.idx == 0
}

fn test_get_presentation() {
	mut c := make_regular_collection() or { panic(err) }
	lo := c.load_options or { panic('missing load options') }
	emoji_idx := c.add(Face.init_mem(lo.library, embedded_emoji, lo.face_options()) or { panic(err) }, AddOptions{
		style: .regular
		size_adjustment: .none_
	}) or { panic(err) }
	mut r := CodepointResolver{ collection: c }
	defer { r.deinit() }
	assert r.get_presentation(Index.init_special(.sprite), 0x2500) or { panic(err) } == .text
	regular_face := r.collection.get_face(Index{}) or { panic(err) }
	regular_glyph := regular_face.glyph_index(0x41) or { panic('missing regular A') }
	assert r.get_presentation(Index{}, regular_glyph) or { panic(err) } == .text
	emoji_face := r.collection.get_face(emoji_idx) or { panic(err) }
	emoji_glyph := emoji_face.glyph_index(0x1f978) or { panic('missing emoji glyph') }
	assert r.get_presentation(emoji_idx, emoji_glyph) or { panic(err) } == .emoji
}

fn test_render_glyph() {
	c := make_regular_collection() or { panic(err) }
	mut r := CodepointResolver{ collection: c }
	defer { r.deinit() }
	mut face := r.collection.get_face(Index{}) or { panic(err) }
	glyph_index := face.glyph_index(0x41) or { panic('missing A') }
	metrics := Metrics.calc(face.get_metrics())
	mut atlas := Atlas.init(512, .grayscale)!
	defer { atlas.deinit() }
	glyph := r.render_glyph(mut atlas, Index{}, glyph_index, RenderOptions{
		grid_metrics: metrics
	}) or { panic(err) }
	assert glyph.width > 0
	assert glyph.height > 0
}
