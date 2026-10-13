module zigimg

// Packed TGA records from locked zigimg. Sentinel arrays include their final
// byte in V; packed flags retain the source word through typed accessors.
@[packed]
pub struct TGAImageType {
pub mut:
	raw u8
}

pub fn (value TGAImageType) indexed() bool {
	return value.raw & 1 != 0
}

pub fn (value TGAImageType) truecolor() bool {
	return value.raw & 2 != 0
}

pub fn (value TGAImageType) pad0() bool {
	return value.raw & 4 != 0
}

pub fn (value TGAImageType) run_length() bool {
	return value.raw & 8 != 0
}

pub fn (value TGAImageType) pad1() u8 {
	return value.raw >> 4
}

pub fn (mut value TGAImageType) set_indexed(indexed bool) {
	value.raw = (value.raw & 0xfe) | u8(indexed)
}

pub fn (mut value TGAImageType) set_truecolor(truecolor bool) {
	value.raw = (value.raw & 0xfd) | (u8(truecolor) << 1)
}

pub fn (mut value TGAImageType) set_pad0(pad bool) {
	value.raw = (value.raw & 0xfb) | (u8(pad) << 2)
}

pub fn (mut value TGAImageType) set_run_length(run_length bool) {
	value.raw = (value.raw & 0xf7) | (u8(run_length) << 3)
}

pub fn (mut value TGAImageType) set_pad1(pad u8) {
	if pad > 15 { panic('integer does not fit in destination type') }
	value.raw = (value.raw & 15) | (pad << 4)
}

@[packed]
pub struct TGAColorMapSpec {
pub mut:
	first_entry_index u16
	length            u16
	bit_depth         u8
}

@[packed]
pub struct TGADescriptor {
pub mut:
	raw u8
}

pub fn (value TGADescriptor) num_attributes_bit() u8 {
	return value.raw & 15
}

pub fn (value TGADescriptor) right_to_left() bool {
	return value.raw & 16 != 0
}

pub fn (value TGADescriptor) top_to_bottom() bool {
	return value.raw & 32 != 0
}

pub fn (value TGADescriptor) pad() u8 {
	return value.raw >> 6
}

pub fn (mut value TGADescriptor) set_num_attributes_bit(bits u8) {
	if bits > 15 { panic('integer does not fit in destination type') }
	value.raw = (value.raw & 0xf0) | bits
}

pub fn (mut value TGADescriptor) set_right_to_left(right_to_left bool) {
	value.raw = (value.raw & 0xef) | (u8(right_to_left) << 4)
}

pub fn (mut value TGADescriptor) set_top_to_bottom(top_to_bottom bool) {
	value.raw = (value.raw & 0xdf) | (u8(top_to_bottom) << 5)
}

pub fn (mut value TGADescriptor) set_pad(pad u8) {
	if pad > 3 { panic('integer does not fit in destination type') }
	value.raw = (value.raw & 63) | (pad << 6)
}

@[packed]
pub struct TGAImageSpec {
pub mut:
	origin_x      u16
	origin_y      u16
	width         u16
	height        u16
	bit_per_pixel u8
	descriptor    TGADescriptor
}

@[packed]
pub struct TGAHeader {
pub mut:
	id_length      u8
	has_color_map  u8
	image_type     TGAImageType
	color_map_spec TGAColorMapSpec
	image_spec     TGAImageSpec
}

pub fn (header TGAHeader) is_valid() bool {
	return header.has_color_map in [u8(0), 1] && !header.image_type.pad0()
		&& header.image_type.pad1() == 0
		&& header.color_map_spec.bit_depth in [u8(0), 15, 16, 24, 32]
}

@[packed]
pub struct TGAExtensionComment {
pub mut:
	lines [4][81]u8
}

@[packed]
pub struct TGAExtensionSoftwareVersion {
pub mut:
	number u16
	letter u8 = ` `
}

@[packed]
pub struct TGAExtensionTimestamp {
pub mut:
	month  u16
	day    u16
	year   u16
	hour   u16
	minute u16
	second u16
}

@[packed]
pub struct TGAExtensionJobTime {
pub mut:
	hours   u16
	minutes u16
	seconds u16
}

@[packed]
pub struct TGAExtensionRatio {
pub mut:
	numerator   u16
	denominator u16
}

pub enum TGAAttributeType as u8 {
	no_alpha                 = 0
	undefined_alpha_ignore   = 1
	undefined_alpha_retained = 2
	useful_alpha_channel     = 3
	premultipled_alpha       = 4
}

@[packed]
pub struct TGAExtension {
pub mut:
	extension_size          u16 = 495
	author_name             [41]u8
	author_comment          TGAExtensionComment
	timestamp               TGAExtensionTimestamp
	job_id                  [41]u8
	job_time                TGAExtensionJobTime
	software_id             [41]u8
	software_version        TGAExtensionSoftwareVersion
	key_color               Bgra32 = Bgra32{
		a: 0
	}
	pixel_aspect            TGAExtensionRatio
	gamma_value             TGAExtensionRatio
	color_correction_offset u32
	postage_stamp_offset    u32
	scanline_offset         u32
	attributes              TGAAttributeType
}

@[packed]
pub struct TGAFooter {
pub mut:
	extension_offset u32
	dev_area_offset  u32
	signature        [16]u8
	dot              u8 = `.`
	null_value       u8
}

pub const tga_signature = 'TRUEVISION-XFILE'

pub struct TgaEncoderOptions {
pub mut:
	rle_compressed      bool = true
	top_to_bottom_image bool = true
	color_map_depth     u8   = 24
	image_id            []u8
	author_name         string
	author_comment      TGAExtensionComment
	timestamp           TGAExtensionTimestamp
	job_id              string
	job_time            TGAExtensionJobTime
	software_id         string
	software_version    TGAExtensionSoftwareVersion
}

pub struct TGA {
pub mut:
	header    TGAHeader
	id        FixedStorage256[u8]
	extension ?TGAExtension
}

fn tga_u16(bytes []u8, offset int) u16 {
	return u16(bytes[offset]) | u16(bytes[offset + 1]) << 8
}

fn tga_u32(bytes []u8, offset int) u32 {
	return u32(bytes[offset]) | u32(bytes[offset + 1]) << 8 | u32(bytes[offset + 2]) << 16 | u32(bytes[
		offset + 3]) << 24
}

fn tga_append_u16(mut bytes []u8, word u16) {
	bytes << [u8(word), u8(word >> 8)]
}

fn tga_append_u32(mut bytes []u8, word u32) {
	bytes << [u8(word), u8(word >> 8), u8(word >> 16), u8(word >> 24)]
}

fn tga_header_read(bytes []u8) TGAHeader {
	assert bytes.len == 18
	return TGAHeader{
		id_length:      bytes[0]
		has_color_map:  bytes[1]
		image_type:     TGAImageType{
			raw: bytes[2]
		}
		color_map_spec: TGAColorMapSpec{
			first_entry_index: tga_u16(bytes, 3)
			length:            tga_u16(bytes, 5)
			bit_depth:         bytes[7]
		}
		image_spec:     TGAImageSpec{
			origin_x:      tga_u16(bytes, 8)
			origin_y:      tga_u16(bytes, 10)
			width:         tga_u16(bytes, 12)
			height:        tga_u16(bytes, 14)
			bit_per_pixel: bytes[16]
			descriptor:    TGADescriptor{
				raw: bytes[17]
			}
		}
	}
}

fn tga_header_bytes(header TGAHeader) []u8 {
	mut bytes := [header.id_length, header.has_color_map, header.image_type.raw]
	tga_append_u16(mut bytes, header.color_map_spec.first_entry_index)
	tga_append_u16(mut bytes, header.color_map_spec.length)
	bytes << header.color_map_spec.bit_depth
	for word in [header.image_spec.origin_x, header.image_spec.origin_y, header.image_spec.width,
		header.image_spec.height] {
		tga_append_u16(mut bytes, word)
	}
	bytes << [header.image_spec.bit_per_pixel, header.image_spec.descriptor.raw]
	return bytes
}

fn tga_footer_read(bytes []u8) TGAFooter {
	mut footer := TGAFooter{
		extension_offset: tga_u32(bytes, 0)
		dev_area_offset:  tga_u32(bytes, 4)
		dot:              bytes[24]
		null_value:       bytes[25]
	}
	for i in 0 .. 16 {
		footer.signature[i] = bytes[i + 8]
	}
	return footer
}

fn tga_footer_bytes(footer TGAFooter) []u8 {
	mut bytes := []u8{cap: 26}
	tga_append_u32(mut bytes, footer.extension_offset)
	tga_append_u32(mut bytes, footer.dev_area_offset)
	for byte in footer.signature {
		bytes << byte
	}
	bytes << [footer.dot, footer.null_value]
	return bytes
}

fn tga_extension_read(bytes []u8) TGAExtension {
	assert bytes.len == 495
	mut extension := TGAExtension{
		extension_size:          tga_u16(bytes, 0)
		timestamp:               TGAExtensionTimestamp{
			month:  tga_u16(bytes, 367)
			day:    tga_u16(bytes, 369)
			year:   tga_u16(bytes, 371)
			hour:   tga_u16(bytes, 373)
			minute: tga_u16(bytes, 375)
			second: tga_u16(bytes, 377)
		}
		job_time:                TGAExtensionJobTime{
			hours:   tga_u16(bytes, 420)
			minutes: tga_u16(bytes, 422)
			seconds: tga_u16(bytes, 424)
		}
		software_version:        TGAExtensionSoftwareVersion{
			number: tga_u16(bytes, 467)
			letter: bytes[469]
		}
		key_color:               Bgra32{
			b: bytes[470]
			g: bytes[471]
			r: bytes[472]
			a: bytes[473]
		}
		pixel_aspect:            TGAExtensionRatio{
			numerator:   tga_u16(bytes, 474)
			denominator: tga_u16(bytes, 476)
		}
		gamma_value:             TGAExtensionRatio{
			numerator:   tga_u16(bytes, 478)
			denominator: tga_u16(bytes, 480)
		}
		color_correction_offset: tga_u32(bytes, 482)
		postage_stamp_offset:    tga_u32(bytes, 486)
		scanline_offset:         tga_u32(bytes, 490)
		attributes:              unsafe { TGAAttributeType(bytes[494]) }
	}
	for i in 0 .. 41 {
		extension.author_name[i] = bytes[2 + i]
		extension.job_id[i] = bytes[379 + i]
		extension.software_id[i] = bytes[426 + i]
	}
	for row in 0 .. 4 {
		for col in 0 .. 81 {
			extension.author_comment.lines[row][col] = bytes[43 + row * 81 + col]
		}
	}
	return extension
}

fn tga_extension_bytes(extension TGAExtension) []u8 {
	mut bytes := []u8{cap: 495}
	tga_append_u16(mut bytes, extension.extension_size)
	for byte in extension.author_name {
		bytes << byte
	}
	for row in extension.author_comment.lines {
		for byte in row {
			bytes << byte
		}
	}
	for word in [extension.timestamp.month, extension.timestamp.day, extension.timestamp.year,
		extension.timestamp.hour, extension.timestamp.minute, extension.timestamp.second] {
		tga_append_u16(mut bytes, word)
	}
	for byte in extension.job_id {
		bytes << byte
	}
	for word in [extension.job_time.hours, extension.job_time.minutes, extension.job_time.seconds] {
		tga_append_u16(mut bytes, word)
	}
	for byte in extension.software_id {
		bytes << byte
	}
	tga_append_u16(mut bytes, extension.software_version.number)
	bytes << [extension.software_version.letter, extension.key_color.b, extension.key_color.g,
		extension.key_color.r, extension.key_color.a]
	for word in [extension.pixel_aspect.numerator, extension.pixel_aspect.denominator, extension.gamma_value.numerator,
		extension.gamma_value.denominator] {
		tga_append_u16(mut bytes, word)
	}
	for word in [extension.color_correction_offset, extension.postage_stamp_offset, extension.scanline_offset] {
		tga_append_u32(mut bytes, word)
	}
	bytes << u8(extension.attributes)
	assert bytes.len == 495
	return bytes
}

pub fn TGA.format_detect(mut stream ReadStream) !bool {
	defer { stream.seek_to(0) or {} }
	end := stream.get_end_pos()!
	if end > 26 {
		stream.seek_to(end - 26)!
		footer := tga_footer_read(stream.peek(26)!)
		if footer.dot == `.` && footer.null_value == 0
			&& footer.signature[..] == tga_signature.bytes() {
			return true
		}
	}
	if end > 18 {
		stream.seek_to(0)!
		return tga_header_read(stream.peek(18)!).is_valid()
	}
	return false
}

pub fn (codec TGA) width() usize {
	return usize(codec.header.image_spec.width)
}

pub fn (codec TGA) height() usize {
	return usize(codec.header.image_spec.height)
}

pub fn (codec TGA) pixel_format() !PixelFormat {
	if codec.header.image_type.indexed() {
		return if codec.header.image_type.truecolor() {
			PixelFormat.grayscale8
		} else {
			PixelFormat.indexed8
		}
	}
	if codec.header.image_type.truecolor() {
		match codec.header.image_spec.bit_per_pixel {
			16 { return PixelFormat.rgb555 }
			24 { return PixelFormat.bgr24 }
			32 { return PixelFormat.bgra32 }
			else {}
		}
	}
	return error('Unsupported')
}

pub fn TGA.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := TGA{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.width()
		height: codec.height()
		pixels: pixels
	}
}

fn (codec TGA) palette_end() int {
	// The source adds the two u16 fields before assigning to usize.
	end := u32(codec.header.color_map_spec.first_entry_index) + codec.header.color_map_spec.length
	if end > 65535 { panic('integer overflow') }
	return int(end)
}

pub fn (mut codec TGA) read(mut stream ReadStream) !PixelStorage {
	end := stream.get_end_pos()!
	if end < 26 { return error('InvalidData') }
	stream.seek_to(end - 26)!
	footer := tga_footer_read(stream.take(26)!)
	// Unlike detection, decoding checks only the signature.
	if footer.signature[..] == tga_signature.bytes() && footer.extension_offset > 0 {
		stream.seek_to(footer.extension_offset)!
		codec.extension = tga_extension_read(stream.take(495)!)
	}
	stream.seek_to(0)!
	codec.header = tga_header_read(stream.take(18)!)
	if !codec.header.is_valid() { return error('InvalidData') }
	if codec.header.id_length > 0 {
		codec.id.resize(usize(codec.header.id_length))
		stream.read_slice_all(mut codec.id.data) or { return error('InvalidData') }
	}
	format := codec.pixel_format()!
	mut pixels := PixelStorage.init(format, codec.width() * codec.height())!
	mut input := TgaInput{}
	input.compressed = codec.header.image_type.run_length()
	if input.compressed {
		// This expression is byte arithmetic in the locked source.
		if codec.header.image_spec.bit_per_pixel > 248 { panic('integer overflow') }
		input.bytes_per_pixel = int((u16(codec.header.image_spec.bit_per_pixel) + 7) / 8)
		input.repeat_data = []u8{len: input.bytes_per_pixel}
	}
	match mut pixels {
		IndexedStorage8 {
			depth := codec.header.color_map_spec.bit_depth
			if depth !in [u8(15), 16, 24] { return error('Unsupported') }
			pixels.resize_palette(usize(codec.header.color_map_spec.length))
			for index in int(codec.header.color_map_spec.first_entry_index) .. codec.palette_end() {
				if depth == 24 {
					// Source forms the palette destination before reading its byte.
					if index >= pixels.palette.len { panic('index out of bounds') }
					pixels.palette[index].b = stream.take_byte()!
					pixels.palette[index].g = stream.take_byte()!
					pixels.palette[index].r = stream.take_byte()!
					pixels.palette[index].a = 255
				} else {
					raw := tga_u16(stream.take(2)!, 0)
					// Rounded ScaleValue(u8), rather than bit replication.
					pixels.palette[index].r = u8((u32((raw >> 10) & 31) * 255 + 15) / 31)
					pixels.palette[index].g = u8((u32((raw >> 5) & 31) * 255 + 15) / 31)
					pixels.palette[index].b = u8((u32(raw & 31) * 255 + 15) / 31)
					pixels.palette[index].a = 255
				}
			}
		}
		else {}
	}

	width := int(codec.width())
	height := int(codec.height())
	for y in 0 .. height {
		row := if codec.header.image_spec.descriptor.top_to_bottom() { y } else { height - y - 1 }
		for x in 0 .. width {
			index := row * width + x
			match mut pixels {
				Grayscale8Pixels {
					pixels.data[index].value = input.take_byte(mut stream)!
				}
				IndexedStorage8 {
					pixels.indices[index] = input.take_byte(mut stream)!
				}
				Rgb555Pixels {
					pixels.data[index].raw = tga_u16(input.take(mut stream, 2)!, 0) & 0x7fff
				}
				Bgr24Pixels {
					pixels.data[index].b = input.take_byte(mut stream)!
					pixels.data[index].g = input.take_byte(mut stream)!
					pixels.data[index].r = input.take_byte(mut stream)!
				}
				Bgra32Pixels {
					pixels.data[index].b = input.take_byte(mut stream)!
					pixels.data[index].g = input.take_byte(mut stream)!
					pixels.data[index].r = input.take_byte(mut stream)!
					pixels.data[index].a = input.take_byte(mut stream)!
					if extension := codec.extension {
						if extension.attributes != .useful_alpha_channel {
							pixels.data[index].a = 255
						}
					}
				}
				else {
					return error('Unsupported')
				}
			}
		}
	}
	return pixels
}

pub fn TGA.write_image(mut stream WriteStream, image ImageUnmanaged, options TgaEncoderOptions) ! {
	if image.width > 65535 || image.height > 65535 || options.color_map_depth !in [u8(16), 24] {
		return error('Unsupported')
	}
	mut codec := TGA{}
	codec.header.image_spec.width = u16(image.width)
	codec.header.image_spec.height = u16(image.height)
	codec.header.image_type.set_run_length(options.rle_compressed)
	codec.header.image_spec.descriptor.set_top_to_bottom(options.top_to_bottom_image)
	if options.image_id.len > 0 {
		if options.image_id.len > 256 { return error('Unsupported') }
		codec.header.id_length = u8(options.image_id.len)
		codec.id.resize(usize(options.image_id.len))
		copy(mut codec.id.data, options.image_id)
	}
	if options.author_name.len >= 40 || options.job_id.len >= 40 || options.software_id.len >= 40 {
		return error('Unsupported')
	}
	mut extension := TGAExtension{
		author_comment:   options.author_comment
		timestamp:        options.timestamp
		job_time:         options.job_time
		software_version: options.software_version
	}
	for i, byte in options.author_name.bytes() {
		extension.author_name[i] = byte
	}
	for i, byte in options.job_id.bytes() {
		extension.job_id[i] = byte
	}
	for i, byte in options.software_id.bytes() {
		extension.software_id[i] = byte
	}
	match image.pixels {
		Grayscale8Pixels {
			codec.header.image_type.set_indexed(true)
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 8
		}
		IndexedStorage8 {
			codec.header.image_type.set_indexed(true)
			codec.header.image_spec.bit_per_pixel = 8
			codec.header.color_map_spec = TGAColorMapSpec{
				length:    u16(image.pixels.palette.len)
				bit_depth: options.color_map_depth
			}
			codec.header.has_color_map = 1
		}
		Rgb555Pixels {
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 16
		}
		Rgb24Pixels, Bgr24Pixels {
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 24
		}
		Rgba32Pixels, Bgra32Pixels {
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 32
			codec.header.image_spec.descriptor.set_num_attributes_bit(8)
			extension.attributes = .useful_alpha_channel
		}
		else {
			return error('Unsupported')
		}
	}

	codec.extension = extension
	codec.write(mut stream, image.pixels)!
}

pub fn (codec TGA) write(mut stream WriteStream, pixels PixelStorage) ! {
	stream.write_all(tga_header_bytes(codec.header))!
	if codec.header.id_length > 0 {
		if codec.id.data.len != codec.header.id_length { return error('Unsupported') }
		stream.write_all(codec.id.data)!
	}
	match pixels {
		IndexedStorage8 {
			depth := codec.header.color_map_spec.bit_depth
			if depth !in [u8(15), 16, 24] { return error('Unsupported') }
			for i in int(codec.header.color_map_spec.first_entry_index) .. codec.palette_end() {
				color := pixels.palette[i]
				if depth == 24 {
					stream.write_all([color.b, color.g, color.r])!
				} else {
					raw := u16(color.r >> 3) << 10 | u16(color.g >> 3) << 5 | u16(color.b >> 3)
					stream.write_all([u8(raw), u8(raw >> 8)])!
				}
			}
			codec.write_pixels(mut stream, pixels)!
		}
		Grayscale8Pixels, Rgb555Pixels, Bgr24Pixels, Bgra32Pixels {
			codec.write_pixels(mut stream, pixels)!
		}
		Rgb24Pixels, Rgba32Pixels {
			codec.write_converted(mut stream, pixels)!
		}
		else {
			return error('Unsupported')
		}
	}

	mut footer := TGAFooter{}
	if extension := codec.extension {
		footer.extension_offset = u32(stream.get_pos())
		stream.write_all(tga_extension_bytes(extension))!
	}
	for i, byte in tga_signature.bytes() {
		footer.signature[i] = byte
	}
	stream.write_all(tga_footer_bytes(footer))!
	stream.flush()!
}

fn (codec TGA) write_pixels(mut stream WriteStream, pixels PixelStorage) ! {
	bytes := pixels.as_bytes()
	bpp := int(pixels.pixel_format().pixel_stride())
	stride := int(codec.width()) * bpp
	compressed := codec.header.image_type.run_length()
	top := codec.header.image_spec.descriptor.top_to_bottom()
	if !compressed && top {
		stream.write_all(bytes)!
		return
	}
	for y in 0 .. int(codec.height()) {
		row := if top { y } else { int(codec.height()) - y - 1 }
		line := bytes[row * stride..(row + 1) * stride]
		if !compressed {
			stream.write_all(line)!
		} else if bpp == 3 {
			tga_rle_simple(line, bpp, mut stream)!
		} else {
			tga_rle_simd(line, bpp, tga_vector_length(bpp), mut stream)!
		}
	}
}

fn (codec TGA) write_converted(mut stream WriteStream, pixels PixelStorage) ! {
	compressed := codec.header.image_type.run_length()
	mut rle := TgaRleEncoder{}
	width := int(codec.width())
	for y in 0 .. int(codec.height()) {
		row := if codec.header.image_spec.descriptor.top_to_bottom() {
			y
		} else {
			int(codec.height()) - y - 1
		}
		for x in 0 .. width {
			i := row * width + x
			mut bytes := []u8{}
			match pixels {
				Rgb24Pixels {
					color := pixels.data[i]
					bytes = [color.b, color.g, color.r]
				}
				Rgba32Pixels {
					color := pixels.data[i]
					bytes = [color.b, color.g, color.r, color.a]
				}
				else {
					return error('Unsupported')
				}
			}

			if compressed {
				rle.encode(mut stream, bytes)!
			} else {
				for byte in bytes {
					stream.write_byte(byte)!
				}
			}
		}
	}
	if compressed { rle.flush(mut stream)! }
}
