module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.BMP(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_image  = &p.ImageUnmanaged(unsafe { nil })
	observed_buffer []u8
	observed_data   []u8
	observed_disk   string
)

fn info(value p.BitmapInfoHeader) string {
	return match value {
		p.BitmapInfoHeaderWindows31 { '40:' + unsafe { (&u8(&value)).vbytes(40).hex() } }
		p.BitmapInfoHeaderV4 { '108:' + unsafe { (&u8(&value)).vbytes(108).hex() } }
		p.BitmapInfoHeaderV5 { '124:' + unsafe { (&u8(&value)).vbytes(124).hex() } }
	}
}

fn snapshot() string {
	mut out := if observed_reader != unsafe { nil } {
		'${observed_reader.get_pos()}:${observed_reader.buffered_len()}'
	} else {
		'${observed_writer.get_pos()}:${observed_writer.buffered().len}'
	}
	out += '|${observed_buffer.hex()}|${observed_data.hex()}|'
	if observed_codec != unsafe { nil } {
		h := observed_codec.file_header
		out += unsafe { (&u8(&h)).vbytes(14).hex() } + ':' + info(observed_codec.info_header)
	} else {
		out += '-'
	}
	out += '|'
	if observed_image != unsafe { nil } {
		out += '${observed_image.width}:${observed_image.height}:${u32(observed_image.pixel_format())}:${observed_image.pixels.len()}:${observed_image.raw_bytes().hex()}'
	} else {
		out += '-'
	}
	out += '|' +
		if observed_disk != '' { (os.read_bytes(observed_disk) or { panic(err) }).hex() } else { '-' }
	return out
}

fn observe() {
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn codec(kind int, width i32, height i32) p.BMP {
	return p.BMP{
		file_header: p.BitmapFileHeader{
			magic_header: [u8(`X`), `Y`]!
			size:         1
			reserved:     0x12345678
			pixel_offset: 9000
		}
		info_header: match kind {
			40 {
				p.BitmapInfoHeader(p.BitmapInfoHeaderWindows31{
					header_size:           40
					width:                 width
					height:                height
					bit_count:             99
					compression_method:    .png
					horizontal_resolution: 17
				})
			}
			108 {
				p.BitmapInfoHeader(p.BitmapInfoHeaderV4{
					header_size:           108
					width:                 width
					height:                height
					bit_count:             99
					compression_method:    .png
					horizontal_resolution: 17
				})
			}
			else {
				p.BitmapInfoHeader(p.BitmapInfoHeaderV5{
					header_size:           124
					width:                 width
					height:                height
					bit_count:             99
					compression_method:    .png
					horizontal_resolution: 17
				})
			}
		}
	}
}

fn record(line string, path string) string {
	f := line.split('|')
	cap := f[0].int()
	op := f[1].int()
	start := f[8].u64()
	attempts := f[9].int()
	data := hex.decode(f[10]) or { panic(err) }
	mut buffer := []u8{len: if cap < 0 { 1024 } else { cap }, init: 165}
	mut bmp := codec(if op < 5 { 124 } else { f[2].int() },
		if op == 5 { f[3].i32() } else { i32(7) }, if op == 5 { f[4].i32() } else { i32(9) })
	observed_codec = unsafe { nil }
	if op == 0 || op == 5 { observed_codec = &bmp }
	observed_reader = unsafe { nil }
	observed_writer = unsafe { nil }
	observed_image = unsafe { nil }
	observed_disk = ''
	observed_buffer = []u8{}
	if cap >= 0 || op >= 5 { observed_buffer = unsafe { buffer } }
	observed_data = unsafe { data }
	mut file := os.File{}
	defer {
		if cap >= 0 { file.close() }
	}
	iface := p.BMP.format_interface()
	mut out := ''
	if op < 5 {
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
		for _ in 0 .. attempts {
			if op == 3 || op == 4 {
				mut status := 'ok'
				found := if op == 4 {
					iface.format_detect(mut reader) or {
						status = err.msg()
						false
					}
				} else {
					p.BMP.format_detect(mut reader) or {
						status = err.msg()
						false
					}
				}
				out += '${status}:${int(found)}|'
			} else {
				mut image := p.ImageUnmanaged{}
				if op == 0 {
					pixels := bmp.read(mut reader) or {
						out += '${err.msg()}|${snapshot()}~'
						continue
					}
					image = p.ImageUnmanaged{
						width:  if bmp.width() < 0 { uint(0) } else { uint(bmp.width()) }
						height: if bmp.height() < 0 { uint(0) } else { uint(bmp.height()) }
						pixels: pixels
					}
				} else if op == 2 {
					image = iface.read_image(mut reader) or {
						out += '${err.msg()}|${snapshot()}~'
						continue
					}
				} else {
					image = p.BMP.read_image(mut reader) or {
						out += '${err.msg()}|${snapshot()}~'
						continue
					}
				}
				out += 'ok|${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:'
				if op == 0 && (bmp.width() < 0 || bmp.height() < 0) {
					out += '-'
				} else {
					mut raw := image.pixels.as_bytes()
					out += '${raw.hex()}:'
					if raw.len > 0 { raw[0] ^= 85 }
					out += raw.hex()
				}
				out += '|'
			}
			out += '${snapshot()}~'
		}
		return out
	}
	mut writer := p.WriteStream.init_memory(mut buffer)
	if cap >= 0 {
		os.write_file_array(path, []u8{len: 256, init: 165}) or { panic(err) }
		file = os.open_file(path, 'r+') or { panic(err) }
		file.seek(256, .start) or { panic(err) }
		writer = p.WriteStream.init_file(file, mut buffer)
		observed_disk = path
	}
	observed_writer = &writer
	if start > 0 { writer.seek_to(start) or { panic(err) } }
	pixels := p.PixelStorage.init(unsafe { p.PixelFormat(f[5].u32()) }, uint(f[6].u64())) or {
		panic(err)
	}
	mut raw := pixels.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = if f[7] == '1' {
			u8(0)
		} else if f[7] == '2' {
			u8(255)
		} else {
			u8(i * 37 + 19)
		}
	}
	mut image := p.ImageUnmanaged{
		width:  if op == 5 { uint(17) } else { uint(f[3].u64()) }
		height: if op == 5 { uint(19) } else { uint(f[4].u64()) }
		pixels: pixels
	}
	observed_image = &image
	for _ in 0 .. attempts {
		mut status := 'ok'
		if op == 5 {
			bmp.write(mut writer, pixels) or { status = err.msg() }
		} else if op == 6 {
			p.BMP.write_image(mut writer, image, p.BmpEncoderOptions{}) or { status = err.msg() }
		} else {
			iface.write_image(mut writer, image, p.EncoderOptions(p.QoiEncoderOptions{
				colorspace: .linear
			})) or { status = err.msg() }
		}
		out += '${status}|${snapshot()}~'
	}
	writer.flush() or { panic(err) }
	return out + 'flush|' + snapshot()
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
