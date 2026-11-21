module main

import os
import strconv
import strings
import encoding.hex
import vaxis as vx

// Fixture-only observer runs after the ordinary V panic diagnostic/exit path.
__global (
	observed_screen = &vx.InternalScreen(unsafe { nil })
	observed_path   string
)

fn observe_exit() {
	if observed_path != '' && observed_screen != unsafe { nil } {
		mut out := strings.new_builder(512)
		state(mut out, observed_screen, 'abcURIid0'.bytes(), vx.Cell{})
		os.write_file(observed_path, out.str()) or { eprintln('OBSERVER ERROR: ' + err.msg()) }
	}
}

fn number(p []string, i int) u16 {
	return u16(strconv.parse_uint(p[i], 10, 16) or { panic(err) })
}

fn color(c vx.Color) u32 {
	return match c {
		vx.ColorDefault { 0 }
		vx.ColorIndex { u32(0x1000000) + u32(c.index) }
		vx.ColorRgb { u32(0x2000000) + (u32(c.rgb[0]) << 16) + (u32(c.rgb[1]) << 8) + u32(c.rgb[2]) }
	}
}

fn offset(value string, data []u8) i64 {
	ptr := uint(value.str)
	base := uint(data.data)
	return if ptr >= base && ptr <= base + uint(data.len)
		&& uint(value.len) <= base + uint(data.len) - ptr {
		i64(ptr - base)
	} else {
		i64(-1)
	}
}

fn flags(s vx.Style) u8 {
	return u8(s.bold) | (u8(s.dim) << 1) | (u8(s.italic) << 2) | (u8(s.blink) << 3) | (u8(s.reverse) << 4) | (u8(s.invisible) << 5) | (u8(s.strikethrough) << 6)
}

fn cell(data []u8, n u8) vx.Cell {
	return vx.Cell{
		char_:    vx.CellCharacter{
			grapheme: unsafe { tos(data.data, int(n % 4)) }
			width:    n
		}
		style:    vx.Style{
			fg:            match n % 3 {
				0 {
					vx.Color(vx.ColorDefault{})
				}
				1 {
					vx.Color(vx.ColorIndex{
						index: n
					})
				}
				else {
					vx.Color(vx.ColorRgb{
						rgb: [n, n ^ 0xaa, 255 - n]!
					})
				}
			}
			bg:            vx.ColorRgb{
				rgb: [n, u8(0), 255 - n]!
			}
			ul:            vx.ColorIndex{
				index: 255 - n
			}
			ul_style:      unsafe { vx.UnderlineStyle(n % 6) }
			bold:          n & 1 != 0
			dim:           n & 2 != 0
			italic:        n & 4 != 0
			blink:         n & 8 != 0
			reverse:       n & 16 != 0
			invisible:     n & 32 != 0
			strikethrough: n & 64 != 0
		}
		link:     vx.CellHyperlink{
			uri:    unsafe { tos(&u8(data.data) + 3, 3) }
			params: unsafe { tos(&u8(data.data) + 6, 3) }
		}
		default_: n & 1 != 0
		wrapped:  n & 2 != 0
		scale:    vx.CellScale.init(n % 8, n % 16, u8((u16(n) + 1) % 16),
			unsafe { vx.VerticalAlignment(n % 3) })
		image:    if n & 1 != 0 {
			vx.ImagePlacement{
				img_id:  u32(0x1000000) + u32(n)
				options: vx.ImageDrawOptions{
					pixel_offset: vx.ImagePixelOffset{
						x: n
						y: 255 - n
					}
					z_index:      -i32(n)
					clip_region:  vx.ImageClipRegion{
						x:      n
						height: 65535
					}
					scale:        unsafe { vx.ImageScale(n % 4) }
					size:         vx.ImageCellSize{
						cols: n
					}
				}
			}
		} else {
			none
		}
	}
}

fn cell_value(mut out strings.Builder, c vx.Cell, data []u8) {
	out.write_string('${hex.encode(c.char_.grapheme.bytes())},${offset(c.char_.grapheme, data)},${c.char_.width},${int(c.default_)},${int(c.wrapped)},${color(c.style.fg)},${color(c.style.bg)},${color(c.style.ul)},${u8(c.style.ul_style)},${flags(c.style)},${hex.encode(c.link.uri.bytes())},${offset(c.link.uri,
		data)},${hex.encode(c.link.params.bytes())},${offset(c.link.params, data)},${c.scale.scale()},${c.scale.numerator()},${c.scale.denominator()},${u8(c.scale.vertical_alignment())},')
	if img := c.image {
		opts := img.options
		pix := opts.pixel_offset or { panic('pixel offset') }
		z := opts.z_index or { panic('z') }
		clip := opts.clip_region or { panic('clip') }
		x := clip.x or { panic('x') }
		height := clip.height or { panic('height') }
		size := opts.size or { panic('size') }
		cols := size.cols or { panic('cols') }
		out.write_string('I${img.img_id},${pix.x},${pix.y},${z},${x},${int(clip.y != none)},${int(clip.width != none)},${height},${u8(opts.scale)},${int(size.rows != none)},${cols},${int(opts.size != none)},${int(opts.clip_region != none)};')
	} else {
		out.write_string('-;')
	}
}

fn internal_value(mut out strings.Builder, c vx.InternalCell, data []u8, incoming vx.Cell) {
	cell_value(mut out, vx.Cell{
		char_:    vx.CellCharacter{
			grapheme: c.char_
		}
		style:    c.style
		link:     vx.CellHyperlink{
			uri:    c.uri
			params: c.uri_id
		}
		default_: c.default_
		scale:    c.scale
	}, data)
	ignored := vx.Cell{
		...incoming
		char_:   vx.CellCharacter{
			...incoming.char_
			width: 255
		}
		image:   none
		wrapped: !incoming.wrapped
		scale:   vx.CellScale.init(7, 0, 0, .center)
	}
	out.write_string('${int(c.skipped)},${int(c.skip)},${int(c.eql(incoming))},${int(c.eql(ignored))};')
}

fn state(mut out strings.Builder, s &vx.InternalScreen, data []u8, incoming vx.Cell) {
	out.write_string('${s.width},${s.height},${s.buf.len},${s.cursor_col},${s.cursor_row},${int(s.cursor_vis)},${u8(s.mouse_shape)},${u8(s.cursor_shape)}|')
	for c in s.buf {
		internal_value(mut out, c, data, incoming)
	}
}

fn fit_record(mut out strings.Builder, p []string, data []u8) {
	field := number(p, 1)
	first := int(number(p, 2))
	second := int(number(p, 3))
	mut s := vx.InternalScreen.new(1, 1)
	value := vx.Cell{
		char_: vx.CellCharacter{
			grapheme: if field == 0 { 'a'.repeat(first) } else { 'C' }
		}
		link:  vx.CellHyperlink{
			uri:    if field == 1 { 'a'.repeat(first) } else { 'U' }
			params: if field == 2 { 'a'.repeat(first) } else { 'I' }
		}
	}
	s.write_cell(0, 0, value)
	old := s.read_cell(0, 0) or { panic('missing') }
	next := vx.Cell{
		char_: vx.CellCharacter{
			grapheme: if field == 0 { 'b'.repeat(second) } else { 'D' }
		}
		link:  vx.CellHyperlink{
			uri:    if field == 1 { 'b'.repeat(second) } else { 'V' }
			params: if field == 2 { 'b'.repeat(second) } else { 'J' }
		}
	}
	s.write_cell(0, 0, next)
	current := s.read_cell(0, 0) or { panic('missing') }
	cell_value(mut out, old, data)
	out.write_string('|')
	cell_value(mut out, current, data)
	out.write_string('|${int(uint(old.char_.grapheme.str) == uint(current.char_.grapheme.str))},${int(uint(old.link.uri.str) == uint(current.link.uri.str))},${int(uint(old.link.params.str) == uint(current.link.params.str))}')
	s.deinit()
}

fn record(line string, index int) {
	p := line.split('|')
	mut data := 'abcURIid0'.bytes()
	mut out := strings.new_builder(512)
	out.write_string('${index}|')
	if p[0] == 'F' {
		fit_record(mut out, p, data)
		println(out.str())
		return
	}
	if p[0] == 'E' {
		internal_value(mut out, vx.InternalCell{}, data, cell(data, u8(number(p, 1))))
		println(out.str())
		return
	}
	mut s := &vx.InternalScreen{
		buf: []vx.InternalCell{}
	}
	mut read := ?vx.Cell(none)
	mut incoming := cell(data, 0)
	if p[0] in ['N', 'P'] {
		created := vx.InternalScreen.new(number(p, 1), number(p, 2))
		s = &vx.InternalScreen{
			...created
		}
		if p[0] == 'P' { read = s.read_cell(0, 0) }
	} else {
		created := vx.InternalScreen.new(number(p, 3), 1)
		s = &vx.InternalScreen{
			...created
		}
		for i in 0 .. s.buf.len {
			s.write_cell(u16(i), 0, cell(data, u8((i + 3) % 256)))
			s.buf[i].skipped = i % 2 == 0
			s.buf[i].skip = i % 3 == 0
			s.buf[i].scale = vx.CellScale.init(u8(i % 8), u8(i % 16), u8((i + 1) % 16),
				unsafe { vx.VerticalAlignment(i % 3) })
		}
		n := u8(number(p, 9))
		meta := number(p, 11)
		incoming = cell(data, n)
		s.width = number(p, 1)
		s.height = number(p, 2)
		s.cursor_col = meta * 257
		s.cursor_row = 65535 - meta * 257
		s.cursor_vis = meta & 1 != 0
		s.mouse_shape = unsafe { vx.MouseShape(meta % 9) }
		s.cursor_shape = unsafe { vx.CursorShape(meta % 7) }
		if p[0] != 'R' { s.write_cell(number(p, 4), number(p, 5), incoming) }
		if p[0] != 'W' { read = s.read_cell(number(p, 6), number(p, 7)) }
	}
	state(mut out, s, data, incoming)
	out.write_string('|')
	if c := read {
		cell_value(mut out, c, data)
	} else {
		out.write_string('-')
	}
	if p[0] != 'N' {
		if number(p, 10) != 0 {
			data[0] = 88
			data[3] = 89
			data[6] = 90
		}
		if p[0] in ['B', 'P'] {
			if c := read {
				unsafe {
					if c.char_.grapheme.len > 0 { c.char_.grapheme.str[0] = 81 }
					if c.link.uri.len > 0 { c.link.uri.str[0] = 82 }
					if c.link.params.len > 0 { c.link.params.str[0] = 83 }
				}
			}
		}
		out.write_string('|')
		state(mut out, s, data, incoming)
		out.write_string('|')
		if c := read {
			cell_value(mut out, c, data)
		} else {
			out.write_string('-')
		}
	}
	println(out.str())
	s.deinit()
}

fn alias_case(label string, path string) {
	mut s := vx.InternalScreen.new(1, 1)
	s.write_cell(0, 0, vx.Cell{
		char_: vx.CellCharacter{
			grapheme: 'abc'
		}
		link:  vx.CellHyperlink{
			uri:    'URI'
			params: 'id0'
		}
	})
	s.buf[0].skip = true
	s.buf[0].skipped = true
	observed_screen = &s
	observed_path = path
	if path != '' { at_exit(observe_exit) or { panic(err) } }
	mut value := s.read_cell(0, 0) or { panic('missing') }
	value.style = vx.Style{
		italic: true
	}
	value.default_ = true
	if label in ['alias_uri', 'alias_id'] { value.char_.grapheme = 'NEW' }
	if label == 'alias_uri' { value.link.uri = unsafe { tos(value.link.uri.str + 1, 2) } }
	if label == 'alias_id' {
		value.link.uri = 'NEW_URI'
		value.link.params = unsafe { tos(value.link.params.str + 1, 2) }
	}
	if label == 'alias_partial' {
		value.char_.grapheme = unsafe { tos(value.char_.grapheme.str + 1, 2) }
	}
	s.write_cell(0, 0, value)
	println('MANAGED: ' + (s.read_cell(0, 0) or { panic('missing') }).char_.grapheme)
}

fn boundary_case(label string) {
	if label == 'array_limit' {
		s := vx.InternalScreen.new(65535, 65535)
		println('UNEXPECTED: ' + s.buf.len.str())
		return
	}
	mut s := vx.InternalScreen.new(1, 1)
	if label == 'alloc_init' {
		println('INIT_MANAGED: ' + s.buf.len.str())
		return
	}
	if label == 'alloc_write' {
		s.write_cell(0, 0, vx.Cell{
			char_:    vx.CellCharacter{
				grapheme: 'a'.repeat(8192)
			}
			link:     vx.CellHyperlink{
				uri:    'URI'
				params: 'id0'
			}
			style:    vx.Style{
				bold: true
			}
			default_: true
		})
		c := s.read_cell(0, 0) or { panic('missing') }
		println('WRITE: ${c.char_.grapheme.len},${c.link.uri},${c.link.params},${int(c.style.bold)},${int(c.default_)}')
		return
	}
	s.write_cell(0, 0, vx.Cell{
		char_: vx.CellCharacter{
			grapheme: 'abc'
		}
	})
	old := s.read_cell(0, 0) or { panic('missing') }
	s.write_cell(0, 0, vx.Cell{
		char_: vx.CellCharacter{
			grapheme: 'def'
		}
	})
	current := s.read_cell(0, 0) or { panic('missing') }
	println('BORROW: ${old.char_.grapheme}|${current.char_.grapheme}')
}

fn main() {
	if os.args[1] in ['old_view', 'alloc_init', 'alloc_write', 'array_limit'] {
		boundary_case(os.args[1])
		return
	}
	if os.args[1] in ['alias_self', 'alias_uri', 'alias_id', 'alias_partial'] {
		alias_case(os.args[1], if os.args.len > 2 { os.args[2] } else { '' })
		return
	}
	for i, line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line.len > 0 { record(line, i) }
	}
}
