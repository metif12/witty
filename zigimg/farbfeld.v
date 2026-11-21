module zigimg

@[packed]
pub struct FarbfeldHeader {
pub mut:
	width  u32
	height u32
}

pub struct Farbfeld {
pub mut:
	header FarbfeldHeader
}

pub fn Farbfeld.format_detect(mut stream ReadStream) !bool {
	return stream.peek(8)!.bytestr() == 'farbfeld'
}

pub fn Farbfeld.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := Farbfeld{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  uint(codec.header.width)
		height: uint(codec.header.height)
		pixels: pixels
	}
}

pub fn Farbfeld.write_image(mut stream WriteStream, image ImageUnmanaged) ! {
	// Source casts both dimensions before checking the storage or writing bytes.
	if image.width > 0xffffffff || image.height > 0xffffffff {
		panic('integer does not fit in destination type')
	}
	codec := Farbfeld{
		header: FarbfeldHeader{
			width:  u32(image.width)
			height: u32(image.height)
		}
	}
	codec.write(mut stream, image.pixels)!
}

pub fn (mut codec Farbfeld) read(mut stream ReadStream) !PixelStorage {
	magic := stream.take(8) or { return error('InvalidData') }
	if magic.bytestr() != 'farbfeld' { return error('InvalidData') }
	bytes := stream.take(8) or { return error('InvalidData') }
	codec.header = FarbfeldHeader{
		width:  read_be_u32(bytes[..4])
		height: read_be_u32(bytes[4..])
	}
	mut data := []Rgba64{len: int(uint(codec.header.width) * uint(codec.header.height))}
	for i in 0 .. data.len {
		pixel := stream.take(8) or { return error('InvalidData') }
		data[i] = Rgba64{
			r: u16(pixel[0]) << 8 | pixel[1]
			g: u16(pixel[2]) << 8 | pixel[3]
			b: u16(pixel[4]) << 8 | pixel[5]
			a: u16(pixel[6]) << 8 | pixel[7]
		}
	}
	return Rgba64Pixels{
		data: data
	}
}

pub fn (codec Farbfeld) write(mut stream WriteStream, pixels PixelStorage) ! {
	data := match pixels {
		Rgba64Pixels { pixels.data }
		else { return error('Unsupported') }
	}

	mut header := 'farbfeld'.bytes()
	append_be_u32(mut header, codec.header.width)
	append_be_u32(mut header, codec.header.height)
	stream.write_all(header)!
	for pixel in data {
		stream.write_all([u8(pixel.r >> 8), u8(pixel.r), u8(pixel.g >> 8), u8(pixel.g),
			u8(pixel.b >> 8), u8(pixel.b), u8(pixel.a >> 8), u8(pixel.a)])!
	}
	stream.flush()!
}
