module zigimg

fn jpeg_scan_test_frame(jpeg &JPEG, ids []u8) JpegFrame {
	mut components := []JpegComponent{}
	for id in ids {
		components << JpegComponent{
			id:                         id
			horizontal_sampling_factor: 1
			vertical_sampling_factor:   1
			quantization_table_id:      0
		}
	}
	return JpegFrame{
		frame_header:                   JpegFrameHeader{
			sample_precision: 8
			width:            8
			height:           8
			components:       components
		}
		quantization_tables:            &jpeg.quantization_tables
		dc_huffman_tables:              &jpeg.dc_huffman_tables
		ac_huffman_tables:              &jpeg.ac_huffman_tables
		block_storage:                  []JpegBlockComponents{len: 1}
		frame_type:                     0xffc0
		block_width:                    1
		block_height:                   1
		block_width_actual:             1
		block_height_actual:            1
		horizontal_sampling_factor_max: 1
		vertical_sampling_factor_max:   1
	}
}

fn jpeg_scan_test_table(symbol u8, cls u8) JpegHuffmanTable {
	return JpegHuffmanTable{
		code_counts: [16]u8{}
		code_map:    {
			u32(0): symbol
		}
		fast_table:  [512]u8{init: symbol}
		fast_size:   [512]u8{init: 1}
		table_class: cls
	}
}

fn test_jpeg_public_scan_component_reader_keeps_two_bit_ac_mask_and_position() {
	mut stream := ReadStream.init_memory([u8(255), 0xff, 7])
	c := JpegScanComponentSpec.read(mut stream)!
	assert c.component_id == 255
	assert c.dc_table_selector == 15
	assert c.ac_table_selector == 3
	assert stream.get_pos() == 2
	JpegScanComponentSpec.read(mut stream) or { assert err.msg() == 'EndOfStream' }
	assert stream.get_pos() == 3
}

fn test_jpeg_scan_init_retains_source_or_validation_and_fixed_value_copies() {
	mut jpeg := JPEG.init()
	mut frame := jpeg_scan_test_frame(&jpeg, [u8(1)])
	mut rejected := ReadStream.init_memory([u8(0), 8, 1, 7, 0, 0, 63, 0])
	JpegScan.init(&frame, mut rejected) or { assert err.msg() == 'InvalidData' }
	assert rejected.get_pos() == 5
	jpeg.ac_huffman_tables.values[0] = jpeg_scan_test_table(0, 1)
	mut stream := ReadStream.init_memory([u8(0), 8, 1, 7, 0, 0, 63, 0])
	mut scan := JpegScan.init(&frame, mut stream)!
	assert scan.component_count == 1
	assert scan.start_of_spectral_selection == 0 && scan.end_of_spectral_selection == 63
	assert scan.components[1] == none && scan.components[3] == none
	assert scan.prediction_values == [3]int{}
	assert scan.reader.table == none
	assert scan.reader.stream.get_pos() == 8
	copied := scan
	entry := scan.components[0]
	mut spec := entry or { panic('missing component') }
	spec.component_id = 9
	scan.components[0] = spec
	scan.prediction_values[0] = 42
	scan.reader.bit_buffer = 17
	frame.block_width = 7
	copied_entry := copied.components[0]
	old := copied_entry or { panic('missing copied component') }
	assert old.component_id == 7
	assert copied.prediction_values[0] == 0
	assert copied.reader.bit_buffer == 0
	assert copied.frame.block_width == 7
	assert scan.frame.block_width == 7
}

fn test_jpeg_public_scan_performs_baseline_and_initialized_progressive_refinement() {
	mut jpeg := JPEG.init()
	jpeg.dc_huffman_tables.values[0] = jpeg_scan_test_table(0, 0)
	jpeg.ac_huffman_tables.values[0] = jpeg_scan_test_table(0, 1)
	mut frame := jpeg_scan_test_frame(&jpeg, [u8(1)])
	frame.block_storage[0].blocks[0].values = [64]int{init: 42}
	mut baseline := ReadStream.init_memory([u8(0), 8, 1, 1, 0, 0, 63, 0, 0, 0, 0])
	JpegScan.perform_scan(&frame, 0, mut baseline)!
	assert frame.block_storage[0].blocks[0].values == [64]int{}
	assert baseline.get_pos() == 11
	frame.frame_type = 0xffc2
	frame.block_storage[0].blocks[0].values[0] = 5
	mut refine := ReadStream.init_memory([u8(0), 8, 1, 1, 0, 0, 0, 0x11, 0x80, 0, 0])
	JpegScan.perform_scan(&frame, 0, mut refine)!
	assert frame.block_storage[0].blocks[0].values[0] == 7
	assert refine.get_pos() == 11
}
