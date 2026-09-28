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
	mut row := 0
	mut col := 0
	mut cursor_style := Style{}
	mut link := CellHyperlink{}
	mut cursor_pos_row := 0
	mut cursor_pos_col := 0
	mut i := 0
	for i < vx.screen.buf.len {
		cell := vx.screen.buf[i]
		w := if cell.char_.width != 0 {
			int(cell.char_.width)
		} else {
			max_int(1,
				gwidth(cell.char_.grapheme, vx.caps.unicode))
		}
		assert w > 0
		if col >= int(vx.screen.width) {
			row++
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
					n := col - cursor_pos_col
					if n > 0 {
						out.write_string('\x1b[${n}C')
					}
				} else {
					n := row - cursor_pos_row
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
			cursor_pos_col = col + w
			cursor_pos_row = row
			cursor_style = cell.style
			link = cell.link
		}
		for j in i + 1 .. min_int(i + w, vx.screen_last.buf.len) {
			vx.screen_last.buf[j].skipped = true
		}
		col += w
		i += w
	}
	out.write_string('\r\n\x1b[m\x1b[?2026l')
	return out.str()
}
