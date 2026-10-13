module zigimg

fn test_png_filter_accepts_source_sixteen_bit_shorter_destination_row() {
	pixels := PixelStorage(Grayscale16Pixels{
		data: [Grayscale16{ value: 0x1234 }, Grayscale16{ value: 0xabcd }]
	})
	mut bytes := []u8{len: 8, init: 0xa5}
	mut writer := WriteStream.init_memory(mut bytes)
	// Source fills a two-byte row from the first native u16; it does not
	// require matching lengths for the sixteen-bit path.
	png_filter(mut writer, pixels, PngSpecified{ filter: .none }, PngHeaderData{
		color_type:         .grayscale
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:     2
		height:    1
		bit_depth: 8
	})!
	assert writer.get_pos() == 3
	assert bytes == [u8(0), 0x12, 0x34, 0xa5, 0xa5, 0xa5, 0xa5, 0xa5]
}

fn test_png_filter_empty_rows_and_zero_height_choice_order() {
	pixels := PixelStorage.init(.grayscale8, 0)!
	mut bytes := []u8{len: 8, init: 0xa5}
	mut writer := WriteStream.init_memory(mut bytes)
	png_filter(mut writer, pixels, PngTryAll{}, PngHeaderData{
		color_type:         .grayscale
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:     17
		height:    0
		bit_depth: 8
	})!
	assert writer.get_pos() == 0
	png_filter(mut writer, pixels, PngSpecified{ filter: .up }, PngHeaderData{
		color_type:         .grayscale
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:     0
		height:    3
		bit_depth: 8
	})!
	assert writer.get_pos() == 3
	assert bytes[..3] == [u8(2), 2, 2]
	assert bytes[3..] == []u8{len: 5, init: 0xa5}
}

fn test_png_filter_unsupported_source_format_empty_row_has_defined_noop() {
	mut bytes := []u8{len: 4, init: 0xa5}
	mut writer := WriteStream.init_memory(mut bytes)
	png_filter(mut writer, InvalidPixels{}, PngSpecified{ filter: .none }, PngHeaderData{
		color_type:         .grayscale
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:     1
		height:    3
		bit_depth: 0
	})!
	assert writer.get_pos() == 3
	assert bytes == [u8(0), 0, 0, 0xa5]
}

fn test_png_filter_packed_rows_keep_source_clipping_and_input_bytes() {
	pixels := PixelStorage(Grayscale4Pixels{
		data: [Grayscale4{ value: 3 }, Grayscale4{ value: 8 },
			Grayscale4{ value: 13 }]
	})
	before := pixels.as_bytes().clone()
	mut output := []u8{len: 8, init: u8(165)}
	mut writer := WriteStream.init_memory(mut output)
	png_filter(mut writer, pixels, PngSpecified{ filter: .none }, PngHeaderData{
		width:              3
		height:             1
		bit_depth:          1
		color_type:         .grayscale
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none
	})!
	assert writer.get_pos() == 2
	assert output == [u8(0), 0x38, 165, 165, 165, 165, 165, 165]
	assert pixels.as_bytes() == before
}
