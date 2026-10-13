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
	if observed_op == 11 { return '${observed_reader.get_pos()}|-|${observed_data.hex()}' }
	codec := observed_codec
	return '${observed_reader.get_pos()}|${codec.cmap_bits}:${u8(codec.format_id)}:${header_bytes(codec.header)}:${codec.pitch}:${codec.pixel_byte_size}:${codec.viewport_mode}:${palette(codec)}|${observed_data.hex()}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn run_case(fields []string, mut data []u8) {
	op := fields[0].int()
	mut codec := p.IFF{
		format_id:       unsafe { p.IffFormat(fields[2].u8()) }
		header:          if fields[1] == '0' { p.IffHeader(p.BmhdHeader{
				width:             fields[3].u16()
				height:            fields[4].u16()
				x:                 -7
				y:                 -9
				planes:            fields[5].u8()
				mask_type:         .has_lasso
				compression_type:  .byterun2
				pad:               19
				transparent_color: 513
				x_asoect:          23
				y_aspect:          29
				page_width:        31
				page_height:       37
			}) } else { p.IffHeader(p.DgblHeader{
				width:            fields[3].u16()
				height:           fields[4].u16()
				compression_type: .jpeg
				x_aspect:         23
				y_aspect:         29
			}) }
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
	if op == 9 {
		view := unsafe { data[start..] }
		result := p.IffChunk.init(view)
		copy := result
		before := result.name.hex()
		if view.len > 0 { data[start] ^= 85 }
		println('ok|${result.id}|${before}|${result.name.hex()}|${copy.id}|${copy.name.hex()}|' +
			state())
		return
	}
	if op == 8 {
		println('ok|${codec.width()}|${codec.height()}|' + state())
		return
	}
	if op == 7 {
		format := codec.pixel_format() or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|${u32(format)}|' + state())
		return
	}
	if op == 6 {
		codec.reduce_ham_palette()
		println('ok|' + state())
		return
	}
	if op == 5 {
		p.extend_ehb_palette(mut codec.palette)
		println('ok|' + state())
		return
	}
	if op == 4 {
		codec.decode_cmap_chunk(mut reader, p.IffChunkHeader{ type_: 37, length: fields[10].u32() }) or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|' + state())
		return
	}
	if op == 3 {
		codec.decode_camg_chunk(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|' + state())
		return
	}
	if op == 10 {
		result := p.IFF.format_detect(mut reader) or { panic(err) }
		println('ok|${if result { 1 } else { 0 }}|' + state())
		return
	}
	if op == 12 || op == 13 {
		format := if op == 12 {
			p.peek_iff_format_id(mut reader) or {
				println('${err.msg()}|' + state())
				return
			}
		} else {
			p.take_iff_format_id(mut reader) or {
				println('${err.msg()}|' + state())
				return
			}
		}
		println('ok|${u8(format)}|' + state())
		return
	}
	if op == 0 {
		result := p.decode_bmhd_chunk(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|' + header_bytes(p.IffHeader(result)) + '|' + state())
		return
	}
	if op == 1 {
		result := p.iff_load_header(mut reader, codec.format_id) or {
			println('${err.msg()}|' + state())
			return
		}
		println('ok|' + header_bytes(result) + '|' + state())
		return
	}
	mut image := p.ImageUnmanaged{}
	if op == 2 {
		pixels := codec.read(mut reader) or {
			println('${err.msg()}|' + state())
			return
		}
		image = p.ImageUnmanaged{
			width:  codec.width()
			height: codec.height()
			pixels: pixels
		}
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
			separate = if op == 2 && usize(view.data) == usize(codec.palette.data.data) {
				'0'
			} else {
				'1'
			}
			view[0].g ^= 85
		}
		palette_after = unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
	}
	println(
		'ok|${image.width}|${image.height}|${u32(image.pixel_format())}|${image.pixels.len()}|${before}|${raw.hex()}|${independent}|${palette_before}|${palette_after}|${separate}|' +
		state())
}

fn line_case(line string) {
	fields := line.split('|')
	mut data := hex.decode(fields[12]) or { panic(err) }
	run_case(fields, mut data)
}

fn main() {
	if os.args.len > 1 {
		if os.args[1] == '--corpus' {
			for line in os.read_lines(os.args[2]) or { panic(err) } {
				line_case(line)
			}
			return
		}
		if os.args[1] == '--boxed' {
			first := p.IffHeader(p.BmhdHeader{
				width: 7
			})
			mut copy := first
			match mut copy {
				p.BmhdHeader { copy.width = 9 }
				else { panic('bad fixture') }
			}

			println('${(first as p.BmhdHeader).width}|${(copy as p.BmhdHeader).width}')
			return
		}
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
		return
	}
	println('${sizeof(p.IffChunkHeader)}|${sizeof(p.BmhdHeader)}|${sizeof(p.DgblHeader)}')
	for magic in [p.iff_chunk_bmhd, p.iff_chunk_body, p.iff_chunk_camg, p.iff_chunk_cmap,
		p.iff_chunk_abit, p.iff_chunk_dgbl, p.iff_chunk_dloc] {
		println('${magic.id}|${magic.name.hex()}')
	}
	for value in [u32(0), 1, 0x80, 0x800, 0x880, 0xffffffff] {
		println('${value}|${p.IffViewportMode.is_ehb(value)}|${p.IffViewportMode.is_ham(value)}')
	}
	mut chunk := p.IffChunkHeader{
		type_:  0x12345678
		length: 99
	}
	view := chunk.name()
	before := view.hex()
	copy := chunk
	chunk.type_ = 0x87654321
	println('${before}|${view.hex()}|${copy.type_}|${copy.length}')
}
