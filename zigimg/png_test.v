module zigimg

fn test_png_writer_matches_pinned_signature_only_output() {
	assert sizeof(PngHeaderData) == 13
	image := ImageUnmanaged.create(2, 1, .rgba32)!
	mut bytes := []u8{len: 8}
	mut stream := WriteStream.init_memory(mut bytes)
	PNG.write_image(mut stream, image, PngEncoderOptions{})!
	assert stream.buffered() == png_magic_header[..]
	assert stream.get_pos() == 8
	mut reader := ReadStream.init_memory(bytes)
	assert PNG.format_detect(mut reader)!
	assert reader.get_pos() == 0
}

fn test_png_writer_uses_source_buffer_size_and_error_contract() {
	image := ImageUnmanaged.create(1, 1, .rgba32)!
	mut bytes := []u8{len: int(image.image_byte_size())}
	mut stream := WriteStream.init_memory(mut bytes)
	PNG.write_image(mut stream, image, PngEncoderOptions{}) or {
		assert err.msg() == 'WriteFailed'
		assert stream.buffered() == png_magic_header[..4]
		return
	}
	assert false
}

fn test_png_writer_rejects_interlace_and_unsupported_pixel_formats() {
	mut bytes := []u8{len: 100}
	mut stream := WriteStream.init_memory(mut bytes)
	for format in [PixelFormat.invalid, .indexed16, .rgb332, .rgb555, .rgb565, .bgr555, .bgr24,
		.bgra32, .float32] {
		image := ImageUnmanaged.create(2, 1, format)!
		PNG.write_image(mut stream, image, PngEncoderOptions{}) or {
			assert err.msg() == 'Unsupported'
			assert stream.get_pos() == 0
			continue
		}
		assert false
	}
	image := ImageUnmanaged.create(2, 1, .rgba32)!
	PNG.write_image(mut stream, image, PngEncoderOptions{ interlaced: true }) or {
		assert err.msg() == 'Unsupported'
		assert stream.get_pos() == 0
		return
	}
	assert false
}

fn test_png_header_dimension_depth_and_format_helpers() {
	mut header := PngHeaderData{
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:      3
		height:     2
		bit_depth:  8
		color_type: .rgba_color
	}
	assert header.is_valid()
	assert header.channel_count() == 4
	assert header.pixel_bits() == 32
	assert header.line_bytes() == 12
	assert header.get_pixel_format() == .rgba32
	assert header.allows_palette()
	header.bit_depth = 16
	assert header.max_palette_size() == 256
	assert header.get_pixel_format() == .rgba64
	header.color_type = .indexed
	assert !header.is_valid()
	header.bit_depth = 2
	assert header.is_valid()
	assert header.max_palette_size() == 4
	assert header.line_bytes() == 1
	assert header.get_pixel_format() == .indexed2
	header.width = 0
	assert !header.is_valid()
	assert header.get_pixel_format() == .indexed2 // Source checks depth here, not dimensions.
}
