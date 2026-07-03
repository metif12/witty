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

fn test_metal_buffer_init_fill_copies_data() {
	mut buffer := MetalBuffer.init_fill(MetalBufferOptions{}, [u8(5), 6, 7])!
	defer {
		buffer.deinit()
	}

	assert buffer.len == 3
	assert buffer.capacity == 3
	assert buffer.data == [u8(5), 6, 7]
}

fn test_metal_buffer_sync_within_capacity_leaves_tail() {
	// Preallocate a 4-element buffer, then sync fewer elements. The
	// remaining (untouched) bytes should not be reallocated away and the
	// capacity should be preserved. (Port of buffer.zig sync semantics.)
	mut buffer := MetalBuffer.init(MetalBufferOptions{}, 4)!
	defer {
		buffer.deinit()
	}

	buffer.sync([u8(1), 2])

	assert buffer.len == 2
	assert buffer.capacity == 4
	assert buffer.data[0] == 1
	assert buffer.data[1] == 2
	// Tail is left untouched (still zero from the initial allocation).
	assert buffer.data[2] == 0
	assert buffer.data[3] == 0
}

fn test_metal_texture_bpp_for_pixel_formats() {
	// r8unorm is 1 byte per pixel: a 2x2 texture is 4 bytes.
	mut gray := MetalTexture.init(MetalTextureOptions{
		pixel_format: .r8unorm
	}, 2, 2, none)!
	defer {
		gray.deinit()
	}
	assert gray.bpp == 1
	assert gray.data.len == 4

	// bgra8unorm is 4 bytes per pixel: a 2x2 texture is 16 bytes.
	mut color := MetalTexture.init(MetalTextureOptions{
		pixel_format: .bgra8unorm
	}, 2, 2, none)!
	defer {
		color.deinit()
	}
	assert color.bpp == 4
	assert color.data.len == 16
}

fn test_metal_texture_replace_region_respects_bpp() {
	// 2x2 bgra8unorm texture (4 bytes per pixel, row stride = 8 bytes).
	mut texture := MetalTexture.init(MetalTextureOptions{
		pixel_format: .bgra8unorm
	}, 2, 2, none)!
	defer {
		texture.deinit()
	}

	// Replace the single pixel at (1, 1) with 4 bytes.
	texture.replace_region(1, 1, 1, 1, [u8(11), 22, 33, 44])

	// Pixel (1, 1) lives at offset 1*8 + 1*4 = 12.
	assert texture.data[12] == 11
	assert texture.data[13] == 22
	assert texture.data[14] == 33
	assert texture.data[15] == 44
	// Other pixels untouched.
	assert texture.data[0] == 0
	assert texture.data[11] == 0
}

fn test_metal_text_cell_grayscale_no_flags() {
	cell := CellText{
		atlas:    .grayscale
		grid_pos: [u16(1), 2]!
	}

	metal_cell := metal_text_cell(cell)

	assert metal_cell.atlas == 0
	assert metal_cell.flags == 0
	assert metal_cell.grid_x == 1
	assert metal_cell.grid_y == 2
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
