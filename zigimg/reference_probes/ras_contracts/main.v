module main

import os
import encoding.hex
import zigimg as p

const formats = [p.PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
	.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
	.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48,
	.rgba64, .float32]

__global (
	observed_path   string
	observed_codec  = &p.RAS(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_data   []u8
	observed_buffer []u8
	observed_op     int
)
fn header(w u32, h u32, d u32, kind p.RasType, map_kind p.RasColorMapType, length u32) p.RasHeader {
	return p.RasHeader{
		width:            w
		height:           h
		depth:            d
		length:           123
		type_:            kind
		color_map_type:   map_kind
		color_map_length: length
	}
}

fn bytes(h p.RasHeader) string {
	return unsafe { (&u8(&h)).vbytes(28).hex() }
}

fn palette(pixels p.PixelStorage) string {
	if pal := pixels.get_palette() { return unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() } }
	return '-'
}

fn state() string {
	if observed_op == 3 || observed_op == 4 {
		return '${observed_reader.get_pos()}|-|-|${observed_buffer.hex()}|${observed_data.hex()}'
	}
	pal := observed_codec.palette.data
	return '${observed_reader.get_pos()}|${bytes(observed_codec.header)}|' +
		unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() } +
		'|${observed_buffer.hex()}|${observed_data.hex()}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
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

fn run_case(op int, kind u32, map_kind u32, length u32, capacity int, start int, data []u8) {
	mut codec := p.RAS{
		header: header(7, 9, 8, unsafe { p.RasType(kind) }, unsafe { p.RasColorMapType(map_kind) },
			length)
	}
	codec.palette.resize(256)
	for i in 0 .. 256 {
		codec.palette.data[i] = p.Rgba32{
			r: u8(i * 31)
			g: u8(i * 71)
			b: u8(i * 47)
			a: 99
		}
	}
	codec.palette.resize(4)
	mut reader := p.ReadStream.init_memory(data)
	if start > 0 { reader.take(start) or { panic(err) } }
	observed_codec = &codec
	observed_reader = &reader
	observed_data = unsafe { data[..] }
	observed_op = op
	observed_buffer = []
	if op == 4 {
		mut status := 'ok'
		result := p.RAS.format_detect(mut reader) or {
			status = err.msg()
			false
		}
		println('${status}|${if result { 1 } else { 0 }}|' + state())
		return
	}
	if op == 1 {
		codec.read_palette(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|' + state())
		return
	}
	if op == 2 {
		mut buffer := []u8{len: capacity, init: 165}
		observed_buffer = unsafe { buffer[..] }
		codec.uncompress_bitmap(mut reader, mut buffer) or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|' + state())
		return
	}
	mut result := p.ImageUnmanaged{}
	if op == 0 {
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
		result = p.RAS.read_image(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
	}
	before := result.pixels.as_bytes().hex()
	pal_before := palette(result.pixels)
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
	mut pal_separate := '-'
	if pal := result.pixels.get_palette() {
		if pal.len > 0 {
			mut active := unsafe { pal }
			pal_separate = if op == 0 && uint(pal.data) == uint(codec.palette.data.data) {
				'0'
			} else {
				'1'
			}
			active[0].g ^= 85
		}
	}
	println('ok|' + state() +
		'|${result.width}|${result.height}|${u32(result.pixels.pixel_format())}|${result.pixels.len()}|${before}|${pal_before}|${separate}|${pal_separate}|${raw.hex()}|${palette(result.pixels)}')
}

fn line_case(line string) {
	fields := line.split('|')
	run_case(fields[0].int(), fields[1].u32(), fields[2].u32(), fields[3].u32(), fields[4].int(),
		fields[5].int(), hex.decode(fields[6]) or { panic(err) })
}

fn main() {
	if os.args.len > 1 {
		if os.args[1] == '--corpus' {
			for line in os.read_lines(os.args[2]) or { panic(err) } {
				line_case(line)
			}
			return
		}
		if os.args[1] == '--debug' {
			for kind in [p.RasType.old, .standard, .byte_encoded, .rgb, .tiff, .iff, .experimental] {
				for map_kind in [p.RasColorMapType.no_color_map, .rgb_color_map, .raw_color_map] {
					h := header(7, 9, 8, kind, map_kind, 6)
					h.debug()
				}
			}
			return
		}
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
		observed_path = ''
		return
	}
	println('S|${sizeof(p.RasHeader)}|${sizeof(p.RasType)}|${sizeof(p.RasColorMapType)}')
	for w in [u32(0), 1, 0x80000000, 0xffffffff] {
		for h in [u32(0), 1, 0x80000000, 0xffffffff] {
			codec := p.RAS{
				header: header(w, h, 8, .old, .no_color_map, 0)
			}
			mut changed := codec.header
			changed.width ^= 0x12345678
			changed.height ^= 0x87654321
			println('H|${bytes(codec.header)}|${codec.width()}|${codec.height()}|${bytes(changed)}')
		}
	}
	for d in [u32(0), 1, 2, 8, 16, 24, 32, 0xffffffff] {
		for kind in [p.RasType.old, .standard, .byte_encoded, .rgb, .tiff, .iff, .experimental] {
			for map_kind in [p.RasColorMapType.no_color_map, .rgb_color_map, .raw_color_map] {
				for length in [u32(0), 1, 2, 3, 0xffffffff] {
					codec := p.RAS{
						header: header(1, 1, d, kind, map_kind, length)
					}
					mut status := 'ok'
					pf := codec.pixel_format() or {
						status = err.msg()
						p.PixelFormat.invalid
					}
					println('P|${d}|${u32(kind)}|${u32(map_kind)}|${length}|${status}|${u32(pf)}')
				}
			}
		}
	}
	for format in formats {
		for count in 0 .. 3 {
			pixels := make_pixels(format, count)
			for dims in [[uint(0), 0], [uint(1), 2],
				[uint(0xffffffffffffffff), 0xffffffffffffffff]] {
				for capacity in [0, 1, 8, 16] {
					for entry in 0 .. 2 {
						mut buffer := []u8{len: capacity, init: 165}
						mut stream := p.WriteStream.init_memory(mut buffer)
						if capacity > 1 { stream.seek_to(1) or { panic(err) } }
						image := p.ImageUnmanaged{
							width:  dims[0]
							height: dims[1]
							pixels: pixels
						}
						if entry == 0 {
							p.RAS.write_image(mut stream, image) or { panic(err) }
						} else {
							p.RAS.format_interface().write_image(mut stream, image, p.RasEncoderOptions{}) or {
								panic(err)
							}
						}
						println('W|${u32(format)}|${count}|${dims[0]}|${dims[1]}|${capacity}|${entry}|${stream.get_pos()}|${buffer.hex()}|${pixels.as_bytes().hex()}')
					}
				}
			}
		}
	}
}
