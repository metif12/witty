module stb

const test_png = $embed_file('@VMODROOT/kitty/testdata/image-png-none-50x76-2147483647-raw.data').to_bytes()

fn test_load_png_from_memory_and_free() {
	mut width := 0
	mut height := 0
	mut channels := 0
	pixels := unsafe {
		stbi_load_from_memory(test_png.data, test_png.len, &width, &height, &channels,
			4)
	}
	assert !isnil(pixels)
	defer {
		stbi_image_free(pixels)
	}
	assert width == 50
	assert height == 76
	assert channels == 3
	assert unsafe { pixels.vbytes(width * height * 4) }.len == 50 * 76 * 4
}

fn test_load_invalid_image_preserves_dimensions() {
	data := [u8(1), 2, 3, 4]
	mut width := 11
	mut height := 12
	mut channels := 13
	pixels := unsafe { stbi_load_from_memory(&data[0], data.len, &width, &height, &channels, 4) }
	assert isnil(pixels)
	assert width == 11
	assert height == 12
	assert channels == 13
}

fn test_resize_uint8_uses_source_default_filter() {
	input := [u8(1), 2, 3, 4]
	mut output := []u8{len: 16}

	result := unsafe { stbir_resize_uint8(&input[0], 2, 2, 0, &output[0], 4, 4, 0, 1) }

	assert result == 1
	assert output == [u8(1), 1, 2, 2, 1, 2, 2, 2, 3, 3, 3, 4, 3, 3, 4, 4]
}

fn test_resize_uint8_respects_channels() {
	input := [u8(10), 20, 30, 40, 50, 60]
	mut output := []u8{len: 12}

	result := unsafe { stbir_resize_uint8(&input[0], 2, 1, 0, &output[0], 4, 1, 0, 3) }

	assert result == 1
	assert output == [u8(8), 18, 28, 16, 26, 36, 34, 44, 54, 42, 52, 62]
}
