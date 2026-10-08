module main

import zigimg as p
import os

const formats = [p.PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
	.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
	.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48,
	.rgba64, .float32]

struct InfoAlignment {
	marker u8
	value  p.PixelFormatInfo
}

fn info(value p.PixelFormatInfo) string {
	return '${value.raw}|${value.bits_per_channel()},${value.channel_count()},${u8(value.variant())},${value.padding()}'
}

fn record(fields []string) string {
	raw := fields[1].u32()
	if fields[0] == 'F' {
		f := unsafe { p.PixelFormat(raw) }
		copied := unsafe { p.PixelFormat(p.to_pixel_format_value(f.info())) }
		flags := '${int(f.is_grayscale())},${int(f.is_indexed())},${int(f.is_standard_rgb())},${int(f.is_rgba())},${int(f.is_16_bit())}'
		bits := if f in [.rgb332, .rgb565] { '-' } else { f.bits_per_channel().str() }
		return 'F|${u32(copied)}|' + info(f.info()) +
			'|${flags}|${f.pixel_stride()}|${f.channel_count()}|${bits}'
	}
	mut value := p.PixelFormatInfo{
		raw: raw
	}
	copied := value
	mut borrowed := &value.raw
	before := info(value)
	unsafe {
		*borrowed = fields[2].u32()
	}
	return 'I|' + before + '|' + info(value) + '|' + info(copied)
}

fn defaults() {
	mut value := p.PixelFormatInfo{}
	mut output := 'D|' + info(value)
	value.raw = u32(201) | (u32(15) << 8) | (u32(15) << 12) | (u32(65535) << 16)
	output += '|' + info(value)
	copied := value
	value.raw = 0
	output += '|' + info(value) + '|' + info(copied)
	println(output +
		'|${p.to_pixel_format_value(p.PixelFormatInfo{})}|${sizeof(p.PixelFormatInfo)},${__offsetof(InfoAlignment, value)}')
	for index in 0 .. 1024 {
		packed := p.PixelFormatInfo{
			raw: u32(u8(index * 37)) | (u32((index / 4) & 15) << 8) | (u32((index / 64) & 15) << 12) | (u32(u16(index * 257)) << 16)
		}
		println('P|${index}|${p.to_pixel_format_value(packed)}')
	}
	for index, f in formats {
		println('V|${index}|${u8(f.info().variant())}')
	}
}

fn main() {
	if os.args.len > 2 && os.args[1] == '--variant-wide' {
		value := unsafe { p.PixelFormatVariant(os.args[2].int()) }
		println(u8(value))
		return
	}
	if os.args.len > 2 && os.args[1] == '--trap' {
		f := if os.args[2] == 'rgb332' { p.PixelFormat.rgb332 } else { p.PixelFormat.rgb565 }
		_ = f.bits_per_channel()
		panic('UNEXPECTED returned bits_per_channel')
	}
	defaults()
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line.split('|')))
	}
}
