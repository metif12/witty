module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.RAS(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_buffer []u8
	observed_output []u8
	observed_data   []u8
)

fn pixels_text(pixels p.PixelStorage) string {
	mut out := '${u32(pixels.pixel_format())}:${pixels.len()}:${pixels.as_bytes().hex()}:'
	if pal := pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out
}

fn snapshot() string {
	mut out := '${observed_reader.get_pos()}:${observed_reader.buffered_len()}|'
	if observed_codec != unsafe { nil } {
		h := observed_codec.header
		pal := observed_codec.palette.data
		out +=
			unsafe { (&u8(&h)).vbytes(28).hex() } + ':' + unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out + '|${observed_buffer.hex()}|${observed_output.hex()}|${observed_data.hex()}'
}

fn observe() {
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn record(line string, path string) string {
	f := line.split('|')
	cap := f[0].int()
	op := f[1].int()
	data := hex.decode(f[8]) or { panic(err) }
	mut buffer := []u8{len: if cap < 0 { 0 } else { cap }, init: 165}
	mut output := []u8{len: f[5].int(), init: 165}
	mut codec := p.RAS{
		header: p.RasHeader{
			width:            7
			height:           9
			depth:            8
			length:           123
			type_:            unsafe { p.RasType(f[2].u32()) }
			color_map_type:   unsafe { p.RasColorMapType(f[3].u32()) }
			color_map_length: f[4].u32()
		}
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
	mut file := os.File{}
	defer {
		if cap >= 0 { file.close() }
	}
	if cap >= 0 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		file.seek(i64(data.len), .start) or { panic(err) }
		reader = p.ReadStream.init_file(file, mut buffer)
	}
	observed_reader = &reader
	observed_codec = unsafe { nil }
	if op <= 2 { observed_codec = &codec }
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	observed_data = unsafe { data }
	if f[6].u64() > 0 { reader.discard_all(usize(f[6].u64())) or { panic(err) } }
	iface := p.RAS.format_interface()
	mut out := ''
	for _ in 0 .. f[7].int() {
		if op == 4 || op == 6 {
			mut status := 'ok'
			found := if op == 6 {
				iface.format_detect(mut reader) or {
					status = err.msg()
					false
				}
			} else {
				p.RAS.format_detect(mut reader) or {
					status = err.msg()
					false
				}
			}
			out += '${status}:${int(found)}|'
		} else if op == 1 || op == 2 {
			mut status := 'ok'
			if op == 1 {
				codec.read_palette(mut reader) or { status = err.msg() }
			} else {
				codec.uncompress_bitmap(mut reader, mut output) or { status = err.msg() }
			}
			out += '${status}|'
		} else {
			mut image := p.ImageUnmanaged{}
			if op == 0 {
				pixels := codec.read(mut reader) or {
					out += '${err.msg()}|${snapshot()}~'
					continue
				}
				image = p.ImageUnmanaged{
					width:  codec.width()
					height: codec.height()
					pixels: pixels
				}
			} else if op == 5 {
				image = iface.read_image(mut reader) or {
					out += '${err.msg()}|${snapshot()}~'
					continue
				}
			} else {
				image = p.RAS.read_image(mut reader) or {
					out += '${err.msg()}|${snapshot()}~'
					continue
				}
			}
			out += 'ok|${image.width}:${image.height}:${pixels_text(image.pixels)}|'
			mut raw := image.pixels.as_bytes()
			if raw.len > 0 { raw[0] ^= if image.pixel_format() == .grayscale1 {
					u8(1)
				} else {
					u8(85)
				}
			 }
			if pal := image.pixels.get_palette() {
				if pal.len > 0 {
					mut active := unsafe { pal }
					active[0].g ^= 85
				}
			}
			out += '${pixels_text(image.pixels)}|'
		}
		out += '${snapshot()}~'
	}
	return out + if cap >= 0 {
		'disk|' + (os.read_bytes(path) or { panic(err) }).hex()
	} else {
		'disk|-'
	}
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3], observed_path + '.bin'))
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line, os.args[1] + '.v.bin')) }
	}
}
