module zigimg

import hash.crc32

fn png_foundation_header(width u32, height u32, depth u8, color u8, compression u8, filter u8, interlace u8) []u8 {
	mut bytes := png_magic_header[..].clone()
	append_be_u32(mut bytes, 13)
	bytes << 'IHDR'.bytes()
	append_be_u32(mut bytes, width)
	append_be_u32(mut bytes, height)
	bytes << [depth, color, compression, filter, interlace]
	crc := crc32.sum(bytes[12..29])
	append_be_u32(mut bytes, crc)
	return bytes
}

fn test_png_header_crc_exhaustive_and_open_enums_and_positions() {
	for color in [u8(0), 2, 3, 4, 6] {
		for method in [u8(0), 1, 17, 255] {
			bytes := png_foundation_header(3, 5, 8, color, method, method, 1)
			mut stream := ReadStream.init_memory(bytes)
			header := png_load_header(mut stream)!
			assert header.width == 3 && header.height == 5 && header.bit_depth == 8
			assert u8(header.color_type) == color && u8(header.compression_method) == method
			assert u8(header.filter_method) == method && header.interlace_method == .adam7
			assert stream.get_pos() == 33
			for cut in 0 .. 33 {
				stream = ReadStream.init_memory(bytes[..cut])
				mut failure := ''
				_ = png_load_header(mut stream) or {
					failure = err.msg()
					PngHeaderData{}
				}
				assert failure == 'EndOfStream'
				assert stream.get_pos() == if cut < 8 {
					u64(0)
				} else if cut < 16 {
					u64(8)
				} else if cut < 29 {
					u64(16)
				} else {
					u64(29)
				}
			}
		}
	}
	for bytes in [png_foundation_header(0, 1, 8, 0, 0, 0, 0),
		png_foundation_header(1, 1, 8, 1, 0, 0, 0), png_foundation_header(1, 1, 8, 0, 0, 0, 2)] {
		mut stream := ReadStream.init_memory(bytes)
		mut failure := ''
		_ = png_load_header(mut stream) or {
			failure = err.msg()
			PngHeaderData{}
		}
		assert failure == 'InvalidData' && stream.get_pos() == 29
	}
	mut bytes := png_foundation_header(1, 1, 8, 0, 0, 0, 0)
	bytes[32] ^= 1
	mut stream := ReadStream.init_memory(bytes)
	mut failure := ''
	_ = png_load_header(mut stream) or {
		failure = err.msg()
		PngHeaderData{}
	}
	assert failure == 'InvalidData' && stream.get_pos() == 33
}

fn test_png_chunk_names_borrow_native_field_and_critical_bit() {
	assert sizeof(PngChunkHeader) == 8
	mut header := PngChunkHeader{
		chunk_type: png_chunk_ihdr.id
	}
	name := header.name()
	$if little_endian {
		assert name == 'RDHI'.bytes()
	} $else {
		assert name == 'IHDR'.bytes()
	}
	header.chunk_type = png_chunk_idat.id
	$if little_endian {
		assert name == 'TADI'.bytes()
	} $else {
		assert name == 'IDAT'.bytes()
	}
	assert png_is_chunk_critical(png_chunk_ihdr.id)
	assert !png_is_chunk_critical(png_chunk_trns.id)
}

fn test_png_filtering_16_bit_rows_packing_and_failed_prefix() {
	mut pixels := PixelStorage.init(.grayscale16, 8)!
	match mut pixels {
		Grayscale16Pixels {
			for index in 0 .. 8 {
				pixels.data[index].value = [u16(0xf), 0xff, 0xfff, 0xffff][index % 4]
			}
		}
		else {
			assert false
		}
	}

	header := PngHeaderData{
		width:      4
		height:     2
		bit_depth:  16
		color_type: .grayscale
	}
	mut bytes := []u8{len: 18}
	mut writer := WriteStream.init_memory(mut bytes)
	png_filter(mut writer, pixels, PngSpecified{ filter: .none }, header)!
	assert bytes == [u8(0), 0, 15, 0, 255, 15, 255, 255, 255, 0, 0, 15, 0, 255, 15, 255, 255, 255]
	mut short := []u8{len: 4}
	writer = WriteStream.init_memory(mut short)
	mut failure := ''
	png_filter(mut writer, pixels, PngSpecified{ filter: .none }, header) or { failure = err.msg() }
	assert failure == 'InvalidData' && writer.get_pos() == 4 && short == bytes[..4]
	pixels = PixelStorage.init_raw_pixels([u8(1), 0, 1, 0, 1, 0, 1, 0, 1], .grayscale1)!
	bytes = []u8{len: 3}
	writer = WriteStream.init_memory(mut bytes)
	png_filter(mut writer, pixels, PngSpecified{ filter: .none }, PngHeaderData{
		width:     9
		height:    1
		bit_depth: 1
	})!
	assert bytes == [u8(0), 0xaa, 0x80]
}

fn test_png_defilter_source_rows_and_spreading() {
	previous := [u8(0), 1, 2, 3]
	mut current := [u8(0), 5, 6, 7]
	for filter, expected in [[u8(0), 5, 6, 7], [u8(0), 5, 11, 18],
		[u8(0), 6, 13, 21], [u8(0), 6, 17, 31], [u8(0), 7, 24, 55]] {
		current[0] = u8(filter)
		png_defilter(mut current, previous, 1)!
		assert current == expected
	}
	mut invalid := [u8(5), 7, 8]
	mut failure := ''
	png_defilter(mut invalid, previous, 1) or { failure = err.msg() }
	assert failure == 'InvalidData' && invalid == [u8(5), 7, 8]
	mut destination := []u8{len: 8, init: 0xa5}
	png_spread_row_data(mut destination, [u8(0xa5), 0x7c], 2, 1, 2, false)
	assert destination == [u8(2), 0xa5, 2, 0xa5, 1, 0xa5, 1, 0xa5]
	png_spread_row_data(mut destination, [u8(0xa5), 0x7c, 0x39, 0xf2, 0x5b, 0x15, 0x78, 0xd1], 16,
		2, 4, true)
	assert destination == [u8(0x7c), 0xa5, 0xf2, 0x39, 0x15, 0x5b, 0xd1, 0x78]
}

fn test_png_trns_gray16_retains_byte_index_comparison() {
	mut processor := PngTrnsProcessor{
		trns_data: PngTrnsGray{
			value: 0x1234
		}
	}
	mut bytes := [u8(0x34), 0x12, 0, 0, 0x34, 0x12, 0, 0, 0x34, 0x12, 0, 0]
	mut data := PngRowProcessData{
		src_format:  .grayscale16
		dest_format: .grayscale16_alpha
		dest_row:    unsafe { bytes[..] }
	}
	assert processor.process_data_row(mut data)! == .grayscale16_alpha
	assert processor.processed
	assert png_native_u16(bytes[2..4]) == 65535
	assert png_native_u16(bytes[6..8]) == 65535
	assert png_native_u16(bytes[10..12]) == 65535
	processor.trns_data = PngTrnsGray{
		value: 0x34
	}
	processor.process_data_row(mut data)!
	assert png_native_u16(bytes[2..4]) == 0
	assert png_native_u16(bytes[6..8]) == 65535
	assert png_native_u16(bytes[10..12]) == 0
}

fn test_png_processor_callbacks_options_borrowing_and_palette_order() {
	mut options := png_custom_reader_options2_init(PngTrnsProcessor{
		trns_data: PngTrnsIndexAlpha{
			data: [u8(0), 17]
		}
	}, PngPlteProcessor{})
	configured := options.get()
	assert configured.processors.len == 2
	mut palette := [Rgba32{ r: 1, a: 255 }, Rgba32{ r: 2, a: 255 }]
	png_call_palette_processors(configured, mut palette)!
	assert options.processor1.processed && options.processor2.processed
	assert palette[0].a == 0 && palette[1].a == 17
	palette[1].r = 9
	assert options.processor2.palette[1].r == 9
	mut row := [u8(1), 0xa5, 0xa5, 0xa5]
	mut data := PngRowProcessData{
		src_format:  .indexed8
		dest_format: .rgba32
		dest_row:    unsafe { row[..] }
	}
	assert png_call_row_processors(configured.processors, mut data)! == .rgba32
	assert data.src_format == .indexed8 && row == [u8(9), 0, 0, 17]
	options.processors[0].id = 123
	assert configured.processors[0].id == 123
	mut defaults := PngDefaultOptions.init(PngTrnsProcessor{})
	assert defaults.get().processors.len == 1
	mut one := PngCustomReaderOptions1.init(PngTrnsProcessor{})
	assert one.get().processors[0].id == png_chunk_trns.id
	mut two := PngCustomReaderOptions2.init(PngTrnsProcessor{}, PngPlteProcessor{})
	assert two.get().processors.len == 2
}

struct PngTestContext {
mut:
	events    []u32
	format    PixelFormat
	fail      bool
	change_id bool
}

fn png_test_chunk(context voidptr, mut data PngChunkProcessData) !PixelFormat {
	mut ctx := unsafe { &PngTestContext(context) }
	ctx.events << data.chunk_id
	if ctx.change_id { data.chunk_id = png_chunk_trns.id }
	return ctx.format
}

fn png_test_row(context voidptr, mut data PngRowProcessData) !PixelFormat {
	mut ctx := unsafe { &PngTestContext(context) }
	ctx.events << u32(data.src_format)
	if ctx.fail { return error('InvalidData') }
	return ctx.format
}

fn test_png_dispatch_critical_notifications_first_ancillary_and_row_error_state() {
	mut first := PngTestContext{
		format: .grayscale8_alpha
	}
	mut second := PngTestContext{
		format: .rgba32
	}
	processors := [
		PngReaderProcessor.init(png_chunk_any.id, unsafe { voidptr(&first) }, png_test_chunk, none,
			png_test_row),
		PngReaderProcessor.init(png_chunk_any.id, unsafe { voidptr(&second) }, png_test_chunk,
			none, png_test_row),
	]
	mut stream := ReadStream.init_memory([]u8{len: 20})
	mut chunk := PngChunkProcessData{
		read_stream:    &stream
		chunk_id:       png_chunk_trns.id
		chunk_length:   2
		current_format: .grayscale8
	}
	png_call_chunk_processors(processors, mut chunk)!
	assert chunk.current_format == .grayscale8_alpha && first.events.len == 1
		&& second.events.len == 0
	chunk.chunk_id = png_chunk_idat.id
	png_call_chunk_processors(processors, mut chunk)!
	assert chunk.current_format == .rgba32 && first.events.len == 2 && second.events.len == 1
	chunk.chunk_id = png_chunk_trns.id
	png_call_chunk_processors([]PngReaderProcessor{}, mut chunk)!
	assert stream.get_pos() == 6
	second.fail = true
	mut row := PngRowProcessData{
		src_format:  .grayscale8
		dest_format: .rgba32
	}
	mut failure := ''
	_ = png_call_row_processors(processors, mut row) or {
		failure = err.msg()
		PixelFormat.invalid
	}
	assert failure == 'InvalidData' && row.src_format == .grayscale8_alpha
}

fn test_png_critical_processor_matching_keeps_the_initial_chunk_id() {
	mut first := PngTestContext{
		format:    .grayscale8
		change_id: true
	}
	mut second := PngTestContext{
		format: .grayscale8
	}
	processors := [
		PngReaderProcessor.init(png_chunk_idat.id, unsafe { voidptr(&first) }, png_test_chunk,
			none, none),
		PngReaderProcessor.init(png_chunk_idat.id, unsafe { voidptr(&second) }, png_test_chunk,
			none, none),
	]
	mut data := PngChunkProcessData{
		chunk_id:       png_chunk_idat.id
		current_format: .grayscale8
	}
	png_call_chunk_processors(processors, mut data)!
	assert first.events == [png_chunk_idat.id]
	assert second.events == [png_chunk_trns.id]
}
