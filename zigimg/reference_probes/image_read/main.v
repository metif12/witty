module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_disk   string
	observed_file   os.File
	observed_buffer []u8
	observed_data   []u8
)
fn snapshot() string {
	return '${observed_file.tell() or { panic(err) }}|${observed_buffer.hex()}|${observed_data.hex()}|' + (os.read_bytes(observed_disk) or {
		panic(err)
	}).hex()
}

fn observe() {
	if observed_path == '' { return }
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn image_state(image p.ImageUnmanaged, defined bool) string {
	mut out :=
		'${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:' +
		if defined { image.raw_bytes().hex() } else { '-' }
	out += ':${image.animation.loop_count}:${image.animation.frames.len}'
	for frame in image.animation.frames {
		duration := frame.duration
		bits := unsafe { *(&u32(&duration)) }
		out += ';${u32(frame.pixels.pixel_format())}:${frame.pixels.len()}:${bits}:' +
			if defined { frame.pixels.as_bytes().hex() } else { '-' }
	}
	return out
}

fn detect(route int, file os.File, path string, data []u8, mut buffer []u8) !p.Format {
	return match route {
		0 { p.ImageUnmanaged.detect_format_from_file(file, mut buffer)! }
		1 { p.Image.detect_format_from_file(file, mut buffer)! }
		2 { p.ImageUnmanaged.detect_format_from_file_path(path, mut buffer)! }
		3 { p.Image.detect_format_from_file_path(path, mut buffer)! }
		4 { p.ImageUnmanaged.detect_format_from_memory(data)! }
		else { p.Image.detect_format_from_memory(data)! }
	}
}

fn decode(route int, file os.File, path string, data []u8, mut buffer []u8) !p.ImageUnmanaged {
	return match route {
		0 { p.ImageUnmanaged.from_file(file, mut buffer)! }
		1 { (p.Image.from_file(file, mut buffer)!).to_unmanaged() }
		2 { p.ImageUnmanaged.from_file_path(path, mut buffer)! }
		3 { (p.Image.from_file_path(path, mut buffer)!).to_unmanaged() }
		4 { p.ImageUnmanaged.from_memory(data)! }
		else { (p.Image.from_memory(data)!).to_unmanaged() }
	}
}

fn record(line string, path string, ready bool) string {
	f := line.split('|')
	cap := f[0].int()
	op := f[1].int()
	route := f[2].int()
	data := hex.decode(f[5]) or { panic(err) }
	mut buffer := []u8{len: cap, init: 165}
	os.write_file_array(path, data) or { panic(err) }
	mut file := os.open_file(path, 'r+') or { panic(err) }
	defer { file.close() }
	file.seek(i64(data.len), .start) or { panic(err) }
	observed_file = file
	observed_disk = path
	observed_buffer = unsafe { buffer }
	observed_data = unsafe { data }
	if ready { println('ready|' + snapshot()) }
	mut out := snapshot() + '~'
	for _ in 0 .. f[3].int() {
		mut status := 'ok'
		mut result := '-'
		if op == 0 {
			value := detect(route, file, path, data, mut buffer) or {
				status = err.msg()
				unsafe { p.Format(0) }
			}
			if status == 'ok' { result = '${value}' }
		} else {
			mut image := decode(route, file, path, data, mut buffer) or {
				status = err.msg()
				p.ImageUnmanaged{}
			}
			if status == 'ok' {
				result = image_state(image, f[4] == '1')
				image.deinit()
			}
		}
		out += '${status}:${result}|${snapshot()}~'
	}
	return out
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := record(os.args[3], observed_path + '.bin', false)
		observed_path = ''
		println(result)
		return
	}
	if os.args[1] == '--loop' {
		println(record(os.args[2], os.args[3], true))
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line, os.args[1] + '.v.bin', false)) }
	}
}
