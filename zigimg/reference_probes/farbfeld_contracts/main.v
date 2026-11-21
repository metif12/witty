module main

import os
import zigimg as p

const formats = [p.PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
	.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
	.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48,
	.rgba64, .float32]

__global (
	observed_path   string
	observed_image  = &p.ImageUnmanaged(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_buffer []u8
)

fn header_bytes(header p.FarbfeldHeader) string {
	return unsafe { (&u8(&header)).vbytes(8).hex() }
}

fn state() string {
	image := observed_image
	return '${image.width}|${image.height}|${u32(image.pixels.pixel_format())}|${image.pixels.len()}|${image.pixels.as_bytes().hex()}|${observed_writer.get_pos()}|${observed_buffer.hex()}'
}

fn observe() {
	if observed_path != '' {
		os.write_file(observed_path, state()) or { eprintln('OBSERVER ERROR: ${err}') }
	}
}

fn make_pixels(format p.PixelFormat, count int) p.PixelStorage {
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
	return pixels
}

fn read_case() {
	entry := os.args[2].int()
	start := os.args[3].u64()
	data := os.read_bytes(os.args[4]) or { panic(err) }
	mut reader := p.ReadStream.init_memory(data)
	if start > 0 { reader.take(int(start)) or { panic(err) } }
	if entry == 2 {
		mut status := 'ok'
		result := p.Farbfeld.format_detect(mut reader) or {
			status = err.msg()
			false
		}
		println('${status}|${if result { 1 } else { 0 }}|${reader.get_pos()}|${data.hex()}')
		return
	}
	mut codec := p.Farbfeld{
		header: p.FarbfeldHeader{
			width:  7
			height: 9
		}
	}
	mut status := 'ok'
	mut result := p.ImageUnmanaged{}
	if entry == 0 {
		pixels := codec.read(mut reader) or {
			println('${err.msg()}|${reader.get_pos()}|${header_bytes(codec.header)}|${data.hex()}')
			return
		}
		result = p.ImageUnmanaged{
			width:  uint(codec.header.width)
			height: uint(codec.header.height)
			pixels: pixels
		}
	} else {
		result = p.Farbfeld.read_image(mut reader) or {
			status = err.msg()
			p.ImageUnmanaged{}
		}
	}
	h := if entry == 0 { header_bytes(codec.header) } else { '-' }
	if status != 'ok' {
		println('${status}|${reader.get_pos()}|${h}|${data.hex()}')
		return
	}
	before := result.pixels.as_bytes().hex()
	mut raw := result.pixels.as_bytes()
	mut separate := '-'
	if raw.len > 0 {
		pointer := uint(raw.data)
		separate = if pointer < uint(data.data) || pointer >= uint(data.data) + uint(data.len) {
			'1'
		} else {
			'0'
		}
		raw[0] ^= 255
	}
	println('ok|${reader.get_pos()}|${h}|${result.width}|${result.height}|${u32(result.pixels.pixel_format())}|${result.pixels.len()}|${before}|${separate}|${raw.hex()}|${data.hex()}')
}

fn main() {
	if os.args.len > 1 {
		if os.args[1] == '--read' {
			read_case()
			return
		}
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		mut image := p.ImageUnmanaged{
			width:  uint(os.args[3].u64())
			height: uint(os.args[4].u64())
			pixels: make_pixels(unsafe { p.PixelFormat(os.args[5].u32()) }, 2)
		}
		mut buffer := []u8{len: os.args[6].int(), init: 165}
		mut writer := p.WriteStream.init_memory(mut buffer)
		start := os.args[7].u64()
		if start > 0 { writer.seek_to(start) or { panic(err) } }
		observed_image = &image
		observed_writer = &writer
		observed_buffer = unsafe { buffer[..] }
		p.Farbfeld.write_image(mut writer, image) or {
			println('${err.msg()}|' + state())
			observed_path = ''
			return
		}
		println('ok|' + state())
		observed_path = ''
		return
	}
	println('H|${sizeof(p.FarbfeldHeader)}|${header_bytes(p.FarbfeldHeader{})}|${header_bytes(p.Farbfeld{}.header)}')
	for width in [u32(0), 1, 2, 0x80000000, 0xffffffff] {
		for height in [u32(0), 1, 2, 0x80000000, 0xffffffff] {
			codec := p.Farbfeld{
				header: p.FarbfeldHeader{
					width:  width
					height: height
				}
			}
			mut copy := codec
			copy.header.width ^= 0x12345678
			copy.header.height ^= 0x87654321
			println('H|${header_bytes(codec.header)}|${header_bytes(copy.header)}')
		}
	}
	for format in formats {
		for count in 0 .. 3 {
			pixels := make_pixels(format, count)
			for width in [u32(0), 1, 2, 0x80000000, 0xffffffff] {
				for height in [u32(0), 1, 2, 0x80000000, 0xffffffff] {
					codec := p.Farbfeld{
						header: p.FarbfeldHeader{
							width:  width
							height: height
						}
					}
					for capacity in [0, 1, 7, 8, 15, 16, 17, 23, 24, 31, 32, 33] {
						for entry in 0 .. 2 {
							mut buffer := []u8{len: capacity, init: 165}
							mut writer := p.WriteStream.init_memory(mut buffer)
							mut status := 'ok'
							if entry == 0 {
								codec.write(mut writer, pixels) or { status = err.msg() }
							} else {
								p.Farbfeld.write_image(mut writer, p.ImageUnmanaged{
									width:  uint(width)
									height: uint(height)
									pixels: pixels
								}) or { status = err.msg() }
							}
							println('W|${u32(format)}|${count}|${width}|${height}|${capacity}|${entry}|${status}|${writer.get_pos()}|${buffer.hex()}|${header_bytes(codec.header)}|${pixels.as_bytes().hex()}')
						}
					}
				}
			}
		}
	}
}
