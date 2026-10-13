module zigimg

// The pinned implementation adapts Felix Queissner's zig-gamedev-lib Netpbm
// reader with his permission. See the original attribution in netpbm.zig.

pub enum NetpbmFormat as u8 {
	bitmap    = 0
	grayscale = 1
	rgb       = 2
}

pub struct NetpbmHeader {
pub mut:
	format    NetpbmFormat @[required]
	binary    bool         @[required]
	width     usize        @[required]
	height    usize        @[required]
	max_value usize        @[required]
}

pub struct PbmKind {}

pub struct PgmKind {}

pub struct PpmKind {}

pub struct Netpbm[T] {
pub mut:
	// Source leaves the header undefined until read or explicit initialization.
	header NetpbmHeader = NetpbmHeader{
		format:    .bitmap
		binary:    false
		width:     0
		height:    0
		max_value: 0
	}
}

pub type PBM = Netpbm[PbmKind]
pub type PGM = Netpbm[PgmKind]
pub type PPM = Netpbm[PpmKind]

// V does not inherit static methods through generic aliases.
pub fn PBM.format_detect(mut stream ReadStream) !bool {
	return Netpbm.format_detect[PbmKind](mut stream)
}

pub fn PGM.format_detect(mut stream ReadStream) !bool {
	return Netpbm.format_detect[PgmKind](mut stream)
}

pub fn PPM.format_detect(mut stream ReadStream) !bool {
	return Netpbm.format_detect[PpmKind](mut stream)
}

pub fn PBM.read_image(mut stream ReadStream) !ImageUnmanaged {
	return Netpbm.read_image[PbmKind](mut stream)
}

pub fn PGM.read_image(mut stream ReadStream) !ImageUnmanaged {
	return Netpbm.read_image[PgmKind](mut stream)
}

pub fn PPM.read_image(mut stream ReadStream) !ImageUnmanaged {
	return Netpbm.read_image[PpmKind](mut stream)
}

pub fn PBM.write_image(mut stream WriteStream, image ImageUnmanaged, options NetpbmEncoderOptions) ! {
	Netpbm.write_image[PbmKind](mut stream, image, options)!
}

pub fn PGM.write_image(mut stream WriteStream, image ImageUnmanaged, options NetpbmEncoderOptions) ! {
	Netpbm.write_image[PgmKind](mut stream, image, options)!
}

pub fn PPM.write_image(mut stream WriteStream, image ImageUnmanaged, options NetpbmEncoderOptions) ! {
	Netpbm.write_image[PpmKind](mut stream, image, options)!
}

pub struct NetpbmEncoderOptions {
pub mut:
	binary bool = true
}

fn netpbm_kind[T]() NetpbmFormat {
	$if T is PbmKind {
		return .bitmap
	} $else $if T is PgmKind {
		return .grayscale
	} $else $if T is PpmKind {
		return .rgb
	} $else {
		$compile_error('Netpbm requires PbmKind, PgmKind, or PpmKind')
	}
}

pub fn Netpbm.format_detect[T](mut stream ReadStream) !bool {
	magic := stream.peek(2)!
	kind := netpbm_kind[T]()
	number := u8(int(kind) + `1`)
	return magic[0] == `P` && magic[1] in [number, number + 3]
}

pub fn Netpbm.read_image[T](mut stream ReadStream) !ImageUnmanaged {
	mut codec := Netpbm[T]{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.header.width
		height: codec.header.height
		pixels: pixels
	}
}

pub fn Netpbm.write_image[T](mut stream WriteStream, image ImageUnmanaged, options NetpbmEncoderOptions) ! {
	format := match image.pixels {
		Grayscale1Pixels { NetpbmFormat.bitmap }
		Grayscale8Pixels, Grayscale16Pixels { NetpbmFormat.grayscale }
		Rgb24Pixels { NetpbmFormat.rgb }
		else { return error('Unsupported') }
	}

	max_value := match image.pixels {
		Grayscale16Pixels { usize(65535) }
		Grayscale1Pixels { usize(1) }
		else { usize(255) }
	}

	mut codec := Netpbm[T]{
		header: NetpbmHeader{
			format:    format
			binary:    options.binary
			width:     image.width
			height:    image.height
			max_value: max_value
		}
	}
	codec.write(mut stream, image.pixels)!
}

pub fn (codec Netpbm[T]) pixel_format[T]() !PixelFormat {
	return match codec.header.format {
		.bitmap {
			PixelFormat.grayscale1
		}
		.grayscale {
			if codec.header.max_value <= 255 {
				PixelFormat.grayscale8
			} else {
				PixelFormat.grayscale16
			}
		}
		.rgb {
			PixelFormat.rgb24
		}
	}
}

pub fn (mut codec Netpbm[T]) read[T](mut stream ReadStream) !PixelStorage {
	// The pinned generic reader accepts all P1..P6 headers, independently of T.
	codec.header = parse_netpbm_header(mut stream)!
	header := codec.header
	format := codec.pixel_format()!
	mut pixels := PixelStorage.init(format, netpbm_multiply(header.width, header.height))!
	match mut pixels {
		Grayscale1Pixels {
			if header.binary {
				mut bits := BitReader[BigEndian]{
					reader: unsafe { &stream }
				}
				for row := usize(0); row < header.height; row++ {
					for i := row * header.width; i < (row + 1) * header.width; i++ {
						pixels.data[int(i)].value = 1 - bits.read_bits_no_eof[BigEndian, u8](1)!
					}
					bits.align_to_byte()
				}
			} else {
				mut index := 0
				for index < pixels.data.len {
					byte := stream.take_byte()!
					if netpbm_whitespace(byte) { continue
					 }
					pixels.data[index].value = if byte == `0` { u8(1) } else { u8(0) }
					index++
				}
			}
		}
		Grayscale8Pixels {
			for mut gray in pixels.data {
				gray.value = if header.binary {
					read_netpbm_linearized(mut stream, header.max_value)!
				} else {
					u8(parse_netpbm_number(mut stream)!)
				}
			}
		}
		Grayscale16Pixels {
			for mut gray in pixels.data {
				gray.value = if header.binary {
					read_netpbm_u16(mut stream)!
				} else {
					u16(parse_netpbm_number(mut stream)!)
				}
			}
		}
		Rgb24Pixels {
			for mut rgb in pixels.data {
				if header.binary {
					rgb.r = read_netpbm_linearized(mut stream, header.max_value)!
					rgb.g = read_netpbm_linearized(mut stream, header.max_value)!
					rgb.b = read_netpbm_linearized(mut stream, header.max_value)!
				} else {
					r := parse_netpbm_number(mut stream)!
					g := parse_netpbm_number(mut stream)!
					b := parse_netpbm_number(mut stream)!
					rgb = Rgb24{
						r: netpbm_linearize(r, header.max_value)
						g: netpbm_linearize(g, header.max_value)
						b: netpbm_linearize(b, header.max_value)
					}
				}
			}
		}
		else {
			panic('unreachable')
		}
	}

	return pixels
}

pub fn (mut codec Netpbm[T]) write[T](mut stream WriteStream, pixels PixelStorage) ! {
	header := codec.header
	if header.format != netpbm_kind[T]() { return error('Unsupported') }
	number := int(header.format) + 1 + if header.binary { 3 } else { 0 }
	stream.write_all('P${number}\n'.bytes())!
	stream.write_all('# Created by zigimg\n'.bytes())!
	stream.write_all('${header.width} ${header.height}\n'.bytes())!
	if header.format != .bitmap { stream.write_all('${header.max_value}\n'.bytes())! }
	match header.format {
		.bitmap {
			if pixels !is Grayscale1Pixels { return error('Unsupported') }
			samples := pixels as Grayscale1Pixels
			if header.binary {
				mut bits := BitWriter[BigEndian]{
					writer: unsafe { &stream }
				}
				for row := usize(0); row < header.height; row++ {
					// Source checks both slices for the complete row before writing
					// any of its bits, including zero-width rows after the end.
					start := netpbm_multiply(row, header.width)
					length := usize(samples.data.len)
					if start > length {
						panic('start index ${start} is larger than end index ${length}')
					}
					remaining := length - start
					if header.width > remaining {
						// The pinned compiler combines these two slices and reports
						// the end relative to the complete sample buffer.
						panic('index out of bounds: index ${start + header.width}, len ${length}')
					}
					for i := usize(0); i < header.width; i++ {
						value := samples.data[int(start + i)].value
						assert value <= 1
						bits.write_bits[BigEndian, u8](1 - value, 1)!
					}
					bits.flush_bits()!
				}
			} else {
				for pixel in samples.data {
					assert pixel.value <= 1
					stream.write_all('${1 - pixel.value}'.bytes())!
				}
				stream.write_byte(`\n`)!
			}
		}
		.grayscale {
			match pixels {
				Grayscale8Pixels { write_netpbm_gray(mut stream, pixels.data, header.binary)! }
				Grayscale16Pixels { write_netpbm_gray(mut stream, pixels.data, header.binary)! }
				else { return error('Unsupported') }
			}
		}
		.rgb {
			if pixels !is Rgb24Pixels { return error('Unsupported') }
			samples := pixels as Rgb24Pixels
			for pixel in samples.data {
				if header.binary {
					stream.write_byte(pixel.r)!
					stream.write_byte(pixel.g)!
					stream.write_byte(pixel.b)!
				} else {
					stream.write_all('${pixel.r} ${pixel.g} ${pixel.b}\n'.bytes())!
				}
			}
		}
	}

	stream.flush()!
}

fn write_netpbm_gray[T](mut stream WriteStream, pixels []T, binary bool) ! {
	for i, pixel in pixels {
		if binary {
			$if T is Grayscale16 { stream.write_byte(u8(pixel.value >> 8))! }
			stream.write_byte(u8(pixel.value))!
		} else {
			stream.write_all('${pixel.value}'.bytes())!
			if i != pixels.len - 1 { stream.write_byte(` `)! }
		}
	}
	if !binary { stream.write_byte(`\n`)! }
}

fn parse_netpbm_header(mut stream ReadStream) !NetpbmHeader {
	magic := stream.take(2)!
	if magic[0] != `P` || magic[1] < `1` || magic[1] > `6` { return error('InvalidData') }
	mut header := NetpbmHeader{
		binary:    magic[1] >= `4`
		format:    unsafe { NetpbmFormat((magic[1] - `1`) % 3) }
		width:     0
		height:    0
		max_value: 1
	}
	header.width = parse_netpbm_number(mut stream)!
	header.height = parse_netpbm_number(mut stream)!
	if header.format != .bitmap { header.max_value = parse_netpbm_number(mut stream)! }
	return header
}

fn netpbm_whitespace(byte u8) bool {
	return byte in [u8(`\n`), `\r`, ` `, `\t`]
}

fn read_netpbm_next(mut stream ReadStream) !u8 {
	for {
		byte := stream.take_byte()!
		if byte != `#` { return byte }
		for {
			comment_byte := stream.take_byte()!
			if comment_byte in [u8(`\r`), `\n`] { break
			 }
		}
	}
	return error('unreachable')
}

fn parse_netpbm_number(mut stream ReadStream) !usize {
	mut buffer := [16]u8{}
	mut length := 0
	for {
		byte := read_netpbm_next(mut stream)!
		if netpbm_whitespace(byte) {
			if length > 0 { return parse_netpbm_decimal(buffer[..length]) }
		} else {
			if length >= buffer.len { return error('OutOfMemory') }
			buffer[length] = byte
			length++
		}
	}
	return error('unreachable')
}

fn parse_netpbm_decimal(bytes []u8) !usize {
	mut start := 0
	negative := bytes[0] == `-`
	if bytes[0] in [u8(`+`), `-`] { start++ }
	if start == bytes.len || bytes[start] == `_` || bytes.last() == `_` {
		return error('InvalidData')
	}
	mut value := usize(0)
	for byte in bytes[start..] {
		if byte == `_` { continue
		 }
		if byte < `0` || byte > `9` { return error('InvalidData') }
		digit := usize(byte - `0`)
		if negative && digit != 0 { return error('InvalidData') }
		if value > (~usize(0) - digit) / 10 { return error('InvalidData') }
		value = value * 10 + digit
	}
	return value
}

fn read_netpbm_u16(mut stream ReadStream) !u16 {
	bytes := stream.take(2)!
	return u16(bytes[0]) << 8 | u16(bytes[1])
}

fn read_netpbm_linearized(mut stream ReadStream, max_value usize) !u8 {
	value := if max_value > 255 {
		usize(read_netpbm_u16(mut stream)!)
	} else {
		usize(stream.take_byte()!)
	}
	return netpbm_linearize(value, max_value)
}

fn netpbm_multiply(left usize, right usize) usize {
	if right != 0 && left > ~usize(0) / right { panic('integer overflow') }
	return left * right
}

fn netpbm_linearize(value usize, max_value usize) u8 {
	numerator := netpbm_multiply(255, value)
	if max_value == 0 { panic('division by zero') }
	return u8(numerator / max_value)
}
