module zigimg

fn ras_fixture(header RasHeader, palette []u8, data []u8) []u8 {
	mut bytes := [u8(0x59), 0xa6, 0x6a, 0x95]
	for value in [header.width, header.height, header.depth, header.length, u32(header.type_),
		u32(header.color_map_type), header.color_map_length] {
		append_be_u32(mut bytes, value)
	}
	bytes << palette
	bytes << data
	return bytes
}

fn test_ras_header_layout_detection_and_uncompressed_color_orders() {
	assert sizeof(RasHeader) == 28
	assert sizeof(RasType) == 4 && sizeof(RasColorMapType) == 4
	for type_ in [RasType.old, .standard, .rgb] {
		bytes := ras_fixture(RasHeader{
			width:            1
			height:           1
			depth:            24
			type_:            type_
			length:           0
			color_map_type:   .no_color_map
			color_map_length: 0
		}, [], [u8(10), 20, 30])
		mut reader := ReadStream.init_memory(bytes)
		assert RAS.format_detect(mut reader)!
		assert reader.get_pos() == 0
		image := RAS.read_image(mut reader)!
		assert image.width == 1 && image.height == 1
		assert image.raw_bytes() == [u8(10), 20, 30]
		assert image.pixel_format() == if type_ == .rgb {
			PixelFormat.rgb24
		} else {
			PixelFormat.bgr24
		}
		mut iter := image.iterator()
		pixel := iter.next() or { panic('missing pixel') }
		assert pixel.r == if type_ == .rgb {
			f32(10) / 255
		} else {
			f32(30) / 255
		}
		assert pixel.b == if type_ == .rgb {
			f32(30) / 255
		} else {
			f32(10) / 255
		}
		assert reader.get_pos() == 35
	}
	for type_ in [RasType.standard, .rgb] {
		mut reader := ReadStream.init_memory(ras_fixture(RasHeader{
			width:            1
			height:           1
			depth:            32
			type_:            type_
			length:           0
			color_map_type:   .no_color_map
			color_map_length: 0
		}, [], [u8(77), 10, 20, 30]))
		image := RAS.read_image(mut reader)!
		assert image.raw_bytes() == if type_ == .rgb {
			[u8(10), 20, 30, 255]
		} else {
			[u8(30), 20, 10, 255]
		}
	}
}

fn test_ras_one_bit_rows_have_16_bit_padding_and_inverted_polarity() {
	mut reader := ReadStream.init_memory(ras_fixture(RasHeader{
		width:            10
		height:           2
		depth:            1
		type_:            .standard
		length:           0
		color_map_type:   .no_color_map
		color_map_length: 0
	}, [], [u8(0xaa), 0x80, 0x55, 0x40]))
	image := RAS.read_image(mut reader)!
	assert image.pixel_format() == .grayscale1
	assert image.raw_bytes() == [u8(0), 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
	reader = ReadStream.init_memory(ras_fixture(RasHeader{
		width:            1
		height:           2
		depth:            1
		length:           0
		type_:            .old
		color_map_type:   .no_color_map
		color_map_length: 0
	}, [], [
		u8(0x80),
		0xff,
		0,
		0xff,
	]))
	assert RAS.read_image(mut reader)!.raw_bytes() == [u8(0), 1]
	// The source does not apply that padding to odd-width eight-bit scanlines.
	reader = ReadStream.init_memory(ras_fixture(RasHeader{
		width:            3
		height:           2
		depth:            8
		length:           0
		type_:            .old
		color_map_type:   .no_color_map
		color_map_length: 0
	}, [], [
		u8(1),
		2,
		3,
		4,
		5,
		6,
	]))
	assert RAS.read_image(mut reader)!.raw_bytes() == [u8(1), 2, 3, 4, 5, 6]
}

fn test_ras_palette_planes_active_capacity_and_pixel_palette_copy() {
	mut reader := ReadStream.init_memory(ras_fixture(RasHeader{
		width:            3
		height:           1
		depth:            8
		type_:            .standard
		color_map_type:   .rgb_color_map
		color_map_length: 7
		length:           0
	}, [u8(10), 11, 20, 21, 30, 31, 99], [u8(0), 1, 0]))
	mut codec := RAS{}
	pixels := codec.read(mut reader)!
	assert pixels.pixel_format() == .indexed8
	assert pixels.as_bytes() == [u8(0), 1, 0]
	palette := pixels.get_palette() or { panic('missing palette') }
	assert palette == [Rgba32{ r: 10, g: 20, b: 30 }, Rgba32{ r: 11, g: 21, b: 31 }]
	assert codec.palette.data.data == unsafe { &codec.palette.storage[0] }
	assert palette.data != codec.palette.data.data
	codec.palette.data[0].r = 55
	assert codec.palette.storage[0].r == 55
	assert palette[0].r == 10
	// One-bit + color map selects indexed8 and copies raw bytes in this source.
	reader = ReadStream.init_memory(ras_fixture(RasHeader{
		width:            1
		height:           1
		depth:            1
		color_map_type:   .rgb_color_map
		color_map_length: 6
		length:           0
		type_:            .old
	}, [u8(0), 255, 0, 255, 0, 255], [u8(0x80), 0]))
	quirk := RAS.read_image(mut reader)!
	assert quirk.pixel_format() == .indexed8
	assert quirk.raw_bytes() == [u8(0x80)]
}

fn test_ras_rle_escape_runs_clipping_and_trailing_input() {
	mut reader := ReadStream.init_memory(ras_fixture(RasHeader{
		width:            7
		height:           1
		depth:            8
		type_:            .byte_encoded
		length:           0
		color_map_type:   .no_color_map
		color_map_length: 0
	}, [], [u8(1), 0x80, 0, 0x80, 2, 7, 0x80, 255, 9, 55]))
	image := RAS.read_image(mut reader)!
	assert image.raw_bytes() == [u8(1), 0x80, 7, 7, 7, 9, 9]
	assert reader.take_byte()! == 55
	assert reader.get_pos() == 42
}

fn test_ras_short_reads_preserve_source_positions_and_noop_writer() {
	mut reader := ReadStream.init_memory([u8(1), 2])
	mut destination := [u8(99), 99, 99]
	reader.read_slice_all(mut destination) or {
		assert err.msg() == 'EndOfStream'
		assert reader.get_pos() == 2
		assert destination == [u8(1), 2, 99]
	}
	for length in [3, 8, 34] {
		expected := if length == 8 { 'InvalidData' } else { 'EndOfStream' }
		position := match length {
			3 { u64(0) }
			8 { u64(4) }
			else { u64(34) }
		}

		bytes := ras_fixture(RasHeader{
			width:            3
			height:           1
			depth:            8
			length:           0
			type_:            .old
			color_map_type:   .no_color_map
			color_map_length: 0
		}, [], [u8(1), 2, 3])
		reader = ReadStream.init_memory(bytes[..length])
		RAS.read_image(mut reader) or {
			assert err.msg() == expected
			assert reader.get_pos() == position
			continue
		}
		assert false
	}
	mut output := []u8{len: 1}
	mut writer := WriteStream.init_memory(mut output)
	RAS.write_image(mut writer, ImageUnmanaged{})!
	assert writer.get_pos() == 0
}

fn test_ras_unsupported_depth_compression_and_color_map_errors() {
	for header in [
		RasHeader{
			depth:            16
			width:            0
			height:           0
			length:           0
			type_:            .old
			color_map_type:   .no_color_map
			color_map_length: 0
		},
		RasHeader{
			depth:            8
			type_:            .tiff
			width:            0
			height:           0
			length:           0
			color_map_type:   .no_color_map
			color_map_length: 0
		},
		RasHeader{
			depth:            8
			color_map_type:   .raw_color_map
			color_map_length: 1
			width:            0
			height:           0
			length:           0
			type_:            .old
		},
	] {
		mut reader := ReadStream.init_memory(ras_fixture(header, [], []))
		RAS.read_image(mut reader) or {
			assert err.msg() == 'Unsupported'
			continue
		}
		assert false
	}
	mut reader := ReadStream.init_memory('other data'.bytes())
	RAS.read_image(mut reader) or {
		assert err.msg() == 'InvalidData'
		assert reader.get_pos() == 0
		return
	}
	assert false
}
