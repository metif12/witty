module zigimg

fn test_png_header_record_copies_remain_independent_after_mutation() {
	mut original := PngHeaderData{
		width:              3
		height:             7
		bit_depth:          8
		color_type:         .rgba_color
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none
	}
	mut copy := original
	copy.width = 0
	copy.color_type = .grayscale
	copy.bit_depth = 1
	original.height = 9
	assert original.is_valid() && !copy.is_valid()
	assert original.line_bytes() == 12 && copy.line_bytes() == 0
	assert original.height == 9 && copy.height == 7
	copy.width = 17
	assert copy.is_valid() && copy.line_bytes() == 3
}

fn test_png_chunk_records_copy_fields_and_keep_live_name_borrows() {
	mut storage := [u8(`I`), `H`, `D`, `R`, 0]!
	mut original := PngChunk{
		id:   11
		name: unsafe { tos(&storage[0], 4) }
	}
	mut copy := original
	copy.id = 17
	storage[0] = `t`
	assert original.id == 11 && copy.id == 17
	assert original.name == 'tHDR' && copy.name == 'tHDR'
	copy.name = 'IDAT'
	original.id = 23
	assert original.id == 23 && copy.id == 17 && copy.name == 'IDAT'

	mut header := PngChunkHeader{
		length:     7
		chunk_type: png_chunk_ihdr.id
	}
	mut header_copy := header
	borrowed := header.name()
	header.chunk_type = png_chunk_idat.id
	header_copy.length = 13
	assert borrowed == header.name()
	assert header_copy.chunk_type == png_chunk_ihdr.id
	assert header.length == 7 && header_copy.length == 13
	$if little_endian {
		assert borrowed == 'TADI'.bytes()
	} $else {
		assert borrowed == 'IDAT'.bytes()
	}
}

fn test_png_encoder_options_default_and_copied_choice_replacement() {
	mut original := PngEncoderOptions{}
	assert !original.interlaced && original.filter_choice is PngHeuristic
	original.interlaced = true
	original.filter_choice = PngSpecified{
		filter: .paeth
	}
	mut copy := original
	copy.interlaced = false
	// Replacing the whole choice preserves the original. V sum-type payloads
	// are boxed; mutation through a copied payload is measured separately in
	// reference_probes/png_records rather than claimed as Source value copying.
	copy.filter_choice = PngSpecified{
		filter: .sub
	}
	assert original.interlaced && !copy.interlaced
	match original.filter_choice {
		PngSpecified { assert original.filter_choice.filter == .paeth }
		else { assert false }
	}

	match copy.filter_choice {
		PngSpecified { assert copy.filter_choice.filter == .sub }
		else { assert false }
	}

	copy.filter_choice = PngTryAll{}
	assert copy.filter_choice is PngTryAll && original.filter_choice is PngSpecified
}
