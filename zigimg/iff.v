module zigimg

pub struct IffChunk {
pub mut:
	id   u32  @[required]
	name []u8 @[required]
}

pub fn IffChunk.init(name []u8) IffChunk {
	if name.len != 4 { panic('reached unreachable code') }
	return IffChunk{
		id:   read_be_u32(name)
		name: unsafe { name }
	}
}

pub const iff_chunk_bmhd = IffChunk.init('BMHD'.bytes())
pub const iff_chunk_body = IffChunk.init('BODY'.bytes())
pub const iff_chunk_camg = IffChunk.init('CAMG'.bytes())
pub const iff_chunk_cmap = IffChunk.init('CMAP'.bytes())
pub const iff_chunk_abit = IffChunk.init('ABIT'.bytes())
// The pinned DGBL declaration uses the name DBGL.
pub const iff_chunk_dgbl = IffChunk.init('DBGL'.bytes())
pub const iff_chunk_dloc = IffChunk.init('DLOC'.bytes())

@[packed]
pub struct IffChunkHeader {
pub mut:
	type_  u32 @[required]
	length u32 @[required]
}

pub fn (header &IffChunkHeader) name() []u8 {
	mut bytes := []u8{}
	unsafe {
		bytes.data = &header.type_
		bytes.len = 4
		bytes.cap = 4
		bytes.flags = .nofree
	}
	return bytes
}

pub enum IlbmCompressionType as u8 {
	none     = 0
	byterun  = 1
	byterun2 = 2
}

pub enum DeepCompressionType as u16 {
	none          = 0
	rle           = 1
	huffman       = 2
	dynamic_chuff = 3
	jpeg          = 4
}

pub enum IffMaskType as u8 {
	none                  = 0
	has_mask              = 1
	has_transparent_color = 2
	has_lasso             = 3
}

pub enum IffViewportMode as u32 {
	ehb = 0x80
	ham = 0x800
}

pub fn IffViewportMode.is_ehb(mode u32) bool {
	return mode & u32(IffViewportMode.ehb) != 0
}

pub fn IffViewportMode.is_ham(mode u32) bool {
	return mode & u32(IffViewportMode.ham) != 0
}

pub enum IffFormat as u8 {
	ilbm = 0
	pbm  = 1
	acbm = 2
	deep = 3
	bad  = 4
}

pub struct BmhdHeader {
pub mut:
	width             u16
	height            u16
	x                 i16
	y                 i16
	planes            u8
	mask_type         IffMaskType         = .none
	compression_type  IlbmCompressionType = .none
	pad               u8
	transparent_color u16
	x_asoect          u8
	y_aspect          u8
	page_width        u16
	page_height       u16
}

pub const bmhd_header_size = u32(20)

pub struct DgblHeader {
pub mut:
	width            u16
	height           u16
	compression_type DeepCompressionType = .none
	x_aspect         u8
	y_aspect         u8
}

pub type IffHeader = BmhdHeader | DgblHeader

fn (header IffHeader) width() u16 {
	return match header {
		BmhdHeader { header.width }
		DgblHeader { header.width }
	}
}

fn (header IffHeader) height() u16 {
	return match header {
		BmhdHeader { header.height }
		DgblHeader { header.height }
	}
}

fn (header IffHeader) bmhd() BmhdHeader {
	return match header {
		BmhdHeader {
			header
		}
		else {
			panic("access of union field 'bmhd' while field 'dgbl' is active")
		}
	}
}

fn iff_get_format_id(magic []u8) !IffFormat {
	if magic.len != 12 || magic[..4] != 'FORM'.bytes() { return error('InvalidData') }
	return match magic[8..].bytestr() {
		'PBM ' { IffFormat.pbm }
		'ILBM' { IffFormat.ilbm }
		'ACBM' { IffFormat.acbm }
		else { return error('InvalidData') }
	}
}

pub fn peek_iff_format_id(mut reader ReadStream) !IffFormat {
	return iff_get_format_id(reader.peek(12)!)!
}

pub fn take_iff_format_id(mut reader ReadStream) !IffFormat {
	return iff_get_format_id(reader.take(12)!)!
}

fn iff_take_chunk(mut stream ReadStream) !IffChunkHeader {
	bytes := stream.take(8)!
	return IffChunkHeader{
		type_:  read_be_u32(bytes[..4])
		length: read_be_u32(bytes[4..])
	}
}

fn iff_u16(bytes []u8, offset int) u16 {
	return u16(bytes[offset]) << 8 | u16(bytes[offset + 1])
}

fn iff_take_u16(mut stream ReadStream) !u16 {
	return iff_u16(stream.take(2)!, 0)
}

pub fn decode_bmhd_chunk(mut stream ReadStream) !BmhdHeader {
	chunk := iff_take_chunk(mut stream)!
	if chunk.type_ != iff_chunk_bmhd.id || chunk.length != bmhd_header_size {
		return error('InvalidData')
	}
	bytes := stream.take(20)!
	$if little_endian {
		// Source validates both enums while swapping the complete header,
		// before a caller assigns it to the codec.
		if bytes[9] > 3 || bytes[10] > 2 { panic('invalid enum value') }
	}
	return BmhdHeader{
		width:             iff_u16(bytes, 0)
		height:            iff_u16(bytes, 2)
		x:                 i16(iff_u16(bytes, 4))
		y:                 i16(iff_u16(bytes, 6))
		planes:            bytes[8]
		mask_type:         unsafe { IffMaskType(bytes[9]) }
		compression_type:  unsafe { IlbmCompressionType(bytes[10]) }
		pad:               bytes[11]
		transparent_color: iff_u16(bytes, 12)
		x_asoect:          bytes[14]
		y_aspect:          bytes[15]
		page_width:        iff_u16(bytes, 16)
		page_height:       iff_u16(bytes, 18)
	}
}

pub fn decode_dbgl_chunk(mut stream ReadStream) !DgblHeader {
	_ = stream
	return DgblHeader{}
}

pub fn iff_load_header(mut stream ReadStream, format IffFormat) !IffHeader {
	if format == .deep { return IffHeader(decode_dbgl_chunk(mut stream)!) }
	return IffHeader(decode_bmhd_chunk(mut stream)!)
}

pub fn extend_ehb_palette(mut palette FixedStorage256[Rgba32]) {
	palette.resize(64)
	for i in 0 .. 32 {
		color := palette.data[i]
		palette.data[i + 32] = Rgba32{
			r: color.r >> 1
			g: color.g >> 1
			b: color.b >> 1
		}
	}
}

pub struct IFF {
pub mut:
	cmap_bits       u8
	format_id       IffFormat = .ilbm
	header          IffHeader = BmhdHeader{}
	palette         FixedStorage256[Rgba32]
	pitch           u16
	pixel_byte_size u8
	viewport_mode   u32
}

pub fn (codec &IFF) width() usize {
	return usize(codec.header.width())
}

pub fn (codec &IFF) height() usize {
	return usize(codec.header.height())
}

pub fn (codec &IFF) pixel_format() !PixelFormat {
	if IffViewportMode.is_ham(codec.viewport_mode) { return .rgb24 }
	header := codec.header.bmhd()
	if header.planes == 24 { return .rgb24 }
	if header.planes <= 8 { return .indexed8 }
	return error('Unsupported')
}

pub fn IFF.format_detect(mut stream ReadStream) !bool {
	format := peek_iff_format_id(mut stream) or { return false }
	return format != .bad
}

pub fn IFF.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := IFF{}
	pixels := codec.read(mut stream)!
	return ImageUnmanaged{
		width:  codec.width()
		height: codec.height()
		pixels: pixels
	}
}

pub fn IFF.write_image(mut stream WriteStream, image ImageUnmanaged) ! {
	_ = stream
	_ = image
}

pub fn (mut codec IFF) read(mut stream ReadStream) !PixelStorage {
	codec.format_id = take_iff_format_id(mut stream)!
	codec.header = iff_load_header(mut stream, codec.format_id)!
	codec.pitch = u16(((u32(codec.header.width()) + 15) / 16) * 2)
	return codec.decode_chunks(mut stream)!
}

pub fn (mut codec IFF) decode_chunks(mut stream ReadStream) !PixelStorage {
	end := stream.get_end_pos()!
	for {
		chunk := iff_take_chunk(mut stream)!
		if chunk.type_ == iff_chunk_abit.id || chunk.type_ == iff_chunk_body.id {
			return codec.decode_ilbm_pixel_chunk(mut stream, chunk)!
		} else if chunk.type_ == iff_chunk_camg.id {
			codec.decode_camg_chunk(mut stream)!
		} else if chunk.type_ == iff_chunk_cmap.id {
			codec.decode_cmap_chunk(mut stream, chunk)!
		} else {
			stream.seek_by(i64(chunk.length))!
		}
		assert end > 0
		if stream.get_pos() >= end - 1 {
			break
		}
	}
	return error('Unsupported')
}

pub fn (codec &IFF) decode_byte_run2(mut stream ReadStream, mut buffer []u8) ! {
	header := codec.header.bmhd()
	for i in 0 .. buffer.len {
		buffer[i] = 0
	}
	for plane := usize(0); plane < header.planes; plane++ {
		stream.discard_all(8)!
		count_with_header := iff_take_u16(mut stream)!
		assert count_with_header >= 2
		mut commands := []u8{len: int(count_with_header - 2)}
		stream.read_slice_all(mut commands)!
		mut x := u32(0)
		mut y := u32(0)
		mut data_count := u16(0)
		mut index := 0
		plane_offset := plane * usize(header.height) * codec.pitch
		for x < codec.pitch {
			command := if commands[index] >= 128 {
				int(commands[index]) - 256
			} else {
				int(commands[index])
			}
			mut repeat := u16(0)
			if command == 0 {
				data_count = iff_take_u16(mut stream)!
			} else if command == 1 {
				data_count = iff_take_u16(mut stream)!
				repeat = iff_take_u16(mut stream)!
			} else if command < 0 {
				data_count = u16(-command)
			} else {
				data_count = u16(command)
				repeat = iff_take_u16(mut stream)!
			}
			for data_count > 0 && x < codec.pitch {
				offset := int(plane_offset + usize(x) + usize(y * codec.pitch))
				if command >= 1 {
					buffer[offset] = u8(repeat >> 8)
					buffer[offset + 1] = u8(repeat)
				} else {
					buffer[offset] = stream.take_byte()!
					buffer[offset + 1] = stream.take_byte()!
				}
				y++
				if y >= header.height {
					y = 0
					x += 2
				}
				data_count--
			}
			index++
		}
	}
}

pub fn (codec &IFF) planar_to_chunky(bitplanes []u8, mut chunky []u8) ! {
	header := codec.header.bmhd()
	planes := header.planes
	pixel_size := if planes / 8 > 1 { usize(planes / 8) } else { usize(1) }
	if codec.format_id == .pbm {
		copy(mut chunky, bitplanes[..chunky.len])
		return
	}
	for i in 0 .. chunky.len {
		chunky[i] = 0
	}
	vertical := header.compression_type == .byterun2
	if codec.format_id == .ilbm {
		for y := usize(0); y < header.height; y++ {
			for plane := usize(0); plane < planes; plane++ {
				// The source evaluates pitch * planes as u16 before multiplying by y.
				if !vertical {
					assert u32(codec.pitch) * planes <= 65535
				}
				base := if !vertical {
					usize(u16(codec.pitch * planes)) * y + plane * codec.pitch
				} else {
					plane * usize(header.height) * codec.pitch + y * codec.pitch
				}
				iff_apply_plane(bitplanes, mut chunky, base, usize(codec.pitch), y * header.width,
					pixel_size, plane)
			}
		}
	} else {
		for plane := usize(0); plane < planes; plane++ {
			for y := usize(0); y < header.height; y++ {
				base := plane * usize(codec.pitch) * header.height + usize(codec.pitch) * y
				iff_apply_plane(bitplanes, mut chunky, base, usize(codec.pitch), y * header.width,
					pixel_size, plane)
			}
		}
	}
}

fn iff_apply_plane(bitplanes []u8, mut chunky []u8, base usize, pitch usize, scanline usize, pixel_size usize, plane usize) {
	plane_mask := u8(1) << u8(plane % 8)
	for i := usize(0); i < pitch; i++ {
		bits := bitplanes[int(base + i)]
		for bit := usize(0); bit < 8; bit++ {
			if bits & (u8(1) << u8(7 - bit)) != 0 {
				x := i * 8 + bit
				offset := scanline * pixel_size + x * pixel_size + plane / 8
				chunky[int(offset)] |= plane_mask
			}
		}
	}
}

pub fn (mut codec IFF) decode_camg_chunk(mut stream ReadStream) ! {
	codec.viewport_mode = read_be_u32(stream.take(4)!)
}

pub fn (mut codec IFF) decode_cmap_chunk(mut stream ReadStream, chunk IffChunkHeader) ! {
	count := chunk.length / 3
	if count > 256 { panic('index out of bounds: index ${count}, len 256') }
	codec.palette.resize(usize(count))
	for i in 0 .. int(count) {
		bytes := stream.take(3)!
		codec.palette.data[i] = Rgba32{
			r: bytes[0]
			g: bytes[1]
			b: bytes[2]
		}
	}
	if count == 0 { panic('reached unreachable code') }
	mut bits := u8(0)
	mut remaining := count - 1
	for remaining > 0 {
		remaining >>= 1
		bits++
	}
	codec.cmap_bits = bits
}

pub fn (mut codec IFF) reduce_ham_palette() {
	mut bits := codec.cmap_bits
	planes := codec.header.bmhd().planes
	if bits > planes {
		if bits - planes > 253 { panic('integer overflow') }
		reduction := (bits - planes) + 2
		if bits < reduction { panic('integer overflow') }
		bits -= reduction
		if bits < 4 { panic('reached unreachable code') }
		codec.palette.resize(usize(codec.palette.data.len) >> (bits & u8(sizeof(usize) * 8 - 1)))
		codec.cmap_bits = bits
	}
}

pub fn (mut codec IFF) decode_ilbm_pixel_chunk(mut stream ReadStream, chunk IffChunkHeader) !PixelStorage {
	assert codec.pitch != 0
	format := codec.pixel_format()!
	header := codec.header.bmhd()
	width := codec.width()
	height := codec.height()
	mut pixels := PixelStorage.init(format, width * height)!
	mut buffer := []u8{len: int(usize(codec.pitch) * height * header.planes)}
	mut chunky := []u8{len: int(width * height * if header.planes == 24 {
		usize(3)
	} else {
		usize(1)
	})}
	match header.compression_type {
		.byterun {
			if codec.format_id == .acbm {
				stream.read_slice_all(mut buffer)!
			} else {
				packbits_decode(mut stream, mut buffer, chunk.length)!
			}
		}
		.byterun2 {
			codec.decode_byte_run2(mut stream, mut buffer)!
		}
		else {
			stream.read_slice_all(mut buffer)!
		}
	}

	codec.planar_to_chunky(buffer, mut chunky)!
	if IffViewportMode.is_ehb(codec.viewport_mode) && codec.palette.data.len < 64 {
		extend_ehb_palette(mut codec.palette)
	} else if IffViewportMode.is_ham(codec.viewport_mode) {
		codec.reduce_ham_palette()
	}
	match mut pixels {
		IndexedStorage8 {
			copy(mut pixels.indices, chunky[..pixels.indices.len])
			pixels.resize_palette(usize(codec.palette.data.len))
			for i, color in codec.palette.data {
				pixels.palette[i] = color
			}
		}
		Rgb24Pixels {
			ham := IffViewportMode.is_ham(codec.viewport_mode)
			assert codec.cmap_bits <= 8
			cmap_bits := codec.cmap_bits & 7
			pad_bits := (u8(8) - codec.cmap_bits) & 7
			pixel_size := if header.planes / 8 > 1 { usize(header.planes / 8) } else { usize(1) }
			for row := usize(0); row < height; row++ {
				mut previous := Rgb24{}
				for col := usize(0); col < width; col++ {
					index := int(width * row * pixel_size + col * pixel_size)
					if header.planes == 24 {
						previous = Rgb24{
							r: chunky[index]
							g: chunky[index + 1]
							b: chunky[index + 2]
						}
					} else if chunky[index] < codec.palette.data.len {
						color := codec.palette.data[chunky[index]]
						previous = Rgb24{
							r: color.r
							g: color.g
							b: color.b
						}
					} else if ham {
						control := (chunky[index] >> cmap_bits) & 3
						palette_len := u8(codec.palette.data.len)
						assert palette_len > 0
						component := u8((chunky[index] % palette_len) << pad_bits)
						if control == 1 {
							previous.b = component
						} else if control == 2 {
							previous.r = component
						} else {
							previous.g = component
						}
					} else {
						assert false
					}
					pixels.data[int(row * width + col)] = previous
				}
			}
		}
		else {
			assert false
		}
	}

	return pixels
}
