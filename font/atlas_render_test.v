module font

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
		cell_width:   1
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
