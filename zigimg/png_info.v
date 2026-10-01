module zigimg

import strconv

pub struct PngInfoProcessor {
pub mut:
	writer     &WriteStream = unsafe { nil }
	idat_count u32
	idat_size  u64
}

pub type PngInfoOptions = PngCustomReaderOptions1[PngInfoProcessor]

// V does not forward a generic static constructor through a concrete alias.
pub fn PngInfoOptions.init(processor PngInfoProcessor) PngInfoOptions {
	return PngInfoOptions{
		processor: processor
	}
}

pub fn PngInfoProcessor.init(writer &WriteStream) PngInfoProcessor {
	return PngInfoProcessor{
		writer: unsafe { writer }
	}
}

fn png_info_chunk(context voidptr, mut data PngChunkProcessData) !PixelFormat {
	mut processor := unsafe { &PngInfoProcessor(context) }
	return processor.process_chunk(mut data)
}

fn png_info_palette(context voidptr, mut data PngPaletteProcessData) ! {
	mut processor := unsafe { &PngInfoProcessor(context) }
	processor.process_palette(mut data)!
}

pub fn (mut processor PngInfoProcessor) processor() PngReaderProcessor {
	return PngReaderProcessor.init(png_chunk_any.id, unsafe { voidptr(&processor) },
		png_info_chunk, png_info_palette, none)
}

fn (mut processor PngInfoProcessor) print(text string) bool {
	processor.writer.write_all(text.bytes()) or { return false }
	return true
}

fn png_info_byte_size(value u64) string {
	mut reduced := value
	mut divisor := u64(1)
	mut magnitude := 0
	for reduced >= 1024 {
		reduced >>= 10
		divisor *= 1024
		magnitude++
	}
	if magnitude == 0 { return '${value}B' }
	// Zig renders the shortest f64 mantissa in decimal notation for {Bi}.
	scientific := strconv.f64_to_str(f64(value) / f64(divisor), 17)
	parts := scientific.split('e')
	digits := parts[0].replace('.', '')
	point := parts[1].int() + 1
	decimal := if point >= digits.len {
		digits + '0'.repeat(point - digits.len)
	} else if point <= 0 {
		'0.' + '0'.repeat(-point) + digits
	} else {
		digits[..point] + '.' + digits[point..]
	}
	return decimal + ['', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'][magnitude]
}

fn png_info_zero(bytes []u8) int {
	for index, byte in bytes {
		if byte == 0 { return index }
	}
	panic('missing PNG text delimiter')
}

fn png_info_read_short(mut decoder TiffFlate, mut input ReadStream, mut destination []u8) !int {
	mut filled := 0
	for filled < destination.len {
		if decoder.seek < decoder.end {
			available := decoder.end - decoder.seek
			needed := destination.len - filled
			count := if available < needed { available } else { needed }
			for index in 0 .. count {
				destination[filled + index] = decoder.window[decoder.seek + index]
			}
			decoder.seek += count
			filled += count
		} else {
			decoder.fill_window(mut input) or {
				if err.msg() == 'EndOfStream' && decoder.state == .end { return filled }
				return error('InvalidData')
			}
		}
	}
	return filled
}

pub fn (mut processor PngInfoProcessor) process_chunk(mut data PngChunkProcessData) !PixelFormat {
	format := data.current_format
	mut stream := data.read_stream
	if !png_is_chunk_critical(data.chunk_id) {
		match data.chunk_id {
			png_chunk_gama.id {
				if data.chunk_length != 4 {
					stream.seek_by(i64(data.chunk_length))!
					if !processor.print('gAMA: Invalid Length ${data.chunk_length}\n') {
						return format
					}
				} else {
					gamma := read_be_u32(stream.take(4)!)
					if !processor.print('gAMA: ${gamma}\n') { return format }
				}
			}
			png_chunk_sbit.id {
				if data.chunk_length > 4 {
					stream.seek_by(i64(data.chunk_length))!
					if !processor.print('sBIT: Invalid length ${data.chunk_length}\n') {
						return format
					}
				} else {
					mut values := []u8{len: int(data.chunk_length)}
					stream.read_slice_all(mut values)!
					if !processor.print('sBIT (significant bits): ') { return format }
					text := match data.chunk_length {
						1 { 'Grayscale => ${values[0]}\n' }
						2 { 'Grayscale => ${values[0]}, A => ${values[1]}\n' }
						3 { 'R => ${values[0]}, G => ${values[1]}, B => ${values[2]}\n' }
						4 { 'R => ${values[0]}, G => ${values[1]}, B => ${values[2]}, A => ${values[3]}\n' }
						else { 'Invalid length ${data.chunk_length}\n' }
					}

					if !processor.print(text) { return format }
				}
			}
			png_chunk_text.id, png_chunk_itxt.id {
				count := if data.chunk_length > 1024 { 1024 } else { int(data.chunk_length) }
				mut bytes := []u8{len: count}
				stream.read_slice_all(mut bytes)!
				if data.chunk_length > 1024 { stream.seek_by(i64(data.chunk_length) - 1024)! }
				name := if data.chunk_id == png_chunk_text.id { 'tEXt' } else { 'iTXt' }
				if !processor.print('${name} Length ${png_info_byte_size(data.chunk_length)}:\n') {
					return format
				}
				end := png_info_zero(bytes)
				if !processor.print('               Keyword: ${bytes[..end].bytestr()}\n') {
					return format
				}
				mut text := unsafe { bytes[end + 1..] }
				if data.chunk_id == png_chunk_itxt.id {
					if text[0] == 1 {
						method := if text[1] == 0 { 'Zlib Deflate  ' } else { 'Unknown Method' }
						if !processor.print('            Compressed: ${method}\n') { return format }
					} else {
						if !processor.print('            Compressed: No\n') { return format }
					}
					text = unsafe { text[2..] }
					language_end := png_info_zero(text)
					if !processor.print('          Language Tag: ${text[..language_end].bytestr()}\n') {
						return format
					}
					text = unsafe { text[language_end + 1..] }
					translation_end := png_info_zero(text)
					if !processor.print('    Translated Keyword: ${text[..translation_end].bytestr()}\n') {
						return format
					}
					text = unsafe { text[translation_end + 1..] }
				}
				if !processor.print('                  Text: ${text.bytestr()}\n') { return format }
			}
			png_chunk_ztxt.id {
				count := if data.chunk_length > 81 { 81 } else { int(data.chunk_length) }
				mut bytes := []u8{len: count}
				stream.read_slice_all(mut bytes)!
				if !processor.print('zTXt Length ${png_info_byte_size(data.chunk_length)}:\n') {
					return format
				}
				end := png_info_zero(bytes)
				if !processor.print('               Keyword: ${bytes[..end].bytestr()}\n') {
					return format
				}
				if bytes[end + 1] == 0 {
					if !processor.print('           Compression: Zlib Deflate\n') { return format }
					if !processor.print('                  Text: ') { return format }
					stream.seek_by(i64(end) + 2 - count)!
					mut decoder := TiffFlate{}
					mut print_buffer := []u8{len: 1024}
					mut got := png_info_read_short(mut decoder, mut stream, mut print_buffer)!
					for got > 0 {
						if !processor.print(print_buffer[..got].bytestr()) { return format }
						got = png_info_read_short(mut decoder, mut stream, mut print_buffer)!
					}
					if !processor.print('\n') { return format }
				} else {
					if !processor.print('           Compression: Unknown\n') { return format }
				}
			}
			png_chunk_chrm.id {
				if data.chunk_length != 32 {
					stream.seek_by(i64(data.chunk_length))!
					if !processor.print('cHRM: Invalid Length ${data.chunk_length}\n') {
						return format
					}
				} else {
					if !processor.print('cHRM:\n') { return format }
					for name in ['    White', '      Red', '    Green', '     Blue'] {
						x := read_be_u32(stream.take(4)!)
						y := read_be_u32(stream.take(4)!)
						if !processor.print('${name} x,y: ${x}, ${y}\n') { return format }
					}
				}
			}
			png_chunk_phys.id {
				if data.chunk_length != 9 {
					stream.seek_by(i64(data.chunk_length))!
					if !processor.print('pHYs: Invalid Length ${data.chunk_length}\n') {
						return format
					}
				} else {
					if !processor.print('pHYs: ') { return format }
					x := read_be_u32(stream.take(4)!)
					y := read_be_u32(stream.take(4)!)
					if !processor.print('${x} x ${y}') { return format }
					unit := stream.take_byte()!
					if !processor.print(if unit == 1 { ' metres\n' } else { '\n' }) { return format
					 }
				}
			}
			png_chunk_trns.id, png_chunk_bkgd.id {
				background := data.chunk_id == png_chunk_bkgd.id
				name := if background { 'bKGD' } else { 'tRNS' }
				if !processor.print('${name} Length ${png_info_byte_size(data.chunk_length)}: ') {
					return format
				}
				if background && data.chunk_length == 1 {
					value := stream.take_byte()!
					if !processor.print('Index ${value}\n') { return format }
				} else if data.chunk_length == 2
					&& (background || data.header.color_type != .indexed) {
					value := tiff_u16(stream.take(2)!, .big)
					if !processor.print('${value}\n') { return format }
				} else if data.chunk_length == 6
					&& (background || data.header.color_type != .indexed) {
					r := tiff_u16(stream.take(2)!, .big)
					g := tiff_u16(stream.take(2)!, .big)
					b := tiff_u16(stream.take(2)!, .big)
					if !processor.print('RGB ${r}, ${g}, ${b}\n') { return format }
				} else if background {
					if !processor.print('Invalid Length\n') { return format }
					stream.seek_by(i64(data.chunk_length))!
				} else {
					count := if data.chunk_length > 20 { 20 } else { int(data.chunk_length) }
					mut values := []u8{len: count}
					stream.read_slice_all(mut values)!
					mut decimals := []string{cap: count}
					for value in values {
						decimals << value.str()
					}
					if !processor.print('{ ' + decimals.join(', ') + ' }') { return format }
					if data.chunk_length > 20 {
						if !processor.print(' ...\n') { return format }
						stream.seek_by(i64(data.chunk_length - 20))!
					} else {
						if !processor.print('\n') { return format }
					}
				}
			}
			png_chunk_time.id {
				if data.chunk_length != 7 {
					stream.seek_by(i64(data.chunk_length))!
					if !processor.print('tIME: Invalid Length ${data.chunk_length}: ') {
						return format
					}
				} else {
					if !processor.print('tIME: ') { return format }
					year := tiff_u16(stream.take(2)!, .big)
					mut rest := []u8{len: 5}
					stream.read_slice_all(mut rest)!
					if !processor.print('${year}-${rest[0]}-${rest[1]} ${rest[2]}:${rest[3]}:${rest[4]}\n') {
						return format
					}
				}
			}
			png_chunk_iccp.id {
				if data.chunk_length > 1024 {
					stream.seek_by(i64(data.chunk_length))!
					if !processor.print('iCCP: Invalid Length ${data.chunk_length}: ') {
						return format
					}
				} else {
					if !processor.print('iCCP Length ${png_info_byte_size(data.chunk_length)}: ') {
						return format
					}
					mut bytes := []u8{len: int(data.chunk_length)}
					stream.read_slice_all(mut bytes)!
					mut end := -1
					for index, byte in bytes {
						if byte == 0 {
							end = index
							break
						}
					}
					text := if end < 0 {
						'Invalid Data\n'
					} else {
						'Profile Name: ${bytes[..end].bytestr()}\n'
					}
					if !processor.print(text) { return format }
				}
			}
			png_chunk_srgb.id {
				if data.chunk_length != 1 {
					stream.seek_by(i64(data.chunk_length))!
					if !processor.print('sRGB: Invalid Length ${data.chunk_length}: ') {
						return format
					}
				} else {
					if !processor.print('sRGB: ') { return format }
					intent := stream.take_byte()!
					text := match intent {
						0 { 'Perceptual\n' }
						1 { 'Relative colorimetric\n' }
						2 { 'Saturation\n' }
						3 { 'Absolute colorimetric\n' }
						else { 'Uknown Intent\n' }
					}

					if !processor.print(text) { return format }
				}
			}
			else {
				stream.seek_by(i64(data.chunk_length))!
				name := [u8(data.chunk_id >> 24), u8(data.chunk_id >> 16), u8(data.chunk_id >> 8),
					u8(data.chunk_id)].bytestr()
				if !processor.print('${name} Length ${png_info_byte_size(data.chunk_length)}\n') {
					return format
				}
			}
		}

		stream.seek_by(4)!
	} else if data.chunk_id == png_chunk_ihdr.id {
		if !processor.print('Dimensions: ${data.header.width}x${data.header.height}\n') {
			return format
		}
		if !processor.print('Bit Depth: ${data.header.bit_depth}\n') { return format }
		assert u8(data.header.color_type) in [u8(0), 2, 3, 4, 6]
		if !processor.print('Color Type: ${data.header.color_type}\n') { return format }
		assert u8(data.header.compression_method) == 0
		if !processor.print('Compression Method: deflate\n') { return format }
		assert u8(data.header.filter_method) == 0
		if !processor.print('Filter Method: adaptive\n') { return format }
		assert u8(data.header.interlace_method) <= 1
		if !processor.print('Interlace Method: ${data.header.interlace_method}\n\n') {
			return format
		}
	} else if data.chunk_id == png_chunk_idat.id {
		assert processor.idat_count < u32(0xffffffff)
		processor.idat_count++
		assert processor.idat_size <= ~u64(0) - data.chunk_length
		processor.idat_size += data.chunk_length
	} else if data.chunk_id == png_chunk_iend.id {
		if !processor.print('IDAT Count: ${processor.idat_count}, Total Size: ${png_info_byte_size(processor.idat_size)}\n') {
			return format
		}
		if !processor.print('────────────────────────────────────────────────\n') {
			return format
		}
	}
	return format
}

pub fn (mut processor PngInfoProcessor) process_palette(mut data PngPaletteProcessData) ! {
	processor.print('PLTE with ${data.palette.len} entries\n')
}
