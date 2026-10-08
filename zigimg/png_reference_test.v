module zigimg

import hash.crc32

const png_reference_formats = [PixelFormat.indexed1, .indexed2, .indexed4, .indexed8, .grayscale1,
	.grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha, .grayscale16_alpha,
	.rgb24, .rgb48, .rgba32, .rgba64]!

fn png_reference_mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn png_reference_bytes(mut hash []u64, bytes []u8) {
	for byte in bytes {
		png_reference_mix(mut hash, byte)
	}
}

fn png_reference_header(format PixelFormat, width u32, height u32) !PngHeaderData {
	return PngHeaderData{
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:      width
		height:     height
		bit_depth:  format.bits_per_channel()
		color_type: PngColorType.from_pixel_format(format)!
	}
}

fn png_reference_pixels(format PixelFormat, count usize, seed int) !PixelStorage {
	pixels := PixelStorage.init(format, count)!
	mut bytes := pixels.as_bytes()
	depth := format.bits_per_channel()
	for index, mut byte in bytes {
		byte = u8(index * 37 + seed * 19 + index / 7)
		if depth < 8 { byte &= u8((u16(1) << depth) - 1) }
	}
	return pixels
}

fn png_reference_header_hash(mut hash []u64, bytes []u8) {
	mut stream := ReadStream.init_memory(bytes)
	mut failure := ''
	header := png_load_header(mut stream) or {
		failure = err.msg()
		PngHeaderData{
			width:              0
			height:             0
			bit_depth:          0
			color_type:         .grayscale
			compression_method: .deflate
			filter_method:      .adaptive
			interlace_method:   .none
		}
	}
	if failure == '' {
		png_reference_mix(mut hash, 0)
		for value in [u64(header.width), u64(header.height), u64(header.bit_depth),
			u64(header.color_type), u64(header.compression_method), u64(header.filter_method),
			u64(header.interlace_method)] {
			png_reference_mix(mut hash, value)
		}
	} else {
		png_reference_mix(mut hash, if failure == 'InvalidData' {
			u64(1)
		} else if failure == 'EndOfStream' {
			u64(2)
		} else {
			u64(3)
		})
	}
	png_reference_mix(mut hash, stream.get_pos())
}

fn test_png_native_header_matrix() {
	mut base := png_magic_header[..].clone()
	append_be_u32(mut base, 13)
	base << 'IHDR'.bytes()
	append_be_u32(mut base, 17)
	append_be_u32(mut base, 3)
	base << [u8(8), 6, 0, 0, 0]
	append_be_u32(mut base, crc32.sum(base[12..29]))
	mut hash := [u64(14695981039346656037)]
	for cut in 0 .. 34 {
		png_reference_header_hash(mut hash, base[..cut])
	}
	for position in 0 .. 33 {
		for value in 0 .. 256 {
			mut bytes := base.clone()
			bytes[position] = u8(value)
			if position >= 16 && position < 29 {
				crc := crc32.sum(bytes[12..29])
				for index in 0 .. 4 {
					bytes[29 + index] = u8(crc >> ((3 - index) * 8))
				}
			}
			png_reference_header_hash(mut hash, bytes)
		}
	}
	assert hash[0] == u64(0x8cb5945cdde99fe7)
}

fn test_png_native_filtering_matrix() {
	mut hash := [u64(14695981039346656037)]
	mut cases := 0
	for format in png_reference_formats {
		for width in [u32(1), 3, 9, 17] {
			for height in [u32(0), 1, 3] {
				for seed in 0 .. 8 {
					pixels := png_reference_pixels(format, usize(width * height), seed)!
					header := png_reference_header(format, width, height)!
					length := int((header.line_bytes() + 1) * height)
					for choice in 0 .. 6 {
						for capacity in [0, 1, if length > 0 {
							length - 1
						} else {
							0
						}, length, length + 5] {
							mut bytes := []u8{len: capacity, init: 0xa5}
							mut writer := WriteStream.init_memory(mut bytes)
							selected := if choice == 5 { PngFilterChoice(PngHeuristic{}) } else { PngFilterChoice(PngSpecified{
									filter: unsafe { PngFilterType(choice) }
								}) }
							mut failed := false
							png_filter(mut writer, pixels, selected, header) or {
								assert err.msg() == 'InvalidData'
								failed = true
							}
							png_reference_mix(mut hash, u64(failed))
							png_reference_mix(mut hash, writer.get_pos())
							png_reference_bytes(mut hash, bytes)
							cases++
						}
					}
				}
			}
		}
	}
	assert cases == 43200
	assert hash[0] == u64(0x809cede448778a71)
}

fn test_png_native_defilter_spread_through_full_source_reads() {
	mut hash := [u64(14695981039346656037)]
	mut cases := 0
	for format in png_reference_formats {
		for width in [u32(1), 9, 17] {
			for height in [u32(1), 3] {
				for seed in 0 .. 4 {
					for filter in 0 .. 5 {
						pixels := png_reference_pixels(format, usize(width * height), seed)!
						header := png_reference_header(format, width, height)!
						line_bytes := int(header.line_bytes())
						mut encoded := []u8{len: (line_bytes + 1) * int(height)}
						mut writer := WriteStream.init_memory(mut encoded)
						png_filter(mut writer, pixels, PngSpecified{
							filter: unsafe { PngFilterType(filter) }
						}, header)!
						stride := int((header.bit_depth + 7) / 8 * header.channel_count())
						mut previous := []u8{len: line_bytes + stride}
						mut current := []u8{len: line_bytes + stride}
						mut result := []u8{len: int(width * height) * int(format.pixel_stride())}
						for y in 0 .. int(height) {
							mut data := unsafe { current[stride - 1..] }
							copy(mut data,
								encoded[y * (line_bytes + 1)..(y + 1) * (line_bytes + 1)])
							png_defilter(mut current, previous, u8(stride))!
							result_stride := int(width) * int(format.pixel_stride())
							mut dest := unsafe { result[y * result_stride..(y + 1) * result_stride] }
							png_spread_row_data(mut dest, current[stride..], header.bit_depth,
								header.channel_count(), format.pixel_stride(), $if little_endian {
								true
							} $else {
								false
							})
							unsafe {
								previous, current = current, previous
							}
						}
						png_reference_bytes(mut hash, result)
						cases++
					}
				}
			}
		}
	}
	assert cases == 1800
	assert hash[0] == u64(0x2ad35f81b5cd96cd)
}

fn png_reference_trns_hash(mut hash []u64, processor PngTrnsProcessor) {
	png_reference_mix(mut hash, u64(processor.processed))
	match processor.trns_data {
		PngTrnsUnset {
			png_reference_mix(mut hash, 0)
		}
		PngTrnsGray {
			png_reference_mix(mut hash, 1)
			png_reference_mix(mut hash, processor.trns_data.value)
		}
		PngTrnsRGB {
			png_reference_mix(mut hash, 2)
			png_reference_mix(mut hash, processor.trns_data.color.r)
			png_reference_mix(mut hash, processor.trns_data.color.g)
			png_reference_mix(mut hash, processor.trns_data.color.b)
		}
		PngTrnsIndexAlpha {
			png_reference_mix(mut hash, 3)
			png_reference_mix(mut hash, u64(processor.trns_data.data.len))
			png_reference_bytes(mut hash, processor.trns_data.data)
		}
	}
}

fn test_png_native_processor_matrix() {
	mut hash := [u64(14695981039346656037)]
	mut cases := 0
	for format in png_reference_formats {
		for length in 0 .. 13 {
			for processed in [false, true] {
				for seed in 0 .. 4 {
					mut header := png_reference_header(format, 1, 1)!
					mut bytes := []u8{len: length + 5}
					for index, mut byte in bytes {
						byte = u8(index * 37 + seed * 19)
					}
					mut stream := ReadStream.init_memory(bytes)
					mut processor := PngTrnsProcessor{
						processed: processed
					}
					if seed == 1 { processor.trns_data = PngTrnsGray{
							value: 0x1234
						} }
					if seed == 2 { processor.trns_data = PngTrnsRGB{
							color: Rgb48{
								r: 1
								g: 257
								b: 65535
							}
						} }
					if seed == 3 { processor.trns_data = PngTrnsIndexAlpha{
							data: [u8(17), 32]
						} }
					callback := processor.processor()
					mut data := PngChunkProcessData{
						read_stream:    &stream
						chunk_id:       png_chunk_trns.id
						chunk_length:   u32(length)
						current_format: format
						header:         &header
					}
					result := callback.process_chunk(mut data)!
					png_reference_mix(mut hash, u64(result))
					png_reference_mix(mut hash, stream.get_pos())
					png_reference_trns_hash(mut hash, processor)
					cases++
				}
			}
		}
	}
	for source in [PixelFormat.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16,
		.rgb24, .rgb48, .indexed8] {
		for destination in [PixelFormat.grayscale8_alpha, .grayscale16_alpha, .rgba32, .bgra32,
			.rgba64] {
			for seed in 0 .. 8 {
				if source == .rgb24 && destination in [.grayscale8_alpha, .grayscale16_alpha] { continue
				 }
				if source == .rgb48 && destination.pixel_stride() < 8 { continue
				 }
				mut row := []u8{len: 5 * int(destination.pixel_stride())}
				for index, mut byte in row {
					byte = u8(index * 37 + seed * 19)
				}
				mut processor := PngTrnsProcessor{}
				processor.trns_data = if source in [.rgb24, .rgb48] { PngTrnsData(PngTrnsRGB{
						color: Rgb48{
							r: u16(seed * 19)
							g: 37
							b: 74
						}
					}) } else { PngTrnsData(PngTrnsGray{
						value: u16(seed * 19)
					}) }
				mut data := PngRowProcessData{
					header: &PngHeaderData{
						width:              0
						height:             0
						bit_depth:          0
						color_type:         .grayscale
						compression_method: .deflate
						filter_method:      .adaptive
						interlace_method:   .none
					}

					dest_row:    unsafe { row[..] }
					src_format:  source
					dest_format: destination
				}
				result := processor.process_data_row(mut data)!
				png_reference_mix(mut hash, u64(result))
				png_reference_trns_hash(mut hash, processor)
				png_reference_bytes(mut hash, row)
				cases++
			}
		}
	}
	for kind in 0 .. 4 {
		mut processor := PngTrnsProcessor{}
		if kind == 1 { processor.trns_data = PngTrnsGray{
				value: 17
			} }
		if kind == 2 { processor.trns_data = PngTrnsRGB{
				color: Rgb48{
					r: 1
					g: 2
					b: 3
				}
			} }
		if kind == 3 { processor.trns_data = PngTrnsIndexAlpha{
				data: [u8(17), 32]
			} }
		mut palette := [Rgba32{ r: 1, g: 2, b: 3, a: 255 }, Rgba32{ r: 4, g: 5, b: 6, a: 255 }]
		mut data := PngPaletteProcessData{
			palette: unsafe { palette[..] }
		}
		mut failed := false
		processor.process_palette(mut data) or {
			assert err.msg() == 'InvalidData'
			failed = true
		}
		png_reference_mix(mut hash, u64(failed))
		png_reference_trns_hash(mut hash, processor)
		for color in palette {
			png_reference_bytes(mut hash, [color.r, color.g, color.b, color.a])
		}
		cases++
	}
	for format in png_reference_formats {
		for processed in [false, true] {
			mut processor := PngPlteProcessor{
				processed: processed
			}
			mut unused_stream := ReadStream.init_memory([]u8{})
			mut data := PngChunkProcessData{
				read_stream:  &unused_stream
				chunk_length: 0
				header:       &PngHeaderData{
					width:              0
					height:             0
					bit_depth:          0
					color_type:         .grayscale
					compression_method: .deflate
					filter_method:      .adaptive
					interlace_method:   .none
				}

				current_format: format
				chunk_id:       png_chunk_plte.id
			}
			result := processor.process_chunk(mut data)!
			png_reference_mix(mut hash, u64(result))
			png_reference_mix(mut hash, u64(processor.processed))
			cases++
		}
	}
	for source in [PixelFormat.indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .grayscale8] {
		for destination in [PixelFormat.rgba32, .bgra32, .rgba64, .grayscale8] {
			for seed in 0 .. 8 {
				mut row := []u8{len: 5 * int(destination.pixel_stride()), init: 0xa5}
				if destination != .grayscale8 {
					for index in 0 .. 5 {
						at := index * int(destination.pixel_stride())
						row[at] = u8((index + seed) % 4)
						if source == .indexed16 { row[at + 1] = 0 }
					}
				}
				mut palette := [Rgba32{ r: 1, g: 2, b: 3, a: 4 },
					Rgba32{ r: 5, g: 6, b: 7, a: 8 }, Rgba32{ r: 9, g: 10, b: 11, a: 12 },
					Rgba32{ r: 13, g: 14, b: 15, a: 16 }]
				mut processor := PngPlteProcessor{}
				mut palette_data := PngPaletteProcessData{
					palette: unsafe { palette[..] }
				}
				processor.process_palette(mut palette_data)!
				callback := processor.processor()
				mut data := PngRowProcessData{
					header: &PngHeaderData{
						width:              0
						height:             0
						bit_depth:          0
						color_type:         .grayscale
						compression_method: .deflate
						filter_method:      .adaptive
						interlace_method:   .none
					}

					dest_row:    unsafe { row[..] }
					src_format:  source
					dest_format: destination
				}
				result := callback.process_data_row(mut data)!
				png_reference_mix(mut hash, u64(result))
				png_reference_mix(mut hash, u64(processor.processed))
				png_reference_bytes(mut hash, row)
				cases++
			}
		}
	}
	assert cases == 2058
	assert hash[0] == u64(0xb0a838ddd9ac9218)
}

fn test_png_native_trns_chunk_truncations() {
	mut hash := [u64(14695981039346656037)]
	mut cases := 0
	for format in png_reference_formats {
		for length in 0 .. 13 {
			for processed in [false, true] {
				for seed in 0 .. 4 {
					for cut in 0 .. length + 6 {
						mut header := png_reference_header(format, 1, 1)!
						mut bytes := []u8{len: cut}
						for index, mut byte in bytes {
							byte = u8(index * 37 + seed * 19)
						}
						mut stream := ReadStream.init_memory(bytes)
						mut processor := PngTrnsProcessor{
							processed: processed
						}
						if seed == 1 { processor.trns_data = PngTrnsGray{
								value: 0x1234
							} }
						if seed == 2 { processor.trns_data = PngTrnsRGB{
								color: Rgb48{
									r: 1
									g: 257
									b: 65535
								}
							} }
						if seed == 3 { processor.trns_data = PngTrnsIndexAlpha{
								data: [u8(17), 32]
							} }
						mut data := PngChunkProcessData{
							read_stream:    &stream
							header:         &header
							chunk_id:       png_chunk_trns.id
							chunk_length:   u32(length)
							current_format: format
						}
						mut failure := ''
						result := processor.process_chunk(mut data) or {
							failure = err.msg()
							PixelFormat.invalid
						}
						png_reference_mix(mut hash, if failure == '' {
							u64(0)
						} else if failure == 'EndOfStream' {
							u64(1)
						} else if failure == 'Unseekable' {
							u64(2)
						} else {
							u64(3)
						})
						if failure == '' { png_reference_mix(mut hash, u64(result)) }
						png_reference_mix(mut hash, stream.get_pos())
						if !processed
							&& ((format in [.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16]
							&& length == 2 && cut < 2)
							|| (format in [.rgb24, .rgb48] && length == 6 && cut < 6)) {
							// Native failed scalar assignments can leave an undefined union payload.
							png_reference_mix(mut hash, u64(processor.processed))
						} else if !processed && format.is_indexed()
							&& length <= int(header.max_palette_size()) {
							// Newly allocated source alpha tails are undefined after a short read.
							png_reference_mix(mut hash, u64(processor.processed))
							png_reference_mix(mut hash, 3)
							match processor.trns_data {
								PngTrnsIndexAlpha {
									png_reference_mix(mut hash, u64(processor.trns_data.data.len))
									defined := if cut < length { cut } else { length }
									png_reference_bytes(mut hash,
										processor.trns_data.data[..defined])
								}
								else {
									assert false
								}
							}
						} else {
							png_reference_trns_hash(mut hash, processor)
						}
						cases++
					}
				}
			}
		}
	}
	assert cases == 18720
	assert hash[0] == u64(0x0975e75ee48838d7)
}
