module zigimg

pub enum SgiCompressionFlag as u8 {
	uncompressed = 0
	rle          = 1
}

pub enum SgiDimensions as u16 {
	scanline       = 1
	single_channel = 2
	multi_channel  = 3
}

pub enum SgiPixelFormat as u32 {
	normal    = 0
	dithered  = 1
	need_cmap = 2
	cmap_only = 3
}

@[packed]
pub struct SgiHeader {
pub mut:
	compression       SgiCompressionFlag
	bytes_per_channel u8
	dimension         SgiDimensions = .scanline
	x_size            u16
	y_size            u16
	z_size            u16
	pix_min           u32
	pix_max           u32
	dummy1            u32
	image_name        [80]u8
	pixel_format      SgiPixelFormat
	dummy2            [404]u8
}

pub struct SGI {
pub mut:
	header  SgiHeader
	palette FixedStorage256[Rgba32]
}

pub fn (codec &SGI) width() usize {
	return usize(codec.header.x_size)
}

pub fn (codec &SGI) height() usize {
	return usize(codec.header.y_size)
}

pub fn SGI.format_detect(mut stream ReadStream) !bool {
	return stream.peek(2)! == [u8(1), 0xda]
}

pub fn (codec &SGI) pixel_format() !PixelFormat {
	if codec.header.pixel_format != .normal { return error('Unsupported') }
	return match codec.header.dimension {
		.multi_channel {
			match codec.header.z_size {
				3 {
					if codec.header.bytes_per_channel == 1 {
						PixelFormat.rgb24
					} else {
						PixelFormat.rgb48
					}
				}
				4 {
					if codec.header.bytes_per_channel == 1 {
						PixelFormat.rgba32
					} else {
						PixelFormat.rgba64
					}
				}
				else {
					return error('Unsupported')
				}
			}
		}
		.single_channel {
			PixelFormat.grayscale8
		}
		else {
			return error('Unsupported')
		}
	}
}

pub fn SGI.write_image(mut stream WriteStream, image ImageUnmanaged) ! {
	_ = stream
	_ = image
}

pub fn SGI.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := SGI{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.width()
		height: codec.height()
		pixels: pixels
	}
}

pub fn (mut codec SGI) uncompress_bitmap(mut stream ReadStream, mut buffer []u8) ! {
	match codec.header.compression {
		.uncompressed {
			stream.read_slice_all(mut buffer)!
		}
		.rle {
			width := codec.width()
			height := codec.height()
			// Source evaluates the table allocation's products in u16.
			if u32(codec.header.y_size) * codec.header.z_size > 8191 { panic('integer overflow') }
			rows := height * usize(codec.header.z_size)
			mut tables := []u8{len: int(rows * 8)}
			stream.read_slice_all(mut tables)!
			mut data := []u8{len: int(stream.get_end_pos()! - stream.get_pos())}
			data_start := usize(512 + tables.len)
			stream.read_slice_all(mut data)!
			// Table offsets are absolute file offsets, even when reading from
			// a stream whose initial position was not zero.
			for index := usize(0); index < rows; index++ {
				at := int(index * 4)
				offset := usize(read_be_u32(tables[at..at + 4]))
				size_at := int(rows * 4) + at
				scanline_size := usize(read_be_u32(tables[size_at..size_at + 4]))
				if offset < data_start { panic('integer overflow') }
				mut scanline_offset := offset - data_start
				max_offset := scanline_offset + scanline_size
				channel_bytes := if codec.header.bytes_per_channel == 1 {
					usize(1)
				} else {
					usize(2)
				}
				mut pixel_pos := index * width * channel_bytes
				for scanline_offset < max_offset {
					// For sixteen-bit channels, only the low command byte counts.
					run_count := sgi_buffer_byte(data, scanline_offset + channel_bytes - 1)
					scanline_offset += channel_bytes
					if run_count & 128 == 128 {
						for _ in 0 .. int(run_count & 127) {
							for byte := usize(0); byte < channel_bytes; byte++ {
								sgi_check_index(pixel_pos + byte, buffer.len)
								buffer[int(pixel_pos + byte)] = sgi_buffer_byte(data,

									scanline_offset + byte)
							}
							pixel_pos += channel_bytes
							scanline_offset += channel_bytes
						}
					} else if run_count > 0 {
						value_at := scanline_offset
						hi_byte := sgi_buffer_byte(data, value_at)
						low_byte := if channel_bytes == 2 {
							sgi_buffer_byte(data, value_at + 1)
						} else {
							u8(0)
						}
						scanline_offset += channel_bytes
						for _ in 0 .. int(run_count) {
							for byte := usize(0); byte < channel_bytes; byte++ {
								sgi_check_index(pixel_pos + byte, buffer.len)
								buffer[int(pixel_pos + byte)] = if byte == 0 {
									hi_byte
								} else {
									low_byte
								}
							}
							pixel_pos += channel_bytes
						}
					} else {
						break
					}
				}
			}
		}
	}
}

pub fn (mut codec SGI) read(mut stream ReadStream) !PixelStorage {
	if !SGI.format_detect(mut stream)! { return error('InvalidData') }
	stream.take(2)!
	bytes := stream.take(510) or { return error('InvalidData') }
	codec.header = SgiHeader{
		compression:       unsafe { SgiCompressionFlag(bytes[0]) }
		bytes_per_channel: bytes[1]
		dimension:         unsafe { SgiDimensions(sgi_read_be_u16(bytes, 2)) }
		x_size:            sgi_read_be_u16(bytes, 4)
		y_size:            sgi_read_be_u16(bytes, 6)
		z_size:            sgi_read_be_u16(bytes, 8)
		pix_min:           read_be_u32(bytes[10..14])
		pix_max:           read_be_u32(bytes[14..18])
		dummy1:            read_be_u32(bytes[18..22])
		pixel_format:      unsafe { SgiPixelFormat(read_be_u32(bytes[102..106])) }
	}
	for i in 0 .. 80 {
		codec.header.image_name[i] = bytes[22 + i]
	}
	for i in 0 .. 404 {
		codec.header.dummy2[i] = bytes[106 + i]
	}
	format := codec.pixel_format()!
	width := codec.width()
	height := codec.height()
	// Source infers a u16 for this intermediate multiplication.
	if u32(codec.header.z_size) * codec.header.bytes_per_channel > 65535 {
		panic('integer overflow')
	}
	pixel_size := u16(codec.header.z_size * codec.header.bytes_per_channel)
	mut pixels := PixelStorage.init(format, width * height)!
	mut buffer := []u8{len: int(usize(pixel_size) * width * height)}
	codec.uncompress_bitmap(mut stream, mut buffer)!
	channel_size := width * height
	for y := usize(0); y < height; y++ {
		for x := usize(0); x < width; x++ {
			offset := (height - y - 1) * width + x
			index := int(y * width + x)
			match mut pixels {
				Rgba32Pixels {
					pixels.data[index] = Rgba32{
						r: sgi_buffer_byte(buffer, offset)
						g: sgi_buffer_byte(buffer, offset + channel_size)
						b: sgi_buffer_byte(buffer, offset + channel_size * 2)
						a: sgi_buffer_byte(buffer, offset + channel_size * 3)
					}
				}
				Rgb24Pixels {
					pixels.data[index] = Rgb24{
						r: sgi_buffer_byte(buffer, offset)
						g: sgi_buffer_byte(buffer, offset + channel_size)
						b: sgi_buffer_byte(buffer, offset + channel_size * 2)
					}
				}
				Rgba64Pixels {
					pixels.data[index] = Rgba64{
						r: sgi_source_be_word(buffer, offset)
						g: sgi_source_be_word(buffer, offset + channel_size)
						b: sgi_source_be_word(buffer, offset + channel_size * 2)
						a: sgi_source_alpha16(sgi_buffer_byte(buffer, offset + channel_size * 3))
					}
				}
				Rgb48Pixels {
					pixels.data[index] = Rgb48{
						r: sgi_source_be_word(buffer, offset)
						g: sgi_source_be_word(buffer, offset + channel_size)
						b: sgi_source_be_word(buffer, offset + channel_size * 2)
					}
				}
				Grayscale8Pixels {
					pixels.data[index].value = sgi_buffer_byte(buffer, offset)
				}
				else {
					return error('Unsupported')
				}
			}
		}
	}
	return pixels
}

fn sgi_read_be_u16(bytes []u8, offset int) u16 {
	return u16(sgi_buffer_byte(bytes, usize(offset))) << 8 | sgi_buffer_byte(bytes, usize(offset) +
		1)
}

fn sgi_check_index(index usize, length int) {
	if index >= usize(length) { panic('index out of bounds: index ${index}, len ${length}') }
}

fn sgi_buffer_byte(bytes []u8, index usize) u8 {
	sgi_check_index(index, bytes.len)
	return bytes[int(index)]
}

fn sgi_source_be_word(bytes []u8, index usize) u16 {
	// Source reinterprets the byte slice descriptor without dividing its length.
	sgi_check_index(index, bytes.len)
	return sgi_read_be_u16(bytes, int(index * 2))
}

fn sgi_source_alpha16(byte u8) u16 {
	// The pinned RGBA64 branch calls bigToNative(u16) on a single byte,
	// and indexes that byte without multiplying the plane offset by two.
	word := u16(byte)
	unsafe {
		bytes := &u8(&word)
		return u16(bytes[0]) << 8 | u16(bytes[1])
	}
}
