module font

import sprite

fn test_atlas_tripwire_point_layouts() {
	assert sizeof(AtlasInitFailPoint) == 1
	assert u8(AtlasInitFailPoint.alloc_data) == 0
	assert u8(AtlasInitFailPoint.alloc_nodes) == 1
	assert sizeof(AtlasReserveFailPoint) == 1
	assert u8(AtlasReserveFailPoint.insert_node) == 0
	assert sizeof(AtlasGrowFailPoint) == 1
	assert u8(AtlasGrowFailPoint.ensure_node_capacity) == 0
	assert u8(AtlasGrowFailPoint.alloc_data) == 1
}

fn test_atlas_format_contract() {
	assert sizeof(AtlasFormat) == 1
	assert u8(AtlasFormat.grayscale) == 0
	assert u8(AtlasFormat.bgr) == 1
	assert u8(AtlasFormat.bgra) == 2
	assert typeof(AtlasFormat.bgra.depth()).name == 'u8'
	assert AtlasFormat.grayscale.depth() == 1
	assert AtlasFormat.bgr.depth() == 3
	assert AtlasFormat.bgra.depth() == 4
	mut atlas := Atlas.init(4, .grayscale)!
	assert typeof(atlas.modified.load()).name == 'usize'
	assert typeof(atlas.resized.load()).name == 'usize'
}

fn test_atlas_init_tripwires() {
	mut tw := atlas_init_tripwire()
	tw.error_always(.alloc_data, error('OutOfMemory'))
	if _ := Atlas.init(32, .grayscale) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	tw.end(.reset)!

	tw.error_always(.alloc_nodes, error('OutOfMemory'))
	if _ := Atlas.init(32, .grayscale) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	tw.end(.reset)!
}

fn test_atlas_reserve_tripwire_preserves_nodes() {
	mut atlas := Atlas.init(32, .grayscale)!
	original := atlas.nodes.clone()
	mut tw := atlas_reserve_tripwire()
	tw.error_always(.insert_node, error('OutOfMemory'))
	defer {
		tw.end(.reset) or { panic(err) }
	}
	if _ := atlas.reserve(2, 2) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	assert atlas.nodes == original
}

fn test_atlas_grow_tripwires_preserve_size() {
	mut atlas := Atlas.init(8, .grayscale)!
	mut tw := atlas_grow_tripwire()
	tw.error_always(.ensure_node_capacity, error('OutOfMemory'))
	if _ := atlas.grow(16) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	assert atlas.size == 8
	tw.end(.reset)!

	tw.error_always(.alloc_data, error('OutOfMemory'))
	if _ := atlas.grow(16) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	assert atlas.size == 8
	tw.end(.reset)!
}

struct AtlasChunkWriter {
	chunk int
pub mut:
	data []u8
}

fn (mut writer AtlasChunkWriter) write(data []u8) !int {
	if data.len == 0 {
		return 0
	}
	count := if data.len < writer.chunk { data.len } else { writer.chunk }
	writer.data << data[..count]
	return count
}

// ============================================================
// Ghostty Atlas.zig tests, translated.
// Source: /Users/alexander/code/3rd/ghostty/src/font/Atlas.zig
// ============================================================

fn test_atlas_exact_fit() {
	mut atlas := Atlas.init(34, .grayscale)! // +2 for 1px border
	modified := atlas.modified.load()
	atlas.reserve(32, 32)!
	assert atlas.modified.load() == modified
	if _ := atlas.reserve(1, 1) {
		assert false, 'expected AtlasFull'
	}
}

fn test_atlas_doesnt_fit() {
	mut atlas := Atlas.init(32, .grayscale)!
	// doesn't fit due to border
	if _ := atlas.reserve(32, 32) {
		assert false, 'expected AtlasFull'
	}
}

fn test_atlas_fit_multiple() {
	mut atlas := Atlas.init(32, .grayscale)!
	atlas.reserve(15, 30)!
	atlas.reserve(15, 30)!
	if _ := atlas.reserve(1, 1) {
		assert false, 'expected AtlasFull'
	}
}

fn test_atlas_writing_data() {
	mut atlas := Atlas.init(32, .grayscale)!
	reg := atlas.reserve(2, 2)!
	old := atlas.modified.load()
	atlas.set(reg, [u8(1), 2, 3, 4])
	new := atlas.modified.load()
	assert new > old

	// 33 because of the 1px border and so on
	assert atlas.data[33] == 1
	assert atlas.data[34] == 2
	assert atlas.data[65] == 3
	assert atlas.data[66] == 4
}

fn test_atlas_writing_data_from_larger_source() {
	mut atlas := Atlas.init(32, .grayscale)!
	reg := atlas.reserve(2, 2)!
	old := atlas.modified.load()
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
	new := atlas.modified.load()
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
	mut atlas := Atlas.init(32, .bgr)!
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
	mut atlas := Atlas.init(4, .bgr)!
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
	atlas.grow(8)!

	depth := atlas.format.depth()
	first := int((atlas.size + 1) * depth)
	second_row := int((atlas.size * 2 + 1) * depth)
	assert atlas.data[first..first + 6] == [u8(10), 11, 12, 13, 14, 15]
	assert atlas.data[second_row..second_row + 6] == [u8(20), 21, 22, 23, 24, 25]
}

fn test_atlas_dump_grayscale_with_partial_writer() {
	mut atlas := Atlas.init(4, .grayscale)!
	atlas.data[5] = 0x7f
	mut writer := AtlasChunkWriter{
		chunk: 3
	}
	atlas.dump(mut writer)!

	header := 'P5\n4 4\n255\n'.bytes()
	assert writer.data[..header.len] == header
	assert writer.data[header.len..] == atlas.data
}

fn test_atlas_dump_bgr_and_reject_bgra() {
	mut bgr := Atlas.init(3, .bgr)!
	bgr.data[0] = 1
	bgr.data[1] = 2
	bgr.data[2] = 3
	mut writer := AtlasChunkWriter{
		chunk: 1024
	}
	bgr.dump(mut writer)!
	assert writer.data[..11].bytestr() == 'P6\n3 3\n255\n'
	assert writer.data[11..] == bgr.data

	bgra := Atlas.init(3, .bgra)!
	mut rejected := AtlasChunkWriter{
		chunk: 1024
	}
	if _ := bgra.dump(mut rejected) {
		assert false, 'BGRA dump must be rejected'
	}
}

fn test_atlas_grow() {
	mut atlas := Atlas.init(4, .grayscale)! // +2 for 1px border
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
	old_modified := atlas.modified.load()
	old_resized := atlas.resized.load()
	atlas.grow(atlas.size + 1)!
	assert atlas.modified.load() > old_modified
	assert atlas.resized.load() > old_resized
	atlas.reserve(1, 1)!

	// Ensure our data is still set. Note the offsets change due to size.
	assert atlas.data[int(atlas.size + 1)] == 1
	assert atlas.data[int(atlas.size + 2)] == 2
	assert atlas.data[int(atlas.size * 2 + 1)] == 3
	assert atlas.data[int(atlas.size * 2 + 2)] == 4
}

fn test_atlas_set_and_grow_preserves_pixels() {
	mut atlas := Atlas.init(8, .grayscale)!
	region := atlas.reserve(2, 2)!
	atlas.set(region, [u8(1), 2, 3, 4])
	first_idx := int(region.y * atlas.size + region.x)
	assert atlas.data[first_idx] == 1
	assert atlas.data[first_idx + 1] == 2
	old_modified := atlas.modified.load()

	atlas.grow(16)!
	grown_idx := int(region.y * atlas.size + region.x)
	assert atlas.data[grown_idx] == 1
	assert atlas.data[grown_idx + 1] == 2
	assert atlas.modified.load() > old_modified
	assert atlas.resized.load() == 1
}

fn test_sprite_canvas_write_atlas_trims_and_uploads() {
	mut atlas := Atlas.init(16, .grayscale)!
	mut canvas := sprite.Canvas.init(4, 4, 2, 2)
	canvas.box(1, 1, 3, 3, .on)
	region := canvas.write_atlas(mut atlas)!

	assert region.width == 2
	assert region.height == 2
	for y in region.y .. region.y + region.height {
		for x in region.x .. region.x + region.width {
			assert atlas.data[int(y * atlas.size + x)] == 255
		}
	}
}

fn test_sprite_canvas_write_atlas_propagates_full() {
	mut atlas := Atlas.init(4, .grayscale)!
	atlas.reserve(2, 2)!
	mut canvas := sprite.Canvas.init(1, 1, 0, 0)
	canvas.pixel(0, 0, .on)
	canvas.write_atlas(mut atlas) or {
		assert err.msg() == 'AtlasFull'
		return
	}
	assert false, 'expected Canvas.write_atlas to preserve AtlasFull'
}

fn test_builtin_glyph_render_ignores_unsupported_codepoint() {
	mut atlas := Atlas.init(64, .grayscale)!
	glyph := render_builtin_cell_glyph(mut atlas, u32(`A`), default_grid_metrics(8, 16))!
	assert glyph.width == 0
	assert glyph.height == 0
}

fn test_sprite_render_writes_cursor_atlas() {
	mut atlas := Atlas.init(64, .grayscale)!
	sf := SpriteFace{
		metrics: default_grid_metrics(8, 16)
	}
	glyph := sf.render_glyph(mut atlas, u32(Sprite.cursor_rect), RenderOptions{
		cell_width:   1
		grid_metrics: default_grid_metrics(8, 16)
	})!
	assert glyph.width == 8
	assert glyph.height == 16

	for y in glyph.atlas_y .. glyph.atlas_y + glyph.height {
		for x in glyph.atlas_x .. glyph.atlas_x + glyph.width {
			assert atlas.data[int(y * atlas.size + x)] == 255
		}
	}
}

fn test_sprite_face_renders_unicode_sprite_codepoint_without_enum_cast() {
	mut atlas := Atlas.init(64, .grayscale)!
	sf := SpriteFace{
		metrics: default_grid_metrics(8, 16)
	}
	glyph := sf.render_glyph(mut atlas, 0x2500, RenderOptions{
		cell_width:   1
		grid_metrics: default_grid_metrics(8, 16)
	})!

	// The sprite canvas trims transparent margins before atlas insertion.
	assert glyph.width == 8
	assert glyph.height == 1
	mut nonzero := 0
	for y in glyph.atlas_y .. glyph.atlas_y + glyph.height {
		for x in glyph.atlas_x .. glyph.atlas_x + glyph.width {
			if atlas.data[int(y * atlas.size + x)] > 0 {
				nonzero++
			}
		}
	}
	assert nonzero > 0
	assert nonzero < 8 * 16
}
