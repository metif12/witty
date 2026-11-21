module main

import os
import encoding.hex
import zigimg as p

const formats = [p.PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
	.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
	.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48,
	.rgba64, .float32]

type AliasRgb = p.Rgb24
type AliasRgba = p.Rgba32

__global (
	observed_path   string
	observed_codec  = &p.QOI(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_data   []u8
	observed_entry  int
)
fn header_bytes(header p.QoiHeader) string {
	return unsafe { (&u8(&header)).vbytes(10).hex() }
}

fn color_bytes(color p.QoiColor) string {
	return unsafe { (&u8(&color)).vbytes(4).hex() }
}

fn state() string {
	if observed_entry == 3 { return observed_data.hex() }
	h := if observed_entry == 0 { header_bytes(observed_codec.header) } else { '-' }
	return '${observed_reader.get_pos()}|${h}|${observed_data.hex()}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn make_pixels(format p.PixelFormat, count int, pattern int) p.PixelStorage {
	mut pixels := p.PixelStorage.init(format, uint(count)) or { panic(err) }
	mut bytes := pixels.as_bytes()
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + 19)
	}
	// Narrow Source fields must contain valid values even though unsupported
	// storage is rejected before its contents are inspected.
	if format in [.indexed1, .indexed2, .indexed4, .grayscale1, .grayscale2, .grayscale4] {
		mask := if format in [.indexed1, .grayscale1] {
			u8(1)
		} else if format in [.indexed2, .grayscale2] {
			u8(3)
		} else {
			u8(15)
		}
		for i in 0 .. bytes.len {
			bytes[i] &= mask
		}
	}
	if format in [.rgb555, .bgr555] {
		for i in 0 .. count {
			bytes[i * 2 + 1] &= 127
		}
	}
	if format in [.rgb24, .rgba32] {
		mut data := pixels.as_bytes()
		stride := int(format.pixel_stride())
		for i in 0 .. count {
			color := sample(i, pattern)
			data[i * stride] = color.r
			data[i * stride + 1] = color.g
			data[i * stride + 2] = color.b
			if stride == 4 { data[i * stride + 3] = color.a }
		}
	}
	return pixels
}

fn sample(i int, pattern int) p.QoiColor {
	values := [u8(0), 1, 126, 127, 128, 254, 255]
	colors := [p.QoiColor{ r: 10, g: 20, b: 30 }, p.QoiColor{ r: 11, g: 21, b: 31 },
		p.QoiColor{ r: 14, g: 23, b: 32 }, p.QoiColor{ r: 100, g: 150, b: 200, a: 50 },
		p.QoiColor{ r: 0, g: 0, b: 0, a: 0 }]
	return match pattern {
		0 {
			p.QoiColor{
				r: 0
				g: 0
				b: 0
			}
		}
		1 {
			p.QoiColor{
				r: u8(i * 37 + 19)
				g: u8(i * 71 + 53)
				b: u8(i * 97 + 11)
				a: u8(i * 13 + 29)
			}
		}
		2 {
			p.QoiColor{
				r: u8(128 + i % 20)
				g: u8(127 + i % 20)
				b: u8(126 + i % 20)
			}
		}
		3 {
			p.QoiColor{
				r: values[i % 7]
				g: values[(i + 2) % 7]
				b: values[(i + 4) % 7]
				a: values[(i + 6) % 7]
			}
		}
		4 {
			p.QoiColor{
				r: u8((i / 62) % 2)
				g: u8((i / 62) % 2)
				b: u8((i / 62) % 2)
			}
		}
		else {
			colors[i % colors.len]
		}
	}
}

fn read_case(entry int, start int, data []u8) {
	mut reader := p.ReadStream.init_memory(data)
	if start > 0 { reader.take(start) or { panic(err) } }
	mut codec := p.QOI{
		header: p.QoiHeader{
			width:      7
			height:     9
			format:     .rgba
			colorspace: .linear
		}
	}
	observed_reader = &reader
	observed_codec = &codec
	observed_data = unsafe { data[..] }
	observed_entry = entry
	if entry == 2 {
		mut status := 'ok'
		result := p.QOI.format_detect(mut reader) or {
			status = err.msg()
			false
		}
		println('${status}|${if result { 1 } else { 0 }}|${reader.get_pos()}|${data.hex()}')
		return
	}
	mut status := 'ok'
	mut result := p.ImageUnmanaged{}
	if entry == 0 {
		pixels := codec.read(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		result = p.ImageUnmanaged{
			width:  codec.width()
			height: codec.height()
			pixels: pixels
		}
	} else {
		result = p.QOI.read_image(mut reader) or {
			status = err.msg()
			p.ImageUnmanaged{}
		}
	}
	if status != 'ok' {
		println('${status}|' + state())
		return
	}
	before := result.pixels.as_bytes().hex()
	mut raw := result.pixels.as_bytes()
	mut separate := '-'
	if raw.len > 0 {
		ptr := uint(raw.data)
		separate = if ptr < uint(data.data) || ptr >= uint(data.data) + uint(data.len) {
			'1'
		} else {
			'0'
		}
		raw[0] ^= 255
	}
	println('ok|' + state() +
		'|${result.width}|${result.height}|${u32(result.pixels.pixel_format())}|${result.pixels.len()}|${before}|${separate}|${raw.hex()}')
}

fn write_case(format p.PixelFormat, count int, pattern int, width uint, height uint, space p.QoiColorspace, capacity int, entry int) {
	pixels := make_pixels(format, count, pattern)
	codec := p.QOI{
		header: p.QoiHeader{
			width:      u32(width)
			height:     u32(height)
			format:     .rgba
			colorspace: space
		}
	}
	mut buffer := []u8{len: capacity, init: 165}
	mut writer := p.WriteStream.init_memory(mut buffer)
	image := p.ImageUnmanaged{
		width:  width
		height: height
		pixels: pixels
	}
	mut status := 'ok'
	if entry == 0 {
		codec.write(mut writer, pixels) or { status = err.msg() }
	} else if entry == 1 {
		p.QOI.write_image(mut writer, image, p.QoiEncoderOptions{ colorspace: space }) or {
			status = err.msg()
		}
	} else {
		p.QOI.format_interface().write_image(mut writer, image, p.FarbfeldEncoderOptions{}) or {
			status = err.msg()
		}
	}
	println('W|${u32(format)}|${count}|${pattern}|${width}|${height}|${u8(space)}|${capacity}|${entry}|${status}|${writer.get_pos()}|${buffer.hex()}|${pixels.as_bytes().hex()}')
}

fn main() {
	if os.args.len > 1 {
		if os.args[1] == '--corpus' {
			lines := os.read_lines(os.args[2]) or { panic(err) }
			for line in lines {
				fields := line.split('|')
				read_case(fields[0].int(), fields[1].int(), hex.decode(fields[2]) or { panic(err) })
			}
			return
		}
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		if os.args[1] == '--read' {
			data := os.read_bytes(os.args[5]) or { panic(err) }
			read_case(os.args[3].int(), os.args[4].int(), data)
		} else {
			observed_entry = 3
			match os.args[3] {
				'int' {
					value := 7
					observed_data = unsafe { (&u8(&value)).vbytes(4) }
					_ = p.QoiColor.from(value)
				}
				'color' {
					value := p.QoiColor{
						r: 1
						g: 2
						b: 3
						a: 4
					}
					observed_data = unsafe { (&u8(&value)).vbytes(4) }
					_ = p.QoiColor.from(value)
				}
				'rgb48' {
					value := p.Rgb48{
						r: 1
						g: 2
						b: 3
					}
					observed_data = unsafe { (&u8(&value)).vbytes(6) }
					_ = p.QoiColor.from(value)
				}
				'pointer' {
					value := p.Rgb24{
						r: 1
						g: 2
						b: 3
					}
					observed_data = unsafe { (&u8(&value)).vbytes(3) }
					_ = p.QoiColor.from(&value)
				}
				else {
					value := true
					observed_data = unsafe { (&u8(&value)).vbytes(1) }
					_ = p.QoiColor.from(value)
				}
			}

			eprintln('UNEXPECTED: factory returned')
		}
		observed_path = ''
		return
	}
	for r in 0 .. 256 {
		for g in [u8(0), 1, 127, 128, 254, 255] {
			for b in [u8(0), 1, 127, 128, 254, 255] {
				for a in [u8(0), 1, 127, 255] {
					c := p.QoiColor{
						r: u8(r)
						g: g
						b: b
						a: a
					}
					mut other := c
					other.a ^= 255
					rgb := c.to_rgb24()
					rgba := c.to_rgba32()
					println('C|${color_bytes(c)}|${if c.eql(c) { 1 } else { 0 }}|${if c.eql(other) {
						1
					} else {
						0
					}}|${color_bytes(p.QoiColor.from(rgb))}|${color_bytes(p.QoiColor.from(rgba))}')
				}
			}
		}
	}
	println('A|${color_bytes(p.QoiColor.from(AliasRgb{ r: 1, g: 2, b: 3 }))}|${color_bytes(p.QoiColor.from(AliasRgba{
		r: 1
		g: 2
		b: 3
		a: 4
	}))}')
	mut options := p.QoiEncoderOptions{}
	options_copy := options
	options.colorspace = .linear
	println('O|${u8(options_copy.colorspace)}|${u8(options.colorspace)}')
	println('S|${sizeof(p.QoiColor)}|${sizeof(p.QoiHeader)}')
	for width in [u32(0), 1, 2, 0x80000000, 0xffffffff] {
		for height in [u32(0), 1, 2, 0x80000000, 0xffffffff] {
			for format in [p.QoiFormat.rgb, .rgba] {
				for space in [p.QoiColorspace.srgb, .linear] {
					codec := p.QOI{
						header: p.QoiHeader{
							width:      width
							height:     height
							format:     format
							colorspace: space
						}
					}
					mut copy := codec
					copy.header.width ^= 0x12345678
					copy.header.height ^= 0x87654321
					pf := codec.pixel_format() or { panic(err) }
					println('H|${header_bytes(codec.header)}|${codec.width()}|${codec.height()}|${u32(pf)}|${header_bytes(copy.header)}')
				}
			}
		}
	}
	for format in formats {
		for count in 0 .. 3 {
			for dim in [[uint(0), 0], [uint(1), 2], [uint(0xffffffff), 0],
				[uint(0x100000001), 0x100000002], [uint(0xffffffffffffffff), 0xffffffffffffffff]] {
				for space in [p.QoiColorspace.srgb, .linear] {
					for capacity in [0, 3, 4, 13, 14, 15, 21, 22, 23, 32] {
						for entry in 0 .. 3 {
							write_case(format, count, 1, dim[0], dim[1], space, capacity, entry)
						}
					}
				}
			}
		}
	}
	for format in [p.PixelFormat.rgb24, .rgba32] {
		for count in [0, 1, 2, 3, 61, 62, 63, 64, 124, 125] {
			for pattern in 0 .. 6 {
				for space in [p.QoiColorspace.srgb, .linear] {
					for capacity in [0, 14, 15, 16, 17, 21, 22, 23, 31, 32, 64, 256, 1024] {
						for entry in 0 .. 2 {
							write_case(format, count, pattern, 1, uint(count), space, capacity,
								entry)
						}
					}
				}
			}
		}
	}
}
