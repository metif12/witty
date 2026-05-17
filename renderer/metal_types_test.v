module renderer

fn test_metal_buffer_sync_keeps_cpu_copy() {
	mut buffer := MetalBuffer.init(MetalBufferOptions{}, 2)!
	defer {
		buffer.deinit()
	}

	buffer.sync([u8(1), 2, 3, 4])

	assert buffer.len == 4
	assert buffer.capacity == 4
	assert buffer.data == [u8(1), 2, 3, 4]
}

fn test_metal_texture_initial_upload_and_replace_region() {
	mut texture := MetalTexture.init(MetalTextureOptions{
		pixel_format: .r8unorm
		usage:        MetalTextureUsage{
			shader_read: true
		}
	}, 4, 4, [u8(0), 1, 2, 3])!
	defer {
		texture.deinit()
	}

	assert texture.data[0] == 0
	assert texture.data[1] == 1
	assert texture.data[2] == 2
	assert texture.data[3] == 3

	texture.replace_region(1, 1, 2, 2, [u8(9), 8, 7, 6])

	assert texture.data[5] == 9
	assert texture.data[6] == 8
	assert texture.data[9] == 7
	assert texture.data[10] == 6
}

fn test_metal_text_cell_keeps_color_atlas_flag() {
	cell := CellText{
		atlas:      .color
		bools:      CellTextBools{
			no_min_contrast: true
			is_cursor_glyph: true
		}
		grid_pos:   [u16(3), 4]!
		color:      [u8(10), 20, 30, 40]!
		glyph_pos:  [u32(5), 6]!
		glyph_size: [u32(7), 8]!
		bearings:   [i32(1), 2]!
	}

	metal_cell := metal_text_cell(cell)

	assert metal_cell.atlas == 1
	assert metal_cell.flags == 3
	assert metal_cell.grid_x == 3
	assert metal_cell.grid_y == 4
}
