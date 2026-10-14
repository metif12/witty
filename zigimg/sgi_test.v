module zigimg

import os

fn test_sgi_direct_file_rle_retains_unwritten_output_and_retry_state() {
	data := [u8(0), 0, 2, 8, 0, 0, 0, 6, 127, 129, 0x12, 0x34, 127, 0]
	path := os.join_path(os.temp_dir(), 'witty-sgi-direct-${os.getpid()}.bin')
	os.write_file_array(path, data)!
	defer { os.rm(path) or {} }
	mut file := os.open(path)!
	defer { file.close() }
	file.seek(i64(data.len), .start)!
	mut buffer := []u8{len: 3, init: 165}
	mut reader := ReadStream.init_file(file, mut buffer)
	mut codec := SGI{
		header: SgiHeader{
			compression:       .rle
			bytes_per_channel: 255
			x_size:            3
			y_size:            1
			z_size:            1
		}
	}
	mut output := []u8{len: 6, init: 165}
	codec.uncompress_bitmap(mut reader, mut output)!
	assert output == [u8(0x12), 0x34, 165, 165, 165, 165]
	assert reader.get_pos() == 14 && reader.buffered_len() == 0
	assert buffer == [u8(165), 165, 165]
	mut failed := false
	codec.uncompress_bitmap(mut reader, mut output) or {
		assert err.msg() == 'EndOfStream'
		failed = true
	}
	assert failed
	assert output == [u8(0x12), 0x34, 165, 165, 165, 165]
	assert reader.get_pos() == 14 && reader.buffered_len() == 0
	assert buffer == [u8(165), 165, 165] && os.read_bytes(path)! == data
}

fn test_sgi_file_no_op_writers_preserve_pending_prefix_until_caller_flush() {
	mut data := []u8{len: 39, init: `Z`}
	for i in 0 .. 7 {
		data[i] = `x`
	}
	path := os.join_path(os.temp_dir(), 'witty-sgi-noop-${os.getpid()}.bin')
	os.write_file_array(path, data)!
	defer { os.rm(path) or {} }
	mut file := os.open_file(path, 'r+')!
	defer { file.close() }
	file.seek(i64(data.len), .start)!
	mut buffer := []u8{len: 8, init: 165}
	mut writer := WriteStream.init_file(file, mut buffer)
	writer.seek_to(7)!
	writer.write([u8(17), 18, 19])!
	mut image := ImageUnmanaged{
		width:  7
		height: 9
		pixels: PixelStorage.init(.rgb24, 2)!
	}
	mut raw := image.pixels.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(i * 37 + 19)
	}
	before := raw.clone()
	iface := SGI.format_interface()
	for _ in 0 .. 3 {
		SGI.write_image(mut writer, image)!
		iface.write_image(mut writer, image, SgiEncoderOptions{})!
		assert writer.get_pos() == 10 && writer.buffered() == [u8(17), 18, 19]
		assert buffer == [u8(17), 18, 19, 165, 165, 165, 165, 165]
		assert os.read_bytes(path)! == data && image.raw_bytes() == before
	}
	writer.flush()!
	data[7] = 17
	data[8] = 18
	data[9] = 19
	assert os.read_bytes(path)! == data
	assert writer.get_pos() == 10 && writer.buffered().len == 0
	assert buffer == [u8(17), 18, 19, 165, 165, 165, 165, 165]
}

fn test_sgi_rle_table_size_keeps_the_largest_u16_extent() {
	mut tables := []u8{}
	for _ in 0 .. 8191 {
		append_be_u32(mut tables, 66040)
	}
	for _ in 0 .. 8191 {
		append_be_u32(mut tables, 0)
	}
	mut stream := ReadStream.init_memory(tables)
	mut codec := SGI{
		header: SgiHeader{
			compression:       .rle
			bytes_per_channel: 1
			y_size:            1
			z_size:            8191
		}
	}
	mut output := []u8{}
	codec.uncompress_bitmap(mut stream, mut output)!
	assert stream.get_pos() == 65528 && output.len == 0
}

fn test_sgi_rle_uses_two_byte_words_for_every_other_channel_width() {
	for bpc in [u8(0), 2, 3, 255] {
		mut stream := ReadStream.init_memory([u8(0), 0, 2, 8, 0, 0, 0, 4, 127, 1, 0x12, 0x34])
		mut codec := SGI{
			header: SgiHeader{
				compression:       .rle
				bytes_per_channel: bpc
				x_size:            1
				y_size:            1
				z_size:            1
			}
		}
		mut output := []u8{len: 2, init: 165}
		codec.uncompress_bitmap(mut stream, mut output)!
		assert output == [u8(0x12), 0x34] && stream.get_pos() == 12
	}
}

fn sgi_fixture(header SgiHeader, data []u8) []u8 {
	mut bytes := [u8(1), 0xda, u8(header.compression), header.bytes_per_channel]
	for value in [u16(header.dimension), header.x_size, header.y_size, header.z_size] {
		bytes << [u8(value >> 8), u8(value)]
	}
	for value in [header.pix_min, header.pix_max, header.dummy1] {
		append_be_u32(mut bytes, value)
	}
	for byte in header.image_name {
		bytes << byte
	}
	append_be_u32(mut bytes, u32(header.pixel_format))
	for byte in header.dummy2 {
		bytes << byte
	}
	assert bytes.len == 512
	bytes << data
	return bytes
}

fn sgi_rle_fixture(header SgiHeader, scanlines [][]u8) []u8 {
	assert scanlines.len == int(header.y_size) * int(header.z_size)
	mut offsets := []u32{len: scanlines.len}
	mut data := []u8{}
	// Store compressed rows in reverse order to verify the offset table,
	// rather than accidentally relying on sequential compressed scanlines.
	for i := scanlines.len - 1; i >= 0; i-- {
		offsets[i] = u32(512 + scanlines.len * 8 + data.len)
		data << scanlines[i]
	}
	mut tables := []u8{}
	for offset in offsets {
		append_be_u32(mut tables, offset)
	}
	for row in scanlines {
		append_be_u32(mut tables, u32(row.len))
	}
	tables << data
	tables << [u8(99), 88] // The source consumes all bytes after the tables.
	return sgi_fixture(header, tables)
}

fn test_sgi_header_layout_planar_channels_and_bottom_up_rows() {
	assert sizeof(SgiHeader) == 510
	mut header := SgiHeader{
		bytes_per_channel: 1
		dimension:         .multi_channel
		x_size:            2
		y_size:            2
		z_size:            3
		pix_min:           123
		pix_max:           456
		dummy1:            789
	}
	header.image_name[0] = `X`
	header.dummy2[403] = 77
	mut reader := ReadStream.init_memory(sgi_fixture(header, [u8(10), 20, 30, 40, 1, 2, 3, 4, 100,
		110, 120, 130]))
	assert SGI.format_detect(mut reader)!
	assert reader.get_pos() == 0
	mut codec := SGI{}
	pixels := codec.read(mut reader)!
	assert codec.header == header
	assert codec.width() == 2 && codec.height() == 2
	assert pixels.pixel_format() == .rgb24
	assert pixels.as_bytes() == [u8(30), 3, 120, 40, 4, 130, 10, 1, 100, 20, 2, 110]
	header.z_size = 4
	reader = ReadStream.init_memory(sgi_fixture(header, [u8(10), 20, 30, 40, 1, 2, 3, 4, 100, 110,
		120, 130, 5, 6, 7, 8]))
	image := SGI.read_image(mut reader)!
	assert image.pixel_format() == .rgba32
	assert image.raw_bytes() == [u8(30), 3, 120, 7, 40, 4, 130, 8, 10, 1, 100, 5, 20, 2, 110, 6]
}

fn test_sgi_16_bit_channels_preserve_source_alpha_byte_index_and_byte_swap() {
	mut reader := ReadStream.init_memory(sgi_fixture(SgiHeader{
		bytes_per_channel: 2
		dimension:         .multi_channel
		x_size:            1
		y_size:            2
		z_size:            3
	}, [u8(0x11), 0x11, 0x22, 0x22, 0x33, 0x33, 0x44, 0x44, 0x55, 0x55, 0x66, 0x66]))
	image := SGI.read_image(mut reader)!
	match image.pixels {
		Rgb48Pixels {
			assert image.pixels.data == [
				Rgb48{
					r: 0x2222
					g: 0x4444
					b: 0x6666
				},
				Rgb48{
					r: 0x1111
					g: 0x3333
					b: 0x5555
				},
			]
		}
		else {
			assert false
		}
	}

	reader = ReadStream.init_memory(sgi_fixture(SgiHeader{
		bytes_per_channel: 2
		dimension:         .multi_channel
		x_size:            1
		y_size:            1
		z_size:            4
	}, [u8(0x12), 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]))
	rgba := SGI.read_image(mut reader)!
	// Native reference execution verifies 0x7800 on this little-endian host.
	word := u16(1)
	is_little := unsafe { (&u8(&word))[0] == 1 }
	alpha := if is_little { u16(0x7800) } else { u16(0x78) }
	match rgba.pixels {
		Rgba64Pixels {
			assert rgba.pixels.data == [
				Rgba64{
					r: 0x1234
					g: 0x5678
					b: 0x9abc
					a: alpha
				},
			]
		}
		else {
			assert false
		}
	}
}

fn test_sgi_grayscale_always_selects_8_bit_storage() {
	mut reader := ReadStream.init_memory(sgi_fixture(SgiHeader{
		bytes_per_channel: 1
		dimension:         .single_channel
		x_size:            2
		y_size:            2
		z_size:            1
	}, [u8(1), 2, 3, 4]))
	assert SGI.read_image(mut reader)!.raw_bytes() == [u8(3), 4, 1, 2]
	reader = ReadStream.init_memory(sgi_fixture(SgiHeader{
		bytes_per_channel: 2
		dimension:         .single_channel
		x_size:            2
		y_size:            1
		z_size:            1
	}, [u8(0x12), 0x34, 0x56, 0x78]))
	image := SGI.read_image(mut reader)!
	assert image.pixel_format() == .grayscale8
	assert image.raw_bytes() == [u8(0x12), 0x34]
	assert reader.get_pos() == 516
}

fn test_sgi_rle_uses_tables_literal_repeat_empty_literal_and_terminator_commands() {
	rows := [
		[u8(0x80), 0x81, 1, 2, 3, 0],
		[u8(0x83), 4, 5, 6, 0],
		[u8(3), 7, 0],
		[u8(0x83), 8, 9, 10, 0],
		[u8(3), 11, 0],
		[u8(3), 12, 0],
	]
	bytes := sgi_rle_fixture(SgiHeader{
		compression:       .rle
		bytes_per_channel: 1
		dimension:         .multi_channel
		x_size:            3
		y_size:            2
		z_size:            3
	}, rows)
	mut reader := ReadStream.init_memory(bytes)
	image := SGI.read_image(mut reader)!
	assert image.raw_bytes() == [u8(4), 8, 12, 5, 9, 12, 6, 10, 12, 1, 7, 11, 3, 7, 11, 3, 7, 11]
	assert reader.get_pos() == u64(bytes.len)
}

fn test_sgi_16_bit_rle_ignores_high_command_byte() {
	rows := [
		[u8(0xff), 0x83, 0x11, 0x11, 0x22, 0x22, 0x33, 0x33, 0, 0],
		[u8(0x7f), 3, 0x44, 0x44, 0, 0],
		[u8(0), 0x83, 0x55, 0x55, 0x66, 0x66, 0x77, 0x77, 0, 0],
	]
	mut reader := ReadStream.init_memory(sgi_rle_fixture(SgiHeader{
		compression:       .rle
		bytes_per_channel: 2
		dimension:         .multi_channel
		x_size:            3
		y_size:            1
		z_size:            3
	}, rows))
	image := SGI.read_image(mut reader)!
	match image.pixels {
		Rgb48Pixels {
			assert image.pixels.data == [
				Rgb48{
					r: 0x1111
					g: 0x4444
					b: 0x5555
				},
				Rgb48{
					r: 0x2222
					g: 0x4444
					b: 0x6666
				},
				Rgb48{
					r: 0x3333
					g: 0x4444
					b: 0x7777
				},
			]
		}
		else {
			assert false
		}
	}
}

fn test_sgi_rle_does_not_clip_to_scanline_width() {
	mut reader := ReadStream.init_memory(sgi_rle_fixture(SgiHeader{
		compression:       .rle
		bytes_per_channel: 1
		dimension:         .single_channel
		x_size:            2
		y_size:            2
		z_size:            1
	}, [[u8(3), 9, 0], [u8(2), 1, 0]]))
	assert SGI.read_image(mut reader)!.raw_bytes() == [u8(1), 1, 9, 9]
}

fn test_sgi_errors_preserve_magic_header_and_pixel_read_positions_and_noop_writer() {
	bytes := sgi_fixture(SgiHeader{
		bytes_per_channel: 1
		dimension:         .multi_channel
		x_size:            1
		y_size:            1
		z_size:            3
	}, [u8(1), 2, 3])
	for length in [1, 20, 513] {
		mut reader := ReadStream.init_memory(bytes[..length])
		SGI.read_image(mut reader) or {
			assert err.msg() == if length == 20 {
				'InvalidData'
			} else {
				'EndOfStream'
			}
			assert reader.get_pos() == match length {
				1 { u64(0) }
				20 { u64(2) }
				else { u64(513) }
			}

			continue
		}
		assert false
	}
	for header in [SgiHeader{ dimension: .scanline }, SgiHeader{
		dimension: .multi_channel
		z_size:    2
	}, SgiHeader{ dimension: .single_channel, pixel_format: .dithered }] {
		mut reader := ReadStream.init_memory(sgi_fixture(header, []))
		SGI.read_image(mut reader) or {
			assert err.msg() == 'Unsupported'
			assert reader.get_pos() == 512
			continue
		}
		assert false
	}
	mut output := []u8{}
	mut writer := WriteStream.init_memory(mut output)
	SGI.write_image(mut writer, ImageUnmanaged{})!
	assert writer.get_pos() == 0
}

fn test_fixed_storage_specializations_keep_inline_borrowed_views() {
	mut bytes := FixedStorage256[u8]{}
	assert bytes.data.len == 0
	bytes.resize(256)
	bytes.data[255] = 23
	assert bytes.storage[255] == 23
	assert bytes.data.data == unsafe { &bytes.storage[0] }
	bytes.resize(0)
	assert bytes.data.len == 0
	bytes.resize(256)
	assert bytes.data[255] == 23
	mut colors := FixedStorage256[Rgb24]{}
	colors.resize(2)
	colors.data[1].g = 55
	assert colors.storage[1].g == 55
}

fn test_sgi_debug_payload_preserves_source_arrays_and_unsigned_fields() {
	mut h := SgiHeader{}
	assert sgi_debug_message(&h) == '.{ .compression = .uncompressed, .bytes_per_channel = 0, .dimension = .scanline, .x_size = 0, .y_size = 0, .z_size = 0, .pix_min = 0, .pix_max = 0, .dummy1 = 0, .image_name = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, .pixel_format = .normal, .dummy2 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }'
	h.compression = .rle
	h.dimension = .multi_channel
	h.pixel_format = .cmap_only
	h.pix_min = 4294967295
	for i, byte in [u8(0), 34, 92, 10, 128, 255] {
		h.image_name[i] = byte
	}
	h.dummy2[403] = 255
	before := h
	assert sgi_debug_message(&h) == '.{ .compression = .rle, .bytes_per_channel = 0, .dimension = .multi_channel, .x_size = 0, .y_size = 0, .z_size = 0, .pix_min = 4294967295, .pix_max = 0, .dummy1 = 0, .image_name = { 0, 34, 92, 10, 128, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, .pixel_format = .cmap_only, .dummy2 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255 } }'
	assert h == before
}

fn test_sgi_file_buffers_preserve_raw_planes_and_rle_tables() {
	path := os.join_path(os.temp_dir(), 'witty-sgi-buffer-${os.getpid()}.sgi')
	defer { os.rm(path) or {} }
	header := SgiHeader{
		bytes_per_channel: 1
		dimension:         .multi_channel
		x_size:            3
		y_size:            2
		z_size:            3
	}
	raw := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
	mut rows := [][]u8{}
	for start := 0; start < raw.len; start += 3 {
		mut packet := [u8(0x83)]
		packet << raw[start..start + 3]
		packet << 0
		rows << packet
	}
	mut rle_header := header
	rle_header.compression = .rle
	for data in [sgi_fixture(header, raw), sgi_rle_fixture(rle_header, rows)] {
		mut memory := ReadStream.init_memory(data)
		mut expected_codec := SGI{}
		expected := expected_codec.read(mut memory)!
		os.write_file_array(path, data)!
		for capacity in [510, 511, 512, 1024] {
			mut file := os.open(path)!
			mut buffer := []u8{len: capacity, init: u8(165)}
			mut stream := ReadStream.init_file(file, mut buffer)
			mut codec := SGI{}
			actual := codec.read(mut stream)!
			assert codec.header == expected_codec.header
			assert actual.as_bytes() == expected.as_bytes()
			assert stream.get_pos() == memory.get_pos()
			file.close()
		}
	}
}

fn test_sgi_incomplete_header_and_wrong_magic_precede_enum_validation() {
	initial := SgiHeader{
		bytes_per_channel: 1
		dimension:         .single_channel
		x_size:            7
		y_size:            9
		z_size:            1
	}
	mut bytes := sgi_fixture(initial, [])
	bytes[2] = 255
	bytes[4] = 255
	bytes[5] = 255
	bytes[104] = 255
	for length in [3, 6, 108, 511] {
		mut stream := ReadStream.init_memory(bytes[..length])
		mut codec := SGI{
			header: initial
		}
		codec.read(mut stream) or {
			assert err.msg() == 'InvalidData'
			assert codec.header == initial
			assert stream.get_pos() == 2
			continue
		}
		assert false
	}
	bytes[0] = 0
	mut stream := ReadStream.init_memory(bytes)
	mut codec := SGI{
		header: initial
	}
	codec.read(mut stream) or {
		assert err.msg() == 'InvalidData'
		assert codec.header == initial
		assert stream.get_pos() == 0
		return
	}
	assert false
}
