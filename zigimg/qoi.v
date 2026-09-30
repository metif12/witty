module zigimg

@[packed]
pub struct QoiColor {
pub mut:
	r u8
	g u8
	b u8
	a u8 = 255
}

pub fn (color QoiColor) eql(other QoiColor) bool {
	return color == other
}

pub fn (color QoiColor) to_rgb24() Rgb24 {
	return Rgb24{
		r: color.r
		g: color.g
		b: color.b
	}
}

pub fn (color QoiColor) to_rgba32() Rgba32 {
	return Rgba32{
		r: color.r
		g: color.g
		b: color.b
		a: color.a
	}
}

pub fn QoiColor.from[T](pixel T) QoiColor {
	$if T is Rgb24 {
		return QoiColor{
			r: pixel.r
			g: pixel.g
			b: pixel.b
		}
	} $else $if T is Rgba32 {
		return QoiColor{
			r: pixel.r
			g: pixel.g
			b: pixel.b
			a: pixel.a
		}
	} $else {
		panic('unreachable')
	}
}

pub enum QoiColorspace as u8 {
	srgb   = 0
	linear = 1
}
pub enum QoiFormat as u8 {
	rgb  = 3
	rgba = 4
}

@[packed]
pub struct QoiHeader {
pub mut:
	width      u32
	height     u32
	format     QoiFormat
	colorspace QoiColorspace
}

pub struct QoiEncoderOptions {
pub:
	colorspace QoiColorspace = .srgb
}

pub struct QOI {
pub mut:
	header QoiHeader
}

pub fn QOI.format_detect(mut stream ReadStream) !bool {
	return stream.peek(4)!.bytestr() == 'qoif'
}

pub fn QOI.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := QOI{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.width()
		height: codec.height()
		pixels: pixels
	}
}

pub fn QOI.write_image(mut stream WriteStream, image ImageUnmanaged, options QoiEncoderOptions) ! {
	format := match image.pixels {
		Rgb24Pixels { QoiFormat.rgb }
		Rgba32Pixels { QoiFormat.rgba }
		else { return error('Unsupported') }
	}

	codec := QOI{
		header: QoiHeader{
			width:      u32(image.width)
			height:     u32(image.height)
			format:     format
			colorspace: options.colorspace
		}
	}
	codec.write(mut stream, image.pixels)!
}

pub fn (codec QOI) width() usize {
	return usize(codec.header.width)
}

pub fn (codec QOI) height() usize {
	return usize(codec.header.height)
}

pub fn (codec QOI) pixel_format() !PixelFormat {
	assert u8(codec.header.format) in [u8(3), 4]
	return if codec.header.format == .rgb { PixelFormat.rgb24 } else { PixelFormat.rgba32 }
}

pub fn (mut codec QOI) read(mut stream ReadStream) !PixelStorage {
	if stream.take(4)!.bytestr() != 'qoif' { return error('InvalidData') }
	bytes := stream.take(10) or { return error('InvalidData') }
	codec.header = QoiHeader{
		width:      read_be_u32(bytes[..4])
		height:     read_be_u32(bytes[4..8])
		format:     unsafe { QoiFormat(bytes[8]) }
		colorspace: unsafe { QoiColorspace(bytes[9]) }
	}
	count := codec.width() * codec.height()
	mut pixels := PixelStorage.init(codec.pixel_format()!, count)!
	mut current := QoiColor{
		a: 255
	}
	mut lut := [64]QoiColor{init: QoiColor{
		a: 0
	}}
	mut index := usize(0)
	for index < count {
		byte := stream.take_byte()!
		mut color := current
		mut run := usize(1)
		if byte == 0xfe {
			color.r = stream.take_byte()!
			color.g = stream.take_byte()!
			color.b = stream.take_byte()!
		} else if byte == 0xff {
			color.r = stream.take_byte()!
			color.g = stream.take_byte()!
			color.b = stream.take_byte()!
			color.a = stream.take_byte()!
		} else {
			match byte >> 6 {
				0 {
					color = lut[int(byte & 63)]
				}
				1 {
					color.r = u8(int(color.r) + int((byte >> 4) & 3) - 2)
					color.g = u8(int(color.g) + int((byte >> 2) & 3) - 2)
					color.b = u8(int(color.b) + int(byte & 3) - 2)
				}
				2 {
					green := int(byte & 63) - 32
					diff := stream.take_byte()!
					color.r = u8(int(color.r) + green + int(diff >> 4) - 8)
					color.g = u8(int(color.g) + green)
					color.b = u8(int(color.b) + green + int(diff & 15) - 8)
				}
				else {
					run = usize(byte & 63) + 1
				}
			}
		}
		if index + run > count { return error('InvalidData') }
		for run > 0 {
			run--
			match mut pixels {
				Rgb24Pixels { pixels.data[int(index)] = color.to_rgb24() }
				Rgba32Pixels { pixels.data[int(index)] = color.to_rgba32() }
				else {}
			}

			index++
		}
		lut[qoi_hash(color)] = color
		current = color
	}
	return pixels
}

pub fn (codec QOI) write(mut stream WriteStream, pixels PixelStorage) ! {
	mut header := 'qoif'.bytes()
	append_be_u32(mut header, codec.header.width)
	append_be_u32(mut header, codec.header.height)
	header << [u8(codec.header.format), u8(codec.header.colorspace)]
	stream.write_all(header)!
	match pixels {
		Rgb24Pixels { qoi_write_data(mut stream, pixels.data)! }
		Rgba32Pixels { qoi_write_data(mut stream, pixels.data)! }
		else { return error('Unsupported') }
	}

	stream.write_all([u8(0), 0, 0, 0, 0, 0, 0, 1])!
	stream.flush()!
}

fn qoi_hash(color QoiColor) int {
	return (int(color.r) * 3 + int(color.g) * 5 + int(color.b) * 7 + int(color.a) * 11) & 63
}

fn qoi_write_data[T](mut stream WriteStream, data []T) ! {
	mut lut := [64]QoiColor{init: QoiColor{
		a: 0
	}}
	mut previous := QoiColor{
		a: 255
	}
	mut run := 0
	for i, value in data {
		pixel := QoiColor.from(value)
		same := pixel == previous
		if same { run++ }
		if run > 0 && (run == 62 || !same || i == data.len - 1) {
			stream.write_byte(0xc0 | u8(run - 1))!
			run = 0
		}
		if !same {
			hash := qoi_hash(pixel)
			if lut[hash] == pixel {
				stream.write_byte(u8(hash))!
			} else {
				lut[hash] = pixel
				red := int(pixel.r) - int(previous.r)
				green := int(pixel.g) - int(previous.g)
				blue := int(pixel.b) - int(previous.b)
				alpha := int(pixel.a) - int(previous.a)
				rg := red - green
				rb := blue - green
				if alpha == 0 && red >= -2 && red <= 1 && green >= -2 && green <= 1 && blue >= -2
					&& blue <= 1 {
					stream.write_byte(0x40 | (u8(red + 2) << 4) | (u8(green + 2) << 2) | u8(blue + 2))!
				} else if alpha == 0 && green >= -32 && green <= 31 && rg >= -8 && rg <= 7
					&& rb >= -8 && rb <= 7 {
					stream.write_all([u8(0x80) | u8(green + 32), (u8(rg + 8) << 4) | u8(rb + 8)])!
				} else if alpha == 0 {
					stream.write_all([u8(0xfe), pixel.r, pixel.g, pixel.b])!
				} else {
					stream.write_all([u8(0xff), pixel.r, pixel.g, pixel.b, pixel.a])!
				}
			}
		}
		previous = pixel
	}
}
