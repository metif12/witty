module main

import os
import encoding.hex
import vaxis

type StyleAlias = vaxis.Style
type ColorAlias = vaxis.Color

struct ColorAlignment {
	head  u8
	value vaxis.Color
}

struct StyleAlignment {
	head  u8
	value vaxis.Style
}

fn color(kind int, value u32) vaxis.Color {
	return match kind {
		0 {
			vaxis.ColorDefault{}
		}
		1 {
			vaxis.ColorIndex{
				index: u8(value)
			}
		}
		2 {
			vaxis.color_rgb_from_uint(value)
		}
		else {
			panic('fixture kind')
		}
	}
}

fn text(c vaxis.Color) string {
	return match c {
		vaxis.ColorDefault { 'd' }
		vaxis.ColorIndex { 'i${c.index}' }
		vaxis.ColorRgb { 'r${c.rgb[0]},${c.rgb[1]},${c.rgb[2]}' }
	}
}

fn flags(s vaxis.Style) u8 {
	return u8(s.bold) | (u8(s.dim) << 1) | (u8(s.italic) << 2) | (u8(s.blink) << 3) | (u8(s.reverse) << 4) | (u8(s.invisible) << 5) | (u8(s.strikethrough) << 6)
}

fn style_text(s vaxis.Style) string {
	return '${text(s.fg)}/${text(s.bg)}/${text(s.ul)}/${u8(s.ul_style)}/${flags(s)}'
}

fn different_color(c vaxis.Color) vaxis.Color {
	if c is vaxis.ColorDefault {
		return vaxis.ColorIndex{
			index: 0
		}
	}
	return vaxis.ColorDefault{}
}

fn equality_checks(value vaxis.Style) u16 {
	copied := value
	mut result := u16(value.eql(value)) | (u16(value.eql(copied)) << 1)
	for field in 0 .. 11 {
		mut changed := value
		match field {
			0 { changed.fg = different_color(value.fg) }
			1 { changed.bg = different_color(value.bg) }
			2 { changed.ul = different_color(value.ul) }
			3 { changed.ul_style = unsafe { vaxis.UnderlineStyle((u8(value.ul_style) + 1) % 6) } }
			4 { changed.bold = !value.bold }
			5 { changed.dim = !value.dim }
			6 { changed.italic = !value.italic }
			7 { changed.blink = !value.blink }
			8 { changed.reverse = !value.reverse }
			9 { changed.invisible = !value.invisible }
			10 { changed.strikethrough = !value.strikethrough }
			else { panic('fixture field') }
		}

		result |= u16(value.eql(changed)) << (field + 2)
	}
	return result
}

fn spec(raw string) string {
	bytes := hex.decode(raw) or { panic('fixture hex') }
	direct := if c := vaxis.color_rgb_from_spec(bytes.bytestr()) { text(c) } else { 'E${err.msg()}' }
	mut parser := vaxis.Parser{
		buf: [128]u8{init: 17}
	}
	parsed := if r := parser.parse(('\x1b]10;' + bytes.bytestr() + '\x07').bytes(), false) {
		if event := r.event {
			if event is vaxis.ColorReport {
				'r${event.value[0]},${event.value[1]},${event.value[2]}'
			} else {
				'-'
			}
		} else {
			'-'
		}
	} else {
		'E${err.msg()}'
	}
	return '${direct}|${parsed}'
}

fn style(p []string) string {
	mut value := vaxis.Style{}
	before := value
	value.fg = color(p[1].int(), p[2].u32())
	value.bg = color(p[3].int(), p[4].u32())
	value.ul = color(p[5].int(), p[6].u32())
	value.ul_style = unsafe { vaxis.UnderlineStyle(u8(p[7].int())) }
	bits := p[8].int()
	value.bold = bits & 1 != 0
	value.dim = bits & 2 != 0
	value.italic = bits & 4 != 0
	value.blink = bits & 8 != 0
	value.reverse = bits & 16 != 0
	value.invisible = bits & 32 != 0
	value.strikethrough = bits & 64 != 0
	mut copied := value
	copied.bold = !copied.bold
	copied.fg = vaxis.ColorDefault{}
	return '${style_text(before)}|${style_text(value)}|${style_text(copied)}|${int(before.eql(value))}|${int(value.eql(copied))}|${equality_checks(value)}'
}

fn main() {
	if os.args[1] == 'trap' {
		vaxis.color_rgb_from_uint(os.args[2].u32())
		println('UNEXPECTED return')
		return
	}
	if os.args[1] == 'boxed' {
		mut c := vaxis.Color(vaxis.ColorRgb{
			rgb: [u8(1), 2, 3]!
		})
		old := c
		if c is vaxis.ColorRgb {
			unsafe {
				ptr := &c.rgb[0]
				*ptr = 9
			}
		}
		mut s := vaxis.Style{
			fg: vaxis.ColorRgb{
				rgb: [u8(4), 5, 6]!
			}
		}
		copied := s
		if s.fg is vaxis.ColorRgb {
			unsafe {
				ptr := &s.fg.rgb[0]
				*ptr = 8
			}
		}
		println('${text(c)}|${text(old)}|${text(s.fg)}|${text(copied.fg)}')
		return
	}
	if os.args[1] == 'layout' {
		println('${sizeof(vaxis.Color)},${__offsetof(ColorAlignment, value)},${sizeof(vaxis.Style)},${__offsetof(StyleAlignment, value)}')
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line == '' {
			continue
		}
		p := line.split('|')
		output := match p[0] {
			'U' {
				text(vaxis.color_rgb_from_uint(p[1].u32()))
			}
			'S' {
				spec(p[1])
			}
			'E' {
				left := color(p[1].int(), p[2].u32())
				right := color(p[3].int(), p[4].u32())
				'${int(left.eql(right))},${int(right.eql(left))}'
			}
			'T' {
				style(p)
			}
			'A' {
				mut s := StyleAlias{}
				s.bold = true
				s.fg = ColorAlias(vaxis.color_rgb_from_uint(0x123456))
				old := s
				s.dim = true
				'${style_text(s)}|${style_text(old)}|${int(s.eql(old))}'
			}
			'B' {
				mut rgb := [u8(1), 2, 3]!
				c := vaxis.Color(vaxis.ColorRgb{
					rgb: rgb
				})
				rgb[0] = 9
				old := c
				'${text(c)}|${text(old)}|${rgb[0]}'
			}
			else {
				panic('fixture case')
			}
		}

		println(output)
	}
}
