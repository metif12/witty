module zigimg

// Adapted from the locked zigimg PCX codec, originally translated from
// Felix Queissner's zig-gamedev-lib with his permission.
pub enum PcxCompression as u8 {
	none = 0
	rle  = 1
}

pub enum PcxPaletteInfo as u16 {
	color     = 1
	grayscale = 2
}

@[packed]
pub struct PCXHeader {
pub mut:
	id                  u8             = 0x0a
	version             u8             = 5
	compression         PcxCompression = .rle
	bpp                 u8
	xmin                u16
	ymin                u16
	xmax                u16
	ymax                u16
	horizontal_dpi      u16 = 320
	vertical_dpi        u16 = 200
	builtin_palette     [16]Rgb24
	reserved0           u8
	planes              u8
	stride              u16
	palette_information PcxPaletteInfo = .color
	screen_width        u16
	screen_height       u16
	padding             [54]u8
}

pub struct PcxEncoderOptions {}

pub struct PCX {
pub mut:
	header PCXHeader
}

pub fn (codec PCX) width() usize {
	assert codec.header.xmax >= codec.header.xmin
	assert codec.header.xmax - codec.header.xmin < 65535
	return usize(u16(codec.header.xmax - codec.header.xmin + 1))
}

pub fn (codec PCX) height() usize {
	assert codec.header.ymax >= codec.header.ymin
	assert codec.header.ymax - codec.header.ymin < 65535
	return usize(u16(codec.header.ymax - codec.header.ymin + 1))
}

pub fn PCX.format_detect(mut stream ReadStream) !bool {
	magic := stream.peek(2)!
	return magic[0] == 0x0a && magic[1] <= 5
}

pub fn (codec PCX) pixel_format() !PixelFormat {
	return match codec.header.planes {
		1 {
			match codec.header.bpp {
				1 { PixelFormat.indexed1 }
				4 { PixelFormat.indexed4 }
				8 { PixelFormat.indexed8 }
				else { return error('Unsupported') }
			}
		}
		3 {
			if codec.header.bpp != 8 { return error('Unsupported') }
			PixelFormat.rgb24
		}
		else {
			return error('Unsupported')
		}
	}
}

pub fn PCX.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := PCX{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.width()
		height: codec.height()
		pixels: pixels
	}
}

fn pcx_read_u16(bytes []u8, offset int) u16 {
	return u16(bytes[offset]) | u16(bytes[offset + 1]) << 8
}

fn pcx_header_read(mut stream ReadStream) !PCXHeader {
	bytes := stream.take(128)!
	mut header := PCXHeader{
		id:                  bytes[0]
		version:             bytes[1]
		compression:         unsafe { PcxCompression(bytes[2]) }
		bpp:                 bytes[3]
		xmin:                pcx_read_u16(bytes, 4)
		ymin:                pcx_read_u16(bytes, 6)
		xmax:                pcx_read_u16(bytes, 8)
		ymax:                pcx_read_u16(bytes, 10)
		horizontal_dpi:      pcx_read_u16(bytes, 12)
		vertical_dpi:        pcx_read_u16(bytes, 14)
		reserved0:           bytes[64]
		planes:              bytes[65]
		stride:              pcx_read_u16(bytes, 66)
		palette_information: unsafe { PcxPaletteInfo(pcx_read_u16(bytes, 68)) }
		screen_width:        pcx_read_u16(bytes, 70)
		screen_height:       pcx_read_u16(bytes, 72)
	}
	for i in 0 .. 16 {
		header.builtin_palette[i] = Rgb24{
			r: bytes[16 + i * 3]
			g: bytes[17 + i * 3]
			b: bytes[18 + i * 3]
		}
	}
	for i in 0 .. 54 {
		header.padding[i] = bytes[74 + i]
	}
	return header
}

fn pcx_header_bytes(header PCXHeader) []u8 {
	mut bytes := [header.id, header.version, u8(header.compression), header.bpp]
	for word in [header.xmin, header.ymin, header.xmax, header.ymax, header.horizontal_dpi,
		header.vertical_dpi] {
		bytes << [u8(word), u8(word >> 8)]
	}
	for color in header.builtin_palette {
		bytes << [color.r, color.g, color.b]
	}
	bytes << [header.reserved0, header.planes]
	for word in [header.stride, u16(header.palette_information), header.screen_width, header.screen_height] {
		bytes << [u8(word), u8(word >> 8)]
	}
	for byte in header.padding {
		bytes << byte
	}
	assert bytes.len == 128
	return bytes
}

struct PcxRleDecoder {
mut:
	reader    &ReadStream = unsafe { nil }
	value     u8
	remaining usize
}

fn (mut decoder PcxRleDecoder) read_byte() !u8 {
	if decoder.remaining > 0 {
		decoder.remaining--
		return decoder.value
	}
	for {
		byte := decoder.reader.take_byte()!
		if byte == 0xc0 { continue
		 }
		if byte & 0xc0 == 0xc0 {
			count := byte & 0x3f
			value := decoder.reader.take_byte()!
			decoder.value = value
			decoder.remaining = usize(count - 1)
			return value
		}
		return byte
	}
	return error('unreachable')
}

fn (decoder PcxRleDecoder) finish() ! {
	if decoder.remaining != 0 { return error('InvalidData') }
}

pub fn (mut codec PCX) read(mut stream ReadStream) !PixelStorage {
	codec.header = pcx_header_read(mut stream)!
	if codec.header.id != 0x0a || codec.header.version > 5 { return error('InvalidData') }
	if codec.header.planes > 3 { return error('Unsupported') }
	format := codec.pixel_format()!
	width := codec.width()
	height := codec.height()
	// Source bitcasts stride to i16 before comparing it with the pointer-width
	// signed image width. The compression header is deliberately not consulted.
	signed_stride := if codec.header.stride & 0x8000 != 0 {
		int(codec.header.stride) - 65536
	} else {
		int(codec.header.stride)
	}
	has_dummy_byte := isize(signed_stride) - isize(width) == 1
	actual_width := if has_dummy_byte { width + 1 } else { width }
	mut pixels := PixelStorage.init(format, width * height)!
	mut decoder := PcxRleDecoder{
		reader: unsafe { &stream }
	}
	assert u32(codec.header.stride) * codec.header.planes <= 65535
	scanline_length := u16(codec.header.stride * codec.header.planes)
	for y := usize(0); y < height; y++ {
		mut offset := usize(0)
		mut x := usize(0)
		y_stride := y * width
		for offset < scanline_length && x < width {
			byte := decoder.read_byte()!
			match mut pixels {
				IndexedStorage1 {
					for i in 0 .. 8 {
						if x < width {
							pixels.indices[int(y_stride + x)] = (byte >> u8(7 - i)) & 1
							x++
						}
					}
				}
				IndexedStorage4 {
					pixels.indices[int(y_stride + x)] = byte >> 4
					x++
					if x < width {
						pixels.indices[int(y_stride + x)] = byte & 15
						x++
					}
				}
				IndexedStorage8 {
					pixels.indices[int(y_stride + x)] = byte
					x++
				}
				Rgb24Pixels {
					if has_dummy_byte && byte == 0 {
						offset++
						continue
					}
					pixel_x := offset % actual_width
					current_color := offset / actual_width
					match current_color {
						0 { pixels.data[int(y_stride + pixel_x)].r = byte }
						1 { pixels.data[int(y_stride + pixel_x)].g = byte }
						2 { pixels.data[int(y_stride + pixel_x)].b = byte }
						else {}
					}

					if pixel_x > 0 && pixel_x % codec.header.planes == 0 { x++ }
				}
				else {
					return error('Unsupported')
				}
			}

			offset++
		}
		// The pinned reader discards to stride, not to stride * planes.
		for offset < codec.header.stride {
			decoder.read_byte()!
			offset++
		}
	}
	decoder.finish()!
	match mut pixels {
		IndexedStorage1 { pcx_read_palette(mut stream, mut pixels.palette, codec.header, false)! }
		IndexedStorage4 { pcx_read_palette(mut stream, mut pixels.palette, codec.header, false)! }
		IndexedStorage8 { pcx_read_palette(mut stream, mut pixels.palette, codec.header, true)! }
		else {}
	}

	return pixels
}

fn pcx_read_palette(mut stream ReadStream, mut palette []Rgba32, header PCXHeader, vga bool) ! {
	count := if palette.len < 16 { palette.len } else { 16 }
	for i in 0 .. count {
		color := header.builtin_palette[i]
		palette[i] = Rgba32{
			r: color.r
			g: color.g
			b: color.b
			a: 255
		}
	}
	if !vga { return }
	end := stream.get_end_pos()
	assert end >= 769
	stream.seek_to(end - 769)!
	if stream.take_byte()! != 0x0c { return error('InvalidData') }
	for mut color in palette {
		color.r = stream.take_byte()!
		color.g = stream.take_byte()!
		color.b = stream.take_byte()!
		color.a = 255
	}
}

fn pcx_flush_rle(mut stream WriteStream, value u8, count usize) ! {
	mut remaining := count
	for remaining > 0 {
		length := if remaining < 63 { remaining } else { usize(63) }
		if length >= 2 || value & 0xc0 == 0xc0 {
			stream.write_byte(0xc0 | u8(length))!
			stream.write_byte(value)!
		} else {
			stream.write_byte(value)!
		}
		remaining -= length
	}
}

struct PcxRleStreamEncoder {
mut:
	rle_byte ?u8
	length   usize
}

fn (mut encoder PcxRleStreamEncoder) encode_byte(mut stream WriteStream, byte u8) ! {
	if old := encoder.rle_byte {
		if old == byte {
			encoder.length++
		} else {
			pcx_flush_rle(mut stream, old, encoder.length)!
			encoder.length = 1
			encoder.rle_byte = byte
		}
	} else {
		encoder.rle_byte = byte
		encoder.length = 1
	}
}

fn (mut encoder PcxRleStreamEncoder) encode(mut stream WriteStream, bytes []u8) ! {
	for byte in bytes {
		encoder.encode_byte(mut stream, byte)!
	}
}

fn (mut encoder PcxRleStreamEncoder) flush(mut stream WriteStream) ! {
	if encoder.length == 0 { return }
	if byte := encoder.rle_byte { pcx_flush_rle(mut stream, byte, encoder.length)! }
	// Source does not clear the buffered run after flushing.
}

fn pcx_rle_fast_encode(source []u8, mut stream WriteStream) ! {
	if source.len == 0 { return }
	mut index := 0
	mut total := usize(0)
	mut current := u8(0)
	for index < source.len && index + 16 <= source.len {
		current = source[index]
		mut similar := 0
		for similar < 16 && source[index + similar] == current {
			similar++
		}
		total += usize(similar)
		if similar != 16 {
			pcx_flush_rle(mut stream, current, total)!
			total = 0
		}
		index += similar
	}
	pcx_flush_rle(mut stream, current, total)!
	total = 0
	if index < source.len {
		current = source[index]
		for index < source.len {
			byte := source[index]
			if byte == current {
				total++
			} else {
				pcx_flush_rle(mut stream, current, total)!
				current = byte
				total = 1
			}
			index++
		}
		pcx_flush_rle(mut stream, current, total)!
	}
}

pub fn PCX.write_image(mut stream WriteStream, image ImageUnmanaged, options PcxEncoderOptions) ! {
	_ = options
	if image.width > 65535 || image.height > 65535 { return error('Unsupported') }
	assert image.width > 0 && image.height > 0
	mut codec := PCX{
		header: PCXHeader{
			xmax: u16(image.width - 1)
			ymax: u16(image.height - 1)
		}
	}
	match image.pixels {
		IndexedStorage1 {
			codec.header.bpp = 1
			codec.header.planes = 1
			codec.fill_palette(image.pixels.palette)
		}
		IndexedStorage4 {
			codec.header.bpp = 4
			codec.header.planes = 1
			codec.fill_palette(image.pixels.palette)
		}
		IndexedStorage8 {
			codec.header.bpp = 8
			codec.header.planes = 1
		}
		Rgb24Pixels {
			codec.header.bpp = 8
			codec.header.planes = 3
		}
		else {
			return error('Unsupported')
		}
	}

	codec.header.stride = u16((f32(image.width) / 8.0) * f32(codec.header.bpp))
	assert u32(codec.header.stride) + (codec.header.stride & 1) <= 65535
	codec.header.stride += codec.header.stride & 1
	codec.write(mut stream, image.pixels)!
}

fn (mut codec PCX) fill_palette(palette []Rgba32) {
	count := if palette.len < 16 { palette.len } else { 16 }
	for i in 0 .. count {
		codec.header.builtin_palette[i] = Rgb24{
			r: palette[i].r
			g: palette[i].g
			b: palette[i].b
		}
	}
}

pub fn (codec PCX) write(mut stream WriteStream, pixels PixelStorage) ! {
	if pixels !is IndexedStorage1 && pixels !is IndexedStorage4 && pixels !is IndexedStorage8
		&& pixels !is Rgb24Pixels {
		return error('Unsupported')
	}
	stream.write_all(pcx_header_bytes(codec.header))!
	width := codec.width()
	even := width & 1 == 0
	// The source's even indexed8 path reads the whole slice and never evaluates
	// the header's height, including an invalid vertical coordinate range.
	height := if pixels is IndexedStorage8 && even { usize(0) } else { codec.height() }
	mut encoder := PcxRleStreamEncoder{}
	match pixels {
		IndexedStorage1 {
			for y := usize(0); y < height; y++ {
				mut byte := u8(0)
				for x := usize(0); x < width; x++ {
					pixel := pixels.indices[int(y * width + x)]
					assert pixel <= 1
					bit := u8(7 - (x % 8))
					byte |= pixel << bit
					if bit == 0 {
						encoder.encode_byte(mut stream, byte)!
						byte = 0
					}
				}
				if !even { encoder.encode_byte(mut stream, byte)! }
			}
			encoder.flush(mut stream)!
		}
		IndexedStorage4 {
			mut byte := u8(0)
			for y := usize(0); y < height; y++ {
				for x := usize(0); x < width; x++ {
					pixel := pixels.indices[int(y * width + x)]
					assert pixel <= 15
					if x & 1 == 1 {
						byte |= pixel
						encoder.encode_byte(mut stream, byte)!
					} else {
						byte = pixel << 4
					}
				}
				if !even { encoder.encode_byte(mut stream, byte)! }
			}
			encoder.flush(mut stream)!
		}
		IndexedStorage8 {
			if even {
				pcx_rle_fast_encode(pixels.indices, mut stream)!
			} else {
				for y := usize(0); y < height; y++ {
					encoder.encode(mut stream, pixels.indices[int(y * width)..int((y + 1) * width)])!
					encoder.encode_byte(mut stream, 0)!
				}
				encoder.flush(mut stream)!
			}
			stream.write_byte(0x0c)!
			for color in pixels.palette {
				stream.write_all([color.r, color.g, color.b])!
			}
		}
		Rgb24Pixels {
			for y := usize(0); y < height; y++ {
				for plane in 0 .. 3 {
					for x := usize(0); x < width; x++ {
						pixel := pixels.data[int(y * width + x)]
						byte := match plane {
							0 { pixel.r }
							1 { pixel.g }
							else { pixel.b }
						}

						encoder.encode_byte(mut stream, byte)!
					}
					if !even { encoder.encode_byte(mut stream, 0)! }
				}
			}
			encoder.flush(mut stream)!
		}
		else {
			return error('Unsupported')
		}
	}

	stream.flush()!
}
