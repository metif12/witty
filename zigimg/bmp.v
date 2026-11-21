module zigimg

// The locked BMP codec supports V4/V5 BGR and BGRA data. Its offset, mask,
// row-padding, and signed-dimension behavior are preserved below.

@[packed]
pub struct BitmapFileHeader {
pub mut:
	magic_header [2]u8 = [u8(`B`), `M`]!
	size         u32
	reserved     u32
	pixel_offset u32
}

pub enum BmpCompressionMethod as u32 {
	none             = 0
	rle8             = 1
	rle4             = 2
	bitfields        = 3
	jpg              = 4
	png              = 5
	alpha_bit_fields = 6
	cmyk             = 11
	cmyk_rle8        = 12
	cmyk_rle4        = 13
}

pub enum BitmapColorSpace as u32 {
	calibrated_rgb      = 0
	srgb                = 0x73524742
	windows_color_space = 0x57696e20
	profile_linked      = 0x4c494e4b
	profile_embedded    = 0x4d424544
}

pub enum BitmapIntent as u32 {
	business              = 1
	graphics              = 2
	images                = 4
	absolute_colorimetric = 8
}

pub struct CieXyz {
pub mut:
	x u32
	y u32
	z u32
}

pub struct CieXyzTriple {
pub mut:
	red   CieXyz
	green CieXyz
	blue  CieXyz
}

pub struct BitmapInfoHeaderWindows31 {
pub mut:
	header_size           u32
	width                 i32
	height                i32
	color_plane           u16
	bit_count             u16
	compression_method    BmpCompressionMethod = .none
	image_raw_size        u32
	horizontal_resolution u32
	vertical_resolution   u32
	palette_size          u32
	important_colors      u32
}

pub struct BitmapInfoHeaderV4 {
pub mut:
	header_size           u32
	width                 i32
	height                i32
	color_plane           u16
	bit_count             u16
	compression_method    BmpCompressionMethod = .none
	image_raw_size        u32
	horizontal_resolution u32
	vertical_resolution   u32
	palette_size          u32
	important_colors      u32
	red_mask              u32
	green_mask            u32
	blue_mask             u32
	alpha_mask            u32
	color_space           BitmapColorSpace = .srgb
	cie_end_points        CieXyzTriple
	gamma_red             u32
	gamma_green           u32
	gamma_blue            u32
}

pub struct BitmapInfoHeaderV5 {
pub mut:
	header_size           u32
	width                 i32
	height                i32
	color_plane           u16
	bit_count             u16
	compression_method    BmpCompressionMethod = .none
	image_raw_size        u32
	horizontal_resolution u32
	vertical_resolution   u32
	palette_size          u32
	important_colors      u32
	red_mask              u32
	green_mask            u32
	blue_mask             u32
	alpha_mask            u32
	color_space           BitmapColorSpace = .srgb
	cie_end_points        CieXyzTriple
	gamma_red             u32
	gamma_green           u32
	gamma_blue            u32
	intent                BitmapIntent = .graphics
	profile_data          u32
	profile_size          u32
	reserved              u32
}

pub const bitmap_info_header_windows31_size = u32(40)
pub const bitmap_info_header_v4_size = u32(108)
pub const bitmap_info_header_v5_size = u32(124)

pub type BitmapInfoHeader = BitmapInfoHeaderWindows31 | BitmapInfoHeaderV4 | BitmapInfoHeaderV5

pub struct BmpEncoderOptions {}

pub struct BMP {
pub mut:
	file_header BitmapFileHeader
	info_header BitmapInfoHeader = BitmapInfoHeaderWindows31{}
}

pub fn (codec BMP) width() i32 {
	return match codec.info_header {
		BitmapInfoHeaderWindows31 { codec.info_header.width }
		BitmapInfoHeaderV4 { codec.info_header.width }
		BitmapInfoHeaderV5 { codec.info_header.width }
	}
}

pub fn (codec BMP) height() i32 {
	return match codec.info_header {
		BitmapInfoHeaderWindows31 { codec.info_header.height }
		BitmapInfoHeaderV4 { codec.info_header.height }
		BitmapInfoHeaderV5 { codec.info_header.height }
	}
}

pub fn BMP.format_detect(mut stream ReadStream) !bool {
	return stream.peek(2)! == [u8(`B`), `M`]
}

fn bmp_find_pixel_format(bit_count u32, compression BmpCompressionMethod) !PixelFormat {
	if bit_count == 32 && compression == .bitfields { return .bgra32 }
	if bit_count == 24 && compression == .none { return .bgr24 }
	return error('Unsupported')
}

pub fn (codec BMP) pixel_format() !PixelFormat {
	return match codec.info_header {
		BitmapInfoHeaderV4 {
			bmp_find_pixel_format(codec.info_header.bit_count, codec.info_header.compression_method)!
		}
		BitmapInfoHeaderV5 {
			bmp_find_pixel_format(codec.info_header.bit_count, codec.info_header.compression_method)!
		}
		else {
			return error('Unsupported')
		}
	}
}

fn bmp_u32(bytes []u8, offset int) u32 {
	return u32(bytes[offset]) | u32(bytes[offset + 1]) << 8 | u32(bytes[offset + 2]) << 16 | u32(bytes[
		offset + 3]) << 24
}

fn bmp_u16(bytes []u8, offset int) u16 {
	return u16(bytes[offset]) | u16(bytes[offset + 1]) << 8
}

fn bmp_read_file_header(mut stream ReadStream) !BitmapFileHeader {
	bytes := stream.take(14)!
	return BitmapFileHeader{
		magic_header: [bytes[0], bytes[1]]!
		size:         bmp_u32(bytes, 2)
		reserved:     bmp_u32(bytes, 6)
		pixel_offset: bmp_u32(bytes, 10)
	}
}

fn bmp_read_info_header[T](mut stream ReadStream) !T {
	bytes := stream.take(int(sizeof(T)))!
	mut header := T{}
	header.header_size = bmp_u32(bytes, 0)
	header.width = i32(bmp_u32(bytes, 4))
	header.height = i32(bmp_u32(bytes, 8))
	header.color_plane = bmp_u16(bytes, 12)
	header.bit_count = bmp_u16(bytes, 14)
	header.compression_method = unsafe { BmpCompressionMethod(bmp_u32(bytes, 16)) }
	header.image_raw_size = bmp_u32(bytes, 20)
	header.horizontal_resolution = bmp_u32(bytes, 24)
	header.vertical_resolution = bmp_u32(bytes, 28)
	header.palette_size = bmp_u32(bytes, 32)
	header.important_colors = bmp_u32(bytes, 36)
	$if T is BitmapInfoHeaderV4 || T is BitmapInfoHeaderV5 {
		header.red_mask = bmp_u32(bytes, 40)
		header.green_mask = bmp_u32(bytes, 44)
		header.blue_mask = bmp_u32(bytes, 48)
		header.alpha_mask = bmp_u32(bytes, 52)
		header.color_space = unsafe { BitmapColorSpace(bmp_u32(bytes, 56)) }
		header.cie_end_points = CieXyzTriple{
			red:   CieXyz{
				x: bmp_u32(bytes, 60)
				y: bmp_u32(bytes, 64)
				z: bmp_u32(bytes, 68)
			}
			green: CieXyz{
				x: bmp_u32(bytes, 72)
				y: bmp_u32(bytes, 76)
				z: bmp_u32(bytes, 80)
			}
			blue:  CieXyz{
				x: bmp_u32(bytes, 84)
				y: bmp_u32(bytes, 88)
				z: bmp_u32(bytes, 92)
			}
		}
		header.gamma_red = bmp_u32(bytes, 96)
		header.gamma_green = bmp_u32(bytes, 100)
		header.gamma_blue = bmp_u32(bytes, 104)
	}
	$if T is BitmapInfoHeaderV5 {
		header.intent = unsafe { BitmapIntent(bmp_u32(bytes, 108)) }
		header.profile_data = bmp_u32(bytes, 112)
		header.profile_size = bmp_u32(bytes, 116)
		header.reserved = bmp_u32(bytes, 120)
	}
	return header
}

fn bmp_append_u32(mut bytes []u8, value u32) {
	bytes << [u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24)]
}

fn bmp_file_header_bytes(header BitmapFileHeader) []u8 {
	mut bytes := [header.magic_header[0], header.magic_header[1]]
	bmp_append_u32(mut bytes, header.size)
	bmp_append_u32(mut bytes, header.reserved)
	bmp_append_u32(mut bytes, header.pixel_offset)
	return bytes
}

fn bmp_info_header_bytes[T](header T) []u8 {
	mut bytes := []u8{cap: int(sizeof(T))}
	for word in [header.header_size, u32(header.width), u32(header.height)] {
		bmp_append_u32(mut bytes, word)
	}
	for word in [header.color_plane, header.bit_count] {
		bytes << [u8(word), u8(word >> 8)]
	}
	for word in [u32(header.compression_method), header.image_raw_size, header.horizontal_resolution,
		header.vertical_resolution, header.palette_size, header.important_colors] {
		bmp_append_u32(mut bytes, word)
	}
	$if T is BitmapInfoHeaderV4 || T is BitmapInfoHeaderV5 {
		for word in [header.red_mask, header.green_mask, header.blue_mask, header.alpha_mask,
			u32(header.color_space)] {
			bmp_append_u32(mut bytes, word)
		}
		for point in [header.cie_end_points.red, header.cie_end_points.green, header.cie_end_points.blue] {
			for word in [point.x, point.y, point.z] {
				bmp_append_u32(mut bytes, word)
			}
		}
		for word in [header.gamma_red, header.gamma_green, header.gamma_blue] {
			bmp_append_u32(mut bytes, word)
		}
	}
	$if T is BitmapInfoHeaderV5 {
		for word in [u32(header.intent), header.profile_data, header.profile_size, header.reserved] {
			bmp_append_u32(mut bytes, word)
		}
	}
	assert bytes.len == int(sizeof(T))
	return bytes
}

fn bmp_checked_product(a i32, b i32) i32 {
	product := i64(a) * b
	if product < -2147483648 || product > 2147483647 { panic('integer overflow') }
	return i32(product)
}

fn bmp_checked_index(scanline i32, x i32, length int) int {
	index := i64(scanline) + x
	if index < -2147483648 || index > 2147483647 { panic('integer overflow') }
	if index < 0 { panic('integer does not fit in destination type') }
	if uint(index) >= uint(length) {
		panic('index out of bounds: index ${index}, len ${length}')
	}
	return int(index)
}

pub fn (mut codec BMP) read(mut stream ReadStream) !PixelStorage {
	codec.file_header = bmp_read_file_header(mut stream)!
	if codec.file_header.magic_header != [u8(`B`), `M`]! { return error('InvalidData') }
	size := bmp_u32(stream.peek(4)!, 0)
	codec.info_header = match size {
		bitmap_info_header_windows31_size { BitmapInfoHeader(bmp_read_info_header[BitmapInfoHeaderWindows31](mut stream)!) }
		bitmap_info_header_v4_size { BitmapInfoHeader(bmp_read_info_header[BitmapInfoHeaderV4](mut stream)!) }
		bitmap_info_header_v5_size { BitmapInfoHeader(bmp_read_info_header[BitmapInfoHeaderV5](mut stream)!) }
		else { return error('Unsupported') }
	}

	format := codec.pixel_format()!
	width := codec.width()
	height := codec.height()
	count := bmp_checked_product(width, height)
	if count < 0 { panic('integer does not fit in destination type') }
	mut pixels := PixelStorage.init(format, uint(count))!
	// The pinned reader ignores pixel_offset, color masks, and row padding.
	if height == -2147483648 { panic('integer overflow') }
	for y := height - 1; y >= 0; y-- {
		scanline := bmp_checked_product(y, width)
		for x := i32(0); x < width; x++ {
			index := bmp_checked_index(scanline, x, int(pixels.len()))
			match mut pixels {
				Bgr24Pixels {
					bytes := stream.take(3)!
					pixels.data[index] = Bgr24{
						b: bytes[0]
						g: bytes[1]
						r: bytes[2]
					}
				}
				Bgra32Pixels {
					bytes := stream.take(4)!
					pixels.data[index] = Bgra32{
						b: bytes[0]
						g: bytes[1]
						r: bytes[2]
						a: bytes[3]
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

pub fn BMP.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := BMP{}
	pixels := codec.read(mut stream)!
	if codec.width() < 0 || codec.height() < 0 { panic('integer does not fit in destination type') }
	return ImageUnmanaged{
		width:  uint(codec.width())
		height: uint(codec.height())
		pixels: pixels
	}
}

fn bmp_image_sizes(image ImageUnmanaged, channels uint, header_size uint) (u32, u32) {
	if image.width != 0 && image.height > ~uint(0) / image.width { panic('integer overflow') }
	pixels := image.width * image.height
	if pixels > ~uint(0) / channels { panic('integer overflow') }
	bytes := pixels * channels
	if bytes > ~uint(0) - header_size { panic('integer overflow') }
	if bytes + header_size > 0xffffffff { panic('integer does not fit in destination type') }
	return u32(bytes), u32(bytes + header_size)
}

pub fn BMP.write_image(mut stream WriteStream, image ImageUnmanaged, options BmpEncoderOptions) ! {
	_ = options
	mut codec := BMP{}
	match image.pixels {
		Bgr24Pixels {
			raw_size, file_size := bmp_image_sizes(image, 3, 14 + 108)
			if image.width > 2147483647 || image.height > 2147483647 {
				panic('integer does not fit in destination type')
			}
			codec.file_header = BitmapFileHeader{
				size:         file_size
				pixel_offset: 122
			}
			codec.info_header = BitmapInfoHeaderV4{
				header_size:           bitmap_info_header_v4_size
				width:                 i32(image.width)
				height:                i32(image.height)
				color_plane:           1
				bit_count:             24
				image_raw_size:        raw_size
				horizontal_resolution: 2835
				vertical_resolution:   2835
			}
		}
		Bgra32Pixels {
			raw_size, file_size := bmp_image_sizes(image, 4, 14 + 124)
			if image.width > 2147483647 || image.height > 2147483647 {
				panic('integer does not fit in destination type')
			}
			codec.file_header = BitmapFileHeader{
				size:         file_size
				pixel_offset: 138
			}
			codec.info_header = BitmapInfoHeaderV5{
				header_size:           bitmap_info_header_v5_size
				width:                 i32(image.width)
				height:                i32(image.height)
				color_plane:           1
				bit_count:             32
				compression_method:    .bitfields
				image_raw_size:        raw_size
				horizontal_resolution: 2835
				vertical_resolution:   2835
				red_mask:              0x0000ff00
				green_mask:            0x00ff0000
				blue_mask:             0xff000000
				alpha_mask:            0x000000ff
			}
		}
		else {
			return error('InvalidData')
		}
	}

	codec.write(mut stream, image.pixels)!
}

pub fn (codec BMP) write(mut stream WriteStream, pixels PixelStorage) ! {
	stream.write_all(bmp_file_header_bytes(codec.file_header))!
	match codec.info_header {
		BitmapInfoHeaderV4 { stream.write_all(bmp_info_header_bytes(codec.info_header))! }
		BitmapInfoHeaderV5 { stream.write_all(bmp_info_header_bytes(codec.info_header))! }
		else { return error('InvalidData') }
	}

	if pixels !is Bgr24Pixels && pixels !is Bgra32Pixels { return error('InvalidData') }
	width := codec.width()
	height := codec.height()
	if height == -2147483648 { panic('integer overflow') }
	for y := height - 1; y >= 0; y-- {
		scanline := bmp_checked_product(y, width)
		for x := i32(0); x < width; x++ {
			index := bmp_checked_index(scanline, x, int(pixels.len()))
			match pixels {
				Bgr24Pixels {
					color := pixels.data[index]
					stream.write_all([color.b, color.g, color.r])!
				}
				Bgra32Pixels {
					color := pixels.data[index]
					stream.write_all([color.b, color.g, color.r, color.a])!
				}
				else {
					return error('InvalidData')
				}
			}
		}
	}
	stream.flush()!
}
