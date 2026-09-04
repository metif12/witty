module renderer

import macos

fn test_metal_buffer_sync_writes_native_buffer() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut buffer := MetalBuffer.init(MetalBufferOptions{
		device: api.device
	}, 2)!
	defer {
		buffer.deinit()
	}

	buffer.sync([u8(1), 2, 3, 4])!

	assert buffer.len == 8
	assert macos.metal_buffer_length(buffer.handle) == 8
	assert read_metal_buffer(buffer, 4) == [u8(1), 2, 3, 4]
}

fn test_metal_texture_initial_upload_and_replace_region() ! {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut texture := MetalTexture.init(MetalTextureOptions{
		device: api.device
		pixel_format: .r8unorm
		usage: MetalTextureUsage{
			shader_read: true
		}
	}, 4, 4, [u8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])!
	defer {
		texture.deinit()
	}

	texture.replace_region(1, 1, 2, 2, [u8(90), 80, 70, 60])!

	bytes := read_metal_texture(texture)
	assert bytes[0..4] == [u8(0), 1, 2, 3]
	assert bytes[5] == 90
	assert bytes[6] == 80
	assert bytes[9] == 70
	assert bytes[10] == 60
}

fn test_metal_buffer_init_fill_copies_data() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut buffer := MetalBuffer.init_fill(MetalBufferOptions{
		device: api.device
	}, [u8(5), 6, 7])!
	defer {
		buffer.deinit()
	}

	assert buffer.len == 3
	assert macos.metal_buffer_length(buffer.handle) == 3
	assert read_metal_buffer(buffer, 3) == [u8(5), 6, 7]
}

fn test_metal_buffer_sync_within_capacity_leaves_tail() {
	// Preallocate a 4-element buffer, then sync fewer elements. The
	// remaining (untouched) bytes should not be reallocated away and the
	// capacity should be preserved. (Port of buffer.zig sync semantics.)
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	mut buffer := MetalBuffer.init_fill(MetalBufferOptions{
		device: api.device
	}, [u8(0), 0, 0, 0])!
	defer {
		buffer.deinit()
	}

	buffer.sync([u8(1), 2])!

	assert buffer.len == 4
	assert macos.metal_buffer_length(buffer.handle) == 4
	data := read_metal_buffer(buffer, 4)
	assert data[0] == 1
	assert data[1] == 2
	// Tail is left untouched (still zero from the initial allocation).
	assert data[2] == 0
	assert data[3] == 0
}

fn test_metal_texture_bpp_for_pixel_formats() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	// r8unorm is 1 byte per pixel: a 2x2 texture is 4 bytes.
	mut gray := MetalTexture.init(MetalTextureOptions{
		device: api.device
		pixel_format: .r8unorm
	}, 2, 2, none)!
	defer {
		gray.deinit()
	}
	assert gray.bpp == 1

	// bgra8unorm is 4 bytes per pixel: a 2x2 texture is 16 bytes.
	mut color := MetalTexture.init(MetalTextureOptions{
		device: api.device
		pixel_format: .bgra8unorm
	}, 2, 2, none)!
	defer {
		color.deinit()
	}
	assert color.bpp == 4
}

fn test_metal_texture_replace_region_respects_bpp() {
	mut api := MetalAPI.init()!
	defer {
		api.deinit()
	}
	// 2x2 bgra8unorm texture (4 bytes per pixel, row stride = 8 bytes).
	mut texture := MetalTexture.init(MetalTextureOptions{
		device: api.device
		pixel_format: .bgra8unorm
	}, 2, 2, []u8{len: 16})!
	defer {
		texture.deinit()
	}

	// Replace the single pixel at (1, 1) with 4 bytes.
	texture.replace_region(1, 1, 1, 1, [u8(11), 22, 33, 44])!

	// Pixel (1, 1) lives at offset 1*8 + 1*4 = 12.
	data := read_metal_texture(texture)
	assert data[12] == 11
	assert data[13] == 22
	assert data[14] == 33
	assert data[15] == 44
	// Other pixels untouched.
	assert data[0] == 0
	assert data[11] == 0
}

fn read_metal_buffer(buffer MetalBuffer, len int) []u8 {
	mut result := []u8{len: len}
	if len > 0 {
		ptr := macos.metal_buffer_contents(buffer.handle)
		assert ptr != unsafe { nil }
		unsafe { vmemcpy(result.data, ptr, len) }
	}
	return result
}

fn read_metal_texture(texture MetalTexture) []u8 {
	mut result := []u8{len: int(texture.width * texture.height * texture.bpp)}
	macos.metal_texture_get_bytes(texture.handle, mut result, usize(texture.width * texture.bpp), 0, 0, usize(texture.width), usize(texture.height))
	return result
}

fn test_metal_text_cell_grayscale_no_flags() {
	cell := CellText{
		atlas: .grayscale
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
		atlas: .color
		bools: CellTextBools{
			no_min_contrast: true
			is_cursor_glyph: true
		}
		grid_pos: [u16(3), 4]!
		color: [u8(10), 20, 30, 40]!
		glyph_pos: [u32(5), 6]!
		glyph_size: [u32(7), 8]!
		bearings: [i32(1), 2]!
	}

	metal_cell := metal_text_cell(cell)

	assert metal_cell.atlas == 1
	assert metal_cell.flags == 3
	assert metal_cell.grid_x == 3
	assert metal_cell.grid_y == 4
}
