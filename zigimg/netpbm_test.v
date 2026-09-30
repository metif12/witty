module zigimg

fn test_netpbm_format_detection_peeks_and_readers_accept_each_header() {
	for index, magic in ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'] {
		mut stream := ReadStream.init_memory(magic.bytes())
		assert PBM.format_detect(mut stream)! == (index % 3 == 0)
		assert PGM.format_detect(mut stream)! == (index % 3 == 1)
		assert PPM.format_detect(mut stream)! == (index % 3 == 2)
		assert stream.get_pos() == 0
	}
	mut stream := ReadStream.init_memory('P6\n1 1\n255\n\x0a\x14\x1e'.bytes())
	image := PBM.read_image(mut stream)!
	assert image.pixel_format() == .rgb24
	assert image.raw_bytes() == [u8(10), 20, 30]
}

fn test_netpbm_bitmap_polarity_row_padding_and_ascii_quirks() {
	mut reader := ReadStream.init_memory('P4\n10 2\n\xaa\x80\x55\x40'.bytes())
	image := PBM.read_image(mut reader)!
	assert image.width == 10 && image.height == 2
	assert image.raw_bytes() == [u8(0), 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
	assert reader.get_pos() == 12
	mut output := []u8{len: 100}
	mut writer := WriteStream.init_memory(mut output)
	PBM.write_image(mut writer, image, NetpbmEncoderOptions{})!
	assert writer.buffered().bytestr() == 'P4\n# Created by zigimg\n10 2\n\xaa\x80\x55\x40'
	writer.seek_to(0)!
	PBM.write_image(mut writer, image, NetpbmEncoderOptions{ binary: false })!
	assert writer.buffered().bytestr() == 'P1\n# Created by zigimg\n10 2\n10101010100101010101\n'
	reader = ReadStream.init_memory('P1\n5 1\n0#x1\n0'.bytes())
	ascii := PBM.read_image(mut reader)!
	assert ascii.raw_bytes() == [u8(1), 0, 0, 0, 1]
}

fn test_netpbm_ascii_and_binary_grayscale_preserve_source_scaling() {
	mut reader := ReadStream.init_memory('P2\n4 1\n15\n0 7 15 300\n'.bytes())
	ascii := PGM.read_image(mut reader)!
	assert ascii.raw_bytes() == [u8(0), 7, 15, 44]
	reader = ReadStream.init_memory('P5\n4 1\n15\n\x00\x07\x0f\x1e'.bytes())
	binary := PGM.read_image(mut reader)!
	assert binary.raw_bytes() == [u8(0), 119, 255, 254]
	reader = ReadStream.init_memory('P2\n3 1\n1000\n1 999 65537\n'.bytes())
	ascii16 := PGM.read_image(mut reader)!
	match ascii16.pixels {
		Grayscale16Pixels {
			assert ascii16.pixels.data == [Grayscale16{ value: 1 },
				Grayscale16{ value: 999 }, Grayscale16{ value: 1 }]
		}
		else {
			assert false
		}
	}

	reader = ReadStream.init_memory('P5\n2 1\n1000\n\x00\x01\x03\xe7'.bytes())
	binary16 := PGM.read_image(mut reader)!
	mut output := []u8{len: 100}
	mut writer := WriteStream.init_memory(mut output)
	PGM.write_image(mut writer, binary16, NetpbmEncoderOptions{})!
	assert writer.buffered().bytestr() == 'P5\n# Created by zigimg\n2 1\n65535\n\x00\x01\x03\xe7'
	writer.seek_to(0)!
	PGM.write_image(mut writer, binary16, NetpbmEncoderOptions{ binary: false })!
	assert writer.buffered().bytestr() == 'P2\n# Created by zigimg\n2 1\n65535\n1 999\n'
}

fn test_netpbm_rgb_16_bit_input_normalizes_into_rgb24() {
	mut reader := ReadStream.init_memory('P3\n2 1\n1000\n0 500 1000 1 999 65537\n'.bytes())
	ascii := PPM.read_image(mut reader)!
	assert ascii.raw_bytes() == [u8(0), 127, 255, 0, 254, 71]
	reader =
		ReadStream.init_memory('P6\n2 1\n1000\n\x00\x00\x01\xf4\x03\xe8\x00\x01\x03\xe7\xff\xff'.bytes())
	binary := PPM.read_image(mut reader)!
	assert binary.raw_bytes() == [u8(0), 127, 255, 0, 254, 71]
	mut output := []u8{len: 100}
	mut writer := WriteStream.init_memory(mut output)
	PPM.write_image(mut writer, binary, NetpbmEncoderOptions{})!
	assert writer.buffered().bytestr() == 'P6\n# Created by zigimg\n2 1\n255\n\x00\x7f\xff\x00\xfe\x47'
	writer.seek_to(0)!
	PPM.write_image(mut writer, binary, NetpbmEncoderOptions{ binary: false })!
	assert writer.buffered().bytestr() == 'P3\n# Created by zigimg\n2 1\n255\n0 127 255\n0 254 71\n'
}

fn test_netpbm_header_comments_signed_zero_underscores_and_single_delimiter() {
	mut reader := ReadStream.init_memory('P3 0# comment\n1 +0_1 +2_55 255 0 0\n'.bytes())
	image := PPM.read_image(mut reader)!
	assert image.width == 1 && image.height == 1
	assert image.raw_bytes() == [u8(255), 0, 0]
	reader = ReadStream.init_memory('P2 -0 +0 255\n'.bytes())
	empty := PGM.read_image(mut reader)!
	assert empty.width == 0 && empty.height == 0 && empty.raw_bytes().len == 0
	reader = ReadStream.init_memory('P5 1 1 255\r\n\xff'.bytes())
	binary := PGM.read_image(mut reader)!
	assert binary.raw_bytes() == [u8(10)]
	assert reader.take_byte()! == 255
}

fn test_netpbm_reports_source_eof_invalid_data_and_fixed_number_buffer_limit() {
	for input, expected in {
		'P':                              'EndOfStream'
		'P0 1 1\n':                       'InvalidData'
		'P2 1 1 255 123':                 'EndOfStream'
		'P2 -1 1 255 0\n':                'InvalidData'
		'P2 1_ 1 255 0\n':                'InvalidData'
		'P2 1 1 255 _1\n':                'InvalidData'
		'P2 1 1 255 00000000000000001\n': 'OutOfMemory'
		'P5 1 1 255\n':                   'EndOfStream'
	} {
		mut reader := ReadStream.init_memory(input.bytes())
		PGM.read_image(mut reader) or {
			assert err.msg() == expected
			continue
		}
		assert false
	}
	mut output := []u8{len: 8}
	mut writer := WriteStream.init_memory(mut output)
	image := ImageUnmanaged{
		width:  1
		height: 1
		pixels: Grayscale8Pixels{
			data: [Grayscale8{ value: 1 }]
		}
	}
	PBM.write_image(mut writer, image, NetpbmEncoderOptions{}) or {
		assert err.msg() == 'Unsupported'
		assert writer.get_pos() == 0
	}
	PGM.write_image(mut writer, image, NetpbmEncoderOptions{}) or {
		assert err.msg() == 'WriteFailed'
		assert writer.buffered().bytestr() == 'P5\n# Cre'
		return
	}
	assert false
}
