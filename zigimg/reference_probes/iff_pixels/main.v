module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.IFF(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_data   []u8
	observed_op     int
)

fn header_bytes(header p.IffHeader) string {
	return match header {
		p.BmhdHeader { 'b:' + unsafe { (&u8(&header)).vbytes(20).hex() } }
		p.DgblHeader { 'd:' + unsafe { (&u8(&header)).vbytes(8).hex() } }
	}
}

fn palette(codec &p.IFF) string {
	data := codec.palette.data
	return unsafe { (&u8(data.data)).vbytes(data.len * 4).hex() }
}

fn state() string {
	if observed_op == 3 { return '${observed_reader.get_pos()}|-|${observed_data.hex()}' }
	codec := observed_codec
	return '${observed_reader.get_pos()}|${codec.cmap_bits}:${u8(codec.format_id)}:${header_bytes(codec.header)}:${codec.pitch}:${codec.pixel_byte_size}:${codec.viewport_mode}:${palette(codec)}|${observed_data.hex()}'
}

fn observe() {
	if observed_path != '' {
		os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')
		}
	}
}

fn run_case(fields []string, mut data []u8) {
	op := fields[0].int()
	mut codec := p.IFF{
		format_id:       unsafe { p.IffFormat(fields[2].u8()) }
		header:          if fields[1] == '0' {
			p.IffHeader(p.BmhdHeader{
				width:             fields[3].u16()
				height:            fields[4].u16()
				x:                 -7
				y:                 -9
				planes:            fields[5].u8()
				mask_type:         .has_lasso
				compression_type:  unsafe { p.IlbmCompressionType(fields[13].u8()) }
				pad:               19
				transparent_color: 513
				x_asoect:          23
				y_aspect:          29
				page_width:        31
				page_height:       37
			})
		} else {
			p.IffHeader(p.DgblHeader{
				width:            fields[3].u16()
				height:           fields[4].u16()
				compression_type: .jpeg
				x_aspect:         23
				y_aspect:         29
			})
		}
		cmap_bits:       fields[6].u8()
		pitch:           fields[7].u16()
		pixel_byte_size: 47
		viewport_mode:   fields[8].u32()
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
	codec.palette.resize(usize(fields[9].u64()))
	mut reader := p.ReadStream.init_memory(data)
	start := fields[11].int()
	if start > 0 { reader.take(start) or { panic(err) } }
	observed_codec = &codec
	observed_reader = &reader
	observed_data = unsafe { data[..] }
	observed_op = op
	mut image := p.ImageUnmanaged{}
	if op != 3 {
		pixels := if op == 0 {
			codec.decode_ilbm_pixel_chunk(mut reader, p.IffChunkHeader{ type_: fields[14].u32(), length: fields[10].u32() }) or {
				println('${err.msg()}|' + state())
				return
			}
		} else if op == 1 {
			codec.decode_chunks(mut reader) or {
				println('${err.msg()}|' + state())
				return
			}
		} else {
			codec.read(mut reader) or {
				println('${err.msg()}|' + state())
				return
			}
		}
		image = p.ImageUnmanaged{ width: codec.width(), height: codec.height(), pixels: pixels }
	} else {
		image = p.IFF.read_image(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
	}
	mut raw := image.raw_bytes()
	before := raw.hex()
	mut independent := '-'
	if raw.len > 0 {
		ptr := usize(raw.data)
		independent = if ptr < usize(data.data) || ptr >= usize(data.data) + usize(data.len) {
			'1'
		} else {
			'0'
		}
		raw[0] ^= 1
	}
	mut palette_before := '-'
	mut palette_after := '-'
	mut separate := '-'
	if pal := image.pixels.get_palette() {
		mut view := unsafe { pal }
		palette_before = unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
		if view.len > 0 {
			separate = if op != 3 && usize(view.data) == usize(codec.palette.data.data) {
				'0'
			} else {
				'1'
			}
			view[0].g ^= 85
		}
		palette_after = unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
	}
	println('ok|${image.width}|${image.height}|${u32(image.pixel_format())}|${image.pixels.len()}|${before}|${raw.hex()}|${independent}|${palette_before}|${palette_after}|${separate}|' +
		state())
}

fn line_case(line string) {
	fields := line.split('|')
	mut data := hex.decode(fields[12]) or { panic(err) }
	run_case(fields, mut data)
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } { line_case(line) }
	} else {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
	}
}
