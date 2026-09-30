module zigimg

import strconv
import zig_fmt

pub enum PamTupleType {
	mono
	mono_a
	gray
	gray_a
	rgb
	rgb_a
}

pub fn PamTupleType.from_string(value string) !PamTupleType {
	return match value {
		'BLACKANDWHITE' { PamTupleType.mono }
		'BLACKANDWHITE_ALPHA' { PamTupleType.mono_a }
		'GRAYSCALE' { PamTupleType.gray }
		'GRAYSCALE_ALPHA' { PamTupleType.gray_a }
		'RGB' { PamTupleType.rgb }
		'RGB_ALPHA' { PamTupleType.rgb_a }
		else { return error('Unsupported') }
	}
}

pub fn (tuple PamTupleType) to_string() string {
	return match tuple {
		.mono { 'BLACKANDWHITE' }
		.mono_a { 'BLACKANDWHITE_ALPHA' }
		.gray { 'GRAYSCALE' }
		.gray_a { 'GRAYSCALE_ALPHA' }
		.rgb { 'RGB' }
		.rgb_a { 'RGB_ALPHA' }
	}
}

pub struct PamHeader {
pub mut:
	width      usize
	height     usize
	depth      usize
	maxval     u16
	tuple_type PamTupleType
	comments   []string
}

fn pam_whitespace(byte u8) bool {
	return byte == ` ` || (byte >= 9 && byte <= 13)
}

fn pam_next_token(line []u8, position int) ([]u8, int) {
	mut index := position
	for index < line.len && pam_whitespace(line[index]) {
		index++
	}
	start := index
	for index < line.len && !pam_whitespace(line[index]) {
		index++
	}
	return unsafe { line[start..index] }, index
}

fn pam_read_line(mut stream ReadStream) ![]u8 {
	mut line := []u8{cap: 32}
	for {
		byte := stream.take_byte()!
		if byte == `\n` { return line }
		line << byte
	}
	return error('unreachable')
}

pub fn PamHeader.read(mut stream ReadStream) !PamHeader {
	mut header := PamHeader{}
	mut has_width := false
	mut has_height := false
	mut has_depth := false
	mut has_maxval := false
	mut has_tuple := false
	for {
		line := pam_read_line(mut stream)!
		if line.len == 0 { continue
		 }
		if line[0] == `#` {
			header.comments << line[1..].bytestr()
			continue
		}
		first, token_end := pam_next_token(line, 0)
		mut index := token_end
		if first.len == 0 { continue
		 }
		if first.len > 8 { return error('InvalidData') }
		key := first.bytestr()
		if key == 'ENDHDR' { break
		 }
		if key == 'TUPLTYPE' {
			// TokenIterator.rest skips leading delimiters but retains all trailing
			// bytes, including spaces and CR in a CRLF tuple-type line.
			for index < line.len && pam_whitespace(line[index]) {
				index++
			}
			header.tuple_type = PamTupleType.from_string(line[index..].bytestr())!
			has_tuple = true
			continue
		}
		second, _ := pam_next_token(line, index)
		if second.len == 0 { return error('InvalidData') }
		limit := if key == 'MAXVAL' { u64(65535) } else { u64(~usize(0)) }
		value := zig_fmt.parse_unsigned(second.bytestr(), limit, 10) or {
			return error('InvalidData')
		}
		match key {
			'WIDTH' {
				header.width = usize(value)
				has_width = true
			}
			'HEIGHT' {
				header.height = usize(value)
				has_height = true
			}
			'DEPTH' {
				header.depth = usize(value)
				has_depth = true
			}
			'MAXVAL' {
				header.maxval = u16(value)
				has_maxval = true
			}
			else {
				return error('InvalidData')
			}
		}
	}
	if !has_width || !has_height || !has_depth || !has_maxval || header.width < 1
		|| header.height < 1 || header.maxval < 1 {
		return error('InvalidData')
	}
	if !has_tuple {
		header.tuple_type = match header.depth {
			1 {
				if header.maxval == 1 { PamTupleType.mono } else { PamTupleType.gray }
			}
			2 {
				if header.maxval == 1 { PamTupleType.mono_a } else { PamTupleType.gray_a }
			}
			3 {
				PamTupleType.rgb
			}
			4 {
				PamTupleType.rgb_a
			}
			else {
				return error('Unsupported')
			}
		}
	}
	matches := match header.tuple_type {
		.mono { header.depth == 1 && header.maxval == 1 }
		.mono_a { header.depth == 2 && header.maxval == 1 }
		.gray { header.depth == 1 }
		.gray_a { header.depth == 2 }
		.rgb { header.depth == 3 }
		.rgb_a { header.depth == 4 }
	}

	if !matches { return error('InvalidData') }
	return header
}

pub fn (header PamHeader) write(mut stream WriteStream) ! {
	stream.write_all('P7\n'.bytes())!
	for comment in header.comments {
		stream.write_all('#${comment}\n'.bytes())!
	}
	stream.write_all(('WIDTH ${header.width}\nHEIGHT ${header.height}\n' +
		'DEPTH ${header.depth}\nMAXVAL ${header.maxval}\n' +
		'TUPLTYPE ${header.tuple_type.to_string()}\nENDHDR\n').bytes())!
}

pub fn (header PamHeader) has_two_bytes_per_component() bool {
	return header.maxval > 255
}

pub fn (header PamHeader) get_pixel_format() PixelFormat {
	two := header.has_two_bytes_per_component()
	return match header.tuple_type {
		.mono, .mono_a {
			PixelFormat.grayscale1
		}
		.gray {
			if two {
				PixelFormat.grayscale16
			} else {
				PixelFormat.grayscale8
			}
		}
		.gray_a {
			if two {
				PixelFormat.grayscale16_alpha
			} else {
				PixelFormat.grayscale8_alpha
			}
		}
		.rgb {
			if two {
				PixelFormat.rgb48
			} else {
				PixelFormat.rgb24
			}
		}
		.rgb_a {
			if two {
				PixelFormat.rgba64
			} else {
				PixelFormat.rgba32
			}
		}
	}
}

pub fn (header PamHeader) init_image() !ImageUnmanaged {
	return ImageUnmanaged.create(header.width, header.height, header.get_pixel_format())
}

pub fn PamHeader.from_image(image ImageUnmanaged) !PamHeader {
	mut header := PamHeader{
		width:  image.width
		height: image.height
	}
	match image.pixel_format() {
		.grayscale1 {
			header.depth = 1
			header.maxval = 1
			header.tuple_type = .mono
		}
		.grayscale2 {
			header.depth = 1
			header.maxval = 3
			header.tuple_type = .gray
		}
		.grayscale4 {
			header.depth = 1
			header.maxval = 15
			header.tuple_type = .gray
		}
		.grayscale8 {
			header.depth = 1
			header.maxval = 255
			header.tuple_type = .gray
		}
		.grayscale16 {
			header.depth = 1
			header.maxval = 65535
			header.tuple_type = .gray
		}
		.grayscale8_alpha {
			header.depth = 2
			header.maxval = 255
			header.tuple_type = .gray_a
		}
		.grayscale16_alpha {
			header.depth = 2
			header.maxval = 65535
			header.tuple_type = .gray_a
		}
		.rgb555, .bgr555 {
			header.depth = 3
			header.maxval = 31
			header.tuple_type = .rgb
		}
		.rgb24, .bgr24 {
			header.depth = 3
			header.maxval = 255
			header.tuple_type = .rgb
		}
		.rgba32, .bgra32 {
			header.depth = 4
			header.maxval = 255
			header.tuple_type = .rgb_a
		}
		.rgb48 {
			header.depth = 3
			header.maxval = 65535
			header.tuple_type = .rgb
		}
		.rgba64 {
			header.depth = 4
			header.maxval = 65535
			header.tuple_type = .rgb_a
		}
		else {
			return error('Unsupported')
		}
	}

	return header
}

pub struct PamEncoderOptions {
pub:
	comments                []string
	add_duration_as_comment bool
}

pub struct PAM {}

pub fn PAM.format_detect(mut stream ReadStream) !bool {
	return stream.peek(3)! == 'P7\n'.bytes()
}

pub fn PAM.read(mut stream ReadStream) ![]ImageUnmanaged {
	mut images := []ImageUnmanaged{}
	for {
		image, found := pam_read_frame(mut stream)!
		if !found { break
		 }
		images << image
	}
	return images
}

pub fn PAM.read_image(mut stream ReadStream) !ImageUnmanaged {
	images := PAM.read(mut stream)!
	if images.len == 0 { return error('InvalidData') }
	mut image := images[0]
	for frame in images[1..] {
		if frame.width != image.width || frame.height != image.height
			|| frame.pixel_format() != image.pixel_format() {
			return error('Unsupported')
		}
		image.animation.frames << AnimationFrame{
			pixels:   frame.pixels
			duration: 0
		}
	}
	return image
}

fn pam_map_value(value u16, source_max u16, destination_max u16) !u16 {
	if value > source_max { return error('InvalidData') }
	if source_max == destination_max { return value }
	return u16(u32(destination_max) * u32(value) / u32(source_max))
}

fn pam_read_component(mut stream ReadStream, header PamHeader) !u16 {
	if header.has_two_bytes_per_component() {
		bytes := stream.take(2)!
		return pam_map_value(u16(bytes[0]) | u16(bytes[1]) << 8, header.maxval, 65535)
	}
	return pam_map_value(u16(stream.take_byte()!), header.maxval, 255)
}

fn pam_read_frame(mut stream ReadStream) !(ImageUnmanaged, bool) {
	magic := stream.take(3) or {
		if err.msg() == 'EndOfStream' { return ImageUnmanaged{}, false }
		return err
	}
	if magic != 'P7\n'.bytes() { return error('InvalidData') }
	header := PamHeader.read(mut stream)!
	mut image := header.init_image()!
	for index := 0; index < int(image.width * image.height); index++ {
		match mut image.pixels {
			Grayscale1Pixels {
				mut value := pam_map_value(stream.take_byte()!, 1, 1)!
				if header.tuple_type != .mono { value &= pam_map_value(stream.take_byte()!, 1, 1)! }
				image.pixels.data[index].value = u8(value)
			}
			Grayscale8Pixels {
				image.pixels.data[index].value = u8(pam_read_component(mut stream, header)!)
			}
			Grayscale16Pixels {
				image.pixels.data[index].value = pam_read_component(mut stream, header)!
			}
			Grayscale8AlphaPixels {
				image.pixels.data[index] = Grayscale8Alpha{
					value: u8(pam_read_component(mut stream, header)!)
					alpha: u8(pam_read_component(mut stream, header)!)
				}
			}
			Grayscale16AlphaPixels {
				image.pixels.data[index] = Grayscale16Alpha{
					value: pam_read_component(mut stream, header)!
					alpha: pam_read_component(mut stream, header)!
				}
			}
			Rgb24Pixels {
				image.pixels.data[index] = Rgb24{
					r: u8(pam_read_component(mut stream, header)!)
					g: u8(pam_read_component(mut stream, header)!)
					b: u8(pam_read_component(mut stream, header)!)
				}
			}
			Rgba32Pixels {
				image.pixels.data[index] = Rgba32{
					r: u8(pam_read_component(mut stream, header)!)
					g: u8(pam_read_component(mut stream, header)!)
					b: u8(pam_read_component(mut stream, header)!)
					a: u8(pam_read_component(mut stream, header)!)
				}
			}
			Rgb48Pixels {
				image.pixels.data[index] = Rgb48{
					r: pam_read_component(mut stream, header)!
					g: pam_read_component(mut stream, header)!
					b: pam_read_component(mut stream, header)!
				}
			}
			Rgba64Pixels {
				image.pixels.data[index] = Rgba64{
					r: pam_read_component(mut stream, header)!
					g: pam_read_component(mut stream, header)!
					b: pam_read_component(mut stream, header)!
					a: pam_read_component(mut stream, header)!
				}
			}
			else {
				panic('unreachable')
			}
		}
	}
	return image, true
}

pub fn PAM.write_image(mut stream WriteStream, image ImageUnmanaged, options PamEncoderOptions) ! {
	mut comments := options.comments.clone()
	if options.add_duration_as_comment && image.is_animation() {
		comments << 'loop count: ${image.animation.loop_count}'
	}
	PAM.write_frame(mut stream, image, PamEncoderOptions{ comments: comments })!
	if options.add_duration_as_comment && image.is_animation() { comments.pop() }
	for frame in image.animation.frames {
		if options.add_duration_as_comment {
			comments << 'duration: ${pam_format_duration(frame.duration)}'
		}
		frame_image := ImageUnmanaged{
			pixels: frame.pixels
			width:  image.width
			height: image.height
		}
		PAM.write_frame(mut stream, frame_image, PamEncoderOptions{ comments: comments })!
		if options.add_duration_as_comment { comments.pop() }
	}
	stream.flush()!
}

pub fn PAM.write_frame(mut stream WriteStream, image ImageUnmanaged, options PamEncoderOptions) ! {
	mut header := PamHeader.from_image(image)!
	header.comments = options.comments
	header.write(mut stream)!
	for index := 0; index < int(image.width * image.height); index++ {
		match image.pixels {
			Grayscale1Pixels {
				assert image.pixels.data[index].value <= 1
				stream.write_byte(image.pixels.data[index].value)!
			}
			Grayscale4Pixels {
				assert image.pixels.data[index].value <= 15
				stream.write_byte(image.pixels.data[index].value)!
			}
			Grayscale8Pixels {
				stream.write_byte(image.pixels.data[index].value)!
			}
			Grayscale16Pixels {
				pam_write_u16(mut stream, image.pixels.data[index].value)!
			}
			Grayscale8AlphaPixels {
				stream.write_byte(image.pixels.data[index].value)!
				stream.write_byte(image.pixels.data[index].alpha)!
			}
			Grayscale16AlphaPixels {
				pam_write_u16(mut stream, image.pixels.data[index].value)!
				pam_write_u16(mut stream, image.pixels.data[index].alpha)!
			}
			Rgb555Pixels {
				pixel := image.pixels.data[index]
				stream.write_byte(u8((pixel.raw >> 10) & 31))!
				stream.write_byte(u8((pixel.raw >> 5) & 31))!
				stream.write_byte(u8(pixel.raw & 31))!
			}
			Bgr555Pixels {
				pixel := image.pixels.data[index]
				stream.write_byte(u8(pixel.raw & 31))!
				stream.write_byte(u8((pixel.raw >> 5) & 31))!
				stream.write_byte(u8((pixel.raw >> 10) & 31))!
			}
			Rgb24Pixels {
				pam_write_rgb(mut stream, image.pixels.data[index])!
			}
			Bgr24Pixels {
				pam_write_rgb(mut stream, image.pixels.data[index])!
			}
			Rgba32Pixels {
				pam_write_rgb(mut stream, image.pixels.data[index])!
				stream.write_byte(image.pixels.data[index].a)!
			}
			Bgra32Pixels {
				pam_write_rgb(mut stream, image.pixels.data[index])!
				stream.write_byte(image.pixels.data[index].a)!
			}
			Rgb48Pixels {
				pam_write_rgb(mut stream, image.pixels.data[index])!
			}
			Rgba64Pixels {
				pam_write_rgb(mut stream, image.pixels.data[index])!
				pam_write_u16(mut stream, image.pixels.data[index].a)!
			}
			// Pinned fromImage accepts grayscale2, but writeFrame omits it.
			else {
				panic('unreachable')
			}
		}
	}
}

fn pam_write_u16(mut stream WriteStream, value u16) ! {
	stream.write_all([u8(value), u8(value >> 8)])!
}

fn pam_write_rgb[T](mut stream WriteStream, pixel T) ! {
	$if T is Rgb48 || T is Rgba64 {
		pam_write_u16(mut stream, pixel.r)!
		pam_write_u16(mut stream, pixel.g)!
		pam_write_u16(mut stream, pixel.b)!
	} $else {
		stream.write_byte(pixel.r)!
		stream.write_byte(pixel.g)!
		stream.write_byte(pixel.b)!
	}
}

fn pam_format_duration(value f32) string {
	bits := unsafe { *(&u32(&value)) }
	negative := bits >> 31 != 0
	sign := if negative { '-' } else { '' }
	if bits & 0x7f800000 == 0x7f800000 {
		return sign + if bits & 0x7fffff == 0 {
			'inf'
		} else {
			'nan'
		}
	}
	// Zig's std.fmt uses Ryu's shortest mantissa and decimal output for {d}.
	// V exposes the same conversion in scientific form; place its decimal
	// point explicitly to preserve zero signs and avoid notation thresholds.
	scientific := strconv.f32_to_str(value, 8)
	parts := scientific.split('e')
	digits := parts[0].trim_left('-').replace('.', '')
	point := parts[1].int() + 1
	if point <= 0 { return sign + '0.' + '0'.repeat(-point) + digits }
	if point >= digits.len { return sign + digits + '0'.repeat(point - digits.len) }
	return sign + digits[..point] + '.' + digits[point..]
}
