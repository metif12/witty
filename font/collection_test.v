module font

import math

fn test_collection_tag_layouts_and_source_ordinals() {
	assert sizeof(SizeAdjustment) == 1
	assert [SizeAdjustment.none_, .ic_width, .ex_height, .cap_height, .line_height].map(u8(it)) == [u8(0),
		1, 2, 3, 4]
	assert sizeof(PresentationModeKind) == 1
	assert [PresentationModeKind.explicit_, .default_, .any].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(PresentationMode) == 2
	assert default_fallback_adjustment == .ic_width
}

// Tests for Collection (translated from ghostty/src/font/Collection.zig).

fn collection_test_options(lib Library, points f32) LoadOptions {
	return LoadOptions{
		library: lib
		size: DesiredSize{
			points: points
			xdpi: 96
			ydpi: 96
		}
	}
}

fn collection_test_add(mut c Collection, data []u8, style Style, adjustment SizeAdjustment) Index {
	load_options := c.load_options or { panic('missing collection load options') }
	face := Face.init_mem(load_options.library, data, load_options.face_options()) or { panic(err) }
	return c.add(face, AddOptions{
		style: style
		fallback: false
		size_adjustment: adjustment
	}) or { panic(err) }
}

fn assert_collection_close(expected f64, actual f64, tolerance f64) {
	assert math.abs(expected - actual) <= tolerance, 'expected ${expected}, got ${actual}'
}

fn collection_test_metrics(mut c Collection, idx Index) FaceMetrics {
	mut face := c.get_face(idx) or { panic(err) }
	return face.get_metrics()
}

fn test_collection_init() {
	mut c := Collection.init()
	c.deinit()
}

fn test_entry_or_alias_const_entry_resolves_both_arms() {
	entry_value := EntryOrAlias{
		entry: Entry{ fallback: true }
	}
	assert entry_value.get_const_entry().fallback

	target := Entry{ fallback: true }
	alias_value := EntryOrAlias{
		is_alias: true
		alias_entry: &target
	}
	assert alias_value.get_const_entry() == &target
}

fn test_collection_add_full() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	// The capacity check depends only on the number of entries. Populate the
	// same 8190 slots without opening 8190 duplicate FreeType faces.
	for _ in 0 .. int(index_special_start) - 1 {
		c.regular_faces << EntryOrAlias.new_entry(Entry{})
	}
	mut face := Face.init_mem(lib, embedded_regular, FaceOptions{
		size: DesiredSize{ points: 12 }
	}) or { panic(err) }
	c.add(face, AddOptions{ style: .regular }) or {
		assert err.msg() == 'collection full'
		face.deinit()
		return
	}
	assert false, 'expected collection full'
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
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	idx := collection_test_add(mut c, embedded_regular, .regular, .none_)
	face1 := c.get_face(idx) or { panic(err) }
	face2 := c.get_face(idx) or { panic(err) }
	assert face1 == face2
}

fn test_get_index() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	collection_test_add(mut c, embedded_regular, .regular, .none_)
	for cp := u32(32); cp < 127; cp++ {
		assert c.get_index(cp, .regular, PresentationMode.any()) != none
	}
	assert c.get_index(0x1f978, .regular, PresentationMode.any()) == none
}

fn test_complete_styles() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	collection_test_add(mut c, embedded_regular, .regular, .none_)
	assert c.get_index(u32(`A`), .bold, PresentationMode.any()) == none
	assert c.get_index(u32(`A`), .italic, PresentationMode.any()) == none
	assert c.get_index(u32(`A`), .bold_italic, PresentationMode.any()) == none
	c.complete_styles(FontSyntheticStyle{}) or { panic(err) }
	assert c.get_index(u32(`A`), .bold, PresentationMode.any()) != none
	assert c.get_index(u32(`A`), .italic, PresentationMode.any()) != none
	assert c.get_index(u32(`A`), .bold_italic, PresentationMode.any()) != none
}

fn test_set_size() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	collection_test_add(mut c, embedded_regular, .regular, .none_)
	assert (c.load_options or { panic('missing options') }).size.points == 12
	c.set_collection_size(DesiredSize{ points: 24, xdpi: 96, ydpi: 96 }) or { panic(err) }
	assert (c.load_options or { panic('missing options') }).size.points == 24
}

fn test_has_codepoint() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	idx := collection_test_add(mut c, embedded_regular, .regular, .none_)
	assert c.has_codepoint(idx, u32(`A`), PresentationMode.any())
	assert !c.has_codepoint(idx, 0x1f978, PresentationMode.any())
}

fn test_has_codepoint_emoji_default_graphical() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	idx := collection_test_add(mut c, embedded_emoji, .regular, .none_)
	assert !c.has_codepoint(idx, u32(`A`), PresentationMode.any())
	assert c.has_codepoint(idx, 0x1f978, PresentationMode.any())
}

fn test_metrics() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	collection_test_add(mut c, embedded_inconsolata, .regular, .none_)
	c.update_metrics() or { panic(err) }
	metrics := c.metrics or { panic('missing metrics') }
	assert metrics.cell_width == 8
	assert metrics.cell_height == 17
	assert metrics.cell_baseline == 3
	assert metrics.underline_position == 17
	assert metrics.strikethrough_position == 10
	assert_collection_close(16.784, metrics.icon_height, 0.001)
	assert_collection_close(12.24, metrics.icon_height_single, 0.001)
	assert_collection_close(-0.04, metrics.face_y, 0.001)
	c.set_collection_size(DesiredSize{ points: 24, xdpi: 96, ydpi: 96 }) or { panic(err) }
	resized := c.metrics or { panic('missing resized metrics') }
	assert resized.cell_width == 16
	assert resized.cell_height == 34
	assert resized.cell_baseline == 6
	assert resized.underline_thickness == 2
	assert resized.strikethrough_position == 19
	assert_collection_close(33.568, resized.icon_height, 0.001)
}

fn test_adjusted_sizes() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	collection_test_add(mut c, embedded_inconsolata, .regular, .none_)
	c.update_metrics() or { panic(err) }
	for adjustment in [SizeAdjustment.ex_height, .cap_height] {
		idx := collection_test_add(mut c, embedded_monaspace_neon, .regular, adjustment)
		primary := collection_test_metrics(mut c, Index{})
		fallback := collection_test_metrics(mut c, idx)
		if adjustment == .ex_height {
			assert_collection_close(primary.ex_height(), fallback.ex_height(), 0.5)
		} else {
			assert_collection_close(primary.cap_height(), fallback.cap_height(), 0.5)
		}
		c.set_collection_size(DesiredSize{ points: 37, xdpi: 96, ydpi: 96 }) or { panic(err) }
		primary_resized := collection_test_metrics(mut c, Index{})
		fallback_resized := collection_test_metrics(mut c, idx)
		if adjustment == .ex_height {
			assert_collection_close(primary_resized.ex_height(), fallback_resized.ex_height(), 0.5)
		} else {
			assert_collection_close(primary_resized.cap_height(), fallback_resized.cap_height(), 0.5)
		}
		c.set_collection_size(DesiredSize{ points: 12, xdpi: 96, ydpi: 96 }) or { panic(err) }
	}
	none_idx := collection_test_add(mut c, embedded_monaspace_neon, .regular, .none_)
	assert (c.get_face(Index{}) or { panic(err) }).size.points == (c.get_face(none_idx) or {
		panic(err)
	}).size.points
	symbol_idx := collection_test_add(mut c, embedded_symbols_nerd_font, .regular, .ex_height)
	primary_metrics := collection_test_metrics(mut c, Index{})
	symbol_metrics := collection_test_metrics(mut c, symbol_idx)
	assert_collection_close(primary_metrics.line_height(), symbol_metrics.line_height(), 0.5)
}

fn test_face_metrics() {
	mut lib := Library.init() or { panic(err) }
	defer { lib.deinit() }
	mut c := Collection.init()
	defer { c.deinit() }
	c.load_options = collection_test_options(lib, 12)
	narrow_idx := collection_test_add(mut c, embedded_cozette, .regular, .none_)
	wide_idx := collection_test_add(mut c, embedded_geist_mono, .regular, .none_)
	narrow := collection_test_metrics(mut c, narrow_idx)
	wide := collection_test_metrics(mut c, wide_idx)
	assert_collection_close(16.0, narrow.px_per_em, 0.001)
	$if macos {
		// The native CoreText backend uses unhinted advances.
		assert_collection_close(7.3828125, narrow.cell_width, 0.001)
	} $else {
		assert_collection_close(8.0, narrow.cell_width, 0.001)
	}
	assert_collection_close(12.3046875, narrow.ascent, 0.001)
	$if macos {
		assert_collection_close(9.6, wide.cell_width, 0.001)
	} $else {
		assert_collection_close(10.0, wide.cell_width, 0.001)
	}
	assert_collection_close(14.72, wide.ascent, 0.001)
	assert narrow.ic_width() == 2 * narrow.cell_width
	assert wide.ic_width() == wide.ascii_height()
}

fn test_index_special() {
	assert sizeof(Index) == sizeof(u16)
	assert sizeof(Special) == sizeof(u16)

	// Verify special index properties.
	idx := Index.init_special(.sprite)
	assert idx.int_val() == 0xfff8
	assert idx.special() != none
	assert idx.special() or { Special.sprite } == .sprite

	// Normal index should not be special.
	normal := Index{}
	assert normal.special() == none
}

fn test_font_synthetic_style_packed_layout_matches_ghostty() {
	assert sizeof(FontSyntheticStyle) == 1
	assert FontSyntheticStyle{}.int_val() == 0x07
	style := FontSyntheticStyle.init(true, false, true)
	assert style.int_val() == 0x05
	assert style.bold()
	assert !style.italic()
	assert style.bold_italic()
}

fn test_index_packed_layout_matches_ghostty() {
	for style in [Style.regular, .bold, .italic, .bold_italic] {
		for face_index in [u16(0), 1, 42, 0x1ffe, 0x1fff] {
			idx := Index.init(style, face_index)
			packed := idx.int_val()
			assert packed == (face_index << 3) | u16(style)
			assert idx.style() == style
			assert idx.idx() == face_index
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
