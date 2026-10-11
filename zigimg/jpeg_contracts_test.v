module zigimg

fn test_jpeg_huffman_table_is_borrowed_and_reader_state_is_retained() {
	mut stream := ReadStream.init_memory([u8(0), 0])
	mut reader := JpegHuffmanReader.init(mut stream)
	mut table := JpegHuffmanTable{
		code_counts: [16]u8{}
		code_map:    map[u32]u8{}
		fast_table:  [512]u8{init: 255}
		fast_size:   [512]u8{}
		table_class: 0
	}
	table.fast_table[0] = 42
	table.fast_size[0] = 1
	reader.set_huffman_table(&table)
	table.fast_table[0] = 77
	assert reader.read_code()! == 77
	assert reader.bit_count == 15
	assert stream.get_pos() == 2
	table.fast_size[0] = 2
	assert reader.read_code()! == 77
	assert reader.bit_count == 13
}

fn test_jpeg_missing_table_error_order_and_stuffed_restart_bytes() {
	mut short := ReadStream.init_memory([u8(0xff), 0xd9])
	mut empty := JpegHuffmanReader.init(mut short)
	empty.read_code() or { assert err.msg() == 'InvalidData' }
	assert empty.bit_count == 0
	assert short.get_pos() == 0
	mut stuffed := ReadStream.init_memory([u8(0xff), 0xff, 0, 0xff, 0xd0, 0x12])
	mut reader := JpegHuffmanReader.init(mut stuffed)
	assert reader.read_bits(8)! == 255
	assert reader.read_bits(8)! == 0x12
	assert stuffed.get_pos() == 6
}

fn test_jpeg_frame_header_rejects_components_before_length_invariant() {
	mut invalid := ReadStream.init_memory([u8(0), 10, 8, 0, 8, 0, 8, 1, 1, 0x11, 4])
	JpegFrameHeader.read(mut invalid) or { assert err.msg() == 'InvalidData' }
	assert invalid.get_pos() == 11
}

fn test_jpeg_i32_checked_arithmetic_valid_boundaries_and_idct_zero_block() {
	assert jpeg_add_i32(2147483646, 1) == 2147483647
	assert jpeg_sub_i32(-2147483647, 1) == -2147483648
	assert jpeg_mul_i32(-8388608, 256) == -2147483648
	mut block := JpegBlock{}
	jpeg_idct_block(mut block)
	assert block.values == [64]int{}
}
