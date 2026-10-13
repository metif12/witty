module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_codec  = &p.SGI(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_path   string
	observed_buffer []u8
)

fn record_bytes[T](value T) string {
	return unsafe { (&u8(&value)).vbytes(int(sizeof(T))).hex() }
}

fn snapshot(codec &p.SGI, stream &p.ReadStream, buffer []u8) string {
	storage := unsafe { (&u8(&codec.palette.storage[0])).vbytes(1024).hex() }
	return '${stream.get_pos()}|${record_bytes(codec.header)}|${storage}|${codec.palette.data.len}|${stream.buffered_len()}|${buffer.hex()}'
}

fn observe() {
	os.write_file(observed_path, snapshot(observed_codec, observed_stream, observed_buffer)) or {
		eprintln('OBSERVER ERROR: ${err}')
	}
}

fn record(line string, path string) string {
	fields := line.split('|')
	capacity := fields[0].int()
	reads := fields[1].int()
	data := hex.decode(fields[2]) or { panic(err) }
	mut buffer := []u8{len: capacity, init: u8(165)}
	mut stream := p.ReadStream.init_memory(data)
	mut file := os.File{}
	if capacity > 0 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		stream = p.ReadStream.init_file(file, mut buffer)
	}
	mut codec := p.SGI{
		header: p.SgiHeader{
			compression:       .rle
			bytes_per_channel: 1
			dimension:         .single_channel
			x_size:            7
			y_size:            9
			z_size:            3
			pix_min:           123
			pix_max:           456
			dummy1:            789
			image_name:        [80]u8{init: u8(165)}
			pixel_format:      .normal
			dummy2:            [404]u8{init: u8(165)}
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
	if observed_path != '' {
		observed_codec = &codec
		observed_stream = &stream
		observed_buffer = unsafe { buffer }
	}
	mut out := ''
	for _ in 0 .. reads {
		mut status := ''
		pixels := codec.read(mut stream) or {
			out += 'E${err.msg()}|' + snapshot(&codec, &stream, buffer) + '~'
			continue
		}
		bytes := pixels.as_bytes()
		mut palette_bytes := []u8{}
		if palette := pixels.get_palette() {
			for c in palette {
				palette_bytes << [c.r, c.g, c.b, c.a]
			}
		}
		status = 'ok:${u32(pixels.pixel_format())}:${bytes.hex()}:${palette_bytes.hex()}'
		out += status + '|' + snapshot(&codec, &stream, buffer) + '~'
	}
	if capacity > 0 { file.close() }
	return out
}

fn main() {
	if os.args.len == 4 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3], os.args[2] + '.bin'))
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line, os.args[1] + '.v.bin'))
	}
}
