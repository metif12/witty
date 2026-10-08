module zigimg

fn test_pixel_format_info_preserves_all_field_bits_and_unnamed_variant_values() {
	for variant in 0 .. 16 {
		raw := u32(255) | (u32(15) << 8) | (u32(variant) << 12) | (u32(65535) << 16)
		info := PixelFormatInfo{
			raw: raw
		}
		assert info.bits_per_channel() == 255
		assert info.channel_count() == 15
		assert u8(info.variant()) == variant
		assert info.padding() == 65535
		assert to_pixel_format_value(info) == raw
	}
	zero := PixelFormatInfo{}
	assert to_pixel_format_value(zero) == 0
	assert zero.bits_per_channel() == 0 && zero.channel_count() == 0
	assert zero.variant() == .none && zero.padding() == 0
}

fn test_pixel_format_info_raw_mutation_borrows_while_value_copy_is_independent() {
	mut info := PixelFormatInfo{
		raw: 0x1234fedc
	}
	copied := info
	mut raw := &info.raw
	unsafe {
		*raw = 0xabcd4321
	}
	assert info.bits_per_channel() == 0x21
	assert info.channel_count() == 3
	assert u8(info.variant()) == 4
	assert info.padding() == 0xabcd
	assert copied.raw == 0x1234fedc
	info.raw = 0
	assert unsafe { *raw } == 0
}

fn test_pixel_format_named_stride_and_classification_quirks() {
	assert PixelFormat.invalid.is_indexed()
	assert PixelFormat.invalid.channel_count() == 1
	assert PixelFormat.invalid.pixel_stride() == 0
	assert PixelFormat.invalid.bits_per_channel() == 0
	assert PixelFormat.rgb332.info().bits_per_channel() == 3
	assert PixelFormat.rgb332.pixel_stride() == 1
	assert PixelFormat.rgb565.info().bits_per_channel() == 5
	assert PixelFormat.rgb565.pixel_stride() == 2
	assert PixelFormat.bgr555.bits_per_channel() == 5
	assert PixelFormat.bgr555.pixel_stride() == 2
	assert !PixelFormat.bgr24.is_standard_rgb()
	assert !PixelFormat.bgra32.is_rgba()
	assert PixelFormat.float32.info().variant() == .float_
	assert PixelFormat.float32.bits_per_channel() == 32
	assert PixelFormat.float32.channel_count() == 4
	assert PixelFormat.float32.pixel_stride() == 16
	assert !PixelFormat.float32.is_rgba()
}
