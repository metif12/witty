module zigimg

fn test_jpeg_header_copies_share_components_and_keep_scalar_and_slice_state() {
	mut stream := ReadStream.init_memory([u8(0), 17, 8, 0, 9, 0, 11, 3, 1, 0x22, 0, 2, 0x11, 1,
		3, 0x11, 1])
	mut header := JpegFrameHeader.read(mut stream)!
	copied := header
	header.width = 13
	header.components[1].horizontal_sampling_factor = 4
	header.components = header.components[..1]
	assert header.width == 13
	assert copied.width == 11
	assert header.components.len == 1
	assert copied.components.len == 3
	assert header.max_horizontal_sampling_factor() == 2
	assert copied.max_horizontal_sampling_factor() == 4
	assert copied.max_vertical_sampling_factor() == 2
	header.deinit()
}

fn test_jpeg_component_reader_preserves_late_validation_and_consumed_bytes() {
	mut stream := ReadStream.init_memory([u8(17), 0x04, 7, 42, 0x41, 3])
	JpegComponent.read(mut stream) or { assert err.msg() == 'InvalidData' }
	assert stream.get_pos() == 3
	c := JpegComponent.read(mut stream)!
	assert c.id == 42
	assert c.horizontal_sampling_factor == 4
	assert c.vertical_sampling_factor == 1
	assert c.quantization_table_id == 3
	assert stream.get_pos() == 6
}

fn test_jpeg_quantization_tags_and_whole_table_replacement() {
	mut bytes := []u8{cap: 128}
	for i in 0 .. 64 {
		bytes << u8(i >> 8)
		bytes << u8(i)
	}
	mut stream := ReadStream.init_memory(bytes)
	mut table := JpegQuantizationTable.read(1, mut stream)!
	assert table is JpegQuantization16
	if mut table is JpegQuantization16 {
		assert table.values[0] == 0
		assert table.values[8] == 2
		assert table.values[63] == 63
		table.values[8] = 65535
	}
	copied := table
	table = JpegQuantization8{
		values: [64]u8{init: 7}
	}
	assert table is JpegQuantization8
	assert copied is JpegQuantization16
	if copied is JpegQuantization16 { assert copied.values[8] == 65535
	 }
	assert stream.get_pos() == 128
}

fn test_jpeg_mutable_quantization_table_reaches_frame_arithmetic() {
	mut jpeg := JPEG.init()
	mut stream := ReadStream.init_memory([u8(0), 11, 8, 0, 8, 0, 8, 1, 1, 0x11, 0])
	mut frame := JpegFrame.read(0xffc0, &jpeg.quantization_tables, &jpeg.dc_huffman_tables,
		&jpeg.ac_huffman_tables, mut stream)!
	mut table := JpegQuantization8{
		values: [64]u8{init: 1}
	}
	table.values[0] = 2
	jpeg.quantization_tables.values[0] = table
	frame.block_storage[0] = JpegBlockComponents{
		blocks: [3]JpegBlock{init: JpegBlock{
			values: [64]int{}
		}}
	}
	frame.block_storage[0].blocks[0].values[0] = 8
	frame.dequantize_blocks()!
	assert frame.block_storage[0].blocks[0].values[0] == 16
	frame.idct_blocks()
	mut pixels := PixelStorage(Grayscale8Pixels{
		data: []Grayscale8{len: 64}
	})
	frame.render_to_pixels(mut pixels)!
	if pixels is Grayscale8Pixels {
		for pixel in pixels.data {
			assert pixel.value == 130
		}
	}
}
