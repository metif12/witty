module zigimg

import os

fn tga_test_header(kind u8, depth u8, width u16, height u16, descriptor u8) TGAHeader {
	return TGAHeader{
		image_type: TGAImageType{
			raw: kind
		}
		image_spec: TGAImageSpec{
			width:         width
			height:        height
			bit_per_pixel: depth
			descriptor:    TGADescriptor{
				raw: descriptor
			}
		}
	}
}

fn tga_fixture(header TGAHeader, body []u8, extension ?TGAExtension) []u8 {
	mut bytes := tga_header_bytes(header)
	bytes << body
	mut footer := TGAFooter{}
	if value := extension {
		footer.extension_offset = u32(bytes.len)
		bytes << tga_extension_bytes(value)
	}
	for i, byte in tga_signature.bytes() {
		footer.signature[i] = byte
	}
	bytes << tga_footer_bytes(footer)
	return bytes
}

fn tga_expect_read_error(mut codec TGA, mut source ReadStream, message string, position u64) {
	if _ := codec.read(mut source) {
		assert false
	} else {
		assert err.msg() == message && source.get_pos() == position
	}
}

fn tga_expect_write_error(codec TGA, mut writer WriteStream, pixels PixelStorage, message string, position u64) {
	if _ := codec.write(mut writer, pixels) {
		assert false
	} else {
		assert err.msg() == message && writer.get_pos() == position
	}
}

fn test_tga_packed_records_flags_and_extension_bytes() {
	assert sizeof(TGAImageType) == 1 && sizeof(TGADescriptor) == 1
	assert sizeof(TGAColorMapSpec) == 5 && sizeof(TGAImageSpec) == 10
	assert sizeof(TGAHeader) == 18 && sizeof(TGAFooter) == 26
	assert sizeof(TGAExtension) == 495 && sizeof(TGAExtensionComment) == 324
	for raw in 0 .. 256 {
		flags := TGAImageType{
			raw: u8(raw)
		}
		assert flags.indexed() == (raw & 1 != 0) && flags.truecolor() == (raw & 2 != 0)
		assert flags.pad0() == (raw & 4 != 0) && flags.run_length() == (raw & 8 != 0)
		assert flags.pad1() == u8(raw >> 4)
		desc := TGADescriptor{
			raw: u8(raw)
		}
		assert desc.num_attributes_bit() == u8(raw & 15)
		assert desc.right_to_left() == (raw & 16 != 0) && desc.top_to_bottom() == (raw & 32 != 0)
		assert desc.pad() == u8(raw >> 6)
	}
	mut extension := TGAExtension{
		extension_size:          123
		timestamp:               TGAExtensionTimestamp{
			month:  1
			day:    2
			year:   2003
			hour:   4
			minute: 5
			second: 6
		}
		job_time:                TGAExtensionJobTime{
			hours:   100
			minutes: 11
			seconds: 12
		}
		software_version:        TGAExtensionSoftwareVersion{
			number: 321
			letter: `b`
		}
		key_color:               Bgra32{
			b: 1
			g: 2
			r: 3
			a: 4
		}
		pixel_aspect:            TGAExtensionRatio{
			numerator:   5
			denominator: 6
		}
		gamma_value:             TGAExtensionRatio{
			numerator:   7
			denominator: 8
		}
		color_correction_offset: 0x12345678
		postage_stamp_offset:    0x89abcdef
		scanline_offset:         0x76543210
		attributes:              .premultipled_alpha
	}
	for i in 0 .. 40 {
		extension.author_name[i] = u8(i + 1)
		extension.job_id[i] = u8(i + 2)
		extension.software_id[i] = u8(i + 3)
	}
	for row in 0 .. 4 {
		for col in 0 .. 80 {
			extension.author_comment.lines[row][col] = u8(row * 81 + col)
		}
	}
	bytes := tga_extension_bytes(extension)
	assert bytes.len == 495 && bytes[367..379] == [u8(1), 0, 2, 0, 0xd3, 7, 4, 0, 5, 0, 6, 0]
	assert bytes[467..] == [u8(0x41), 1, `b`, 1, 2, 3, 4, 5, 0, 6, 0, 7, 0, 8, 0, 0x78, 0x56, 0x34,
		0x12, 0xef, 0xcd, 0xab, 0x89, 0x10, 0x32, 0x54, 0x76, 4]
	assert tga_extension_read(bytes) == extension
	defaults := tga_extension_bytes(TGAExtension{})
	assert defaults[..2] == [u8(0xef), 1] && defaults[469] == ` ` && defaults[473] == 0
}

fn test_tga_detection_strict_lengths_signature_and_reset() {
	for length in [0, 18, 19, 26, 27] {
		mut bytes := []u8{len: length}
		mut source := ReadStream.init_memory(bytes)
		if length > 1 { source.seek_to(1)! }
		assert TGA.format_detect(mut source)! == (length > 18)
		assert source.get_pos() == 0
	}
	mut bytes := tga_fixture(tga_test_header(0xf0, 7, 0, 0, 0), []u8{}, none)
	mut source := ReadStream.init_memory(bytes)
	assert TGA.format_detect(mut source)! // Valid footer ignores invalid header.
	bytes[bytes.len - 2] = 0
	source = ReadStream.init_memory(bytes)
	assert !TGA.format_detect(mut source)! && source.get_pos() == 0
	for depth in [u8(0), 15, 16, 24, 32, 7] {
		mut header := TGAHeader{}
		header.color_map_spec.bit_depth = depth
		assert header.is_valid() == (depth != 7)
	}
}

fn test_tga_raw_rows_channels_ids_and_ignored_descriptor_fields() {
	mut header :=
		tga_test_header(2, 24, 2, 2, 0xdf) // Right-to-left and reserved descriptor bits are ignored.
	header.id_length = 3
	header.image_spec.origin_x = 77
	header.image_spec.origin_y = 88
	body := [u8(`i`), `d`, `!`, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	mut source := ReadStream.init_memory(tga_fixture(header, body, none))
	mut codec := TGA{}
	pixels := codec.read(mut source)!
	assert pixels.pixel_format() == .bgr24
	assert pixels.as_bytes() == [u8(7), 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6]
	assert codec.id.data == 'id!'.bytes() && codec.header == header
	assert source.get_pos() == 33 && codec.width() == 2 && codec.height() == 2
	header = tga_test_header(3, 200, 2, 2, 32) // Grayscale format ignores bpp.
	source = ReadStream.init_memory(tga_fixture(header, [u8(1), 2, 3, 4], none))
	gray := codec.read(mut source)!
	assert gray.as_bytes() == [u8(1), 2, 3, 4] && codec.id.data == 'id!'.bytes()
	source = ReadStream.init_memory(tga_fixture(tga_test_header(2, 16, 2, 1, 32), [
		u8(0xff),
		0xff,
		0x43,
		0xa5,
	], none))
	rgb := codec.read(mut source)!
	assert rgb.as_bytes() == [u8(0xff), 0x7f, 0x43, 0x25]
	mut short := tga_header_bytes(tga_test_header(3, 8, 8, 1, 32))
	short << [u8(1), 2, 3, 4, 5, 6, 7, 8]
	source = ReadStream.init_memory(short)
	assert codec.read(mut source)!.as_bytes() == [u8(1), 2, 3, 4, 5, 6, 7, 8] // No footer signature is needed.
}

fn test_tga_palette_depths_has_map_flag_and_alpha_extension_policy() {
	for depth in [u8(15), 16, 24] {
		mut header := tga_test_header(1, 8, 2, 1, 32)
		header.color_map_spec = TGAColorMapSpec{
			length:    2
			bit_depth: depth
		}
		body := if depth == 24 { [u8(3), 2, 1, 6, 5, 4, 1, 0] } else { [u8(0x23), 0xc5, 0xff, 0x7f,
				1, 0] }
		mut source := ReadStream.init_memory(tga_fixture(header, body, none))
		mut codec := TGA{}
		pixels := codec.read(mut source)!
		match pixels {
			IndexedStorage8 {
				assert pixels.indices == [u8(1), 0] && pixels.palette.len == 2
				if depth == 24 {
					assert pixels.palette[0] == Rgba32{
						r: 1
						g: 2
						b: 3
					}
				} else {
					assert pixels.palette[0] == Rgba32{
						r: 140
						g: 74
						b: 25
					} && pixels.palette[1] == Rgba32{
						r: 255
						g: 255
						b: 255
					}
				}
			}
			else {
				assert false
			}
		}
	}
	for attribute in [TGAAttributeType.no_alpha, .undefined_alpha_ignore, .undefined_alpha_retained,
		.useful_alpha_channel, .premultipled_alpha] {
		mut bytes := tga_fixture(tga_test_header(2, 32, 1, 1, 0), [u8(1), 2, 3, 4], TGAExtension{
			attributes:     attribute
			extension_size: 1
		})
		bytes[bytes.len - 2] = 0 // read ignores dot/null unlike format_detect.
		bytes[bytes.len - 1] = 7
		mut source := ReadStream.init_memory(bytes)
		mut codec := TGA{}
		pixels := codec.read(mut source)!
		assert pixels.as_bytes() == [u8(1), 2, 3, if attribute == .useful_alpha_channel {
			u8(4)
		} else {
			u8(255)
		}]
		assert codec.extension?.extension_size == 1 && source.get_pos() == 22
	}
	mut source := ReadStream.init_memory(tga_fixture(tga_test_header(2, 32, 1, 1, 0), [
		u8(1),
		2,
		3,
		4,
	], none))
	mut codec := TGA{}
	assert codec.read(mut source)!.as_bytes() == [u8(1), 2, 3, 4]
	codec.extension = TGAExtension{}
	source = ReadStream.init_memory(tga_fixture(tga_test_header(2, 32, 1, 1, 0), [
		u8(1),
		2,
		3,
		4,
	], none))
	assert codec.read(mut source)!.as_bytes() == [u8(1), 2, 3, 255] // Reusing a codec retains its old extension.
}

fn test_tga_rle_read_ahead_raw_repeat_partial_and_zero_width() {
	for bpp in [1, 2, 3, 4] {
		mut body := []u8{}
		for packet in 0 .. 8 {
			body << u8(0xff)
			for channel in 0 .. bpp {
				body << u8(packet * 8 + channel)
			}
		}
		header := tga_test_header(if bpp == 1 { u8(11) } else { u8(10) }, u8(bpp * 8), 200, 1, 32)
		mut source := ReadStream.init_memory(tga_fixture(header, body, none))
		mut codec := TGA{}
		pixels := codec.read(mut source)!
		mut expected := []u8{}
		for pixel in 0 .. 200 {
			for channel in 0 .. bpp {
				expected << u8((pixel / 128) * 8 + channel)
			}
		}
		assert pixels.as_bytes() == expected
		packets := if bpp == 1 {
			4
		} else if bpp == 2 {
			2
		} else if bpp == 3 {
			3
		} else {
			2
		}
		assert source.get_pos() == u64(18 + packets * (1 + bpp))
	}
	// Exact raw packet leaves data buffered but read-ahead reaches EOF while
	// requesting the next header: the stream's whole write is then uncommitted.
	mut source := ReadStream.init_memory(tga_header_bytes(tga_test_header(11, 8, 1, 1, 32)))
	mut bytes := source.buffer.clone()
	bytes << [u8(0x87), 9]
	bytes << []u8{len: 8, init: u8(0x80)}
	source = ReadStream.init_memory(bytes)
	mut codec := TGA{}
	tga_expect_read_error(mut codec, mut source, 'EndOfStream', 28)
	// Undersized raw packet returns its prefix successfully, without trying
	// another packet; the small image can therefore succeed at source EOF.
	bytes = tga_header_bytes(tga_test_header(11, 8, 1, 1, 32))
	bytes << u8(127)
	bytes << []u8{len: 7, init: u8(9)}
	source = ReadStream.init_memory(bytes)
	assert codec.read(mut source)!.as_bytes() == [u8(9)] && source.get_pos() == 26
	// Both empty dimensions allocate but consume no compressed pixel packets.
	source = ReadStream.init_memory(tga_fixture(tga_test_header(11, 8, 0, 1, 0), []u8{}, none))
	assert codec.read(mut source)!.len() == 0 && source.get_pos() == 18
}

fn test_tga_exact_encoding_formats_orientation_and_metadata() {
	for format in [PixelFormat.grayscale8, .indexed8, .rgb555, .rgb24, .bgr24, .rgba32, .bgra32] {
		mut pixels := PixelStorage.init(format, 4)!
		mut raw := pixels.as_bytes()
		for i in 0 .. raw.len {
			raw[i] = u8(i + 1)
		}
		match mut pixels {
			IndexedStorage8 {
				pixels.resize_palette(2)
				pixels.palette[0] = Rgba32{
					r: 1
					g: 2
					b: 3
				}
				pixels.palette[1] = Rgba32{
					r: 4
					g: 5
					b: 6
				}
			}
			else {}
		}

		for top in [true, false] {
			mut output := []u8{len: 2000}
			mut writer := WriteStream.init_memory(mut output)
			image := ImageUnmanaged{
				width:  2
				height: 2
				pixels: pixels
			}
			TGA.write_image(mut writer, image, TgaEncoderOptions{
				rle_compressed:      false
				top_to_bottom_image: top
				image_id:            'ID'.bytes()
				author_name:         'author'
				job_id:              'job'
				software_id:         'V'
				timestamp:           TGAExtensionTimestamp{
					year: 2026
				}
			})!
			bytes := writer.buffered()
			stride := int(format.pixel_stride())
			palette_size := if format == .indexed8 { 6 } else { 0 }
			assert bytes[0] == 2 && bytes[17] & 32 != 0 == top && bytes[18..20] == 'ID'.bytes()
			mut expected := []u8{}
			for y in 0 .. 2 {
				row := if top { y } else { 1 - y }
				for x in 0 .. 2 {
					i := (row * 2 + x) * stride
					if format in [PixelFormat.rgb24, .rgba32] {
						expected << [raw[i + 2], raw[i + 1], raw[i]]
						if stride == 4 { expected << raw[i + 3] }
					} else {
						expected << raw[i..i + stride]
					}
				}
			}
			assert bytes[20 + palette_size..20 + palette_size + expected.len] == expected
			ext_pos := bytes.len - 521
			assert tga_u32(bytes, bytes.len - 26) == u32(ext_pos)
			assert bytes[ext_pos + 2..ext_pos + 8] == 'author'.bytes()
			assert tga_u16(bytes, ext_pos + 371) == 2026
			assert bytes[ext_pos + 494] == if format in [PixelFormat.rgba32, .bgra32] {
				u8(3)
			} else {
				u8(0)
			}
			assert bytes[bytes.len - 18..bytes.len - 2] == tga_signature.bytes()
		}
	}
}

fn test_tga_rle_encoding_vector_tails_scanlines_and_cross_row_runs() {
	mut output := []u8{len: 4000}
	for vector_length in [4, 8, 16, 32] {
		data := [u8(1), 1, 1, 1, 1, 1, 1, 1, 1, 64, 64, 2, 2, 2, 2, 2, 215, 215, 215, 3, 3, 3,
			3, 3, 3, 3, 3, 3, 3, 200, 200, 200, 200, 210, 210]
		mut writer := WriteStream.init_memory(mut output)
		tga_rle_simd(data, 1, vector_length, mut writer)!
		assert writer.buffered() == [u8(0x88), 1, 0x81, 64, 0x84, 2, 0x82, 215, 0x89, 3, 0x83,
			200, 0x81, 210]
	}
	mut writer := WriteStream.init_memory(mut output)
	tga_rle_simd([]u8{len: 17, init: u8(7)}, 1, 16, mut writer)!
	assert writer.buffered() == [u8(0x8f), 7, 0, 7] // Tail starts a fresh run.
	writer = WriteStream.init_memory(mut output)
	tga_rle_simple([]u8{len: 129, init: u8(7)}, 1, mut writer)!
	assert writer.buffered() == [u8(0xff), 7, 0, 7]
	for format in [PixelFormat.rgb24, .bgr24, .rgba32, .bgra32] {
		mut pixels := PixelStorage.init(format, 4)!
		mut bytes := pixels.as_bytes()
		for i in 0 .. bytes.len {
			bytes[i] = 7
		}
		writer = WriteStream.init_memory(mut output)
		TGA.write_image(mut writer, ImageUnmanaged{ width: 2, height: 2, pixels: pixels }, TgaEncoderOptions{})!
		stride := int(format.pixel_stride())
		encoded := writer.buffered()[18..writer.buffered().len - 521]
		mut expected := [u8(0x83)]
		expected << []u8{len: stride, init: u8(7)}
		if format in [PixelFormat.bgr24, .bgra32] {
			expected[0] = 0x81
			expected << u8(0x81)
			expected << []u8{len: stride, init: u8(7)}
		}
		assert encoded == expected
	}
}

fn test_tga_errors_partial_read_write_positions_and_option_bounds() {
	for length in [0, 18, 25] {
		mut source := ReadStream.init_memory([]u8{len: length})
		mut codec := TGA{}
		codec.read(mut source) or {
			assert err.msg() == 'InvalidData' && source.get_pos() == 0
			continue
		}
		assert false
	}
	mut header := tga_test_header(2, 24, 0, 0, 0)
	header.id_length = 20
	mut bytes := tga_header_bytes(header)
	bytes << []u8{len: 8, init: u8(77)}
	mut source := ReadStream.init_memory(bytes)
	mut codec := TGA{}
	tga_expect_read_error(mut codec, mut source, 'InvalidData', 26)
	assert codec.id.data[..8] == []u8{len: 8, init: u8(77)}
	// Atomic 16-bit reads retain their final lone byte. Channel reads consume
	// individually before EOF. These are 1.0 inputs without an actual footer.
	for depth in [u8(8), 16, 24, 32] {
		kind := if depth == 8 { u8(3) } else { u8(2) }
		width := if depth == 8 {
			u16(10)
		} else if depth == 16 {
			u16(5)
		} else {
			u16(3)
		}
		bytes = tga_header_bytes(tga_test_header(kind, depth, width, 1, 32))
		bytes << []u8{len: if depth == 16 { 9 } else { 8 }, init: u8(7)}
		source = ReadStream.init_memory(bytes)
		tga_expect_read_error(mut codec, mut source, 'EndOfStream', 26)
	}
	bytes = tga_fixture(tga_test_header(2, 24, 0, 0, 0), []u8{}, none)
	bytes[bytes.len - 26] = 250
	source = ReadStream.init_memory(bytes)
	tga_expect_read_error(mut codec, mut source, 'Unseekable', u64(bytes.len))
	bytes[bytes.len - 26] = 1
	source = ReadStream.init_memory(bytes)
	tga_expect_read_error(mut codec, mut source, 'EndOfStream', 1)
	for kind in [u8(0), 4, 0x10] {
		source =
			ReadStream.init_memory(tga_fixture(tga_test_header(kind, 8, 0, 0, 0), []u8{}, none))
		codec.read(mut source) or {
			assert err.msg() == if kind == 0 {
				'Unsupported'
			} else {
				'InvalidData'
			}
			assert source.get_pos() == 18
			continue
		}
		assert false
	}
	mut pixels := PixelStorage.init(.grayscale8, 1)!
	mut output := []u8{len: 1000}
	image := ImageUnmanaged{
		width:  1
		height: 1
		pixels: pixels
	}
	for id_len in [255, 256, 257] {
		mut writer := WriteStream.init_memory(mut output)
		TGA.write_image(mut writer, image, TgaEncoderOptions{
			rle_compressed: false
			image_id:       []u8{len: id_len, init: u8(8)}
		}) or {
			assert id_len == 257 && err.msg() == 'Unsupported' && writer.get_pos() == 0
			continue
		}
		assert writer.buffered()[0] == u8(id_len)
		assert writer.get_pos() == u64(540 + if id_len == 255 {
			255
		} else {
			0
		})
	}
	for options in [TgaEncoderOptions{ color_map_depth: 15 },
		TgaEncoderOptions{ author_name: 'a'.repeat(40) }, TgaEncoderOptions{ job_id: 'j'.repeat(40) },
		TgaEncoderOptions{ software_id: 's'.repeat(40) }] {
		mut writer := WriteStream.init_memory(mut output)
		TGA.write_image(mut writer, image, options) or {
			assert err.msg() == 'Unsupported' && writer.get_pos() == 0
			continue
		}
		assert false
	}
	mut writer := WriteStream.init_memory(mut output)
	TGA.write_image(mut writer, image, TgaEncoderOptions{ rle_compressed: false })!
	complete := writer.buffered().clone()
	for length in [0, 17, 18, 19, 50, 539] {
		mut short := []u8{len: length}
		mut limited := WriteStream.init_memory(mut short)
		TGA.write_image(mut limited, image, TgaEncoderOptions{ rle_compressed: false }) or {
			assert err.msg() == 'WriteFailed' && limited.get_pos() == u64(length)
			assert limited.buffered() == complete[..length]
			continue
		}
		assert false
	}
	writer = WriteStream.init_memory(mut output)
	codec = TGA{
		header: TGAHeader{
			id_length: 1
		}
	}
	tga_expect_write_error(codec, mut writer, pixels, 'Unsupported', 18)
	// Raw top-to-bottom writes the entire supplied storage, despite dimensions.
	codec = TGA{
		header: tga_test_header(3, 8, 0, 0, 32)
	}
	writer = WriteStream.init_memory(mut output)
	codec.write(mut writer, pixels)!
	assert writer.get_pos() == 45
	writer = WriteStream.init_memory(mut output)
	TGA.write_image(mut writer, image, TgaEncoderOptions{
		rle_compressed: false
		author_name:    'a'.repeat(39)
	})!
	source = ReadStream.init_memory(writer.buffered())
	decoded := TGA.read_image(mut source)!
	assert decoded.width == 1 && decoded.height == 1
		&& decoded.pixels.as_bytes() == pixels.as_bytes()
}

fn test_tga_encoder_hash_matches_unchanged_locked_source() {
	mut hash := u64(14695981039346656037)
	mut cases := 0
	mut output := []u8{len: 20000}
	for format in [PixelFormat.grayscale8, .indexed8, .rgb555, .rgb24, .bgr24, .rgba32, .bgra32] {
		for width in [0, 1, 2, 3, 4, 7, 8, 9, 15, 16, 17, 31, 32, 33, 127, 128, 129, 255] {
			mut pixels := PixelStorage.init(format, usize(width * 3))!
			match mut pixels {
				IndexedStorage8 {
					pixels.resize_palette(32)
					for i in 0 .. 32 {
						pixels.palette[i] = Rgba32{
							r: u8(i * 7)
							g: u8(i * 11)
							b: u8(i * 13)
							a: u8(i * 3)
						}
					}
				}
				else {}
			}

			stride := int(format.pixel_stride())
			for pattern in 0 .. 4 {
				mut raw := pixels.as_bytes()
				for i in 0 .. raw.len {
					pixel := i / stride
					channel := i % stride
					value := match pattern {
						0 { 7 }
						1 { pixel / 17 }
						2 { pixel * 13 }
						else { pixel / 16 * 3 }
					}

					raw[i] = u8((value + channel * 5) % if format == .indexed8 { 32 } else { 256 })
					if format == .rgb555 && channel == 1 { raw[i] &= 127 }
				}
				for compressed in [true, false] {
					for top in [true, false] {
						mut writer := WriteStream.init_memory(mut output)
						image := ImageUnmanaged{
							width:  usize(width)
							height: 3
							pixels: pixels
						}
						TGA.write_image(mut writer, image, TgaEncoderOptions{
							rle_compressed:      compressed
							top_to_bottom_image: top
							color_map_depth:     if pattern % 2 == 0 { u8(24) } else { u8(16) }
							image_id:            'ID!'.bytes()
							author_name:         'author'
							job_id:              'job'
							software_id:         'V'
							timestamp:           TGAExtensionTimestamp{
								year: 2026
							}
							software_version:    TGAExtensionSoftwareVersion{
								number: 123
								letter: `b`
							}
						})!
						for byte in writer.buffered() {
							hash ^= byte
							hash *= 1099511628211
						}
						cases++
					}
				}
			}
		}
	}
	assert cases == 2016
	assert hash == u64(0x44cd8ebeb8f84afc)
}

fn test_tga_decoder_hash_matches_unchanged_locked_source() {
	mut hash := u64(14695981039346656037)
	mut cases := 0
	for format in [PixelFormat.grayscale8, .indexed8, .rgb555, .bgr24, .bgra32] {
		bpp := int(format.pixel_stride())
		kind := if format == .grayscale8 {
			u8(3)
		} else if format == .indexed8 {
			u8(1)
		} else {
			u8(2)
		}
		for mode in 0 .. 4 {
			mut body := []u8{}
			if kind == 1 {
				for i in 0 .. 32 {
					body << [u8(i * 13), u8(i * 11), u8(i * 7)]
				}
			}
			for packet in 0 .. 16 {
				repeated := mode == 1 || (mode == 2 && packet % 2 == 1)
				if mode != 3 { body << if repeated { u8(255) } else { u8(127) }
				 }
				count := if repeated { 1 } else { 128 }
				for i in 0 .. count {
					for channel in 0 .. bpp {
						pixel := packet * 128 + i
						value := if repeated { packet * 3 } else { pixel / 17 }
						body << u8((value + channel * 5) % if kind == 1 { 32 } else { 256 })
					}
				}
			}
			for width in [0, 1, 2, 127, 128, 129, 171, 172, 255, 256, 257, 511, 512, 513] {
				for top in [true, false] {
					for extended in [true, false] {
						mut header := tga_test_header(kind | if mode == 3 { u8(0) } else { u8(8) },
							u8(bpp * 8), u16(width), 2, if top { u8(32) } else { u8(0) })
						if kind == 1 { header.color_map_spec = TGAColorMapSpec{
								length:    32
								bit_depth: 24
							} }
						mut extension := ?TGAExtension(none)
						if extended { extension = TGAExtension{} }
						mut source := ReadStream.init_memory(tga_fixture(header, body, extension))
						mut codec := TGA{}
						pixels := codec.read(mut source)!
						for i, byte in pixels.as_bytes() {
							hash ^= if bpp == 2 && i % 2 == 1 { byte & 127 } else { byte }
							hash *= 1099511628211
						}
						match pixels {
							IndexedStorage8 {
								for color in pixels.palette {
									for byte in [color.r, color.g, color.b, color.a] {
										hash ^= byte
										hash *= 1099511628211
									}
								}
							}
							else {}
						}

						mut position := source.get_pos()
						for _ in 0 .. 8 {
							hash ^= u8(position)
							hash *= 1099511628211
							position >>= 8
						}
						cases++
					}
				}
			}
		}
	}
	assert cases == 1120
	assert hash == u64(0x04232c58bcb7f905)
}

fn test_tga_indexed_palette_file_refills_match_defined_memory_pixels() {
	path := os.join_path(os.temp_dir(), 'witty-tga-indexed-${os.getpid()}')
	defer { os.rm(path) or {} }
	for depth in [u8(15), 16, 24] {
		mut header := tga_test_header(1, 8, 2, 1, 32)
		header.color_map_spec = TGAColorMapSpec{
			length:    2
			bit_depth: depth
		}
		body := if depth == 24 { [u8(3), 2, 1, 6, 5, 4, 1, 0] } else { [u8(0x23), 0xc5, 0xff, 0x7f,
				1, 0] }
		bytes := tga_fixture(header, body, none)
		os.write_file_array(path, bytes)!
		for capacity in [26, 27, 31, 64] {
			mut file := os.open(path)!
			mut buffer := []u8{len: capacity, init: 165}
			mut stream := ReadStream.init_file(file, mut buffer)
			mut codec := TGA{}
			pixels := codec.read(mut stream)!
			file.close()
			match pixels {
				IndexedStorage8 {
					assert pixels.indices == [u8(1), 0] && pixels.palette.len == 2
					if depth == 24 {
						assert pixels.palette == [Rgba32{ r: 1, g: 2, b: 3 },
							Rgba32{ r: 4, g: 5, b: 6 }]
					} else {
						assert pixels.palette == [Rgba32{ r: 140, g: 74, b: 25 },
							Rgba32{ r: 255, g: 255, b: 255 }]
					}
				}
				else {
					assert false
				}
			}

			assert codec.header == header && stream.get_pos() == usize(18 + body.len)
		}
	}
}
