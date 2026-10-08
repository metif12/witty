module zigimg

import hash.crc32

pub struct PngChunk {
pub:
	id   u32
	name string
}

pub fn PngChunk.init(name string) PngChunk {
	// Source's *const [4:0]u8 parameter enforces this at the caller boundary.
	if name.len != 4 { panic('PNG chunk name must contain four bytes') }
	return PngChunk{
		id:   read_be_u32(name.bytes())
		name: name
	}
}

pub const png_chunk_ihdr = PngChunk.init('IHDR')
pub const png_chunk_plte = PngChunk.init('PLTE')
pub const png_chunk_idat = PngChunk.init('IDAT')
pub const png_chunk_iend = PngChunk.init('IEND')
pub const png_chunk_gama = PngChunk.init('gAMA')
pub const png_chunk_sbit = PngChunk.init('sBIT')
pub const png_chunk_text = PngChunk.init('tEXt')
pub const png_chunk_ztxt = PngChunk.init('zTXt')
pub const png_chunk_itxt = PngChunk.init('iTXt')
pub const png_chunk_chrm = PngChunk.init('cHRM')
pub const png_chunk_phys = PngChunk.init('pHYs')
pub const png_chunk_trns = PngChunk.init('tRNS')
pub const png_chunk_bkgd = PngChunk.init('bKGD')
pub const png_chunk_time = PngChunk.init('tIME')
pub const png_chunk_iccp = PngChunk.init('iCCP')
pub const png_chunk_srgb = PngChunk.init('sRGB')
pub const png_chunk_any = PngChunk.init('_ANY')

@[packed]
pub struct PngChunkHeader {
pub mut:
	length     u32
	chunk_type u32
}

// Source ChunkHeader.name exposes the native-endian bytes of its numeric
// type field, rather than converting them back to the original chunk name.
pub fn (header &PngChunkHeader) name() []u8 {
	return unsafe { (&u8(&header.chunk_type)).vbytes(4) }
}

pub fn png_is_chunk_critical(id u32) bool {
	return id & 0x20000000 == 0
}

pub fn png_load_header(mut stream ReadStream) !PngHeaderData {
	signature := stream.take(8)!
	if signature != png_magic_header[..] { return error('InvalidData') }
	chunk := stream.take(8)!
	if read_be_u32(chunk[4..]) != png_chunk_ihdr.id || read_be_u32(chunk[..4]) != 13 {
		return error('InvalidData')
	}
	data := stream.take(13)!
	// Pinned utils.takeStruct validates exhaustive enum fields, but accepts
	// unnamed compression/filter values in their non-exhaustive byte enums.
	if data[9] !in [u8(0), 2, 3, 4, 6] || data[12] > 1 { return error('InvalidData') }
	header := PngHeaderData{
		width:              read_be_u32(data[..4])
		height:             read_be_u32(data[4..8])
		bit_depth:          data[8]
		color_type:         unsafe { PngColorType(data[9]) }
		compression_method: unsafe { PngCompressionMethod(data[10]) }
		filter_method:      unsafe { PngFilterMethod(data[11]) }
		interlace_method:   unsafe { PngInterlaceMethod(data[12]) }
	}
	if !header.is_valid() { return error('InvalidData') }
	expected_crc := read_be_u32(stream.take(4)!)
	mut crc_input := 'IHDR'.bytes()
	crc_input << data
	if crc32.sum(crc_input) != expected_crc { return error('InvalidData') }
	return header
}
