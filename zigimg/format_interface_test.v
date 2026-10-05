module zigimg

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
