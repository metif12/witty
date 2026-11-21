module main

import os
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.PCX(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_output []u8
)
fn header_bytes(header p.PCXHeader) string {
	return unsafe { (&u8(&header)).vbytes(128).hex() }
}

fn observe() {
	mut out := ''
	if observed_reader != unsafe { nil } { out += '${observed_reader.get_pos()}|' }
	if observed_writer != unsafe { nil } {
		out += '${observed_writer.get_pos()}|${observed_output.hex()}|'
	}
	if observed_codec != unsafe { nil } { out += header_bytes(observed_codec.header) }
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn pixels(format p.PixelFormat, count int, seed int) p.PixelStorage {
	mut result := p.PixelStorage.init(format, uint(count)) or { panic(err) }
	mut raw := result.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(if seed == 0 {
			1
		} else if seed == 1 {
			i * 17
		} else if seed == 2 {
			192
		} else {
			i / 16 + 1
		})
	}
	if _ := result.get_palette() {
		mut pal := result.get_palette() or { panic('missing palette') }
		length := if pal.len < 4 { pal.len } else { 4 }
		result.resize_palette(uint(length))
		for i in 0 .. length {
			pal[i] = p.Rgba32{
				r: u8(i * 31)
				g: u8(i * 71)
				b: u8(i * 113)
				a: u8(i * 47)
			}
		}
		if format == .indexed1 {
			for i in 0 .. raw.len {
				raw[i] &= 1
			}
		}
		if format == .indexed4 {
			for i in 0 .. raw.len {
				raw[i] &= 15
			}
		}
	}
	return result
}

fn write_case(format p.PixelFormat, width int, height int, seed int, capacity int, direct bool) {
	data := pixels(format, width * height, seed)
	mut buf := []u8{len: 1024, init: 165}
	mut section := unsafe { buf[..capacity] }
	mut writer := p.WriteStream.init_memory(mut section)
	mut status := 'ok'
	mut codec := p.PCX{
		header: p.PCXHeader{
			id:                  7
			version:             6
			compression:         .none
			bpp:                 99
			xmin:                10
			xmax:                u16(width + 9)
			ymin:                20
			ymax:                u16(height + 19)
			planes:              0
			reserved0:           37
			palette_information: unsafe { p.PcxPaletteInfo(u16(65535)) }
		}
	}
	if direct {
		codec.write(mut writer, data) or { status = err.msg() }
	} else {
		p.PCX.write_image(mut writer, p.ImageUnmanaged{
			width:  uint(width)
			height: uint(height)
			pixels: data
		}, p.PcxEncoderOptions{}) or { status = err.msg() }
	}
	println('W|${direct}|${u32(format)}|${width}|${height}|${seed}|${capacity}|${status}|${writer.get_pos()}|${buf[..capacity].hex()}')
}

fn main() {
	if os.args.len > 1 {
		if os.args[2] != '-' {
			observed_path = os.args[2]
			at_exit(observe) or { panic(err) }
		}
		if os.args[1] == '--dimension' {
			mut codec := p.PCX{
				header: p.PCXHeader{
					xmin: os.args[4].u16()
					xmax: os.args[5].u16()
					ymin: os.args[4].u16()
					ymax: os.args[5].u16()
				}
			}
			observed_codec = &codec
			_ = if os.args[3] == 'width' { codec.width() } else { codec.height() }
		} else if os.args[1] == '--read' {
			bytes := os.read_bytes(os.args[3]) or { panic(err) }
			mut reader := p.ReadStream.init_memory(bytes)
			mut codec := p.PCX{
				header: p.PCXHeader{
					version:   4
					bpp:       4
					xmax:      7
					ymax:      8
					reserved0: 165
					planes:    1
				}
			}
			observed_reader = &reader
			observed_codec = &codec
			result := codec.read(mut reader) or {
				if observed_path != '' {
					eprintln('UNEXPECTED: recoverable ${err.msg()}')
					return
				}
				println('${err.msg()}|${reader.get_pos()}|${header_bytes(codec.header)}')
				return
			}
			if observed_path == '' {
				pal := if colors := result.get_palette() {
					unsafe { (&u8(colors.data)).vbytes(colors.len * 4).hex() }
				} else {
					'-'
				}
				println(
					'ok|${reader.get_pos()}|${header_bytes(codec.header)}|${result.as_bytes().hex()}|' +
					pal)
				return
			}
		} else {
			capacity := os.args[3].int()
			mut output := []u8{len: 1024, init: 165}
			mut section := unsafe { output[..capacity] }
			mut writer := p.WriteStream.init_memory(mut section)
			observed_writer = &writer
			observed_output = unsafe { output[..capacity] }
			width := uint(os.args[4].u64())
			height := uint(os.args[5].u64())
			format := unsafe { p.PixelFormat(os.args[6].u32()) }
			data := pixels(format, 4, 1)
			mut status := 'ok'
			if os.args[1] == '--image' {
				p.PCX.write_image(mut writer, p.ImageUnmanaged{
					width:  width
					height: height
					pixels: data
				}, p.PcxEncoderOptions{}) or { status = err.msg() }
			} else {
				mut codec := p.PCX{
					header: p.PCXHeader{
						xmin: os.args[7].u16()
						xmax: os.args[8].u16()
						ymin: os.args[9].u16()
						ymax: os.args[10].u16()
					}
				}
				observed_codec = &codec
				codec.write(mut writer, data) or { status = err.msg() }
			}
			if observed_path == '' {
				println('${status}|${writer.get_pos()}|${output[..capacity].hex()}')
				return
			}
		}
		eprintln('UNEXPECTED: operation returned')
		return
	}
	for high in 0 .. 65535 {
		mut codec := p.PCX{
			header: p.PCXHeader{
				xmax: u16(high)
				ymax: u16(high)
			}
		}
		println('D|0|${high}|${codec.width()}|${codec.height()}')
	}
	for low in 1 .. 65536 {
		mut codec := p.PCX{
			header: p.PCXHeader{
				xmin: u16(low)
				xmax: 65535
				ymin: u16(low)
				ymax: 65535
			}
		}
		println('D|${low}|65535|${codec.width()}|${codec.height()}')
	}
	original := p.PCX{}
	mut copied := original
	copied.header.builtin_palette[15] = p.Rgb24{
		r: 1
		g: 2
		b: 3
	}
	copied.header.padding[53] = 99
	println('H|${sizeof(p.PCXHeader)}|${header_bytes(original.header)}|${header_bytes(copied.header)}')
	for direct in [false, true] {
		for format in [p.PixelFormat.indexed1, .indexed4, .indexed8, .rgb24, .grayscale8] {
			for width in [1, 2, 3, 8, 17, 32, 65] {
				for height in [1, 2] {
					for seed in 0 .. 4 {
						for capacity in [0, 1, 127, 128, 129, 160, 256, 1024] {
							write_case(format, width, height, seed, capacity, direct)
						}
					}
				}
			}
		}
	}
}
