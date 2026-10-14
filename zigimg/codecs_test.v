module zigimg

import os

fn test_binary_codecs_file_buffers_preserve_pixels_and_unread_qoi_marker() {
	path := os.join_path(os.temp_dir(), 'witty-binary-codecs-${os.getpid()}')
	defer { os.rm(path) or {} }
	for kind in 0 .. 2 {
		os.write_file_array(path, []u8{len: 256, init: 165})!
		mut file := os.open_file(path, 'r+')!
		file.seek(256, .start)!
		mut output := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file(file, mut output)
		mut expected := []u8{}
		if kind == 0 {
			image := ImageUnmanaged{
				width:  1
				height: 1
				pixels: Rgba64Pixels{
					data: [Rgba64{ r: 0x3813, g: 0x825d, b: 0xcca7, a: 0x16f1 }]
				}
			}
			Farbfeld.write_image(mut writer, image)!
			expected = 'farbfeld'.bytes()
			expected << [u8(0), 0, 0, 1, 0, 0, 0, 1, 0x38, 0x13, 0x82, 0x5d, 0xcc, 0xa7, 0x16,
				0xf1]
			assert output == expected[16..]
		} else {
			image := ImageUnmanaged{
				width:  1
				height: 1
				pixels: Rgba32Pixels{
					data: [Rgba32{ r: 19, g: 56, b: 93, a: 130 }]
				}
			}
			QOI.write_image(mut writer, image, QoiEncoderOptions{ colorspace: .linear })!
			expected = 'qoif'.bytes()
			expected << [u8(0), 0, 0, 1, 0, 0, 0, 1, 4, 1, 0xff, 19, 56, 93, 130, 0, 0, 0, 0, 0,
				0, 0, 1]
			assert output == [u8(0), 0, 0, 0, 0, 0, 0, 1]
		}
		assert writer.get_pos() == u64(expected.len)
		assert writer.buffered().len == 0
		bytes := os.read_bytes(path)!
		assert bytes[..expected.len] == expected
		assert bytes[expected.len..] == []u8{len: 256 - expected.len, init: 165}
		mut input := []u8{len: if kind == 0 { 8 } else { 10 }, init: 165}
		mut reader := ReadStream.init_file(file, mut input)
		if kind == 0 {
			image := Farbfeld.read_image(mut reader)!
			assert image.raw_bytes() == [u8(0x13), 0x38, 0x5d, 0x82, 0xa7, 0xcc, 0xf1, 0x16]
			assert reader.get_pos() == 24 && reader.buffered_len() == 0
		} else {
			image := QOI.read_image(mut reader)!
			assert image.raw_bytes() == [u8(19), 56, 93, 130]
			assert reader.get_pos() == 19 && reader.buffered_len() == 5
		}
		file.close()
	}
}

fn qoi_test_bytes(width u32, format u8, ops []u8) []u8 {
	mut bytes := 'qoif'.bytes()
	append_be_u32(mut bytes, width)
	append_be_u32(mut bytes, 1)
	bytes << [format, u8(0)]
	bytes << ops
	return bytes
}

fn test_qoi_decodes_all_operations_and_preserves_source_trailer_behavior() {
	assert sizeof(QoiHeader) == 10
	assert sizeof(QoiColor) == 4
	mut encoded := qoi_test_bytes(8, 4, [u8(0xfe), 10, 20, 30, 0x7f, 0xa2, 0x97, 0xff, 100, 150,
		200, 50, 0xc1, 9, 0])
	end := encoded.len
	encoded << [u8(0), 0, 0, 0, 0, 0, 0, 1]
	mut stream := ReadStream.init_memory(encoded)
	assert QOI.format_detect(mut stream)!
	assert stream.get_pos() == 0
	image := QOI.read_image(mut stream)!
	assert image.width == 8 && image.height == 1
	assert image.pixel_format() == .rgba32
	assert stream.get_pos() == u64(end) // Source reads no end marker.
	assert image.raw_bytes() == [u8(10), 20, 30, 255, 11, 21, 31, 255, 14, 23, 32, 255, 100, 150,
		200, 50, 100, 150, 200, 50, 100, 150, 200, 50, 10, 20, 30, 255, 0, 0, 0, 0]
}

fn test_qoi_exact_encoder_bytes_rgb_rgba_and_run_limit() {
	image := ImageUnmanaged{
		width:  8
		height: 1
		pixels: Rgba32Pixels{
			data: [
				Rgba32{
					r: 10
					g: 20
					b: 30
				},
				Rgba32{
					r: 11
					g: 21
					b: 31
				},
				Rgba32{
					r: 14
					g: 23
					b: 32
				},
				Rgba32{
					r: 100
					g: 150
					b: 200
					a: 50
				},
				Rgba32{
					r: 100
					g: 150
					b: 200
					a: 50
				},
				Rgba32{
					r: 100
					g: 150
					b: 200
					a: 50
				},
				Rgba32{
					r: 10
					g: 20
					b: 30
				},
				Rgba32{
					a: 0
				},
			]
		}
	}
	mut buffer := []u8{len: 100}
	mut writer := WriteStream.init_memory(mut buffer)
	QOI.write_image(mut writer, image, QoiEncoderOptions{})!
	mut expected := qoi_test_bytes(8, 4, [u8(0xfe), 10, 20, 30, 0x7f, 0xa2, 0x97, 0xff, 100, 150,
		200, 50, 0xc1, 9, 0])
	expected << [u8(0), 0, 0, 0, 0, 0, 0, 1]
	assert writer.buffered() == expected
	assert writer.buffered().data == buffer.data
	rgb := ImageUnmanaged{
		width:  63
		height: 1
		pixels: Rgb24Pixels{
			data: []Rgb24{len: 63}
		}
	}
	writer.seek_to(0)!
	QOI.write_image(mut writer, rgb, QoiEncoderOptions{ colorspace: .linear })!
	assert writer.buffered()[12..16] == [u8(3), 1, 0xfd, 0xc0]
}

fn test_qoi_wrapping_arithmetic_and_source_errors() {
	mut stream := ReadStream.init_memory(qoi_test_bytes(1, 3, [u8(0x40)]))
	image := QOI.read_image(mut stream)!
	assert image.raw_bytes() == [u8(254), 254, 254]
	for bytes, expected in {
		'':                                                  'EndOfStream'
		'nope':                                              'InvalidData'
		'qoif':                                              'InvalidData'
		qoi_test_bytes(1, 4, [u8(0xc1)]).bytestr():          'InvalidData'
		qoi_test_bytes(1, 4, [u8(0xff), 1, 2, 3]).bytestr(): 'EndOfStream'
	} {
		mut invalid := ReadStream.init_memory(bytes.bytes())
		QOI.read_image(mut invalid) or {
			assert err.msg() == expected
			continue
		}
		assert false
	}
}

fn test_farbfeld_big_endian_pixels_and_exact_encoding() {
	assert sizeof(FarbfeldHeader) == 8
	mut encoded := 'farbfeld'.bytes()
	append_be_u32(mut encoded, 2)
	append_be_u32(mut encoded, 1)
	encoded << [u8(0xff), 0xff, 0x12, 0x34, 0, 0x99, 0x80, 0, 0, 0, 0xff, 0xff, 0xbe, 0xef, 0,
		1]
	mut stream := ReadStream.init_memory(encoded)
	assert Farbfeld.format_detect(mut stream)!
	image := Farbfeld.read_image(mut stream)!
	assert image.width == 2 && image.height == 1
	if image.pixels is Rgba64Pixels {
		assert image.pixels.data == [
			Rgba64{
				r: 0xffff
				g: 0x1234
				b: 0x99
				a: 0x8000
			},
			Rgba64{
				g: 0xffff
				b: 0xbeef
				a: 1
			},
		]
	} else {
		assert false
	}
	mut buffer := []u8{len: encoded.len}
	mut writer := WriteStream.init_memory(mut buffer)
	Farbfeld.write_image(mut writer, image)!
	assert writer.buffered() == encoded
	for length in [0, 7, 8, 15, 16, encoded.len - 1] {
		mut truncated := ReadStream.init_memory(encoded[..length])
		Farbfeld.read_image(mut truncated) or {
			assert err.msg() == 'InvalidData'
			continue
		}
		assert false
	}
}

fn test_codec_output_failures_preserve_partial_fixed_buffer() {
	mut buffer := []u8{len: 3}
	mut writer := WriteStream.init_memory(mut buffer)
	codec := QOI{
		header: QoiHeader{
			width:      0
			height:     0
			format:     .rgb
			colorspace: .srgb
		}
	}
	codec.write(mut writer, Rgb24Pixels{}) or {
		assert err.msg() == 'WriteFailed'
		assert writer.get_pos() == 3
		assert buffer.bytestr() == 'qoi'
		return
	}
	assert false
}

fn test_memory_stream_seek_bounds_and_borrowing() {
	mut bytes := 'abcd'.bytes()
	mut reader := ReadStream.init_memory(bytes)
	assert reader.peek(2)!.data == bytes.data
	assert reader.take(2)!.bytestr() == 'ab'
	reader.seek_by(-1)!
	assert reader.get_pos() == 1
	reader.seek_to(4) or {
		assert err.msg() == 'Unseekable'
		assert reader.get_pos() == 1
		return
	}
	assert false
}
