module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.SGI(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_buffer []u8
	observed_output []u8
	observed_data   []u8
	observed_disk   string
)

fn packed[T](value T) string {
	return unsafe { (&u8(&value)).vbytes(int(sizeof(T))).hex() }
}

fn snapshot() string {
	position := if observed_reader != unsafe { nil } {
		'${observed_reader.get_pos()}:${observed_reader.buffered_len()}'
	} else {
		'${observed_writer.get_pos()}:${observed_writer.buffered().len}'
	}
	codec := observed_codec
	palette := unsafe { (&u8(&codec.palette.storage[0])).vbytes(1024).hex() }
	return '${position}|${observed_buffer.hex()}|${observed_output.hex()}|${packed(codec.header)}:${codec.palette.data.len}:${palette}|${observed_data.hex()}|' + if observed_disk != '' {
		(os.read_bytes(observed_disk) or { panic(err) }).hex()
	} else {
		'-'
	}
}

fn observe() {
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn record(line string, path string) string {
	f := line.split('|')
	cap := f[0].int()
	op := f[1].int()
	start := f[2].u64()
	data := hex.decode(f[9]) or { panic(err) }
	mut codec := p.SGI{
		header: p.SgiHeader{
			compression:       if op == 1 { .uncompressed } else { .rle }
			bytes_per_channel: f[4].u8()
			dimension:         .single_channel
			x_size:            f[5].u16()
			y_size:            f[6].u16()
			z_size:            f[7].u16()
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
	mut buffer := []u8{len: if cap < 0 {
		if op >= 5 { 32 } else { 0 }
	} else {
		cap
	}, init: 165}
	mut output := []u8{len: f[8].int(), init: 165}
	mut file := os.File{}
	defer {
		if cap >= 0 { file.close() }
	}
	observed_codec = &codec
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	observed_data = unsafe { data }
	observed_disk = ''
	observed_reader = unsafe { nil }
	observed_writer = unsafe { nil }
	iface := p.SGI.format_interface()
	mut out := ''
	if op >= 5 {
		mut writer := p.WriteStream.init_memory(mut buffer)
		if cap >= 0 {
			os.write_file_array(path, data) or { panic(err) }
			file = os.open_file(path, 'r+') or { panic(err) }
			file.seek(i64(data.len), .start) or { panic(err) }
			writer = p.WriteStream.init_file(file, mut buffer)
			observed_disk = path
		}
		observed_writer = &writer
		writer.seek_to(start) or { panic(err) }
		writer.write([u8(17), 18, 19]) or { panic(err) }
		mut image := p.ImageUnmanaged{
			width:  7
			height: 9
			pixels: p.PixelStorage.init(.rgb24, 2) or { panic(err) }
		}
		mut raw := image.pixels.as_bytes()
		for i in 0 .. raw.len {
			raw[i] = u8(i * 37 + 19)
		}
		out += 'before|${snapshot()}|${raw.hex()}~'
		for _ in 0 .. f[3].int() {
			if op == 5 {
				p.SGI.write_image(mut writer, image) or { panic(err) }
			} else {
				iface.write_image(mut writer, image, p.SgiEncoderOptions{}) or { panic(err) }
			}
			out += 'ok|${snapshot()}|${raw.hex()}~'
		}
		writer.flush() or { panic(err) }
		return out + 'flush|${snapshot()}~'
	}
	mut reader := p.ReadStream.init_memory(data)
	if cap >= 0 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		file.seek(i64(data.len), .start) or { panic(err) }
		reader = p.ReadStream.init_file(file, mut buffer)
		observed_disk = path
	}
	observed_reader = &reader
	if start > 0 { reader.discard_all(uint(start)) or { panic(err) } }
	for _ in 0 .. f[3].int() {
		if op == 2 || op == 3 {
			mut status := 'ok'
			found := if op == 2 {
				p.SGI.format_detect(mut reader) or {
					status = err.msg()
					false
				}
			} else {
				iface.format_detect(mut reader) or {
					status = err.msg()
					false
				}
			}
			out += '${status}:${int(found)}|${snapshot()}~'
		} else if op == 4 {
			mut pixels := codec.read(mut reader) or {
				out += '${err.msg()}|${snapshot()}~'
				continue
			}
			mut raw := pixels.as_bytes()
			before := raw.hex()
			if raw.len > 0 { raw[0] ^= 1 }
			out += 'ok:${u32(pixels.pixel_format())}:${before}:${raw.hex()}|${snapshot()}~'
		} else {
			codec.uncompress_bitmap(mut reader, mut output) or {
				out += '${err.msg()}|${snapshot()}~'
				continue
			}
			out += 'ok|${snapshot()}~'
		}
	}
	return out
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } {
			println(record(line, os.args[2] + '.v.bin'))
		}
	} else {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3], observed_path + '.bin'))
	}
}
