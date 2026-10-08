module zigimg

fn test_png_transparency_keeps_native_sample_index_behavior() {
	mut processor := PngTrnsProcessor{
		trns_data: PngTrnsGray{
			value: 7
		}
	}
	mut bytes := [u8(7), 0, 33, 44, 7, 0, 33, 44]
	mut row := PngRowProcessData{
		dest_row:    unsafe { bytes[..] }
		src_format:  .grayscale16
		dest_format: .grayscale16_alpha
		header:      &PngHeaderData{
			width:              0
			height:             0
			bit_depth:          0
			color_type:         .grayscale
			compression_method: .deflate
			filter_method:      .adaptive
			interlace_method:   .none
		}
	}
	assert processor.process_data_row(mut row)! == .grayscale16_alpha
	assert processor.processed && row.src_format == .grayscale16
	// The second comparison sees the alpha byte written by the first iteration.
	$if little_endian {
		assert bytes == [u8(7), 0, 0, 0, 7, 0, 255, 255]
	} $else {
		assert bytes == [u8(7), 0, 0, 0, 7, 0, 255, 255]
	}
}

fn test_png_processor_palette_views_follow_mutable_consumer_storage() {
	mut palette := [Rgba32{ r: 10, g: 20, b: 30, a: 40 }, Rgba32{ r: 50, g: 60, b: 70, a: 80 }]
	mut processor := PngPlteProcessor{}
	adapter := processor.processor()
	mut data := PngPaletteProcessData{
		palette: unsafe { palette[..] }
	}
	adapter.process_palette(mut data)!
	palette[1].a = 127
	mut bytes := [u8(1), 9, 9, 9, 77, 78, 79, 80]
	mut row := PngRowProcessData{
		dest_row:    unsafe { bytes[..] }
		src_format:  .indexed8
		dest_format: .rgba64
		header:      &PngHeaderData{
			width:              0
			height:             0
			bit_depth:          0
			color_type:         .grayscale
			compression_method: .deflate
			filter_method:      .adaptive
			interlace_method:   .none
		}
	}
	assert adapter.process_data_row(mut row)! == .rgba32
	assert processor.processed && row.src_format == .indexed8
	assert bytes == [u8(50), 60, 70, 127, 77, 78, 79, 80]
}

fn test_png_transparency_palette_error_sets_processed_before_returning() {
	mut processor := PngTrnsProcessor{
		trns_data: PngTrnsRGB{
			color: Rgb48{
				r: 1
				g: 2
				b: 3
			}
		}
	}
	mut palette := [Rgba32{ r: 7, g: 8, b: 9, a: 11 }]
	mut data := PngPaletteProcessData{
		palette: unsafe { palette[..] }
	}
	mut status := ''
	processor.process_palette(mut data) or { status = err.msg() }
	assert status == 'InvalidData' && processor.processed
	assert palette[0] == Rgba32{
		r: 7
		g: 8
		b: 9
		a: 11
	}
}

fn test_png_processor_row_bypass_precedes_incompatible_transparency_arm() {
	mut processor := PngTrnsProcessor{
		trns_data: PngTrnsIndexAlpha{
			data: [u8(3), 17]
		}
	}
	mut bytes := [u8(1), 2, 3]
	mut row := PngRowProcessData{
		dest_row:    unsafe { bytes[..] }
		src_format:  .rgb24
		dest_format: .rgb24
		header:      &PngHeaderData{
			width:              0
			height:             0
			bit_depth:          0
			color_type:         .grayscale
			compression_method: .deflate
			filter_method:      .adaptive
			interlace_method:   .none
		}
	}
	assert processor.process_data_row(mut row)! == .rgb24
	assert processor.processed && bytes == [u8(1), 2, 3]
	row.src_format = .indexed8
	row.dest_format = .rgba32
	assert processor.process_data_row(mut row)! == .indexed8
	assert bytes == [u8(1), 2, 3]
}
