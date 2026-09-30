module zigimg

fn test_complete_pixel_format_words_and_strides() {
	formats := [PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
		.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
		.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32,
		.rgb48, .rgba64, .float32]
	words := [u32(0), 1, 2, 4, 8, 16, 0x101, 0x102, 0x104, 0x108, 0x110, 0x208, 0x210, 0x303, 0x305,
		0x3305, 0x308, 0x408, 0x1305, 0x1308, 0x1408, 0x310, 0x410, 0x2420]
	strides := [u8(0), 1, 1, 1, 1, 2, 1, 1, 1, 1, 2, 2, 4, 1, 2, 2, 3, 4, 2, 3, 4, 6, 8, 16]
	assert sizeof(PixelFormat) == 4
	assert sizeof(PixelFormatInfo) == 4
	for i, format in formats {
		assert u32(format) == words[i]
		assert to_pixel_format_value(format.info()) == words[i]
		assert format.pixel_stride() == strides[i]
		storage := PixelStorage.init(format, 3)!
		assert storage.pixel_format() == format
		assert storage.len() == if format == .invalid {
			usize(0)
		} else {
			usize(3)
		}
		assert storage.as_bytes().len == int(strides[i]) * 3
	}
	assert PixelFormat.invalid.is_indexed()
	assert !PixelStorage(InvalidPixels{}).is_indexed()
	assert PixelFormat.rgb565.info().variant() == .rgb565
	assert PixelFormat.float32.channel_count() == 4
	assert PixelFormat.invalid.channel_count() == 1
	assert PixelFormat.grayscale16.is_16_bit()
}

fn test_raw_storage_borrows_and_slices_native_channel_bytes() {
	assert sizeof(Rgb24) == 3
	assert sizeof(Rgba32) == 4
	assert sizeof(Rgb48) == 6
	assert sizeof(Rgba64) == 8
	assert sizeof(Colorf32) == 16
	mut bytes := [u8(1), 2, 3, 4, 5, 6]
	mut storage := PixelStorage.init_raw_pixels(bytes, .rgb24)!
	assert storage.as_bytes().data == bytes.data
	match mut storage {
		Rgb24Pixels { storage.data[1].g = 9 }
		else { assert false }
	}

	assert bytes[4] == 9
	slice := storage.slice(1, 2)
	assert slice.as_bytes().data == unsafe { &bytes[0] + 3 }
	assert slice.as_bytes() == [u8(4), 9, 6]
	for format in [PixelFormat.invalid, .indexed1, .indexed16, .grayscale16] {
		PixelStorage.init_raw_pixels(bytes, format) or {
			assert err.msg() == 'Unsupported'
			continue
		}
		assert false
	}
}

fn test_palette_capacity_and_storage_slice_share_source_palette() {
	mut indexed := IndexedStorage2.init_palette_size(3, 2)
	assert indexed.palette.len == 2
	assert indexed.palette[0] == Rgba32{
		a: 255
	}
	pointer := indexed.palette.data
	indexed.resize_palette(4)
	assert indexed.palette.data == pointer
	assert indexed.palette.len == 4
	indexed.indices = [u8(0), 1, 0]
	storage := PixelStorage(indexed)
	slice := storage.slice(1, 3)
	assert slice.is_indexed()
	assert (slice.get_palette() or { panic('missing palette') }).data == pointer
	assert slice.as_bytes().data == unsafe { &indexed.indices[0] + 1 }
	assert slice.as_bytes() == [u8(1), 0]
}

fn test_image_raw_pixel_copy_and_owned_initialization_do_not_infer_dimensions() {
	mut bytes := [u8(1), 2, 3, 4, 5, 6]
	owned := ImageUnmanaged.from_raw_pixels_owned(9, 2, bytes, .rgb24)!
	duplicate := ImageUnmanaged.from_raw_pixels(9, 2, bytes, .rgb24)!
	assert owned.width == 9 && owned.height == 2
	assert owned.pixels.len() == 2 // Source accepts dimensions independently.
	assert owned.image_byte_size() == 6
	assert owned.row_byte_size() == 3
	assert !owned.is_animation()
	assert owned.raw_bytes().data == bytes.data
	assert duplicate.raw_bytes().data != bytes.data
	bytes[0] = 7
	assert owned.raw_bytes()[0] == 7
	assert duplicate.raw_bytes()[0] == 1
}
