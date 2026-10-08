module main

import zigimg as p
import encoding.hex
import os

__global (
	observed      = &p.PngHeaderData(unsafe { nil })
	observed_path string
)

fn fields(h p.PngHeaderData) string {
	return '${h.width},${h.height},${h.bit_depth},${u8(h.color_type)},${u8(h.compression_method)},${u8(h.filter_method)},${u8(h.interlace_method)}'
}

fn observe() {
	if observed != unsafe { nil } { os.write_file(observed_path, fields(observed)) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn n(a []string, i int) u32 {
	return a[i].u32()
}

fn record(a []string, id int, file_path string) string {
	mut out := '${id}|'
	if a[0] == 'H' {
		h := p.PngHeaderData{
			width:              n(a, 1)
			height:             n(a, 2)
			bit_depth:          u8(n(a, 3))
			color_type:         unsafe { p.PngColorType(n(a, 4)) }
			compression_method: unsafe { p.PngCompressionMethod(n(a, 5)) }
			filter_method:      unsafe { p.PngFilterMethod(n(a, 6)) }
			interlace_method:   unsafe { p.PngInterlaceMethod(n(a, 7)) }
		}
		out += fields(h) +
			'|${u8(h.is_valid())},${u8(h.allows_palette())},${h.max_palette_size()},${h.channel_count()},${h.pixel_bits()},${h.line_bytes()}|'
		valid_depth := match h.color_type {
			.grayscale { h.bit_depth in [u8(1), 2, 4, 8, 16] }
			.indexed { h.bit_depth in [u8(1), 2, 4, 8] }
			else { h.bit_depth in [u8(8), 16] }
		}

		out += if valid_depth { u32(h.get_pixel_format()).str() } else { '-' }
	} else if a[0] == 'F' {
		mut valid := true
		c := p.PngColorType.from_pixel_format(unsafe { p.PixelFormat(n(a, 1)) }) or {
			out += 'E${err.msg()}'
			valid = false
			p.PngColorType.grayscale
		}
		if valid { out += '${u8(c)}|${c.channel_count()}' }
	} else if a[0] == 'C' {
		mut bytes := hex.decode(a[1]) or { panic(err) }
		bytes << u8(0)
		c := p.PngChunk.init(unsafe { tos(bytes.data, 4) })
		copy := c
		bytes[int(n(a, 2))] = u8(n(a, 3))
		out += '${c.id}|${hex.encode(c.name.bytes())}|${copy.id}|${hex.encode(copy.name.bytes())}'
		mut header := p.PngChunkHeader{
			length:     n(a, 4)
			chunk_type: c.id
		}
		copied := header
		borrowed := header.name()
		header.chunk_type ^= 0xffffffff
		out += '|${header.length}|${hex.encode(borrowed)}|${copied.chunk_type}|${u8(p.png_is_chunk_critical(c.id))},${u8(p.png_is_chunk_critical(header.chunk_type))}'
	} else {
		bytes := hex.decode(a[2]) or { panic(err) }
		mut buf := []u8{len: int(n(a, 1)), init: 0xa5}
		mut stream := p.ReadStream.init_memory(bytes)
		mut file := os.File{}
		if buf.len > 0 {
			os.write_file_array(file_path, bytes) or { panic(err) }
			file = os.open(file_path) or { panic(err) }
			stream = p.ReadStream.init_file(file, mut buf)
		}
		mut valid := true
		h := p.png_load_header(mut stream) or {
			out += 'E${err.msg()}'
			valid = false
			p.PngHeaderData{
				width:              0
				height:             0
				bit_depth:          0
				color_type:         .grayscale
				compression_method: .deflate
				filter_method:      .adaptive
				interlace_method:   .none
			}
		}
		if valid { out += 'OK|' + fields(h) }
		out += '|${stream.get_pos()}'
		if buf.len > 0 { file.close() }
	}
	return out + '\n'
}

fn trap(name string, path string) {
	mut h := &p.PngHeaderData{
		color_type:         .grayscale
		compression_method: .deflate
		filter_method:      .adaptive
		interlace_method:   .none

		width:     1
		height:    1
		bit_depth: 8
	}
	observed = h
	observed_path = path
	at_exit(observe) or { panic(err) }
	match name {
		'pixel_rgb' {
			h.color_type = .rgb_color
			h.bit_depth = 86
			_ = h.pixel_bits()
		}
		'pixel_rgba' {
			h.color_type = .rgba_color
			h.bit_depth = 64
			_ = h.pixel_bits()
		}
		'pixel_alpha' {
			h.color_type = .grayscale_alpha
			h.bit_depth = 128
			_ = h.pixel_bits()
		}
		'line_pixel_first' {
			h.width = 0
			h.color_type = .rgba_color
			h.bit_depth = 255
			_ = h.line_bytes()
		}
		'line_mul' {
			h.width = 134217728
			h.color_type = .rgba_color
			_ = h.line_bytes()
		}
		'line_add' {
			h.width = 0xfffffff9
			h.bit_depth = 1
			_ = h.line_bytes()
		}
		else {
			h.width = 0
			h.height = 0
			h.bit_depth = 0
			if name == 'format_rgb' {
				h.color_type = .rgb_color
			} else if name == 'format_index' {
				h.color_type = .indexed
				h.bit_depth = 16
			} else if name == 'format_alpha' {
				h.color_type = .grayscale_alpha
			} else if name == 'format_rgba' {
				h.color_type = .rgba_color
			}
			_ = h.get_pixel_format()
		}
	}

	panic('UNEXPECTED returning trap')
}

fn main() {
	if os.args.len > 2 && os.args[1] == '--chunk-length' {
		_ = p.PngChunk.init('a'.repeat(os.args[2].int()))
		panic('UNEXPECTED returning chunk length')
	}
	if os.args.len > 2 && os.args[1] == '--trap' {
		trap(os.args[2], os.args[3])
		return
	}
	input := os.read_file(os.args[1]) or { panic(err) }
	mut id := 0
	for line in input.split_into_lines() {
		if line == '' { continue
		 }
		print(record(line.split('|'), id, os.args[1] + '.png'))
		id++
	}
}
