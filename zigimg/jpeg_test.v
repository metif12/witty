module zigimg

import os

fn jpeg_test_hash(bytes []u8) u64 {
	mut hash := u64(14695981039346656037)
	for byte in bytes { hash = (hash ^ byte) * u64(1099511628211) }
	return hash
}

fn test_jpeg_native_reference_hashes_memory_and_file_registry() {
	// Hashes obtained from the unchanged locked Zig JPEG reader.
	for i, name in ['grayscale-baseline.jpg', 'rgb-baseline.jpg', 'rgb-progressive-restart.jpg'] {
		path := os.join_path(@VMODROOT, 'zigimg', 'testdata', 'jpeg', name)
		data := os.read_bytes(path)!
		memory := Image.from_memory(data)!
		mut buffer := []u8{len: 4096}
		file := Image.from_file_path(path, mut buffer)!
		assert file.width == memory.width && file.height == memory.height
		assert file.raw_bytes() == memory.raw_bytes()
		assert file.pixel_format() == if i == 0 { PixelFormat.grayscale8 } else { PixelFormat.rgb24 }
		assert Image.detect_format_from_file_path(path, mut buffer)! == .jpeg
		expected := [u64(0x8b359c89b231c6f9), 0xc680971371d74bfc, 0xaa4f129f577f0b1f][i]
		assert jpeg_test_hash(memory.raw_bytes()) == expected
	}
}

fn test_jpeg_magnitude_eight_and_source_error_cleanup() {
	mut stream := ReadStream.init_memory([u8(0x3f), 0])
	mut reader := JpegHuffmanReader.init(mut stream)
	assert reader.read_magnitude_coded(8)! == -192
	mut invalid := ReadStream.init_memory([u8(0), 0])
	mut jpeg := JPEG.init()
	mut pixels := JpegPixels{ value: Grayscale8Pixels{data: [Grayscale8{value: 17}]} }
	jpeg.read(mut invalid, mut pixels) or { assert err.msg() == 'InvalidData' }
	assert pixels.value == none
	mut unsupported := ReadStream.init_memory([u8(0xff), 0xd8, 0xff, 0xc1])
	JPEG.read_image(mut unsupported) or { assert err.msg() == 'Unsupported' }
}

fn test_jpeg_source_encoder_is_an_empty_success() {
	// The locked JPEG writer itself has no output; preserve that upstream API.
	image := Image.create(1, 1, .rgb24)!
	mut buffer := []u8{len: 16, init: 0xa5}
	assert image.write_to_memory(mut buffer, JpegEncoderOptions{})! == []u8{}
	assert buffer == []u8{len: 16, init: 0xa5}
}
