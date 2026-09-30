module zigimg

pub enum RasType as u32 {
	old          = 0
	standard     = 1
	byte_encoded = 2
	rgb          = 3
	tiff         = 4
	iff          = 5
	experimental = 0xffff
}

pub enum RasColorMapType as u32 {
	no_color_map  = 0
	rgb_color_map = 1
	raw_color_map = 2
}

@[packed]
pub struct RasHeader {
pub mut:
	width            u32
	height           u32
	depth            u32
	length           u32
	type_            RasType
	color_map_type   RasColorMapType
	color_map_length u32
}

pub fn (header &RasHeader) debug() {
	// Preserve the source's debug-print enum labels.
	eprint(
		'size: ${header.width}x${header.height} (d=${header.depth})\nlen=${header.length}\n' + 'type=.${header.type_}\ncmap=.${header.color_map_type}\n' + 'cmap_len=${header.color_map_length}\n')
}

pub struct RAS {
pub mut:
	header  RasHeader
	palette FixedStorage256[Rgba32]
}

pub fn (codec &RAS) width() usize {
	return usize(codec.header.width)
}

pub fn (codec &RAS) height() usize {
	return usize(codec.header.height)
}

pub fn RAS.format_detect(mut stream ReadStream) !bool {
	return stream.peek(4)! == [u8(0x59), 0xa6, 0x6a, 0x95]
}

pub fn (codec &RAS) pixel_format() !PixelFormat {
	return match codec.header.depth {
		24 {
			if codec.header.type_ == .rgb {
				PixelFormat.rgb24
			} else {
				PixelFormat.bgr24
			}
		}
		32 {
			PixelFormat.rgba32
		}
		8 {
			if codec.header.color_map_length > 0 {
				PixelFormat.indexed8
			} else {
				PixelFormat.grayscale8
			}
		}
		1 {
			if codec.header.color_map_length > 0 {
				PixelFormat.indexed8
			} else {
				PixelFormat.grayscale1
			}
		}
		else {
			return error('Unsupported')
		}
	}
}

pub fn RAS.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := RAS{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.width()
		height: codec.height()
		pixels: pixels
	}
}

pub fn (mut codec RAS) uncompress_bitmap(mut stream ReadStream, mut buffer []u8) ! {
	match codec.header.type_ {
		.old, .standard, .rgb {
			stream.read_slice_all(mut buffer)!
		}
		.byte_encoded {
			mut position := 0
			for position < buffer.len {
				flag := stream.take_byte()!
				if flag == 0x80 {
					count := u16(stream.take_byte()!)
					if count == 0 {
						buffer[position] = flag
						position++
					} else {
						run := stream.take_byte()!
						for _ in 0 .. int(count) + 1 {
							buffer[position] = run
							position++
							if position >= buffer.len { break
							 }
						}
					}
				} else {
					buffer[position] = flag
					position++
				}
			}
		}
		else {
			return error('Unsupported')
		}
	}
}

pub fn (mut codec RAS) read_palette(mut stream ReadStream) ! {
	if codec.header.color_map_type != .rgb_color_map { return error('Unsupported') }
	colors := usize(codec.header.color_map_length / 3)
	codec.palette.resize(colors)
	mut buffer := []u8{len: int(codec.header.color_map_length)}
	stream.read_slice_all(mut buffer)!
	for i in 0 .. int(colors) {
		codec.palette.data[i] = Rgba32{
			r: buffer[i]
			g: buffer[i + int(colors)]
			b: buffer[i + 2 * int(colors)]
		}
	}
}

pub fn (mut codec RAS) read(mut stream ReadStream) !PixelStorage {
	if !RAS.format_detect(mut stream)! { return error('InvalidData') }
	stream.take(4)!
	bytes := stream.take(28) or { return error('InvalidData') }
	codec.header = RasHeader{
		width:            read_be_u32(bytes[..4])
		height:           read_be_u32(bytes[4..8])
		depth:            read_be_u32(bytes[8..12])
		length:           read_be_u32(bytes[12..16])
		type_:            unsafe { RasType(read_be_u32(bytes[16..20])) }
		color_map_type:   unsafe { RasColorMapType(read_be_u32(bytes[20..24])) }
		color_map_length: read_be_u32(bytes[24..28])
	}
	format := codec.pixel_format()!
	width := codec.width()
	height := codec.height()
	if codec.header.color_map_type != .no_color_map && codec.header.color_map_length > 0 {
		codec.read_palette(mut stream)!
	}
	mut pixels := PixelStorage.init(format, width * height)!
	pixel_size := if codec.header.depth < 8 { usize(1) } else { usize(codec.header.depth / 8) }
	// Only the one-bit path rounds rows to sixteen bits in the pinned source.
	bytes_needed := (width + 7) / 8
	line_size := if codec.header.depth == 1 { bytes_needed + (bytes_needed & 1) } else { width }
	mut buffer := []u8{len: int(line_size * height * pixel_size)}
	codec.uncompress_bitmap(mut stream, mut buffer)!
	mut pixel_bytes := pixels.as_bytes()
	match mut pixels {
		Grayscale1Pixels {
			for y := usize(0); y < height; y++ {
				for x := usize(0); x < width; x++ {
					offset := y * line_size + x / 8
					mask := u8(1) << u8(7 - x % 8)
					pixels.data[int(y * width + x)].value = if buffer[int(offset)] & mask != 0 {
						u8(0)
					} else {
						u8(1)
					}
				}
			}
		}
		Grayscale8Pixels, Rgb24Pixels, Bgr24Pixels {
			assert pixel_bytes.len == buffer.len
			copy(mut pixel_bytes, buffer)
		}
		IndexedStorage8 {
			// Source copies raw bytes here even for a one-bit image with a palette.
			copy(mut pixels.indices, buffer[..pixels.indices.len])
			pixels.resize_palette(usize(codec.palette.data.len))
			for i, color in codec.palette.data {
				pixels.palette[i] = color
			}
		}
		Rgba32Pixels {
			for offset in 0 .. pixels.data.len {
				at := offset * int(pixel_size)
				pixels.data[offset] = if codec.header.type_ == .rgb {
					Rgba32{
						r: buffer[at + 1]
						g: buffer[at + 2]
						b: buffer[at + 3]
					}
				} else {
					Rgba32{
						r: buffer[at + 3]
						g: buffer[at + 2]
						b: buffer[at + 1]
					}
				}
			}
		}
		else {
			return error('Unsupported')
		}
	}

	return pixels
}

// This exact revision exposes a successful writer that emits no bytes.
pub fn RAS.write_image(mut stream WriteStream, image ImageUnmanaged) ! {
	_ = stream
	_ = image
}
