module zigimg

import os

fn test_pam_file_header_preserves_pending_tail_and_caller_buffer() {
	path := os.join_path(os.temp_dir(), 'witty-pam-buffered-header-${os.getpid()}')
	defer { os.rm(path) or {} }
	for capacity in [8, 16] {
		os.write_file_array(path, []u8{len: 256, init: 165})!
		mut file := os.open_file(path, 'r+')!
		file.seek(256, .start)!
		mut buffer := []u8{len: capacity, init: 165}
		mut writer := WriteStream.init_file(file, mut buffer)
		mut image := ImageUnmanaged{
			pixels: Grayscale1Pixels{
				data: []
			}
			width:  0
			height: 0
		}
		if capacity == 16 {
			image = ImageUnmanaged{
				pixels: Grayscale8Pixels{
					data: [Grayscale8{ value: 19 }]
				}
				width:  1
				height: 1
			}
		}
		comments := if capacity == 8 { []string{} } else { ['one', 'two'] }
		PAM.write_frame(mut writer, image, PamEncoderOptions{ comments: comments })!
		expected := if capacity == 8 {
			'P7\nWIDTH 0\nHEIGHT 0\nDEPTH 1\nMAXVAL 1\nTUPLTYPE BLACKANDWHITE\nENDHDR\n'.bytes()
		} else {
			'P7\n#one\n#two\nWIDTH 1\nHEIGHT 1\nDEPTH 1\nMAXVAL 255\nTUPLTYPE GRAYSCALE\nENDHDR\n\x13'.bytes()
		}
		pending := if capacity == 8 { 8 } else { 9 }
		assert writer.get_pos() == u64(expected.len)
		assert writer.buffered() == expected[expected.len - pending..]
		assert buffer == if capacity == 8 {
			'\nENDHDR\n'.bytes()
		} else {
			'\nENDHDR\n\x13YPE AL '.bytes()
		}
		before := os.read_bytes(path)!
		assert before[..expected.len - pending] == expected[..expected.len - pending]
		assert before[expected.len - pending..] == []u8{len: 256 - expected.len + pending, init: 165}
		writer.flush()!
		assert writer.buffered().len == 0
		after := os.read_bytes(path)!
		assert after[..expected.len] == expected
		assert after[expected.len..] == []u8{len: 256 - expected.len, init: 165}
		file.close()
	}
}

fn pam_fixture(width uint, height uint, depth uint, maxval u16, tuple string, data []u8) []u8 {
	mut bytes := 'P7\nWIDTH ${width}\nHEIGHT ${height}\nDEPTH ${depth}\nMAXVAL ${maxval}\n'.bytes()
	if tuple != '' { bytes << 'TUPLTYPE ${tuple}\n'.bytes() }
	bytes << 'ENDHDR\n'.bytes()
	bytes << data
	return bytes
}

fn test_pam_header_comments_duplicates_whitespace_and_tuple_inference() {
	text := '\n#one\r\n\t \x0b\x0c\nWIDTH 9 ignored\nWIDTH 0__2\nHEIGHT\t1\r\n' +
		'DEPTH 3\nMAXVAL 3_1\n#two\nENDHDR ignored\n'
	mut reader := ReadStream.init_memory(text.bytes())
	header := PamHeader.read(mut reader)!
	assert header.width == 2 && header.height == 1 && header.depth == 3
	assert header.maxval == 31 && header.tuple_type == .rgb
	assert header.comments == ['one\r', 'two']
	mut output := []u8{len: 200}
	mut writer := WriteStream.init_memory(mut output)
	header.write(mut writer)!
	assert writer.buffered().bytestr() == 'P7\n#one\r\n#two\nWIDTH 2\nHEIGHT 1\nDEPTH 3\n' +
		'MAXVAL 31\nTUPLTYPE RGB\nENDHDR\n'
	for depth in [uint(1), uint(2), uint(3), uint(4)] {
		for maxval in [u16(1), u16(255), u16(256)] {
			mut stream := ReadStream.init_memory(pam_fixture(1, 1, depth, maxval, '', []))
			stream.take(3)!
			inferred := PamHeader.read(mut stream)!
			assert inferred.depth == depth && inferred.maxval == maxval
			assert inferred.has_two_bytes_per_component() == (maxval > 255)
			if maxval == 1 && depth <= 2 { assert inferred.get_pixel_format() == .grayscale1
			 }
		}
	}
}

fn test_pam_magic_and_short_trailing_bytes_preserve_source_consumption() {
	mut reader := ReadStream.init_memory('P7\n'.bytes())
	assert PAM.format_detect(mut reader)!
	assert reader.get_pos() == 0
	reader = ReadStream.init_memory('P7 332'.bytes())
	assert !PAM.format_detect(mut reader)!
	for ending in ['', 'x', 'xy'] {
		mut bytes := pam_fixture(1, 1, 1, 1, '', [u8(1)])
		consumed := bytes.len
		bytes << ending.bytes()
		reader = ReadStream.init_memory(bytes)
		images := PAM.read(mut reader)!
		assert images.len == 1 && images[0].raw_bytes() == [u8(1)]
		assert reader.get_pos() == u64(consumed)
	}
	for bytes in [[]u8{}, [u8(1)], [u8(1), 2]] {
		reader = ReadStream.init_memory(bytes)
		PAM.read_image(mut reader) or {
			assert err.msg() == 'InvalidData'
			assert reader.get_pos() == 0
			continue
		}
		assert false
	}
}

struct PamDecodeCase {
	depth  uint
	maxval u16
	tuple  string
	data   []u8
	format PixelFormat
	values []u16
}

fn test_pam_decodes_all_tuple_types_scaling_and_little_endian_samples() {
	cases := [
		PamDecodeCase{
			depth:  1
			maxval: 1
			data:   [u8(1)]
			format: .grayscale1
			values: [u16(1)]
		},
		PamDecodeCase{
			depth:  2
			maxval: 1
			data:   [u8(1), 0]
			format: .grayscale1
			values: [u16(0)]
		},
		PamDecodeCase{
			depth:  1
			maxval: 15
			data:   [u8(7)]
			format: .grayscale8
			values: [u16(119)]
		},
		PamDecodeCase{
			depth:  2
			maxval: 15
			data:   [u8(7), 15]
			format: .grayscale8_alpha
			values: [u16(119), 255]
		},
		PamDecodeCase{
			depth:  3
			maxval: 31
			tuple:  'RGB'
			data:   [u8(0), 15, 31]
			format: .rgb24
			values: [u16(0), 123, 255]
		},
		PamDecodeCase{
			depth:  4
			maxval: 15
			tuple:  'RGB_ALPHA'
			data:   [u8(1), 7, 15, 0]
			format: .rgba32
			values: [u16(17), 119, 255, 0]
		},
		PamDecodeCase{
			depth:  1
			maxval: 1000
			data:   [u8(0xf4), 1]
			format: .grayscale16
			values: [u16(32767)]
		},
		PamDecodeCase{
			depth:  2
			maxval: 1000
			data:   [u8(1), 0, 0xe8, 3]
			format: .grayscale16_alpha
			values: [u16(65), 65535]
		},
		PamDecodeCase{
			depth:  3
			maxval: 1000
			data:   [u8(0), 0, 0xf4, 1, 0xe8, 3]
			format: .rgb48
			values: [u16(0), 32767, 65535]
		},
		PamDecodeCase{
			depth:  4
			maxval: 65535
			data:   [u8(0x34), 0x12, 0x78, 0x56, 0xbc, 0x9a, 0xf0, 0xde]
			format: .rgba64
			values: [u16(0x1234), 0x5678, 0x9abc, 0xdef0]
		},
	]
	for item in cases {
		mut stream := ReadStream.init_memory(pam_fixture(1, 1, item.depth, item.maxval, item.tuple,
			item.data))
		image := PAM.read_image(mut stream)!
		assert image.pixel_format() == item.format
		mut values := []u16{}
		match image.pixels {
			Grayscale1Pixels {
				values << u16(image.pixels.data[0].value)
			}
			Grayscale8Pixels {
				values << u16(image.pixels.data[0].value)
			}
			Grayscale16Pixels {
				values << image.pixels.data[0].value
			}
			Grayscale8AlphaPixels {
				pixel := image.pixels.data[0]
				values << [u16(pixel.value), u16(pixel.alpha)]
			}
			Grayscale16AlphaPixels {
				pixel := image.pixels.data[0]
				values << [pixel.value, pixel.alpha]
			}
			Rgb24Pixels {
				pixel := image.pixels.data[0]
				values << [u16(pixel.r), u16(pixel.g), u16(pixel.b)]
			}
			Rgba32Pixels {
				pixel := image.pixels.data[0]
				values << [u16(pixel.r), u16(pixel.g), u16(pixel.b), u16(pixel.a)]
			}
			Rgb48Pixels {
				pixel := image.pixels.data[0]
				values << [pixel.r, pixel.g, pixel.b]
			}
			Rgba64Pixels {
				pixel := image.pixels.data[0]
				values << [pixel.r, pixel.g, pixel.b, pixel.a]
			}
			else {
				assert false
			}
		}

		assert values == item.values
	}
	mut reader := ReadStream.init_memory(pam_fixture(4, 1, 2, 1, 'BLACKANDWHITE_ALPHA', [
		u8(0),
		0,
		0,
		1,
		1,
		0,
		1,
		1,
	]))
	assert PAM.read_image(mut reader)!.raw_bytes() == [u8(0), 0, 0, 1]
}

fn test_pam_sequences_keep_only_subsequent_frames_and_compare_storage_tags() {
	mut bytes := pam_fixture(1, 1, 3, 255, '', [u8(1), 2, 3])
	bytes << pam_fixture(1, 1, 3, 15, '', [u8(1), 2, 3])
	mut reader := ReadStream.init_memory(bytes)
	image := PAM.read_image(mut reader)!
	assert image.raw_bytes() == [u8(1), 2, 3]
	assert image.animation.loop_count == -1
	assert image.animation.frames.len == 1
	assert image.animation.frames[0].duration == 0
	assert image.animation.frames[0].pixels.as_bytes() == [u8(17), 34, 51]
	for second in [pam_fixture(2, 1, 3, 255, '', [u8(1), 2, 3, 4, 5, 6]),
		pam_fixture(1, 1, 1, 255, '', [u8(1)]),
		pam_fixture(1, 1, 3, 256, '', [u8(1), 0, 2, 0, 3,
			0])] {
		mut sequence := pam_fixture(1, 1, 3, 255, '', [u8(1), 2, 3])
		sequence << second
		reader = ReadStream.init_memory(sequence)
		PAM.read_image(mut reader) or {
			assert err.msg() == 'Unsupported'
			assert reader.get_pos() == u64(sequence.len)
			continue
		}
		assert false
	}
}

struct PamWriteCase {
	pixels PixelStorage
	depth  uint
	maxval u16
	tuple  string
	data   []u8
}

fn test_pam_writers_emit_exact_headers_raw_compact_channels_and_little_endian_words() {
	cases := [
		PamWriteCase{
			pixels: Grayscale1Pixels{
				data: [Grayscale1{ value: 1 }]
			}
			depth:  1
			maxval: 1
			tuple:  'BLACKANDWHITE'
			data:   [u8(1)]
		},
		PamWriteCase{
			pixels: Grayscale4Pixels{
				data: [Grayscale4{ value: 7 }]
			}
			depth:  1
			maxval: 15
			tuple:  'GRAYSCALE'
			data:   [u8(7)]
		},
		PamWriteCase{
			pixels: Grayscale8Pixels{
				data: [Grayscale8{ value: 23 }]
			}
			depth:  1
			maxval: 255
			tuple:  'GRAYSCALE'
			data:   [u8(23)]
		},
		PamWriteCase{
			pixels: Grayscale16Pixels{
				data: [Grayscale16{ value: 0x1234 }]
			}
			depth:  1
			maxval: 65535
			tuple:  'GRAYSCALE'
			data:   [u8(0x34), 0x12]
		},
		PamWriteCase{
			pixels: Grayscale8AlphaPixels{
				data: [Grayscale8Alpha{ value: 23, alpha: 17 }]
			}
			depth:  2
			maxval: 255
			tuple:  'GRAYSCALE_ALPHA'
			data:   [u8(23), 17]
		},
		PamWriteCase{
			pixels: Grayscale16AlphaPixels{
				data: [Grayscale16Alpha{ value: 0x1234, alpha: 0x5678 }]
			}
			depth:  2
			maxval: 65535
			tuple:  'GRAYSCALE_ALPHA'
			data:   [u8(0x34), 0x12, 0x78, 0x56]
		},
		PamWriteCase{
			pixels: Rgb555Pixels{
				data: [Rgb555{ raw: (17 << 10) | (9 << 5) | 3 }]
			}
			depth:  3
			maxval: 31
			tuple:  'RGB'
			data:   [u8(17), 9, 3]
		},
		PamWriteCase{
			pixels: Bgr555Pixels{
				data: [Bgr555{ raw: 17 | (9 << 5) | (3 << 10) }]
			}
			depth:  3
			maxval: 31
			tuple:  'RGB'
			data:   [u8(17), 9, 3]
		},
		PamWriteCase{
			pixels: Rgb24Pixels{
				data: [Rgb24{ r: 1, g: 2, b: 3 }]
			}
			depth:  3
			maxval: 255
			tuple:  'RGB'
			data:   [u8(1), 2, 3]
		},
		PamWriteCase{
			pixels: Bgr24Pixels{
				data: [Bgr24{ r: 1, g: 2, b: 3 }]
			}
			depth:  3
			maxval: 255
			tuple:  'RGB'
			data:   [u8(1), 2, 3]
		},
		PamWriteCase{
			pixels: Rgba32Pixels{
				data: [Rgba32{ r: 1, g: 2, b: 3, a: 4 }]
			}
			depth:  4
			maxval: 255
			tuple:  'RGB_ALPHA'
			data:   [u8(1), 2, 3, 4]
		},
		PamWriteCase{
			pixels: Bgra32Pixels{
				data: [Bgra32{ r: 1, g: 2, b: 3, a: 4 }]
			}
			depth:  4
			maxval: 255
			tuple:  'RGB_ALPHA'
			data:   [u8(1), 2, 3, 4]
		},
		PamWriteCase{
			pixels: Rgb48Pixels{
				data: [Rgb48{ r: 0x1234, g: 0x5678, b: 0x9abc }]
			}
			depth:  3
			maxval: 65535
			tuple:  'RGB'
			data:   [u8(0x34), 0x12, 0x78, 0x56, 0xbc, 0x9a]
		},
		PamWriteCase{
			pixels: Rgba64Pixels{
				data: [Rgba64{ r: 0x1234, g: 0x5678, b: 0x9abc, a: 0xdef0 }]
			}
			depth:  4
			maxval: 65535
			tuple:  'RGB_ALPHA'
			data:   [u8(0x34), 0x12, 0x78, 0x56, 0xbc, 0x9a, 0xf0, 0xde]
		},
	]
	mut output := []u8{len: 1000}
	for item in cases {
		mut writer := WriteStream.init_memory(mut output)
		image := ImageUnmanaged{
			width:  1
			height: 1
			pixels: item.pixels
		}
		PAM.write_frame(mut writer, image, PamEncoderOptions{})!
		assert writer.buffered() == pam_fixture(1, 1, item.depth, item.maxval, item.tuple,
			item.data)
	}
	// Header.fromImage accepts grayscale2 even though writeFrame then traps.
	header := PamHeader.from_image(ImageUnmanaged{ pixels: Grayscale2Pixels{} })!
	assert header.depth == 1 && header.maxval == 3 && header.tuple_type == .gray
	for format in [PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
		.float32, .rgb332, .rgb565] {
		mut writer := WriteStream.init_memory(mut output)
		image := ImageUnmanaged.create(1, 1, format) or { ImageUnmanaged{} }
		PAM.write_frame(mut writer, image, PamEncoderOptions{}) or {
			assert err.msg() == 'Unsupported'
			assert writer.get_pos() == 0
			continue
		}
		assert false
	}
}

fn test_pam_animation_writer_keeps_user_comments_and_adds_duration_only_when_requested() {
	image := ImageUnmanaged{
		width:     1
		height:    1
		pixels:    Rgb24Pixels{
			data: [Rgb24{ r: 1, g: 2, b: 3 }]
		}
		animation: Animation{
			loop_count: 7
			frames:     [
				AnimationFrame{
					duration: 0.125
					pixels:   Rgb24Pixels{
						data: [Rgb24{ r: 4, g: 5, b: 6 }]
					}
				},
				AnimationFrame{
					duration: 2
					pixels:   Grayscale8Pixels{
						data: [Grayscale8{ value: 17 }]
					}
				},
			]
		}
	}
	mut output := []u8{len: 1000}
	for add_duration in [false, true] {
		mut writer := WriteStream.init_memory(mut output)
		options := PamEncoderOptions{
			comments:                ['note', '']
			add_duration_as_comment: add_duration
		}
		PAM.write_image(mut writer, image, options)!
		loop_comment := if add_duration { '#loop count: 7\n' } else { '' }
		first_duration := if add_duration { '#duration: 0.125\n' } else { '' }
		second_duration := if add_duration { '#duration: 2\n' } else { '' }
		expected :=
			'P7\n#note\n#\n${loop_comment}WIDTH 1\nHEIGHT 1\nDEPTH 3\nMAXVAL 255\nTUPLTYPE RGB\nENDHDR\n\x01\x02\x03' +
			'P7\n#note\n#\n${first_duration}WIDTH 1\nHEIGHT 1\nDEPTH 3\nMAXVAL 255\nTUPLTYPE RGB\nENDHDR\n\x04\x05\x06' +
			'P7\n#note\n#\n${second_duration}WIDTH 1\nHEIGHT 1\nDEPTH 1\nMAXVAL 255\nTUPLTYPE GRAYSCALE\nENDHDR\n\x11'
		assert writer.buffered() == expected.bytes()
		assert options.comments == ['note', '']
	}
}

struct PamErrorCase {
	bytes    []u8
	error    string
	position u64
}

fn test_pam_errors_preserve_header_raster_and_sequence_positions() {
	base := 'P7\nWIDTH 1\nHEIGHT 1\nDEPTH 1\nMAXVAL 255\n'
	cases := [
		PamErrorCase{
			bytes:    'bad'.bytes()
			error:    'InvalidData'
			position: 3
		},
		PamErrorCase{
			bytes:    '${base}ENDHDR'.bytes()
			error:    'EndOfStream'
			position: u64(base.len + 6)
		},
		PamErrorCase{
			bytes:    '${base}ENDHDR\n'.bytes()
			error:    'EndOfStream'
			position: u64(base.len + 7)
		},
		PamErrorCase{
			bytes:    '${base}TUPLTYPE GRAYSCALE \n'.bytes()
			error:    'Unsupported'
			position: u64(base.len + 20)
		},
		PamErrorCase{
			bytes:    '${base}TUPLTYPE GRAYSCALE\r\n'.bytes()
			error:    'Unsupported'
			position: u64(base.len + 20)
		},
		PamErrorCase{
			bytes:    '${base} #note\n'.bytes()
			error:    'InvalidData'
			position: u64(base.len + 7)
		},
		PamErrorCase{
			bytes:    '${base}LONGTOKEN 1\n'.bytes()
			error:    'InvalidData'
			position: u64(base.len + 12)
		},
		PamErrorCase{
			bytes:    '${base}WIDTH +1\n'.bytes()
			error:    'InvalidData'
			position: u64(base.len + 9)
		},
		PamErrorCase{
			bytes:    '${base}WIDTH -0\n'.bytes()
			error:    'InvalidData'
			position: u64(base.len + 9)
		},
		PamErrorCase{
			bytes:    '${base}MAXVAL 65536\n'.bytes()
			error:    'InvalidData'
			position: u64(base.len + 13)
		},
		PamErrorCase{
			bytes:    '${base}MAXVAL 0\nENDHDR\n'.bytes()
			error:    'InvalidData'
			position: u64(base.len + 16)
		},
		PamErrorCase{
			bytes:    '${base}DEPTH 5\nENDHDR\n'.bytes()
			error:    'Unsupported'
			position: u64(base.len + 15)
		},
		PamErrorCase{
			bytes:    '${base}TUPLTYPE RGB\nENDHDR\n'.bytes()
			error:    'InvalidData'
			position: u64(base.len + 20)
		},
		PamErrorCase{
			bytes:    pam_fixture(1, 1, 1, 15, '', [u8(16)])
			error:    'InvalidData'
			position: 46
		},
		PamErrorCase{
			bytes:    pam_fixture(1, 1, 2, 1, '', [u8(0), 2])
			error:    'InvalidData'
			position: 46
		},
		PamErrorCase{
			bytes:    pam_fixture(1, 1, 1, 1000, '', [u8(1)])
			error:    'EndOfStream'
			position: 47
		},
	]
	for item in cases {
		mut reader := ReadStream.init_memory(item.bytes)
		PAM.read_image(mut reader) or {
			assert err.msg() == item.error
			assert reader.get_pos() == item.position, item.bytes.bytestr()
			continue
		}
		assert false
	}
	mut bytes := pam_fixture(1, 1, 1, 255, '', [u8(1)])
	consumed := bytes.len
	bytes << 'bad'.bytes()
	mut reader := ReadStream.init_memory(bytes)
	PAM.read_image(mut reader) or {
		assert err.msg() == 'InvalidData'
		assert reader.get_pos() == u64(consumed + 3)
	}
	image := ImageUnmanaged{
		width:  1
		height: 1
		pixels: Grayscale16Pixels{
			data: [Grayscale16{ value: 0x1234 }]
		}
	}
	for length in [0, 1, 5, 68] {
		mut output := []u8{len: length}
		mut writer := WriteStream.init_memory(mut output)
		PAM.write_image(mut writer, image, PamEncoderOptions{}) or {
			assert err.msg() == 'WriteFailed'
			assert writer.get_pos() == u64(length)
			assert writer.buffered() == pam_fixture(1, 1, 1, 65535, 'GRAYSCALE', [
				u8(0x34),
				0x12,
			])[..length]
			continue
		}
		assert false
	}
}

fn test_pam_duration_comments_preserve_decimal_notation_special_values_and_sign_bits() {
	words := [u32(0), u32(0x80000000), u32(0x3e000000), u32(0x40000000), u32(0x3dcccccd), u32(1),
		u32(0x7f7fffff), u32(0x7f800000), u32(0xff800000), u32(0x7fc00000), u32(0xffc00000)]
	expected := ['0', '-0', '0.125', '2', '0.1', '0.000000000000000000000000000000000000000000001',
		'340282350000000000000000000000000000000', 'inf', '-inf', 'nan', '-nan']
	for i, word in words {
		value := unsafe { *(&f32(&word)) }
		assert pam_format_duration(value) == expected[i]
	}
}

fn pam_duration_hash_add(hash u64, word u32) u64 {
	value := unsafe { *(&f32(&word)) }
	mut result := hash
	for byte in pam_format_duration(value).bytes() {
		result = (result ^ byte) * u64(0x100000001b3)
	}
	return (result ^ u8(`\n`)) * u64(0x100000001b3)
}

fn test_pam_duration_formatter_matches_native_reference_across_exponents_and_bit_patterns() {
	mut hash := u64(0xcbf29ce484222325)
	for exponent in 0 .. 256 {
		for mantissa in [u32(0), u32(1), u32(2), u32(0x3fffff), u32(0x400000), u32(0x7ffffe),
			u32(0x7fffff)] {
			bits := u32(exponent) << 23 | mantissa
			hash = pam_duration_hash_add(hash, bits)
			hash = pam_duration_hash_add(hash, bits | u32(0x80000000))
		}
	}
	mut state := u32(0x12345678)
	for _ in 0 .. 16384 {
		state = u32(u64(state) * 1664525 + 1013904223)
		hash = pam_duration_hash_add(hash, state)
	}
	// Generated independently by Zig 0.15.2 std.fmt in verify_pam_reference.zig.
	assert hash == u64(0x721aeceda8f4ab7d)
}
