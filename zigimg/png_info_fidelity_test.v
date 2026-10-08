module zigimg

fn png_info_fidelity_chunk(mut processor PngInfoProcessor, id u32, length u32, bytes []u8, color PngColorType) !u64 {
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

fn test_png_info_idat_reaches_count_and_size_limits_without_wrapping() {
	mut bytes := []u8{}
	mut writer := WriteStream.init_memory(mut bytes)
	mut processor := PngInfoProcessor{
		writer:     &writer
		idat_count: 0xfffffffe
		idat_size:  ~u64(0) - 0xffffffff
	}
	png_info_fidelity_chunk(mut processor, png_chunk_idat.id, 0xffffffff, []u8{}, .grayscale)!
	assert processor.idat_count == 0xffffffff
	assert processor.idat_size == ~u64(0)
	assert writer.get_pos() == 0
	processor.idat_count = 0
	png_info_fidelity_chunk(mut processor, png_chunk_idat.id, 0, []u8{}, .grayscale)!
	assert processor.idat_count == 1 && processor.idat_size == ~u64(0)
}

fn test_png_info_writer_failure_precedes_invalid_header_tag_names() {
	prefixes := [30, 52, 80, 104]
	for field, prefix in prefixes {
		for capacity in [0, prefix - 1] {
			mut bytes := []u8{len: capacity}
			mut writer := WriteStream.init_memory(mut bytes)
			mut processor := PngInfoProcessor.init(&writer)
			mut input := ReadStream.init_memory([]u8{})
			mut header := PngHeaderData{
				color_type:         .grayscale
				compression_method: .deflate
				filter_method:      .adaptive

				width:            17
				height:           3
				bit_depth:        8
				interlace_method: .adam7
			}
			unknown := '255'.int()
			match field {
				0 { header.color_type = unsafe { PngColorType(unknown) } }
				1 { header.compression_method = unsafe { PngCompressionMethod(unknown) } }
				2 { header.filter_method = unsafe { PngFilterMethod(unknown) } }
				else { header.interlace_method = unsafe { PngInterlaceMethod(unknown) } }
			}

			mut data := PngChunkProcessData{
				read_stream:    &input
				header:         &header
				chunk_id:       png_chunk_ihdr.id
				chunk_length:   13
				current_format: .grayscale8
			}
			callback := processor.processor()
			assert callback.process_chunk(mut data)! == .grayscale8
			assert input.get_pos() == 0 && writer.get_pos() == u64(capacity)
		}
	}
}

fn test_png_info_writer_failure_suppresses_missing_text_fields_after_reading_payload() {
	for payload in [[u8(0)], [u8(0), 0], [u8(0), 1], [u8(0), 2]] {
		// Stop the last preceding print one byte before it completes.
		capacity := if payload.len == 2 && payload[1] != 1 { 67 } else { 40 }
		mut bytes := []u8{len: capacity}
		mut writer := WriteStream.init_memory(mut bytes)
		mut processor := PngInfoProcessor.init(&writer)
		assert png_info_fidelity_chunk(mut processor, png_chunk_itxt.id, u32(payload.len), payload,
			.grayscale)! == u64(payload.len)
		assert writer.get_pos() == u64(capacity)
	}
}

fn test_png_info_by_value_counter_copy_retains_borrowed_writer() {
	mut bytes := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut bytes)
	mut original := PngInfoProcessor{
		writer: &writer
	}
	assert original.idat_count == 0 && original.idat_size == 0
	original.idat_count = 17
	original.idat_size = 23
	mut copy := original
	png_info_fidelity_chunk(mut copy, png_chunk_idat.id, 7, []u8{}, .grayscale)!
	png_info_fidelity_chunk(mut copy, png_chunk_iend.id, 0, []u8{}, .grayscale)!
	assert original.idat_count == 17 && original.idat_size == 23
	assert copy.idat_count == 18 && copy.idat_size == 30
	assert copy.writer == original.writer
	assert writer.buffered().bytestr().starts_with('IDAT Count: 18, Total Size: 30B\n')
}
