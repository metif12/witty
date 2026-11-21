module main

import os
import strconv
import strings
import encoding.hex
import vaxis
import vaxis.vxfw as fw

fn number(p []string, i int) i64 {
	return strconv.parse_int(p[i], 10, 64) or { panic(err) }
}

fn color(c vaxis.Color) int {
	return match c {
		vaxis.ColorDefault { -1 }
		vaxis.ColorIndex { int(c.index) }
		else { -2 }
	}
}

fn flags(s vaxis.Style) u8 {
	return u8(s.bold) | (u8(s.dim) << 1) | (u8(s.italic) << 2) | (u8(s.blink) << 3) | (u8(s.reverse) << 4) | (u8(s.invisible) << 5) | (u8(s.strikethrough) << 6)
}

fn cells(mut out strings.Builder, s &fw.Surface, data []u8) {
	for c in s.buffer {
		pointer := uint(c.char_.grapheme.str)
		base := uint(data.data)
		offset := if pointer >= base && pointer <= base + uint(data.len)
			&& uint(c.char_.grapheme.len) <= base + uint(data.len) - pointer {
			i64(pointer - base)
		} else {
			i64(-1)
		}
		out.write_string('${hex.encode(c.char_.grapheme.bytes())},${offset},${c.char_.width},${color(c.style.fg)},${color(c.style.bg)},${color(c.style.ul)},${u8(c.style.ul_style)},${flags(c.style)},${int(c.default_)},${int(c.wrapped)},${c.link.uri.len},${c.link.params.len},${int(c.image != none)},${c.scale.scale()},${c.scale.numerator()},${c.scale.denominator()};')
	}
}

// Do not retain a Surface value in the serializer's scope: pinned V production
// recursively scans aggregate locals on every call, including writer calls.
fn drawn_surface(text &fw.Text, ctx fw.DrawContext, widget bool) &fw.Surface {
	value := if !widget { text.draw(ctx) or { panic(err) } } else { text.widget().draw(ctx) or {
			panic(err)} }
	return &fw.Surface{
		...value
	}
}

fn record(line string, index int) {
	p := line.split('|')
	mut data := hex.decode(p[0]) or { panic(err) }
	textbytes := if data.len == 0 { '' } else { unsafe { tos(data.data, data.len) } }
	fw.DrawContext.init(unsafe { vaxis.GWidthMethod(number(p, 1)) })
	text := fw.Text{
		text:        textbytes
		softwrap:    number(p, 2) != 0
		text_align:  unsafe { fw.TextAlign(number(p, 3)) }
		overflow:    unsafe { fw.TextOverflow(number(p, 4)) }
		width_basis: if number(p, 5) == 0 { .longest_line } else { .parent }
		style:       if number(p, 10) != 0 {
			vaxis.Style{
				fg:            vaxis.ColorIndex{
					index: 4
				}
				bg:            vaxis.ColorIndex{
					index: 5
				}
				ul:            vaxis.ColorIndex{
					index: 6
				}
				ul_style:      .curly
				bold:          true
				dim:           true
				italic:        true
				blink:         true
				reverse:       true
				invisible:     true
				strikethrough: true
			}
		} else {
			vaxis.Style{}
		}
	}
	ctx := fw.DrawContext{
		min:       fw.Size{
			width:  u16(number(p, 6))
			height: u16(number(p, 7))
		}
		max:       fw.MaxSize{
			width:  if number(p, 8) < 0 { none } else { u16(number(p, 8)) }
			height: if number(p, 9) < 0 { none } else { u16(number(p, 9)) }
		}
		cell_size: fw.Size{}
	}
	s := drawn_surface(&text, ctx, number(p, 11) != 0)
	mut out := strings.new_builder(256)
	out.write_string('${index}|${s.size.width},${s.size.height},${s.buffer.len},${s.children.len},${int(s.cursor != none)},${int(s.widget.eql(text.widget()))}|')
	cells(mut out, s, data)
	if p.len > 12 && p[12].len > 0 {
		for change in p[12].split(',') {
			pair := change.split(':')
			i := strconv.atoi(pair[0]) or { panic(err) }
			data[i] = u8(strconv.parse_uint(pair[1], 16, 8) or { panic(err) })
		}
		out.write_string('|')
		cells(mut out, s, data)
	}
	println(out.str())
}

fn main() {
	for i, line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line.len > 0 { record(line, i) }
	}
}
