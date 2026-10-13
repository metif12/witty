module zigimg

import encoding.hex

fn test_tiff_deflate_fixed_header_footer_and_read_ahead() {
	mut bytes := hex.decode('789ccb48cdc9c90700062c0215')!
	bytes << [u8(9), 8, 7, 6, 5, 4, 3, 2, 1]
	codec := TIFF{}
	for ignored_fields in [false, true] {
		if ignored_fields {
			// The pinned reader ignores FCHECK, FDICT, and Adler32 validation.
			bytes[1] = 0x20
			bytes[9] = 0
			bytes[10] = 0
			bytes[11] = 0
			bytes[12] = 0
		}
		mut stream := ReadStream.init_memory(bytes)
		mut destination := []u8{len: 8, init: 0xa5}
		codec.uncompress_deflate(mut stream, mut destination)!
		assert destination == [u8(`h`), `e`, `l`, `l`, `o`, 0xa5, 0xa5, 0xa5]
		assert stream.get_pos() == 13
	}
	mut stream := ReadStream.init_memory(bytes[..12])
	mut destination := []u8{len: 8, init: 0xa5}
	mut failure := ''
	codec.uncompress_deflate(mut stream, mut destination) or { failure = err.msg() }
	assert failure == 'InvalidData'
	assert destination[..5] == 'hello'.bytes()
	assert stream.get_pos() == 9
	stream = ReadStream.init_memory(bytes)
	destination = []u8{len: 3, init: 0xa5}
	failure = ''
	codec.uncompress_deflate(mut stream, mut destination) or { failure = err.msg() }
	assert failure == 'InvalidData'
	assert destination == 'hel'.bytes()
	// Writer failure occurs before the footer, after word-sized bit read-ahead.
	assert stream.get_pos() == 10
}

fn test_tiff_deflate_dynamic_output_is_buffered_through_footer() {
	bytes := hex.decode('789cedc4390100000804a0ace7d3bf8229dc6020d5b391244992244992f4d901c67a8e02')!
	codec := TIFF{}
	mut stream := ReadStream.init_memory(bytes)
	mut destination := []u8{len: 5000}
	codec.uncompress_deflate(mut stream, mut destination)!
	for index, byte in destination {
		assert byte == 'abcde'[index % 5]
	}
	assert stream.get_pos() == u64(bytes.len)
	stream = ReadStream.init_memory(bytes[..bytes.len - 1])
	destination = []u8{len: 5000, init: 0xa5}
	mut failure := ''
	codec.uncompress_deflate(mut stream, mut destination) or { failure = err.msg() }
	assert failure == 'InvalidData'
	assert destination == []u8{len: 5000, init: 0xa5}
	assert stream.get_pos() == u64(bytes.len - 4)
}

fn test_tiff_deflate_stored_blocks_rebase_and_deliver_short_prefixes() {
	mut bytes := [u8(0x78), 0]
	mut expected := []u8{}
	for block in 0 .. 3 {
		count := 50000
		bytes << u8(if block == 2 { 1 } else { 0 })
		bytes << [u8(count), u8(count >> 8), u8(~u16(count)), u8(~u16(count) >> 8)]
		for index in 0 .. count {
			value := u8(index * 23 + block * 19)
			bytes << value
			expected << value
		}
	}
	bytes << [u8(0), 0, 0, 0, 99, 88, 77]
	mut stream := ReadStream.init_memory(bytes)
	mut destination := []u8{len: expected.len}
	TIFF{}.uncompress_deflate(mut stream, mut destination)!
	assert destination == expected
	assert stream.get_pos() == u64(bytes.len - 3)
	stream = ReadStream.init_memory([u8(0x78), 0, 1, 5, 0, 0xfa, 0xff, `h`, `e`])
	destination = []u8{len: 5, init: 0xa5}
	mut failure := ''
	TIFF{}.uncompress_deflate(mut stream, mut destination) or { failure = err.msg() }
	assert failure == 'InvalidData'
	assert destination == [u8(`h`), `e`, 0xa5, 0xa5, 0xa5]
	assert stream.get_pos() == 9
}

fn test_tiff_lzw_ccitt_helpers_error_mapping_and_photo_truncation() {
	mut stream := ReadStream.init_memory(hex.decode('8010485010')!)
	mut destination := []u8{len: 2}
	TIFF{}.uncompress_lzw(mut stream, mut destination)!
	assert destination == 'AB'.bytes()
	for photo in [u16(0), 1, 2, 3, 65535] {
		codec := TIFF{
			bitmap: TiffBitmapDescriptor{
				photometric_interpretation: photo
			}
		}
		stream = ReadStream.init_memory([u8(0x98), 0])
		destination = []u8{len: 2, init: 0xa5}
		codec.uncompress_ccitt(mut stream, mut destination, 8, 1)!
		assert destination[0] == if photo & 1 == 1 {
			u8(255)
		} else {
			u8(0)
		}
		assert destination[1] == 0xa5
		assert stream.get_pos() == 1
		stream = ReadStream.init_memory([]u8{})
		mut failure := ''
		codec.uncompress_ccitt(mut stream, mut destination, 8, 1) or { failure = err.msg() }
		assert failure == 'InvalidData'
	}
}

fn tiff_decode_test_append(mut bytes []u8, value u32, size int, endianess TiffEndian) {
	for index in 0 .. size {
		shift := if endianess == .big { (size - index - 1) * 8 } else { index * 8 }
		bytes << u8(value >> shift)
	}
}

fn tiff_decode_test_image(endianess TiffEndian) []u8 {
	mut bytes := if endianess == .big { 'MM'.bytes() } else { 'II'.bytes() }
	tiff_decode_test_append(mut bytes, 43, 2, endianess)
	tiff_decode_test_append(mut bytes, 8, 4, endianess)
	tiff_decode_test_append(mut bytes, 9, 2, endianess)
	for tag in [
		[u32(256), 4, 1, 3]!,
		[u32(257), 4, 1, 3]!,
		[u32(258), 3, 1, 8]!,
		[u32(259), 3, 1, 1]!,
		[u32(262), 3, 1, 0]!,
		[u32(273), 4, 2, 122]!,
		[u32(278), 4, 1, 2]!,
		[u32(279), 4, 2, 130]!,
		[u32(317), 3, 1, 2]!,
	] {
		tiff_decode_test_append(mut bytes, tag[0], 2, endianess)
		tiff_decode_test_append(mut bytes, tag[1], 2, endianess)
		tiff_decode_test_append(mut bytes, tag[2], 4, endianess)
		if tag[1] == 3 {
			tiff_decode_test_append(mut bytes, tag[3], 2, endianess)
			bytes << [u8(0), 0]
		} else {
			tiff_decode_test_append(mut bytes, tag[3], 4, endianess)
		}
	}
	tiff_decode_test_append(mut bytes, 0, 4, endianess)
	for value in [u32(138), 144, 0, 0] {
		tiff_decode_test_append(mut bytes, value, 4, endianess)
	}
	bytes << [u8(250), 10, 2, 3, 4, 5, 1, 2, 3]
	return bytes
}

fn test_tiff_read_both_endians_multiple_strips_and_unvalidated_version() {
	for endianess in [TiffEndian.big, .little] {
		bytes := tiff_decode_test_image(endianess)
		mut stream := ReadStream.init_memory(bytes)
		mut codec := TIFF{}
		pixels := codec.read(mut stream)!
		assert codec.header.version == 43 && codec.header.idf_offset == 8
		assert codec.endianess == endianess && codec.width() == 3 && codec.height() == 3
		assert pixels.as_const_bytes() == [u8(250), 4, 6, 3, 7, 12, 1, 3, 6]
		assert stream.get_pos() == 147
		stream = ReadStream.init_memory(bytes)
		image := TIFF.read_image(mut stream)!
		assert image.width == 3 && image.height == 3
		assert image.pixels.as_const_bytes() == pixels.as_const_bytes()
		assert image.animation.frames.len == 0
	}
}

fn test_tiff_one_bit_floor_rows_polarity_and_short_defined_prefix() {
	for photo in [u16(0), 1] {
		mut codec := TIFF{
			bitmap: TiffBitmapDescriptor{
				image_width:                17
				image_height:               2
				rows_per_strip:             2
				photometric_interpretation: photo
				strip_offsets:              [u32(1)]
				strip_byte_counts:          [u32(0)]
			}
		}
		codec.bitmap.bits_per_sample.resize(1)
		codec.bitmap.bits_per_sample.data[0] = 1
		mut pixels := PixelStorage.init(.grayscale1, 34)!
		mut stream := ReadStream.init_memory([u8(0), 0xaa, 0x55, 0xf0, 0x0f])
		codec.read_strips(mut stream, mut pixels)!
		assert stream.get_pos() == 5
		match pixels {
			Grayscale1Pixels {
				for index in 0 .. 32 {
					byte := [u8(0xaa), 0x55, 0xf0, 0x0f][index / 8]
					value := (byte >> (7 - index % 8)) & 1
					assert pixels.data[index].value == if photo == 1 {
						value
					} else {
						value ^ 1
					}
				}
			}
			else {
				assert false
			}
		}
	}
	mut codec := TIFF{
		bitmap: TiffBitmapDescriptor{
			image_width:       3
			image_height:      1
			rows_per_strip:    1
			strip_offsets:     [u32(1)]
			strip_byte_counts: [u32(0)]
		}
	}
	codec.bitmap.bits_per_sample.resize(1)
	codec.bitmap.bits_per_sample.data[0] = 8
	mut stream := ReadStream.init_memory([u8(0), 0x7e])
	mut pixels := PixelStorage.init(.grayscale8, 3)!
	codec.read_strips(mut stream, mut pixels)!
	assert pixels.as_const_bytes()[0] == 0x7e
	assert stream.get_pos() == 2
	// Unread source allocator bytes and unwritten pixels are excluded.
}

fn test_tiff_debug_payload_preserves_source_nested_records_options_and_newline() {
	mut b := TiffBitmapDescriptor{}
	assert tiff_debug_message(&b) == '.{ .compression = .uncompressed, .image_width = 0, .image_height = 0, .photometric_interpretation = 0, .rows_per_strip = 0, .strip_offsets = null, .strip_byte_counts = null, .x_resolution = { 0, 0 }, .y_resolution = { 0, 0 }, .resolution_unit = .no_unit, .bits_per_sample = .{ .data = {  }, .storage = { 0, 0, 0, 0, 0, 0, 0, 0 } }, .new_subfile_type = 0, .color_map = .{ .data = {  }, .storage = { .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... } } }, .samples_per_pixel = 1, .fill_order = 1, .extra_samples = .{ .data = {  }, .storage = { 0, 0, 0, 0, 0, 0, 0, 0 } }, .planar_configuration = 1, .predictor = 1 }\n'
	b.compression = .pixar_deflate
	b.image_width = 4294967295
	b.image_height = 2147483648
	b.photometric_interpretation = 65535
	b.rows_per_strip = 4294967295
	b.strip_offsets = [u32(0), 4294967295, 10]
	b.strip_byte_counts = []u32{}
	b.x_resolution = [u32(4294967295), 1]!
	b.y_resolution = [u32(0), 2147483648]!
	b.resolution_unit = .cm
	b.bits_per_sample.storage = [u16(0), 1, 9, 10, 99, 100, 32768, 65535]!
	b.bits_per_sample.resize(8)
	b.bits_per_sample.data = unsafe { b.bits_per_sample.data[1..4] }
	b.new_subfile_type = 4294967295
	b.color_map.data = [Rgba32{ r: 0, g: 34, b: 92, a: 255 },
		Rgba32{ r: 10, g: 128, b: 255, a: 0 }]
	b.samples_per_pixel = 65535
	b.fill_order = 32768
	b.extra_samples.storage = [8]u16{init: 65535}
	b.extra_samples.data = [u16(65535), 1]
	b.planar_configuration = 255
	b.predictor = 65535
	assert tiff_debug_message(&b) == '.{ .compression = .pixar_deflate, .image_width = 4294967295, .image_height = 2147483648, .photometric_interpretation = 65535, .rows_per_strip = 4294967295, .strip_offsets = { 0, 4294967295, 10 }, .strip_byte_counts = {  }, .x_resolution = { 4294967295, 1 }, .y_resolution = { 0, 2147483648 }, .resolution_unit = .cm, .bits_per_sample = .{ .data = { 1, 9, 10 }, .storage = { 0, 1, 9, 10, 99, 100, 32768, 65535 } }, .new_subfile_type = 4294967295, .color_map = .{ .data = { .{ ... }, .{ ... } }, .storage = { .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... }, .{ ... } } }, .samples_per_pixel = 65535, .fill_order = 32768, .extra_samples = .{ .data = { 65535, 1 }, .storage = { 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535 } }, .planar_configuration = 255, .predictor = 65535 }\n'
}
