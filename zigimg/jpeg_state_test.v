module zigimg

fn jpeg_state_test_initialize(mut jpeg JPEG) {
	jpeg.frame = JpegFrame{
		frame_header:                   JpegFrameHeader{
			sample_precision: 8
			width:            8
			height:           8
			components:       [
				JpegComponent{
					id:                         1
					horizontal_sampling_factor: 1
					vertical_sampling_factor:   1
					quantization_table_id:      0
				},
			]
		}
		quantization_tables:            &jpeg.quantization_tables
		dc_huffman_tables:              &jpeg.dc_huffman_tables
		ac_huffman_tables:              &jpeg.ac_huffman_tables
		block_storage:                  [
			JpegBlockComponents{
				blocks: [3]JpegBlock{init: JpegBlock{
					values: [64]int{}
				}}
			},
		]
		frame_type:                     0xffc0
		block_width:                    1
		block_height:                   1
		block_width_actual:             1
		block_height_actual:            1
		horizontal_sampling_factor_max: 1
		vertical_sampling_factor_max:   1
	}
	if mut frame := jpeg.frame {
		frame.block_storage[0].blocks[0].values[0] = 64
		jpeg.frame = frame
	}
}

fn jpeg_state_test_pixels() JpegPixels {
	return JpegPixels{
		value: Grayscale8Pixels{
			data: []Grayscale8{len: 64, init: Grayscale8{
				value: 17
			}}
		}
	}
}

fn test_jpeg_failed_finalization_keeps_frame_and_allows_caller_pixel_reset() {
	mut jpeg := JPEG.init()
	jpeg_state_test_initialize(mut jpeg)
	mut pixels := jpeg_state_test_pixels()
	mut missing := ReadStream.init_memory([u8(0xff), 0xd8, 0xff, 0xd9])
	jpeg.read(mut missing, mut pixels) or { assert err.msg() == 'InvalidData' }
	assert missing.get_pos() == 4
	assert pixels.value == none
	stored := jpeg.frame or { panic('missing retained frame') }
	assert stored.block_storage[0].blocks[0].values[0] == 64
	jpeg.quantization_tables.values[0] = JpegQuantization8{
		values: [64]u8{init: 1}
	}
	pixels = jpeg_state_test_pixels()
	mut retry := ReadStream.init_memory([u8(0xff), 0xd8, 0xff, 0xd9])
	frame := jpeg.read(mut retry, mut pixels)!
	assert frame.block_storage[0].blocks[0].values == [64]int{init: 8}
	value := pixels.value or { panic('missing pixels after retry') }
	if value is Grayscale8Pixels {
		assert value.data == []Grayscale8{len: 64, init: Grayscale8{
			value: 136
		}}
	} else {
		assert false
	}
}

fn test_jpeg_duplicate_frame_fails_before_header_and_preserves_existing_record() {
	mut jpeg := JPEG.init()
	jpeg_state_test_initialize(mut jpeg)
	jpeg.restart_interval = 9
	mut pixels := jpeg_state_test_pixels()
	mut stream := ReadStream.init_memory([u8(0xff), 0xd8, 0xff, 0xc0])
	jpeg.read(mut stream, mut pixels) or { assert err.msg() == 'Unsupported' }
	assert stream.get_pos() == 4
	assert pixels.value == none
	assert jpeg.restart_interval == 9
	frame := jpeg.frame or { panic('missing retained frame') }
	assert frame.frame_header.width == 8
	assert frame.block_storage[0].blocks[0].values[0] == 64
}

fn test_jpeg_quantization_segment_preserves_first_install_on_later_truncation() {
	mut jpeg := JPEG.init()
	jpeg_state_test_initialize(mut jpeg)
	jpeg.quantization_tables.values[0] = JpegQuantization8{
		values: [64]u8{init: 3}
	}
	jpeg.quantization_tables.values[1] = JpegQuantization8{
		values: [64]u8{init: 5}
	}
	mut data := [u8(0xff), 0xd8, 0xff, 0xdb, 0, 132, 0]
	data << []u8{len: 64, init: 2}
	data << u8(1)
	data << []u8{len: 10, init: 7}
	mut stream := ReadStream.init_memory(data)
	mut pixels := jpeg_state_test_pixels()
	jpeg.read(mut stream, mut pixels) or { assert err.msg() == 'EndOfStream' }
	assert stream.get_pos() == 82
	assert pixels.value == none
	for slot, expected in [u8(2), 5] {
		entry := jpeg.quantization_tables.values[slot]
		table := entry or { panic('missing retained quantization table') }
		if table is JpegQuantization8 {
			assert table.values == [64]u8{init: expected}
		} else {
			assert false
		}
	}
	frame := jpeg.frame or { panic('missing retained frame') }
	assert frame.block_storage[0].blocks[0].values[0] == 64
}

fn test_jpeg_restart_interval_survives_later_marker_read_failure() {
	mut jpeg := JPEG.init()
	jpeg_state_test_initialize(mut jpeg)
	jpeg.restart_interval = 9
	mut pixels := jpeg_state_test_pixels()
	mut stream := ReadStream.init_memory([u8(0xff), 0xd8, 0xff, 0xdd, 0, 4, 0, 17])
	jpeg.read(mut stream, mut pixels) or { assert err.msg() == 'EndOfStream' }
	assert stream.get_pos() == 8
	assert jpeg.restart_interval == 17
	assert pixels.value == none
	frame := jpeg.frame or { panic('missing retained frame') }
	assert frame.block_storage[0].blocks[0].values[0] == 64
}
