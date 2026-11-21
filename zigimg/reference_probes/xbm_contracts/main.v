module main

import os
import encoding.hex
import zigimg as p

__global (
	loop_ready bool
)

fn state(codec p.XBM, reader &p.ReadStream, data []u8, op int) string {
	fields := if op == 1 {
		'-'
	} else {
		'${codec.width}:${codec.height}:${codec.hotspot_x}:${codec.hotspot_y}'
	}
	return '${reader.get_pos()}|${fields}|${data.hex()}'
}

fn line_case(line string) {
	f := line.split('|')
	op := f[0].int()
	mut data := hex.decode(f[2]) or { panic(err) }
	mut reader := p.ReadStream.init_memory(data)
	start := f[1].int()
	if start > 0 { reader.take(start) or { panic(err) } }
	mut codec := p.XBM{ width: 97, height: 89, hotspot_x: 77, hotspot_y: 66 }
	if loop_ready { println('ready|' + state(codec, &reader, data, op)) }
	if op == 2 {
		result := p.XBM.format_detect(mut reader) or {
			println('${err.msg()}|' + state(codec, &reader, data, op))
			return
		}
		println('ok|${if result { 1 } else { 0 }}|' + state(codec, &reader, data, op))
		return
	}
	if op == 3 {
		mut copy := codec
		copy.width = 1
		copy.height = 2
		copy.hotspot_x = 3
		copy.hotspot_y = 4
		default_value := p.XBM{}
		println('ok|${copy.width}:${copy.height}:${copy.hotspot_x}:${copy.hotspot_y}|${default_value.width}:${default_value.height}:${default_value.hotspot_x}:${default_value.hotspot_y}|' + state(codec, &reader, data, op))
		return
	}
	mut image := if op == 0 {
		pixels := codec.read(mut reader) or {
			println('${err.msg()}|' + state(codec, &reader, data, op))
			return
		}
		p.ImageUnmanaged{ width: uint(codec.width), height: uint(codec.height), pixels: pixels }
	} else {
		p.XBM.read_image(mut reader) or {
			println('${err.msg()}|' + state(codec, &reader, data, op))
			return
		}
	}
	mut raw := image.pixels.as_bytes()
	before := raw.hex()
	mut independent := '-'
	if raw.len > 0 {
		independent = if uint(raw.data) < uint(data.data) || uint(raw.data) >= uint(data.data) + uint(data.len) {
			'1'
		} else {
			'0'
		}
		raw[0] ^= 1
	}
	pal := image.pixels.get_palette() or { panic('bad fixture palette') }
	mut view := unsafe { pal }
	palette_before := unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
	view[0].g ^= 85
	palette_after := unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
	println('ok|${image.width}|${image.height}|${u32(image.pixel_format())}|${before}|${raw.hex()}|${independent}|${palette_before}|${palette_after}|' + state(codec, &reader, data, op))
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } { line_case(line) }
	} else {
		loop_ready = os.args[1] == '--loop'
		line_case(os.args[2])
	}
}
