module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_codec  = &p.TGA(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_path   string
)

fn record_bytes[T](value T) string {
	return unsafe { (&u8(&value)).vbytes(int(sizeof(T))).hex() }
}

fn snapshot(codec &p.TGA, stream &p.ReadStream) string {
	mut out := '${stream.get_pos()}|${record_bytes(codec.header)}|${codec.id.data.hex()}|'
	if extension := codec.extension {
		out += record_bytes(extension)
	} else {
		out += '-'
	}
	return out
}

fn observe() {
	os.write_file(observed_path, snapshot(observed_codec, observed_stream)) or {
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
	mut codec := p.TGA{
		header:    p.TGAHeader{
			image_spec: p.TGAImageSpec{
				width: 99
			}
		}
		extension: p.TGAExtension{
			extension_size: 123
			attributes:     .useful_alpha_channel
		}
	}
	codec.id.resize(3)
	copy(mut codec.id.data, 'OLD'.bytes())
	if observed_path != '' {
		observed_codec = &codec
		observed_stream = &stream
	}
	mut out := ''
	for _ in 0 .. reads {
		mut status := ''
		pixels := codec.read(mut stream) or {
			out += 'E${err.msg()}|' + snapshot(&codec, &stream) + '~'
			continue
		}
		mut bytes := pixels.as_bytes().clone()
		if pixels.pixel_format() == .rgb555 {
			for i in 0 .. bytes.len {
				if i % 2 == 1 { bytes[i] &= 127 }
			}
		}
		status = 'ok:${u32(pixels.pixel_format())}:${bytes.hex()}'
		out += status + '|' + snapshot(&codec, &stream) + '~'
	}
	if capacity > 0 { file.close() }
	return out
}

fn vectors(path string) {
	os.write_file(path, '0123456789abcdefghijklmnopqrstuvwxyz') or { panic(err) }
	for capacity in [1, 8, 31, 64] {
		for length in [1, 3, 8, 9, 32, 40] {
			mut file := os.open(path) or { panic(err) }
			mut buffer := []u8{len: capacity, init: u8(165)}
			mut stream := p.ReadStream.init_file(file, mut buffer)
			for attempt in 0 .. 2 {
				mut destination := []u8{len: length, init: u8(165)}
				count := stream.read_slice_short(mut destination) or { panic(err) }
				println('${capacity}|${length}|${attempt}|${count}|${destination.hex()}|${stream.get_pos()}|${stream.buffered_len()}')
			}
			file.close()
		}
	}
}

fn main() {
	if os.args.len == 3 && os.args[1] == '--vectors' {
		vectors(os.args[2])
		return
	}
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
