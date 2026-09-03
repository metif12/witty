module font

// ============================================================
// Ghostty Atlas.zig tests, translated.
// Source: /Users/alexander/code/3rd/ghostty/src/font/Atlas.zig
// ============================================================

fn test_atlas_exact_fit() {
	mut atlas := Atlas.init(34, .grayscale) // +2 for 1px border
	modified := atlas.modified
	atlas.reserve(32, 32)!
	assert atlas.modified == modified
	if _ := atlas.reserve(1, 1) {
		assert false, 'expected AtlasFull'
	}
}

fn test_atlas_doesnt_fit() {
	mut atlas := Atlas.init(32, .grayscale)
	// doesn't fit due to border
	if _ := atlas.reserve(32, 32) {
		assert false, 'expected AtlasFull'
	}
}

fn test_atlas_fit_multiple() {
	mut atlas := Atlas.init(32, .grayscale)
	atlas.reserve(15, 30)!
	atlas.reserve(15, 30)!
	if _ := atlas.reserve(1, 1) {
		assert false, 'expected AtlasFull'
	}
}

fn test_atlas_writing_data() {
	mut atlas := Atlas.init(32, .grayscale)
	reg := atlas.reserve(2, 2)!
	old := atlas.modified
	atlas.set(reg, [u8(1), 2, 3, 4])
	new := atlas.modified
	assert new > old

	// 33 because of the 1px border and so on
	assert atlas.data[33] == 1
	assert atlas.data[34] == 2
	assert atlas.data[65] == 3
	assert atlas.data[66] == 4
}

fn test_atlas_writing_data_from_larger_source() {
	mut atlas := Atlas.init(32, .grayscale)
	reg := atlas.reserve(2, 2)!
	old := atlas.modified
	atlas.set_from_larger(reg, [
		u8(8),
		8,
		8,
		8,
		8,
		8,
		8,
		1,
		2,
		8,
		8,
		8,
		3,
		4,
		8,
		8,
		8,
		8,
		8,
		8,
	], 5, 2, 1)
	new := atlas.modified
	assert new > old

	// 33 because of the 1px border and so on
	assert atlas.data[33] == 1
	assert atlas.data[34] == 2
	assert atlas.data[65] == 3
	assert atlas.data[66] == 4

	// None of the `8`s from the source data outside of the
	// specified region should have made it on to the atlas.
	for b in atlas.data {
		assert b != 8
	}
}

fn test_atlas_writing_bgr_data() {
	mut atlas := Atlas.init(32, .bgr)
	reg := atlas.reserve(1, 2)!
	atlas.set(reg, [u8(1), 2, 3, 4, 5, 6])

	depth := atlas.format.depth()
	assert depth == 3
	first := int(33 * depth)
	second := int(65 * depth)
	assert atlas.data[first..first + 3] == [u8(1), 2, 3]
	assert atlas.data[second..second + 3] == [u8(4), 5, 6]
}

fn test_atlas_grow_bgr() {
	mut atlas := Atlas.init(4, .bgr)
	reg := atlas.reserve(2, 2)!
	atlas.set(reg, [
		u8(10),
		11,
		12,
		13,
		14,
		15,
		20,
		21,
		22,
		23,
		24,
		25,
	])
	atlas.grow(8)

	depth := atlas.format.depth()
	first := int((atlas.size + 1) * depth)
	second_row := int((atlas.size * 2 + 1) * depth)
	assert atlas.data[first..first + 6] == [u8(10), 11, 12, 13, 14, 15]
	assert atlas.data[second_row..second_row + 6] == [u8(20), 21, 22, 23, 24, 25]
}

fn test_atlas_grow() {
	mut atlas := Atlas.init(4, .grayscale) // +2 for 1px border
	reg := atlas.reserve(2, 2)!
	if _ := atlas.reserve(1, 1) {
		assert false, 'expected AtlasFull'
	}

	// Write some data so we can verify that growing doesn't mess it up
	atlas.set(reg, [u8(1), 2, 3, 4])
	assert atlas.data[5] == 1
	assert atlas.data[6] == 2
	assert atlas.data[9] == 3
	assert atlas.data[10] == 4

	// Expand by exactly 1 should fit our new 1x1 block.
	old_modified := atlas.modified
	old_resized := atlas.resized
	atlas.grow(atlas.size + 1)
	assert atlas.modified > old_modified
	assert atlas.resized > old_resized
	atlas.reserve(1, 1)!

	// Ensure our data is still set. Note the offsets change due to size.
	assert atlas.data[int(atlas.size + 1)] == 1
	assert atlas.data[int(atlas.size + 2)] == 2
	assert atlas.data[int(atlas.size * 2 + 1)] == 3
	assert atlas.data[int(atlas.size * 2 + 2)] == 4
}

fn test_atlas_set_and_grow_preserves_pixels() {
	mut atlas := Atlas.init(8, .grayscale)
	region := atlas.reserve(2, 2)!
	atlas.set(region, [u8(1), 2, 3, 4])
	first_idx := int(region.y * atlas.size + region.x)
	assert atlas.data[first_idx] == 1
	assert atlas.data[first_idx + 1] == 2
	old_modified := atlas.modified

	atlas.grow(16)
	grown_idx := int(region.y * atlas.size + region.x)
	assert atlas.data[grown_idx] == 1
	assert atlas.data[grown_idx + 1] == 2
	assert atlas.modified > old_modified
	assert atlas.resized == 1
}

fn test_builtin_glyph_render_writes_grayscale_atlas() {
	mut atlas := Atlas.init(64, .grayscale)
	glyph := render_builtin_cell_glyph(mut atlas, u32(`A`), default_grid_metrics(8, 16))!
	assert glyph.width == 8
	assert glyph.height == 16

	mut nonzero := 0
	for y in glyph.atlas_y .. glyph.atlas_y + glyph.height {
		for x in glyph.atlas_x .. glyph.atlas_x + glyph.width {
			if atlas.data[int(y * atlas.size + x)] > 0 {
				nonzero++
			}
		}
	}
	assert nonzero > 0
}

fn test_sprite_render_writes_cursor_atlas() {
	mut atlas := Atlas.init(64, .grayscale)
	glyph := render_sprite_glyph(mut atlas, .cursor_rect, default_grid_metrics(8, 16), 1)!
	assert glyph.width == 8
	assert glyph.height == 16

	for y in glyph.atlas_y .. glyph.atlas_y + glyph.height {
		for x in glyph.atlas_x .. glyph.atlas_x + glyph.width {
			assert atlas.data[int(y * atlas.size + x)] == 255
		}
	}
}

fn test_sprite_face_renders_unicode_sprite_codepoint_without_enum_cast() {
	mut atlas := Atlas.init(64, .grayscale)
	sf := SpriteFace{
		metrics: default_grid_metrics(8, 16)
	}
	glyph := sf.render_glyph(mut atlas, 0x2500, RenderOptions{
		cell_width: 1
		grid_metrics: default_grid_metrics(8, 16)
	})!

	assert glyph.width == 8
	assert glyph.height == 16
	mut nonzero := 0
	for y in glyph.atlas_y .. glyph.atlas_y + glyph.height {
		for x in glyph.atlas_x .. glyph.atlas_x + glyph.width {
			if atlas.data[int(y * atlas.size + x)] > 0 {
				nonzero++
			}
		}
	}
	assert nonzero > 0
}
