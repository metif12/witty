module zigimg

pub fn (codec TIFF) uncompress_deflate(mut stream ReadStream, mut destination []u8) ! {
	mut writer := WriteStream.init_memory(mut destination)
	tiff_zlib_stream(mut stream, mut writer) or { return error('InvalidData') }
}

pub fn (codec TIFF) uncompress_lzw(mut stream ReadStream, mut destination []u8) ! {
	mut writer := WriteStream.init_memory(mut destination)
	mut decoder := lzw_decoder_init[BigEndian](8, 1)!
	defer { decoder.deinit[BigEndian]() }
	decoder.decode[BigEndian](mut stream, mut writer) or { return error('InvalidData') }
}

pub fn (codec TIFF) uncompress_ccitt(mut stream ReadStream, mut destination []u8, width usize, rows usize) ! {
	mut writer := WriteStream.init_memory(mut destination)
	mut decoder := CcittDecoder.init(width, rows, u8(codec.bitmap.photometric_interpretation & 1))!
	decoder.decode(mut stream, mut writer) or { return error('InvalidData') }
}

pub fn (codec TIFF) read_strips(mut stream ReadStream, mut pixels PixelStorage) ! {
	bitmap := &codec.bitmap
	// Both operands of the source's strip-count expression are u32.
	assert bitmap.image_height <= u32(0xffffffff) - bitmap.rows_per_strip
	sum := bitmap.image_height + bitmap.rows_per_strip
	assert sum > 0 && bitmap.rows_per_strip > 0
	total_strips := (sum - 1) / bitmap.rows_per_strip
	byte_counts := bitmap.strip_byte_counts or { panic('missing TIFF strip byte counts') }
	offsets := bitmap.strip_offsets or { panic('missing TIFF strip offsets') }
	width := bitmap.image_width
	height := bitmap.image_height
	rows := if bitmap.rows_per_strip < height { bitmap.rows_per_strip } else { height }
	assert rows > 0
	remainder := height % rows
	last_rows := if height > rows && remainder > 0 { remainder } else { rows }
	row_bytes := codec.cal_row_byte_size()!
	for index := usize(0); index < total_strips; index++ {
		current_rows := if total_strips > 1 && index < total_strips - 1 { rows } else { last_rows }
		byte_count := image_pixel_count(usize(current_rows), row_bytes)
		compressed_count := byte_counts[int(index)]
		offset := offsets[int(index)]
		// Source allocator memory and pixels left unwritten are undefined. V's
		// zero initialization is a recorded representation boundary.
		mut strip := []u8{len: int(byte_count)}
		mut pixel_index := image_pixel_count(image_pixel_count(index, usize(rows)), usize(width))
		stream.seek_to(offset)!
		match bitmap.compression {
			.uncompressed {
				stream.read_slice_short(mut strip)!
			}
			.packbits {
				packbits_decode(mut stream, mut strip, compressed_count)!
			}
			.ccitt_rle {
				codec.uncompress_ccitt(mut stream, mut strip, usize(width), usize(current_rows))!
			}
			.lzw {
				codec.uncompress_lzw(mut stream, mut strip)!
			}
			.deflate, .pixar_deflate {
				codec.uncompress_deflate(mut stream, mut strip)!
			}
			else {
				return error('Unsupported')
			}
		}

		match mut pixels {
			Grayscale1Pixels {
				mut complete := false
				for byte in strip {
					for bit in 0 .. 8 {
						value := (byte >> (7 - bit)) & 1
						pixels.data[int(pixel_index)].value = if bitmap.photometric_interpretation == 1 {
							value
						} else {
							value ^ 1
						}
						pixel_index++
						if pixel_index >= usize(pixels.data.len) {
							complete = true
							break
						}
					}
					if complete { break
					 }
				}
			}
			Grayscale8Pixels {
				for byte in strip {
					value := if bitmap.predictor == 1 || pixel_index % width == 0 {
						byte
					} else {
						pixels.data[int(pixel_index - 1)].value + byte
					}
					pixels.data[int(pixel_index)].value = value
					pixel_index++
					if pixel_index >= usize(pixels.data.len) { break
					 }
				}
			}
			IndexedStorage8 {
				for color_index, color in bitmap.color_map.data {
					pixels.palette[color_index] = color
				}
				for byte in strip {
					value := if bitmap.predictor == 1 || pixel_index % width == 0 {
						byte
					} else {
						pixels.indices[int(pixel_index - 1)] + byte
					}
					pixels.indices[int(pixel_index)] = value
					pixel_index++
					if pixel_index >= usize(pixels.indices.len) { break
					 }
				}
			}
			Rgb24Pixels {
				for strip_index := 0; strip_index < strip.len; strip_index += 3 {
					if bitmap.predictor == 1 || pixel_index % width == 0 {
						pixels.data[int(pixel_index)] = Rgb24{
							r: strip[strip_index]
							g: strip[strip_index + 1]
							b: strip[strip_index + 2]
						}
					} else {
						previous := pixels.data[int(pixel_index - 1)]
						pixels.data[int(pixel_index)] = Rgb24{
							r: previous.r + strip[strip_index]
							g: previous.g + strip[strip_index + 1]
							b: previous.b + strip[strip_index + 2]
						}
					}
					pixel_index++
					if pixel_index >= usize(pixels.data.len) { break
					 }
				}
			}
			Rgba32Pixels {
				for strip_index := 0; strip_index < strip.len; strip_index += 4 {
					if bitmap.predictor == 1 || pixel_index % width == 0 {
						pixels.data[int(pixel_index)] = Rgba32{
							r: strip[strip_index]
							g: strip[strip_index + 1]
							b: strip[strip_index + 2]
							a: strip[strip_index + 3]
						}
					} else {
						previous := pixels.data[int(pixel_index - 1)]
						pixels.data[int(pixel_index)] = Rgba32{
							r: previous.r + strip[strip_index]
							g: previous.g + strip[strip_index + 1]
							b: previous.b + strip[strip_index + 2]
							a: previous.a + strip[strip_index + 3]
						}
					}
					pixel_index++
					if pixel_index >= usize(pixels.data.len) { break
					 }
				}
			}
			else {
				return error('Unsupported')
			}
		}
	}
}

pub fn (mut codec TIFF) read(mut stream ReadStream) !PixelStorage {
	magic := stream.peek(2)!
	codec.endianess = if magic == tiff_little_endian_magic.bytes() {
		TiffEndian.little
	} else if magic == tiff_big_endian_magic.bytes() {
		TiffEndian.big
	} else {
		return error('InvalidData')
	}
	stream.toss(2)
	// Commit the header only after both fields were read, as in the source.
	version := tiff_u16(stream.take(2)!, codec.endianess)
	ifd_offset := tiff_u32(stream.take(4)!, codec.endianess)
	codec.header = TiffHeader{
		version:    version
		idf_offset: ifd_offset
	}
	codec.bitmap = TiffBitmapDescriptor{}
	defer { codec.bitmap.deinit() }
	codec.ifd = TiffIFD.init(&stream, ifd_offset)!
	defer { codec.ifd.deinit() }
	codec.ifd.read_tags(codec.endianess)!
	codec.decode_bitmap(mut stream)!
	format := codec.bitmap.guess_pixel_format()!
	assert codec.bitmap.image_height == 0
		|| codec.bitmap.image_width <= u32(0xffffffff) / codec.bitmap.image_height
	count := codec.bitmap.image_width * codec.bitmap.image_height
	mut pixels := PixelStorage.init(format, usize(count))!
	codec.read_strips(mut stream, mut pixels)!
	return pixels
}

pub fn TIFF.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := TIFF{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.width()
		height: codec.height()
		pixels: pixels
	}
}
