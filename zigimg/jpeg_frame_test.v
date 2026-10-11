module zigimg

import os

fn test_jpeg_frame_read_returns_metadata_values_and_borrows_fixed_tables() {
	mut jpeg := JPEG.init()
	mut stream := ReadStream.init_memory([u8(0), 11, 8, 0, 9, 0, 17, 1, 1, 0x22, 0])
	mut frame := JpegFrame.read(0xffc0, &jpeg.quantization_tables, &jpeg.dc_huffman_tables,
		&jpeg.ac_huffman_tables, mut stream)!
	assert frame.block_width == 3 && frame.block_height == 2
	assert frame.block_width_actual == 4 && frame.block_height_actual == 2
	assert frame.block_storage.len == 8
	assert frame.horizontal_sampling_factor_max == 2
	assert frame.vertical_sampling_factor_max == 2
	assert stream.get_pos() == 11
	copied := frame
	frame.frame_header.width = 7
	frame.block_width = 1
	frame.block_storage[0].blocks[0].values[0] = 42
	jpeg.quantization_tables.values[0] = JpegQuantization8{
		values: [64]u8{init: 2}
	}
	assert copied.frame_header.width == 17 && copied.block_width == 3
	assert copied.block_storage[0].blocks[0].values[0] == 42
	entry := copied.quantization_tables.values[0]
	table := entry or { panic('missing borrowed table') }
	assert table is JpegQuantization8
	if table is JpegQuantization8 { assert table.values[0] == 2
	 }
	jpeg.quantization_tables.values[0] = none
	assert copied.quantization_tables.values[0] == none
}

fn test_jpeg_public_rgb_render_crops_rows_and_uses_actual_block_stride() {
	mut jpeg := JPEG.init()
	mut frame := JpegFrame{
		frame_header:        JpegFrameHeader{
			sample_precision: 8
			width:            9
			height:           9
			components:       []JpegComponent{}
		}
		quantization_tables: &jpeg.quantization_tables
		dc_huffman_tables:   &jpeg.dc_huffman_tables
		ac_huffman_tables:   &jpeg.ac_huffman_tables
		block_storage:       []JpegBlockComponents{len: 6}
		block_width:         2
		block_height:        2
		block_width_actual:  3
		block_height_actual: 2
	}
	for bi in 0 .. 6 {
		for i in 0 .. 64 {
			frame.block_storage[bi].blocks[0].values[i] = bi * 32 + i
			frame.block_storage[bi].blocks[1].values[i] = 17
			frame.block_storage[bi].blocks[2].values[i] = 29
		}
	}
	mut pixels := []Rgb24{len: 81}
	frame.render_to_pixels_rgb(mut pixels)!
	assert pixels[7] == Rgb24{
		r: 7
		g: 17
		b: 29
	}
	assert pixels[8] == Rgb24{
		r: 32
		g: 17
		b: 29
	}
	assert pixels[71] == Rgb24{
		r: 88
		g: 17
		b: 29
	}
	assert pixels[72] == Rgb24{
		r: 96
		g: 17
		b: 29
	}
	assert pixels[80] == Rgb24{
		r: 128
		g: 17
		b: 29
	}
}

fn test_jpeg_public_chroma_block_supports_aliased_downsampling() {
	mut jpeg := JPEG.init()
	mut frame := JpegFrame{
		frame_header:                   JpegFrameHeader{
			sample_precision: 8
			width:            8
			height:           8
			components:       []JpegComponent{}
		}
		quantization_tables:            &jpeg.quantization_tables
		dc_huffman_tables:              &jpeg.dc_huffman_tables
		ac_huffman_tables:              &jpeg.ac_huffman_tables
		block_storage:                  []JpegBlockComponents{}
		horizontal_sampling_factor_max: 2
		vertical_sampling_factor_max:   2
	}
	mut block := JpegBlockComponents{
		blocks: [JpegBlock{ values: [64]int{} }, JpegBlock{ values: [64]int{init: 10} },
			JpegBlock{ values: [64]int{init: 20} }]!
	}
	frame.ycbcr_to_rgb_block(mut block, &block, 0, 0)
	for i in 0 .. 64 {
		assert block.blocks[0].values[i] == 156
		assert block.blocks[1].values[i] == 110
		assert block.blocks[2].values[i] == 145
	}
	copied := block
	block.blocks[0].values[0] = 7
	assert copied.blocks[0].values[0] == 156
}

fn test_jpeg_read_returned_and_stored_frames_copy_metadata_and_share_coefficients() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'zigimg', 'testdata', 'jpeg',
		'grayscale-baseline.jpg'))!
	mut stream := ReadStream.init_memory(bytes)
	mut jpeg := JPEG.init()
	mut pixels := JpegPixels{}
	mut returned := jpeg.read(mut stream, mut pixels)!
	copied := returned
	returned.frame_header.width++
	returned.block_width++
	returned.block_storage[0].blocks[0].values[0] = 42
	stored := jpeg.frame or { panic('missing retained frame') }
	assert stored.frame_header.width == copied.frame_header.width
	assert stored.block_width == copied.block_width
	assert stored.frame_header.width + 1 == returned.frame_header.width
	assert stored.block_storage[0].blocks[0].values[0] == 42
	assert copied.block_storage[0].blocks[0].values[0] == 42
	jpeg.quantization_tables.values[0] = none
	assert returned.quantization_tables.values[0] == none
}
