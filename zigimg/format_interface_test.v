module zigimg

fn interface_detect_false(mut stream ReadStream) !bool {
	_ = stream
	return false
}

fn interface_detect_true(mut stream ReadStream) !bool {
	_ = stream
	return true
}

fn interface_read_first(mut stream ReadStream) !ImageUnmanaged {
	_ = stream
	return ImageUnmanaged{
		width: 1
	}
}

fn interface_read_second(mut stream ReadStream) !ImageUnmanaged {
	_ = stream
	return ImageUnmanaged{
		width: 2
	}
}

fn interface_write_first(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = image
	_ = options
	stream.write_byte(0x11)!
}

fn interface_write_second(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = image
	_ = options
	stream.write_byte(0x22)!
}

fn test_format_interface_mutable_callbacks_and_independent_copies() {
	mut codec := FormatInterface{
		format_detect: interface_detect_false
		read_image:    interface_read_first
		write_image:   interface_write_first
	}
	mut copied := codec
	codec.format_detect = interface_detect_true
	codec.read_image = interface_read_second
	codec.write_image = interface_write_second
	mut reader := ReadStream.init_memory([]u8{})
	assert codec.format_detect(mut reader)!
	assert !copied.format_detect(mut reader)!
	loaded := codec.read_image(mut reader)!
	old_loaded := copied.read_image(mut reader)!
	assert loaded.width == 2 && old_loaded.width == 1
	mut output := []u8{len: 2}
	mut writer := WriteStream.init_memory(mut output)
	codec.write_image(mut writer, ImageUnmanaged{}, QoiEncoderOptions{})!
	copied.write_image(mut writer, ImageUnmanaged{}, QoiEncoderOptions{})!
	assert output == [u8(0x22), 0x11]
	copied.read_image = interface_read_second
	codec.read_image = interface_read_first
	independent := copied.read_image(mut reader)!
	assert independent.width == 2
}

fn test_format_interface_qoi_default_options_and_direct_loading() {
	image := ImageUnmanaged.from_raw_pixels(1, 1, [u8(12), 34, 56, 78], .rgba32)!
	codec := QOI.format_interface()
	mut output := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut output)
	// The source selects sRGB when the encoder-options tag belongs to another codec.
	codec.write_image(mut writer, image, PngEncoderOptions{ interlaced: true })!
	assert output[13] == 0
	mut reader := ReadStream.init_memory(writer.buffered())
	found := codec.format_detect(mut reader)!
	assert found && reader.get_pos() == 0
	decoded := codec.read_image(mut reader)!
	assert decoded.width == 1 && decoded.height == 1
	assert decoded.raw_bytes() == image.raw_bytes()
	// The source reader leaves QOI's eight-byte end marker unread.
	assert reader.get_pos() == writer.get_pos() - 8
	loaded := ImageUnmanaged.from_memory(writer.buffered())!
	assert loaded.raw_bytes() == image.raw_bytes()
}

fn test_format_interface_netpbm_accepts_each_netpbm_option_tag() {
	image := ImageUnmanaged.from_raw_pixels(1, 1, [u8(127)], .grayscale8)!
	codec := PGM.format_interface()
	mut output := []u8{len: 128}
	mut stream := WriteStream.init_memory(mut output)
	codec.write_image(mut stream, image, QoiEncoderOptions{})!
	assert stream.buffered() == 'P2\n# Created by zigimg\n1 1\n255\n127\n'.bytes()
	stream = WriteStream.init_memory(mut output)
	codec.write_image(mut stream, image, PbmEncoderOptions{ binary: true })!
	mut expected := 'P5\n# Created by zigimg\n1 1\n255\n'.bytes()
	expected << u8(127)
	assert stream.buffered() == expected
}

fn test_format_interface_noop_writers_accept_other_option_tags() {
	for codec in [JPEG.format_interface(), TIFF.format_interface()] {
		mut output := []u8{len: 8, init: 0xa5}
		mut stream := WriteStream.init_memory(mut output)
		codec.write_image(mut stream, ImageUnmanaged{}, PngEncoderOptions{ interlaced: true })!
		assert stream.get_pos() == 0 && output == []u8{len: 8, init: 0xa5}
	}
}
