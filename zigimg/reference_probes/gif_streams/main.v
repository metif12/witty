module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path     string
	observed_codec    = &p.GIF(unsafe { nil })
	observed_reader   = &p.ReadStream(unsafe { nil })
	observed_buffer   []u8
	observed_data     []u8
	observed_disk     string
	observed_private  bool
	observed_comments bool
	observed_ready    string
)

fn packed[T](value T) string {
	return unsafe { (&u8(&value)).vbytes(int(sizeof(T))).hex() }
}

fn snapshot() string {
	// Failed toss leaves buffered length outside its Source API domain.
	position := if observed_reader.buffered_len() < 0 {
		if observed_disk == '' { '${observed_reader.get_pos()}:-' } else { '-:-' }
	} else {
		'${observed_reader.get_pos()}:${observed_reader.buffered_len()}'
	}
	mut out := '${position}|${observed_buffer.hex()}|'
	if observed_private {
		out += '-'
	} else {
		codec := observed_codec
		colors := codec.global_color_table.data
		out += packed(codec.header) + ':' +
			unsafe { (&u8(colors.data)).vbytes(colors.len * 3).hex() } + ':${codec.frames.len}:'
		for frame in codec.frames {
			out += if control := frame.graphics_control { packed(control) } else { '-' }
			out += ':'
			for image in frame.sub_images {
				out += packed(image.image_descriptor) +
					':${image.local_color_table.data.len}:${image.pixels.len},'
			}
			out += ';'
		}
		out += ':${codec.comments.len}:'
		if observed_comments {
			for comment in codec.comments {
				out += comment.comment.hex() + ';'
			}
		}
		out += ':'
		for info in codec.application_infos {
			out += info.application_identifier[..].hex() + info.authentification_code[..].hex() +
				':' + info.data.hex() + ';'
		}
	}
	return out + '|${observed_data.hex()}|' + if observed_disk != '' {
		(os.read_bytes(observed_disk) or { panic(err) }).hex()
	} else {
		'-'
	}
}

fn observe() {
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn frame(mut value p.AnimationFrame) string {
	mut raw := value.pixels.as_bytes()
	before := raw.hex()
	if raw.len > 0 { raw[0] ^= 1 }
	mut colors_before := '-'
	mut colors_after := '-'
	if pal := value.pixels.get_palette() {
		mut view := unsafe { pal }
		colors_before = unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
		if view.len > 0 { view[0].g ^= 85 }
		colors_after = unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
	}
	return '${u32(value.pixels.pixel_format())}:${packed(value.duration)}:${before}:${raw.hex()}:${colors_before}:${colors_after};'
}

fn record(line string, path string) string {
	f := line.split('|')
	cap := f[0].int()
	op := f[1].int()
	data := hex.decode(f[5]) or { panic(err) }
	mut codec := p.GIF.init()
	codec.header = p.GifHeader{
		magic:                  [u8(`O`), `L`, `D`]!
		version:                [u8(`T`), `S`, `T`]!
		width:                  7
		height:                 9
		flags:                  p.GifHeaderFlags{
			raw: 1
		}
		background_color_index: 2
		pixel_aspect_ratio:     3
	}
	codec.global_color_table.resize(256)
	for i in 0 .. 256 {
		codec.global_color_table.data[i] = p.Rgb24{
			r: u8(i * 31)
			g: u8(i * 71)
			b: u8(i * 47)
		}
	}
	codec.global_color_table.resize(4)
	mut buffer := []u8{len: if cap < 0 { 0 } else { cap }, init: 165}
	mut file := os.File{}
	defer {
		if cap >= 0 { file.close() }
	}
	mut reader := p.ReadStream.init_memory(data)
	observed_disk = ''
	if cap >= 0 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		file.seek(i64(data.len), .start) or { panic(err) }
		reader = p.ReadStream.init_file(file, mut buffer)
		observed_disk = path
	}
	observed_codec = &codec
	observed_reader = &reader
	observed_data = unsafe { data }
	observed_buffer = unsafe { buffer }
	observed_private = op == 1 || op == 2
	observed_comments = false
	if f[2] != '0' { reader.discard_all(usize(f[2].u64())) or { panic(err) } }
	if observed_ready != '' { os.write_file(observed_ready, snapshot()) or { panic(err) } }
	iface := p.GIF.format_interface()
	mut out := ''
	mut poisoned_comments := false
	for _ in 0 .. f[3].int() {
		observed_comments = false
		if op == 3 || op == 4 {
			mut status := 'ok'
			found := if op == 3 {
				p.GIF.format_detect(mut reader) or {
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
			continue
		}
		if op == 0 {
			mut frames := codec.read(mut reader) or {
				poisoned_comments = poisoned_comments || codec.comments.len > 0
				out += '${err.msg()}|${snapshot()}~'
				continue
			}
			observed_comments = !poisoned_comments
			loop := if f[4] == '1' { codec.loop_count().str() } else { '-' }
			out += 'ok:${loop}:${frames.len}|'
			for mut value in frames {
				out += frame(mut value)
			}
		} else {
			mut image := if op == 1 {
				p.GIF.read_image(mut reader) or {
					out += '${err.msg()}|${snapshot()}~'
					continue
				}
			} else {
				iface.read_image(mut reader) or {
					out += '${err.msg()}|${snapshot()}~'
					continue
				}
			}
			out += 'ok:${image.animation.loop_count}:${image.animation.frames.len}:${image.width}:${image.height}|'
			for mut value in image.animation.frames {
				out += frame(mut value)
			}
			out += 'main:${image.raw_bytes().hex()}|'
		}
		out += '${snapshot()}~'
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
		if os.args[1] == '--loop' { observed_ready = observed_path + '.ready' }
		at_exit(observe) or { panic(err) }
		println(record(os.args[3], observed_path + '.bin'))
	}
}
