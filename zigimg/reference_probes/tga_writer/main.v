module main

import os
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.TGA(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_image  = &p.ImageUnmanaged(unsafe { nil })
	observed_buffer []u8
	observed_disk   string
)

fn snapshot() string {
	mut out := '${observed_writer.get_pos()}:${observed_writer.buffered().len}|${observed_buffer.hex()}|'
	if observed_codec != unsafe { nil } {
		h := observed_codec.header
		out += unsafe { (&u8(&h)).vbytes(18).hex() } + ':' + observed_codec.id.data.hex() +
			':${observed_codec.extension != none}'
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
	mut pixels := p.PixelStorage.init(format, uint(f[5].u64())) or { panic(err) }
	mut raw := pixels.as_bytes()
	stride := if raw.len > 0 { int(format.pixel_stride()) } else { 1 }
	for i in 0 .. raw.len {
		value := match f[6].int() {
			0 { 7 }
			1 { (i / stride) / 17 }
			2 { (i / stride) * 13 }
			else { (i / stride) / 16 * 3 }
		}

		raw[i] = u8(value + (i % stride) * 5)
		if format in [.rgb555, .bgr555] && i % 2 == 1 { raw[i] &= 127 }
	}
	if pal := pixels.get_palette() {
		length := if f[7].int() < pal.len { f[7].int() } else { pal.len }
		pixels.resize_palette(uint(length))
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
		width:  uint(w)
		height: uint(h)
		pixels: pixels
	}
	observed_image = &image
	mut id := []u8{len: f[13].int(), init: `i`}
	meta := f[14].int()
	options := p.TgaEncoderOptions{
		rle_compressed:      f[10] == '1'
		top_to_bottom_image: f[11] == '1'
		color_map_depth:     f[12].u8()
		image_id:            id
		author_name:         if meta == 1 {
			'author'
		} else if meta == 2 {
			'a'.repeat(40)
		} else {
			''
		}
		job_id:              if meta == 1 {
			'job'
		} else if meta == 3 {
			'j'.repeat(40)
		} else {
			''
		}
		software_id:         if meta == 1 {
			'V'
		} else if meta == 4 {
			's'.repeat(40)
		} else {
			''
		}
		timestamp:           p.TGAExtensionTimestamp{
			year: 2026
		}
		software_version:    p.TGAExtensionSoftwareVersion{
			number: 123
			letter: `b`
		}
	}
	mut codec := p.TGA{
		header: p.TGAHeader{
			id_length:  u8(id.len)
			image_spec: p.TGAImageSpec{
				width:    u16(w)
				height:   u16(h)
				origin_x: 37
				origin_y: 11
			}
		}
	}
	codec.header.image_type.set_run_length(options.rle_compressed)
	codec.header.image_spec.descriptor.set_top_to_bottom(options.top_to_bottom_image)
	match format {
		.grayscale8 {
			codec.header.image_type.set_indexed(true)
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 8
		}
		.indexed8 {
			codec.header.image_type.set_indexed(true)
			codec.header.has_color_map = 1
			codec.header.image_spec.bit_per_pixel = 8
			palette := pixels.get_palette() or { panic('missing palette') }
			codec.header.color_map_spec.length = u16(palette.len)
			codec.header.color_map_spec.bit_depth = options.color_map_depth
		}
		.rgb555 {
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 16
		}
		.rgb24, .bgr24 {
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 24
		}
		.rgba32, .bgra32 {
			codec.header.image_type.set_truecolor(true)
			codec.header.image_spec.bit_per_pixel = 32
			codec.header.image_spec.descriptor.set_num_attributes_bit(8)
		}
		else {}
	}

	if op == 0 {
		codec.id.resize(uint(id.len))
		copy(mut codec.id.data, id)
		if f[15] != '5' { codec.extension = p.TGAExtension{
				timestamp:        options.timestamp
				software_version: options.software_version
			} }
		match f[15].int() {
			1 {
				codec.header.color_map_spec.first_entry_index = 1
			}
			2 {
				codec.header.color_map_spec.first_entry_index = 1
				codec.header.color_map_spec.length = 65535
			}
			3 {
				codec.header.id_length = 1
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
	iface := p.TGA.format_interface()
	mut out := ''
	for _ in 0 .. f[9].int() {
		mut status := 'ok'
		if op == 0 {
			codec.write(mut writer, pixels) or { status = err.msg() }
		} else if op == 1 {
			p.TGA.write_image(mut writer, image, options) or { status = err.msg() }
		} else {
			iface.write_image(mut writer, image, options) or { status = err.msg() }
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
