module zigimg

fn png_info_test_chunk(mut processor PngInfoProcessor, id u32, length u32, bytes []u8, color PngColorType) !u64 {
	mut stream := ReadStream.init_memory(bytes)
	mut header := PngHeaderData{
		compression_method: .deflate
		filter_method:      .adaptive

		width:            17
		height:           3
		bit_depth:        8
		color_type:       color
		interlace_method: .adam7
	}
	mut data := PngChunkProcessData{
		read_stream:    &stream
		header:         &header
		chunk_id:       id
		chunk_length:   length
		current_format: .grayscale8
	}
	callback := processor.processor()
	result := callback.process_chunk(mut data)!
	assert result == .grayscale8
	return stream.get_pos()
}

fn test_png_info_header_idat_palette_and_borrowed_options() {
	mut bytes := []u8{len: 600}
	mut writer := WriteStream.init_memory(mut bytes)
	mut options := PngInfoOptions.init(PngInfoProcessor.init(&writer))
	configured := options.get()
	assert configured.processors[0].id == png_chunk_any.id
	png_info_test_chunk(mut options.processor, png_chunk_ihdr.id, 13, []u8{}, .grayscale)!
	assert writer.buffered().bytestr() == 'Dimensions: 17x3\nBit Depth: 8\nColor Type: grayscale\nCompression Method: deflate\nFilter Method: adaptive\nInterlace Method: adam7\n\n'
	png_info_test_chunk(mut options.processor, png_chunk_idat.id, 1024, []u8{}, .grayscale)!
	png_info_test_chunk(mut options.processor, png_chunk_idat.id, 1025, []u8{}, .grayscale)!
	assert options.processor.idat_count == 2 && options.processor.idat_size == 2049
	png_info_test_chunk(mut options.processor, png_chunk_iend.id, 0, []u8{}, .grayscale)!
	assert writer.buffered().bytestr().contains('IDAT Count: 2, Total Size: 2.0009765625KiB\n')
	mut data := PngPaletteProcessData{
		palette: []Rgba32{len: 3}
	}
	configured.processors[0].process_palette(mut data)!
	assert writer.buffered().bytestr().ends_with('PLTE with 3 entries\n')
	mut row := PngRowProcessData{
		dest_row: []u8{}
		header:   &PngHeaderData{
			width:              0
			height:             0
			bit_depth:          0
			color_type:         .grayscale
			compression_method: .deflate
			filter_method:      .adaptive
			interlace_method:   .none
		}

		src_format:  .grayscale8
		dest_format: .rgba32
	}
	assert configured.processors[0].process_data_row(mut row)! == .rgba32
}

fn test_png_info_suppressed_write_failures_keep_unconsumed_data_and_crc() {
	for row in [
		[png_chunk_gama.id, u32(4), 4],
		[png_chunk_chrm.id, u32(32), 0],
		[png_chunk_phys.id, u32(9), 0],
		[png_chunk_trns.id, u32(2), 0],
		[png_chunk_time.id, u32(7), 0],
		[png_chunk_iccp.id, u32(10), 0],
		[png_chunk_sbit.id, u32(3), 3],
	] {
		id := row[0]
		length := row[1]
		expected := row[2]
		mut bytes := []u8{}
		mut writer := WriteStream.init_memory(mut bytes)
		mut processor := PngInfoProcessor.init(&writer)
		position := png_info_test_chunk(mut processor, id, length, []u8{len: 40}, .grayscale)!
		assert position == expected && writer.get_pos() == 0
	}
}

fn test_png_info_ancillary_formatting_and_ignored_crc() {
	mut bytes := []u8{len: 600}
	mut writer := WriteStream.init_memory(mut bytes)
	mut processor := PngInfoProcessor.init(&writer)
	position := png_info_test_chunk(mut processor, png_chunk_trns.id, 3, [u8(17), 255, 0, 1, 2,
		3, 4, 5], .indexed)!
	assert position == 7
	assert writer.buffered().bytestr() == 'tRNS Length 3B: { 17, 255, 0 }\n'
	png_info_test_chunk(mut processor, png_chunk_srgb.id, 1, [u8(255), 1, 2, 3, 4, 5], .grayscale)!
	assert writer.buffered().bytestr().ends_with('sRGB: Uknown Intent\n')
}

fn test_png_info_ztxt_uses_buffered_zlib_and_prints_raw_itxt() {
	mut bytes := []u8{len: 700}
	mut writer := WriteStream.init_memory(mut bytes)
	mut processor := PngInfoProcessor.init(&writer)
	mut text := 'key'.bytes()
	text << [u8(0), 0, 0x78, 0, 1, 5, 0, 0xfa, 0xff]
	text << 'hello'.bytes()
	text << []u8{len: 9}
	position := png_info_test_chunk(mut processor, png_chunk_ztxt.id, 21, text, .grayscale)!
	assert position == 25
	assert writer.buffered().bytestr() == 'zTXt Length 21B:\n               Keyword: key\n           Compression: Zlib Deflate\n                  Text: hello\n'
	mut itxt := [u8(0), 1, 0, 0, 0]
	itxt << 'raw'.bytes()
	itxt << []u8{len: 5}
	png_info_test_chunk(mut processor, png_chunk_itxt.id, 8, itxt, .grayscale)!
	assert writer.buffered().bytestr().ends_with('iTXt Length 8B:\n               Keyword: \n            Compressed: Zlib Deflate  \n          Language Tag: \n    Translated Keyword: \n                  Text: raw\n')
}
