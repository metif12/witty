module vaxis

import strings

// Print a screen in the primary buffer without retaining its rendered state.
// This follows pinned Vaxis.prettyPrint, including its default-cell skips.
pub fn (mut vx Vaxis) pretty_print() !string {
	if vx.state.alt_screen {
		return error('NotInPrimaryScreen')
	}
	mut out := strings.new_builder(vx.screen.buf.len * 2 + 64)
	out.write_string('\x1b[?25l\x1b[?2026h\x1b[m')
	mut reposition := false
	mut row := u16(0)
	mut col := u16(0)
	mut cursor_style := Style{}
	mut link := CellHyperlink{}
	mut cursor_pos_row := u16(0)
	mut cursor_pos_col := u16(0)
	mut i := u16(0)
	for usize(i) < usize(vx.screen.buf.len) {
		cell := vx.screen.buf[int(i)]
		w := if cell.char_.width != 0 {
			u16(cell.char_.width)
		} else {
			u16(max_int(1, gwidth(cell.char_.grapheme, vx.caps.unicode)))
		}
		if w == 0 { panic('Assertion failed') }
		if col >= vx.screen.width {
			row = session_u16_add(row, 1)
			col = 0
			if !cell.wrapped {
				reposition = true
			}
		}
		if cell.default_ {
			reposition = true
		} else {
			if reposition {
				reposition = false
				link = CellHyperlink{}
				if cursor_pos_row == row {
					n := session_u16_sub(col, cursor_pos_col)
					if n > 0 {
						out.write_string('\x1b[${n}C')
					}
				} else {
					n := session_u16_sub(row, cursor_pos_row)
					for _ in 0 .. n {
						out.write_u8(`\n`)
					}
					out.write_u8(`\r`)
					if col > 0 {
						out.write_string('\x1b[${col}C')
					}
				}
			}
			if img := cell.image {
				out.write_string(render_image_placement(img))
			}
			out.write_string(render_style_delta(cursor_style, cell.style, vx.sgr,
				vx.enable_workarounds))
			if link.uri != cell.link.uri {
				params := if cell.link.uri.len == 0 { '' } else { cell.link.params }
				out.write_string('\x1b]8;${params};${cell.link.uri}\x1b\\')
			}
			out.write_string(cell.char_.grapheme)
			cursor_pos_col = session_u16_add(col, w)
			cursor_pos_row = row
			cursor_style = cell.style
			link = cell.link
		}
		mut j := session_u16_add(i, 1)
		for j < session_u16_add(i, w) {
			if usize(j) >= usize(vx.screen_last.buf.len) {
				break
			}
			vx.screen_last.buf[int(j)].skipped = true
			j = session_u16_add(j, 1)
		}
		col = session_u16_add(col, w)
		i = session_u16_add(i, w)
	}
	out.write_string('\r\n\x1b[m\x1b[?2026l')
	return out.str()
}
