module zigimg

// pixel_format.zig at d7b7ab0ba0899643831ef042bd73289510b39906.
pub enum PixelFormatVariant as u8 {
	none   = 0
	bgr    = 1
	float_ = 2
	rgb565 = 3
}

// PixelFormatInfo is a packed u32 in the source.
pub struct PixelFormatInfo {
pub mut:
	raw u32
}

pub fn (info PixelFormatInfo) bits_per_channel() u8 {
	return u8(info.raw)
}

pub fn (info PixelFormatInfo) channel_count() u8 {
	return u8((info.raw >> 8) & 15)
}

pub fn (info PixelFormatInfo) variant() PixelFormatVariant {
	return unsafe { PixelFormatVariant(u8((info.raw >> 12) & 15)) }
}

pub fn (info PixelFormatInfo) padding() u16 {
	return u16(info.raw >> 16)
}

pub fn to_pixel_format_value(info PixelFormatInfo) u32 {
	return info.raw
}

pub enum PixelFormat as u32 {
	invalid           = 0x0
	indexed1          = 0x1
	indexed2          = 0x2
	indexed4          = 0x4
	indexed8          = 0x8
	indexed16         = 0x10
	grayscale1        = 0x101
	grayscale2        = 0x102
	grayscale4        = 0x104
	grayscale8        = 0x108
	grayscale16       = 0x110
	grayscale8_alpha  = 0x208
	grayscale16_alpha = 0x210
	rgb332            = 0x303
	rgb555            = 0x305
	rgb565            = 0x3305
	rgb24             = 0x308
	rgba32            = 0x408
	bgr555            = 0x1305
	bgr24             = 0x1308
	bgra32            = 0x1408
	rgb48             = 0x310
	rgba64            = 0x410
	float32           = 0x2420
}
pub fn (format PixelFormat) info() PixelFormatInfo {
	return PixelFormatInfo{
		raw: u32(format)
	}
}

pub fn (format PixelFormat) is_grayscale() bool {
	return format in [.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16,
		.grayscale8_alpha, .grayscale16_alpha]
}

pub fn (format PixelFormat) is_indexed() bool {
	return format.info().channel_count() == 0
}

pub fn (format PixelFormat) is_standard_rgb() bool {
	return format in [.rgb24, .rgb48]
}

pub fn (format PixelFormat) is_rgba() bool {
	return format in [.rgba32, .rgba64]
}

pub fn (format PixelFormat) is_16_bit() bool {
	return format.info().bits_per_channel() == 16
}

pub fn (format PixelFormat) pixel_stride() u8 {
	info := format.info()
	if format.is_indexed() { return (info.bits_per_channel() + 7) / 8 }
	if format == .rgb332 { return 1 }
	return (info.channel_count() * info.bits_per_channel() + 7) / 8
}

pub fn (format PixelFormat) bits_per_channel() u8 {
	if format in [.rgb332, .rgb565] { panic('reached unreachable code') }
	return format.info().bits_per_channel()
}

pub fn (format PixelFormat) channel_count() u8 {
	return if format.is_indexed() { u8(1) } else { format.info().channel_count() }
}
