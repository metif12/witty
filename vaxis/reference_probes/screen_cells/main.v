module main

import os
import strconv
import strings
import encoding.hex
import vaxis as vx

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

fn state(mut out strings.Builder, s &vx.Screen, data []u8) {
	out.write_string('${s.width},${s.height},${s.width_pix},${s.height_pix},${s.buf.len},${s.cursor_col},${s.cursor_row},${int(s.cursor_vis)},${u8(s.width_method)},${u8(s.mouse_shape)},${u8(s.cursor_shape)}|')
	for c in s.buf {
		cell_value(mut out, c, data)
	}
}

fn record(line string, index int) {
	p := line.split('|')
	mut data := 'abcURIid0'.bytes()
	mut s := &vx.Screen{}
	mut read := ?vx.Cell(none)
	if p[0] == 'D' {
	} else if p[0] == 'N' {
		created := vx.Screen.new(vx.Winsize{
			cols:    number(p, 1)
			rows:    number(p, 2)
			x_pixel: number(p, 3)
			y_pixel: number(p, 4)
		})
		s = &vx.Screen{
			...created
		}
	} else {
		n := u8(number(p, 9))
		meta := number(p, 11)
		mut backing := []vx.Cell{len: int(number(p, 3))}
		for i in 0 .. backing.len {
			backing[i] = cell(data, u8((i + 3) % 256))
		}
		s = &vx.Screen{
			width:        number(p, 1)
			height:       number(p, 2)
			buf:          backing
			width_pix:    meta * 257
			height_pix:   65535 - meta * 257
			cursor_col:   meta * 257
			cursor_row:   65535 - meta * 257
			cursor_vis:   meta & 1 != 0
			width_method: unsafe { vx.GWidthMethod(meta % 3) }
			mouse_shape:  unsafe { vx.MouseShape(meta % 9) }
			cursor_shape: unsafe { vx.CursorShape(meta % 7) }
		}
		if p[0] != 'R' { s.write_cell(number(p, 4), number(p, 5), cell(data, n)) }
		if p[0] != 'W' { read = s.read_cell(number(p, 6), number(p, 7)) }
	}
	mut out := strings.new_builder(512)
	out.write_string('${index}|')
	state(mut out, s, data)
	out.write_string('|')
	if c := read {
		cell_value(mut out, c, data)
	} else {
		out.write_string('-')
	}
	if p[0] != 'N' && p[0] != 'D' {
		if number(p, 10) != 0 {
			data[0] = 88
			data[3] = 89
			data[6] = 90
		}
		out.write_string('|')
		state(mut out, s, data)
		out.write_string('|')
		if c := read {
			cell_value(mut out, c, data)
		} else {
			out.write_string('-')
		}
		if number(p, 8) != 0 { s.clear() }
		out.write_string('|')
		state(mut out, s, data)
	}
	println(out.str())
	s.deinit()
}

fn main() {
	for i, line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line.len > 0 { record(line, i) }
	}
}
