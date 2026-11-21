module main

import os
import encoding.hex
import zigimg as p

fn pixels_text(pixels p.PixelStorage) string {
	palette := pixels.get_palette() or { panic('fixture palette') }
	return '${u32(pixels.pixel_format())}:${pixels.len()}:${pixels.as_bytes().hex()}:${unsafe { (&u8(palette.data)).vbytes(palette.len * 4).hex() }}'
}

fn snapshot(reader &p.ReadStream, codec p.XBM, direct bool, buffer []u8, data []u8) string {
	fields := if direct {
		'${codec.width}:${codec.height}:${codec.hotspot_x}:${codec.hotspot_y}'
	} else {
		'-'
	}
	return '${reader.get_pos()}:${reader.buffered_len()}|${buffer.hex()}|${data.hex()}|${fields}'
}

fn record(line string, path string, ready bool) string {
	f := line.split('|')
	capacity := f[0].int()
	op := f[1].int()
	start := f[2].u64()
	attempts := f[3].int()
	data := hex.decode(f[6]) or { panic(err) }
	mut buffer := []u8{len: if capacity == -2 {
		32
	} else if capacity < 0 {
		0
	} else {
		capacity
	}, init: 165}
	mut file := os.File{}
	defer {
		if capacity >= 0 { file.close() }
	}
	iface := p.XBM.format_interface()
	mut out := ''
	if op <= 4 {
		mut reader := p.ReadStream.init_memory(data)
		if capacity >= 0 {
			os.write_file_array(path, data) or { panic(err) }
			file = os.open(path) or { panic(err) }
			file.seek(i64(data.len), .start) or { panic(err) }
			reader = p.ReadStream.init_file(file, mut buffer)
		}
		if start > 0 { reader.discard_all(uint(start)) or { panic(err) } }
		mut codec := p.XBM{
			width:     97
			height:    89
			hotspot_x: 77
			hotspot_y: 66
		}
		if ready {
			reader.peek_delimiter_inclusive(`\n`) or { panic(err) }
			println('ready|' + snapshot(&reader, codec, true, buffer, data))
		}
		for _ in 0 .. attempts {
			if op == 2 || op == 4 {
				mut status := 'ok'
				found := if op == 4 {
					iface.format_detect(mut reader) or {
						status = err.msg()
						false
					}
				} else {
					p.XBM.format_detect(mut reader) or {
						status = err.msg()
						false
					}
				}
				out += '${status}:${int(found)}|'
			} else {
				mut image := p.ImageUnmanaged{}
				if op == 0 {
					pixels := codec.read(mut reader) or {
						out += '${err.msg()}|${snapshot(&reader, codec, true, buffer, data)}~'
						continue
					}
					image = p.ImageUnmanaged{
						width:  uint(codec.width)
						height: uint(codec.height)
						pixels: pixels
					}
				} else if op == 3 {
					image = iface.read_image(mut reader) or {
						out += '${err.msg()}|${snapshot(&reader, codec, false, buffer, data)}~'
						continue
					}
				} else {
					image = p.XBM.read_image(mut reader) or {
						out += '${err.msg()}|${snapshot(&reader, codec, false, buffer, data)}~'
						continue
					}
				}
				out += 'ok|${image.width}:${image.height}:${pixels_text(image.pixels)}|'
				mut raw := image.pixels.as_bytes()
				if raw.len > 0 { raw[0] ^= 1 }
				palette := image.pixels.get_palette() or { panic('fixture palette') }
				mut view := unsafe { palette }
				view[0].g ^= 85
				out += '${pixels_text(image.pixels)}|'
			}
			out += '${snapshot(&reader, codec, op == 0 || op == 2 || op == 4, buffer, data)}~'
		}
		return out + if capacity >= 0 {
			'disk|' + (os.read_bytes(path) or { panic(err) }).hex()
		} else {
			'disk|-'
		}
	}
	mut writer := p.WriteStream.init_memory(mut buffer)
	if capacity >= 0 {
		os.write_file_array(path, []u8{len: 32, init: 165}) or { panic(err) }
		file = os.open_file(path, 'r+') or { panic(err) }
		file.seek(32, .start) or { panic(err) }
		writer = p.WriteStream.init_file(file, mut buffer)
	}
	if start > 0 { writer.seek_to(start) or { panic(err) } }
	writer.write_all(data) or { panic(err) }
	mut pixels := p.PixelStorage.init(.rgba32, 1) or { panic(err) }
	mut bytes := pixels.as_bytes()
	copy(mut bytes, [u8(19), 56, 93, 130])
	image := p.ImageUnmanaged{
		width:  uint(f[4].u64())
		height: uint(f[5].u64())
		pixels: pixels
	}
	options := if op == 7 {
		p.EncoderOptions(p.QoiEncoderOptions{
			colorspace: .linear
		})
	} else {
		p.EncoderOptions(p.BmpEncoderOptions{})
	}
	for _ in 0 .. attempts {
		if op == 5 {
			p.XBM.write_image(mut writer, image) or { panic(err) }
		} else {
			iface.write_image(mut writer, image, options) or { panic(err) }
		}
		out += 'ok|${writer.get_pos()}:${writer.buffered().len}|${buffer.hex()}|${image.width}:${image.height}:${pixels.as_bytes().hex()}~'
	}
	writer.flush() or { panic(err) }
	return out + 'flush|${writer.get_pos()}:${writer.buffered().len}|${buffer.hex()}|' + if capacity >= 0 {
		(os.read_bytes(path) or { panic(err) }).hex()
	} else {
		'-'
	}
}

fn main() {
	if os.args[1] == '--loop' {
		println(record(os.args[2], os.args[3], true))
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line, os.args[1] + '.v.bin', false)) }
	}
}
