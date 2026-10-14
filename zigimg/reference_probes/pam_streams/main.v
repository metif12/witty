module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_image  = &p.ImageUnmanaged(unsafe { nil })
	observed_path   string
	observed_disk   string
	observed_data   []u8
	observed_buffer []u8
)

fn pixels_text(pixels p.PixelStorage) string {
	return '${u32(pixels.pixel_format())}:${pixels.len()}:${pixels.as_bytes().hex()}'
}

fn image_text(image p.ImageUnmanaged) string {
	mut out := '${image.width}:${image.height}:${pixels_text(image.pixels)}:${image.animation.loop_count}:${image.animation.frames.len}'
	for frame in image.animation.frames {
		out += ':${pixels_text(frame.pixels)}:${unsafe { *(&u32(&frame.duration)) }}'
	}
	return out
}

fn snapshot() string {
	mut out := if observed_reader != unsafe { nil } {
		'${observed_reader.get_pos()}:${observed_reader.buffered_len()}'
	} else {
		'${observed_writer.get_pos()}:${observed_writer.buffered().len}'
	}
	out += '|${observed_buffer.hex()}|${observed_data.hex()}|'
	out += if observed_disk != '' {
		(os.read_bytes(observed_disk) or { panic(err) }).hex()
	} else {
		'-'
	}
	out += '|'
	out += if observed_image != unsafe { nil } { image_text(*observed_image) } else { '-' }
	return out
}

fn observe() {
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn pixels(format p.PixelFormat, count int) p.PixelStorage {
	mut result := p.PixelStorage.init(format, usize(count)) or { panic(err) }
	mut bytes := result.as_bytes()
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + 19)
	}
	match mut result {
		p.Grayscale1Pixels {
			for i in 0 .. count {
				result.data[i].value = u8(i & 1)
			}
		}
		p.Grayscale2Pixels {
			for i in 0 .. count {
				result.data[i].value = u8(i & 3)
			}
		}
		p.Grayscale4Pixels {
			for i in 0 .. count {
				result.data[i].value = u8(i & 15)
			}
		}
		p.Rgb555Pixels, p.Bgr555Pixels {
			for i in 0 .. count {
				bytes[i * 2 + 1] &= 127
			}
		}
		else {}
	}

	return result
}

fn record(line string, path string) string {
	f := line.split('|')
	capacity := f[0].int()
	op := f[1].int()
	start := f[2].u64()
	attempts := f[3].int()
	data := hex.decode(f[10]) or { panic(err) }
	mut buffer := []u8{len: if capacity < 0 { 0 } else { capacity }, init: 165}
	observed_reader = unsafe { nil }
	observed_writer = unsafe { nil }
	observed_image = unsafe { nil }
	observed_disk = ''
	observed_data = unsafe { data }
	observed_buffer = unsafe { buffer }
	mut file := os.File{}
	defer {
		if capacity >= 0 { file.close() }
	}
	mut out := ''
	if op < 3 || op == 5 {
		mut reader := p.ReadStream.init_memory(data)
		if capacity >= 0 {
			os.write_file_array(path, data) or { panic(err) }
			file = os.open(path) or { panic(err) }
			file.seek(i64(data.len), .start) or { panic(err) }
			reader = p.ReadStream.init_file(file, mut buffer)
			observed_disk = path
		}
		observed_reader = &reader
		if start > 0 { reader.discard_all(usize(start)) or { panic(err) } }
		for _ in 0 .. attempts {
			if op == 2 {
				mut status := 'ok'
				found := p.PAM.format_detect(mut reader) or {
					status = err.msg()
					false
				}
				out += '${status}:${int(found)}|'
			} else if op == 0 {
				images := p.PAM.read(mut reader) or {
					out += '${err.msg()}|${snapshot()}~'
					continue
				}
				out += 'ok:${images.len}'
				for image in images {
					out += '|${image_text(image)}'
				}
				out += '|'
			} else {
				image := if op == 5 {
					p.PAM.format_interface().read_image(mut reader) or {
						out += '${err.msg()}|${snapshot()}~'
						continue
					}
				} else {
					p.PAM.read_image(mut reader) or {
						out += '${err.msg()}|${snapshot()}~'
						continue
					}
				}
				out += 'ok|${image_text(image)}|'
			}
			out += '${snapshot()}~'
		}
		return out
	}
	mut writer := p.WriteStream.init_memory(mut buffer)
	if capacity >= 0 {
		os.write_file_array(path, []u8{len: 256, init: 165}) or { panic(err) }
		file = os.open_file(path, 'r+') or { panic(err) }
		file.seek(256, .start) or { panic(err) }
		writer = p.WriteStream.init_file(file, mut buffer)
		observed_disk = path
	}
	observed_writer = &writer
	if start > 0 { writer.seek_to(start) or { panic(err) } }
	mut image := p.ImageUnmanaged{
		pixels: pixels(unsafe { p.PixelFormat(f[4].u32()) }, f[5].int())
		width:  usize(f[6].u64())
		height: usize(f[7].u64())
	}
	observed_image = &image
	comments := match f[8].int() {
		1 { ['one', 'two'] }
		2 { ['', 'x\ny\r', 'π', '\xff\x00'] }
		else { []string{} }
	}

	options := if f[9] == '5' { p.EncoderOptions(p.PamEncoderOptions{
			comments: comments
		}) } else { p.EncoderOptions(p.BmpEncoderOptions{}) }
	for _ in 0 .. attempts {
		mut status := 'ok'
		if op == 3 {
			p.PAM.write_frame(mut writer, image, options) or { status = err.msg() }
		} else if op == 4 {
			p.PAM.write_image(mut writer, image, options) or { status = err.msg() }
		} else {
			p.PAM.format_interface().write_image(mut writer, image, options) or {
				status = err.msg()
			}
		}
		out += '${status}|${snapshot()}~'
	}
	writer.flush() or { panic(err) }
	return out + 'flush|${snapshot()}'
}

fn main() {
	if os.args.len == 4 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3], observed_path + '.bin'))
		return
	}
	text := os.read_file(os.args[1]) or { panic(err) }
	for line in text.split_into_lines() {
		if line != '' { println(record(line, os.args[1] + '.v.bin')) }
	}
}
