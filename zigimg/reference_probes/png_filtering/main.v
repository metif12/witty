module main

import os
import encoding.hex
import zigimg

const formats = [zigimg.PixelFormat.indexed1, .indexed2, .indexed4, .indexed8, .grayscale1,
	.grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha, .grayscale16_alpha,
	.rgb24, .rgb48, .rgba32, .rgba64, .indexed16, .invalid, .rgb332, .rgb565]!

fn pixels_for(format zigimg.PixelFormat, count uint, seed int) zigimg.PixelStorage {
	if format == .invalid { return zigimg.InvalidPixels{} }
	pixels := zigimg.PixelStorage.init(format, count) or { panic(err) }
	mut bytes := pixels.as_bytes()
	depth := format.bits_per_channel()
	for i, mut byte in bytes {
		byte = u8(i * 37 + seed * 19 + i / 7)
		if depth < 8 { byte &= u8((u16(1) << depth) - 1) }
	}
	return pixels
}

fn trapped(name string) {
	mut header := zigimg.PngHeaderData{
		color_type:         .grayscale
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:     1
		height:    1
		bit_depth: 8
	}
	mut format := zigimg.PixelFormat.grayscale8
	mut count := uint(1)
	mut choice := zigimg.PngFilterChoice(zigimg.PngSpecified{
		filter: .none
	})
	match name {
		'short_pixels' {
			header.width = 2
		}
		'channels8' {
			header.color_type = .rgba_color
		}
		'channels16' {
			format = .grayscale16
			header.bit_depth = 16
			header.color_type = .rgba_color
		}
		'odd16' {
			format = .grayscale16
		}
		'try_all' {
			choice = zigimg.PngTryAll{}
		}
		'rgb332' {
			format = .rgb332
		}
		'rgb565' {
			format = .rgb565
		}
		'pixel_bits' {
			header.bit_depth = 255
			header.color_type = .rgba_color
			header.height = 0
			count = 0
		}
		'line_product' {
			header.width = 0x20000000
			header.bit_depth = 16
			header.height = 0
			count = 0
		}
		'line_round' {
			header.width = 0xfffffffc
			header.bit_depth = 1
			header.height = 0
			count = 0
		}
		else {
			panic('fixture trap')
		}
	}

	pixels := zigimg.PixelStorage.init(format, count) or { panic('UNEXPECTED allocation ${err}') }
	mut source := pixels.as_bytes()
	for mut byte in source {
		byte = 0
	}
	mut bytes := []u8{len: 32, init: 0xa5}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	zigimg.png_filter(mut writer, pixels, choice, header) or {
		eprintln('UNEXPECTED returned ${err}')
		return
	}
	eprintln('UNEXPECTED returned normally')
}

fn main() {
	if os.args[1].starts_with('trap:') {
		trapped(os.args[1][5..])
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		p := line.split('|').map(it.u64())
		pixels := pixels_for(formats[int(p[0])], uint(p[3]), int(p[6]))
		header := zigimg.PngHeaderData{
			compression_method: .deflate
			filter_method:      .adaptive
			interlace_method:   .none

			width:      u32(p[1])
			height:     u32(p[2])
			bit_depth:  u8(p[4])
			color_type: unsafe { zigimg.PngColorType(u8(p[5])) }
		}
		choice := if p[7] == 6 {
			zigimg.PngFilterChoice(zigimg.PngTryAll{})
		} else if p[7] == 5 {
			zigimg.PngFilterChoice(zigimg.PngHeuristic{})
		} else {
			zigimg.PngFilterChoice(zigimg.PngSpecified{
				filter: unsafe { zigimg.PngFilterType(u8(p[7])) }
			})
		}
		mut bytes := []u8{len: int(p[8]), init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut bytes)
		mut failed := false
		zigimg.png_filter(mut writer, pixels, choice, header) or {
			if err.msg() != 'InvalidData' { panic(err) }
			failed = true
		}
		println('${int(failed)}|${writer.get_pos()}|${hex.encode(bytes)}')
	}
}
