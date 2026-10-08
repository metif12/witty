module zigimg

fn test_png_header_zero_depth_and_checked_line_limit_returning_neighbors() {
	mut header := PngHeaderData{
		width:      0xffffffff
		height:     0
		bit_depth:  0
		color_type: .rgba_color
	}
	assert !header.is_valid()
	assert header.pixel_bits() == 0
	assert header.line_bytes() == 0
	assert header.max_palette_size() == 1
	header.color_type = .grayscale
	header.bit_depth = 1
	header.width = 0xfffffff8
	assert header.line_bytes() == 536870911
	header.width = 536870911
	header.bit_depth = 8
	assert header.line_bytes() == 536870911
	header.width = 0
	header.bit_depth = 16
	header.color_type = .rgba_color
	assert header.get_pixel_format() == .rgba64
	assert header.line_bytes() == 0
}

fn test_png_chunk_identity_snapshots_bytes_while_name_borrows_storage() {
	mut bytes := [u8(`I`), `H`, `D`, `R`, 0]
	name := unsafe { tos(bytes.data, 4) }
	chunk := PngChunk.init(name)
	bytes[0] = `X`
	assert chunk.id == png_chunk_ihdr.id
	assert chunk.name == 'XHDR'
	assert PngChunk.init('\x00\xff\x00\xff').id == 0x00ff00ff
}
