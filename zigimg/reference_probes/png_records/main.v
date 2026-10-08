module main

import zigimg as p
import encoding.hex
import os

fn n(a []string, i int) u32 {
	return a[i].u32()
}

fn fields(h p.PngHeaderData) string {
	return '${h.width},${h.height},${h.bit_depth},${u8(h.color_type)},${u8(h.compression_method)},${u8(h.filter_method)},${u8(h.interlace_method)}'
}

// Source's method enums are open byte enums. Pinned V rejects unnamed
// constant enum casts under -prod, so use its runtime numeric adapter.
fn compression(value u8) p.PngCompressionMethod {
	return unsafe { p.PngCompressionMethod(value) }
}

fn filter_method(value u8) p.PngFilterMethod {
	return unsafe { p.PngFilterMethod(value) }
}

fn choice(value u32) p.PngFilterChoice {
	return if value == 0 {
		p.PngFilterChoice(p.PngTryAll{})
	} else if value == 1 {
		p.PngFilterChoice(p.PngHeuristic{})
	} else {
		p.PngFilterChoice(p.PngSpecified{
			filter: unsafe { p.PngFilterType(value - 2) }
		})
	}
}

fn options(value p.PngEncoderOptions) string {
	return '${u8(value.interlaced)},' + match value.filter_choice {
		p.PngTryAll { '0,0' }
		p.PngHeuristic { '1,0' }
		p.PngSpecified { '2,${u8(value.filter_choice.filter)}' }
	}
}

fn record(a []string) string {
	mut out := ''
	if a[0] == 'H' {
		mut h := p.PngHeaderData{
			width:              n(a, 1)
			height:             n(a, 2)
			bit_depth:          u8(n(a, 3))
			color_type:         unsafe { p.PngColorType(n(a, 4)) }
			compression_method: unsafe { p.PngCompressionMethod(n(a, 5)) }
			filter_method:      unsafe { p.PngFilterMethod(n(a, 6)) }
			interlace_method:   unsafe { p.PngInterlaceMethod(n(a, 7)) }
		}
		before := h
		mut copy := h
		match n(a, 8) {
			0 { copy.width = 27 }
			1 { copy.height = 9 }
			2 { copy.bit_depth = 16 }
			3 { copy.color_type = .rgba_color }
			4 { copy.compression_method = compression(255) }
			5 { copy.filter_method = filter_method(1) }
			6 { copy.interlace_method = .adam7 }
			else {}
		}

		h.width ^= 1
		out = fields(before) + '|' + fields(h) + '|' + fields(copy) +
			'|${u8(h.is_valid())},${u8(copy.is_valid())}'
	} else if a[0] == 'C' {
		mut first := hex.decode(a[1]) or { panic(err) }
		mut second := hex.decode(a[2]) or { panic(err) }
		first << u8(0)
		second << u8(0)
		mut c := p.PngChunk{
			id:   n(a, 3)
			name: unsafe { tos(first.data, 4) }
		}
		mut copy := c
		copy.id = n(a, 4)
		copy.name = unsafe { tos(second.data, 4) }
		first[int(n(a, 5))] = u8(n(a, 6))
		c.id ^= 0xffffffff
		out = '${c.id}|${hex.encode(c.name.bytes())}|${copy.id}|${hex.encode(copy.name.bytes())}'
	} else if a[0] == 'N' {
		mut h := p.PngChunkHeader{
			length:     n(a, 1)
			chunk_type: n(a, 2)
		}
		mut copy := h
		borrowed := h.name()
		copy.length = n(a, 3)
		copy.chunk_type = n(a, 4)
		h.chunk_type ^= 0xffffffff
		out = '${h.length},${h.chunk_type}|${hex.encode(borrowed)}|${copy.length},${copy.chunk_type}|${hex.encode(copy.name())}'
	} else if a[0] == 'O' {
		mut original := p.PngEncoderOptions{}
		out = options(original) + '|'
		original.interlaced = n(a, 1) != 0
		original.filter_choice = choice(n(a, 2))
		mut copy := original
		copy.interlaced = !copy.interlaced
		copy.filter_choice = choice(n(a, 3))
		out += options(original) + '|' + options(copy)
	} else {
		mut original := choice(n(a, 1) + 2)
		mut copy := original
		match mut copy {
			p.PngSpecified { copy.filter = unsafe { p.PngFilterType(n(a, 2)) } }
			else { panic('invalid fixture choice') }
		}

		before := match original {
			p.PngSpecified { u8(original.filter) }
			else { panic('invalid fixture choice') }
		}

		after := match copy {
			p.PngSpecified { u8(copy.filter) }
			else { panic('invalid fixture choice') }
		}

		out = '${before},${after}'
	}
	return out + '\n'
}

fn main() {
	input := os.read_file(os.args[1]) or { panic(err) }
	for line in input.split_into_lines() {
		if line != '' { print(record(line.split('|'))) }
	}
}
