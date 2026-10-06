module main

import os
import encoding.hex
import strings
import vaxis as v

fn word(p []string, i int) u16 {
	return u16(p[i].int())
}

fn window(screen &v.Screen, p []string) v.Window {
	return v.Window{
		screen:       screen
		width:        word(p, 4)
		height:       word(p, 5)
		x_off:        p[6].int()
		y_off:        p[7].int()
		parent_x_off: p[8].int()
		parent_y_off: p[9].int()
	}
}

struct InputRows {
	lines []string
}

fn main() {
	rows := &InputRows{
		lines: os.read_lines(os.args[1]) or { panic(err) }
	}
	for id in 0 .. rows.lines.len {
		render_case(id, rows.lines[id])
	}
}

fn render_case(id int, line string) {
	if line.len == 0 { return }
	p := line.split('|')
	mut screen := &v.Screen{
		width:      word(p, 1)
		height:     word(p, 2)
		cursor_col: 7
		cursor_row: 8
		cursor_vis: true
	}
	win := window(screen, p)
	mut out := strings.new_builder(256)
	if p[0] == 'S' {
		mut text := []u8{len: p[3].int()}
		for i in 0 .. text.len {
			text[i] = u8(33 + i % 94)
		}
		original := if text.len == 0 { '' } else { unsafe { tos(text.data, text.len) } }
		screen.buf = []v.Cell{len: text.len}
		for i in 0 .. text.len {
			screen.buf[i] = v.Cell{
				char_:    v.CellCharacter{
					grapheme: original.substr_unsafe(i, i + 1)
					width:    u8(i % 3)
				}
				style:    v.Style{
					fg:   v.ColorIndex{
						index: u8(i % 256)
					}
					bold: i % 2 == 0
				}
				link:     v.CellHyperlink{
					uri:    'u'
					params: 'p'
				}
				default_: i % 3 == 0
				wrapped:  i % 2 != 0
			}
		}
		win.scroll(word(p, 10))
		out.write_string('${id}|S|${screen.cursor_col},${screen.cursor_row},${int(screen.cursor_vis)}|')
		for cell in screen.buf {
			ptr := unsafe { usize(cell.char_.grapheme.str) }
			start := unsafe { usize(original.str) }
			offset := if cell.char_.grapheme.len > 0 && ptr >= start
				&& ptr + usize(cell.char_.grapheme.len) <= start + usize(original.len) {
				i64(ptr - start)
			} else {
				i64(-1)
			}
			color := match cell.style.fg {
				v.ColorIndex { int(cell.style.fg.index) + 1 }
				else { 0 }
			}

			out.write_string('${hex.encode(cell.char_.grapheme.bytes())}/${cell.char_.width},${color},${int(cell.style.bold)},${int(cell.default_)},${int(cell.wrapped)},${cell.link.uri},${cell.link.params},${offset},${int(cell.image != none)},${int(cell.scale.eql(v.CellScale{}))};')
		}
		for i in 0 .. text.len {
			text[i] ^= 1
		}
		mut checksum := u64(14695981039346656037)
		for cell in screen.buf {
			for byte in cell.char_.grapheme {
				checksum = (checksum ^ u64(byte)) * u64(1099511628211)
			}
		}
		out.write_string('|${checksum.hex()}')
	} else {
		event := if p[10].int() == 0 { ?v.Mouse(none) } else { ?v.Mouse(v.Mouse{
				col:     word(p, 11)
				row:     word(p, 12)
				xoffset: word(p, 13)
				yoffset: word(p, 14)
				button:  unsafe { v.MouseButton(word(p, 15)) }
				type_:   unsafe { v.MouseType(word(p, 16)) }
			}) }
		if mouse := win.has_mouse(event) {
			out.write_string('${id}|M|${mouse.col},${mouse.row},${mouse.xoffset},${mouse.yoffset},${int(mouse.button)},${int(mouse.type_)},${
				int(mouse.mods.shift()) + 2 * int(mouse.mods.alt()) + 4 * int(mouse.mods.ctrl())}')
		} else {
			out.write_string('${id}|M|-')
		}
	}
	println(out.str())
}
