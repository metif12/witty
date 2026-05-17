module stb

fn test_resize_uint8_nearest_neighbor_grayscale() {
	input := [u8(1), 2, 3, 4]
	mut output := []u8{len: 16}

	ok := unsafe { stbir_resize_uint8(&input[0], 2, 2, 0, &output[0], 4, 4, 0, 1) }

	assert ok
	assert output[0] == 1
	assert output[1] == 1
	assert output[4] == 1
	assert output[5] == 1
	assert output[10] == 4
	assert output[15] == 4
}

fn test_resize_uint8_respects_channels() {
	input := [u8(10), 20, 30, 40, 50, 60]
	mut output := []u8{len: 12}

	ok := unsafe { stbir_resize_uint8(&input[0], 2, 1, 0, &output[0], 4, 1, 0, 3) }

	assert ok
	assert output[0] == 10
	assert output[1] == 20
	assert output[2] == 30
	assert output[6] == 40
	assert output[7] == 50
	assert output[8] == 60
}

fn test_resize_uint8_rejects_invalid_dimensions() {
	input := [u8(1)]
	mut output := []u8{len: 1}

	assert !unsafe { stbir_resize_uint8(&input[0], 0, 1, 0, &output[0], 1, 1, 0, 1) }
}
