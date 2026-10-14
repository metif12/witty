module main

import os
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.PCX(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_image  = &p.ImageUnmanaged(unsafe { nil })
	observed_buffer []u8
	observed_disk   string
)

fn snapshot() string {
	mut out := '${observed_writer.get_pos()}:${observed_writer.buffered().len}|${observed_buffer.hex()}|'
	if observed_codec != unsafe { nil } {
		h := observed_codec.header
		out += unsafe { (&u8(&h)).vbytes(128).hex() }
	} else {
		out += '-'
	}
	image := observed_image
	out += '|${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:${image.raw_bytes().hex()}|'
	if pal := image.pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out + '|' + if observed_disk != '' {
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
	w := f[2].u64()
	h := f[3].u64()
	format := unsafe { p.PixelFormat(f[4].u32()) }
	mut pixels := p.PixelStorage.init(format, usize(f[5].u64())) or { panic(err) }
	mut raw := pixels.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(match f[6].int() {
			0 { 1 }
			1 { i * 17 }
			2 { 192 }
			3 { i / 16 + 1 }
			4 { 0 }
			else { i / 63 + 191 }
		})
		if format == .indexed1 { raw[i] &= 1 }
		if format == .indexed4 { raw[i] &= 15 }
	}
	if pal := pixels.get_palette() {
		length := if f[7].int() < pal.len { f[7].int() } else { pal.len }
		pixels.resize_palette(usize(length))
		mut active := pixels.get_palette() or { panic('missing palette') }
		for i in 0 .. active.len {
			active[i] = p.Rgba32{
				r: u8(i * 31)
				g: u8(i * 71)
				b: u8(i * 113)
				a: u8(i * 47)
			}
		}
	}
	mut image := p.ImageUnmanaged{
		width:  usize(w)
		height: usize(h)
		pixels: pixels
	}
	observed_image = &image
	mut codec := p.PCX{
		header: p.PCXHeader{
			id:                  7
			version:             6
			compression:         .none
			bpp:                 99
			xmin:                10
			xmax:                10
			ymin:                20
			ymax:                20
			planes:              0
			reserved0:           37
			palette_information: unsafe { p.PcxPaletteInfo(u16(65535)) }
		}
	}
	if op == 0 {
		codec.header.xmax = u16(w + 9)
		codec.header.ymax = u16(h + 19)
		match f[10].int() {
			1 {
				codec.header.xmin = 2
				codec.header.xmax = 1
			}
			2 {
				codec.header.xmin = 0
				codec.header.xmax = 65535
			}
			3 {
				codec.header.ymin = 2
				codec.header.ymax = 1
			}
			4 {
				codec.header.ymin = 0
				codec.header.ymax = 65535
			}
			else {}
		}
	}
	observed_codec = unsafe { nil }
	if op == 0 { observed_codec = &codec }
	mut buffer := []u8{len: if cap < 0 { -cap - 1 } else { cap }, init: 165}
	observed_buffer = unsafe { buffer }
	observed_disk = ''
	mut file := os.File{}
	defer {
		if cap >= 0 { file.close() }
	}
	mut writer := p.WriteStream.init_memory(mut buffer)
	if cap >= 0 {
		os.write_file_array(path, []u8{len: 1024, init: 165}) or { panic(err) }
		file = os.open_file(path, 'r+') or { panic(err) }
		file.seek(1024, .start) or { panic(err) }
		writer = p.WriteStream.init_file(file, mut buffer)
		observed_disk = path
	}
	observed_writer = &writer
	if f[8] != '0' { writer.seek_to(f[8].u64()) or { panic(err) } }
	iface := p.PCX.format_interface()
	mut out := ''
	for _ in 0 .. f[9].int() {
		mut status := 'ok'
		if op == 0 {
			codec.write(mut writer, pixels) or { status = err.msg() }
		} else if op == 1 {
			p.PCX.write_image(mut writer, image, p.PcxEncoderOptions{}) or { status = err.msg() }
		} else {
			iface.write_image(mut writer, image, p.EncoderOptions(p.QoiEncoderOptions{
				colorspace: .linear
			})) or { status = err.msg() }
		}
		out += '${status}|${snapshot()}~'
	}
	mut status := 'ok'
	writer.flush() or { status = err.msg() }
	return out + 'flush:${status}|' + snapshot()
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
