module vaxis

import strings

// Render the current cell screen with the pinned Vaxis.render state machine.
// The V adapter returns the bytes that Zig writes to its IoWriter.
pub fn (mut vx Vaxis) render() string {
	defer {
		vx.refresh = false
	}
	if uint(vx.screen.buf.len) != uint(vx.screen.width) * uint(vx.screen.height) {
		panic('Assertion failed')
	}
	if vx.screen.buf.len != vx.screen_last.buf.len { panic('Assertion failed') }
	mut out := strings.new_builder(vx.screen.buf.len * 2 + 128)
	out.write_string('\x1b[?2026h\x1b[?25l')
	if vx.state.alt_screen {
		out.write_string('\x1b[H')
	} else {
		out.write_string('\r')
		for _ in 0 .. int(vx.state.cursor.row) {
			out.write_string('\x1bM')
		}
	}
	out.write_string('\x1b[m')
	mut reposition := false
	mut row := u16(0)
	mut col := u16(0)
	mut cursor_style := Style{}
	mut link := CellHyperlink{}
	mut cursor_pos_row := u16(0)
	mut cursor_pos_col := u16(0)
	if vx.caps.kitty_graphics {
		out.write_string('\x1b_Ga=d\x1b\\')
	}
	for mut last_cell in vx.screen_last.buf {
		last_cell.skip = false
	}
	mut i := uint(0)
	for i < uint(vx.screen.buf.len) {
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
		last := vx.screen_last.buf[int(i)]
		if (!vx.refresh && last.eql(cell) && !last.skipped && cell.image == none) || last.skip {
			reposition = true
			if link.uri.len > 0 {
				out.write_string('\x1b]8;;\x1b\\')
			}
		} else {
			vx.screen_last.buf[int(i)].skipped = false
			vx.screen_last.write_cell(col, row, cell)
			if vx.caps.scaled_text && cell.scale.scale() > 1 {
				if cell.char_.width == 0 { panic('Assertion failed') }
				cols := session_u8_mul(cell.scale.scale(), cell.char_.width)
				rows := int(cell.scale.scale())
				for skipped_row in 0 .. rows {
					for skipped_col in 0 .. int(cols) {
						if skipped_row == 0 && skipped_col == 0 {
							continue
						}
						skipped_i := session_usize_add(session_usize_mul(session_usize_add(uint(skipped_row),
							uint(row)), uint(vx.screen_last.width)), session_usize_add(uint(skipped_col),
							uint(col)))
						if skipped_i >= uint(vx.screen_last.buf.len) {
							panic('index out of bounds')
						}
						vx.screen_last.buf[int(skipped_i)].skip = true
					}
				}
			}
			if reposition {
				reposition = false
				link = CellHyperlink{}
				if vx.state.alt_screen {
					out.write_string('\x1b[${session_u16_add(row, 1)};${session_u16_add(col, 1)}H')
				} else if cursor_pos_row == row {
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
			if vx.caps.scaled_text && !cell.scale.eql(CellScale{}) {
				scale := cell.scale
				if scale.denominator() == 0 { panic('reached unreachable code') }
				if scale.denominator() == 1 {
					out.write_string('\x1b]66;s=${scale.scale()}:w=${w};${cell.char_.grapheme}\x1b\\')
				} else {
					out.write_string('\x1b]66;s=${scale.scale()}:w=${w}:n=${scale.numerator()}:d=${scale.denominator()}:v=${u8(scale.vertical_alignment())};${cell.char_.grapheme}\x1b\\')
				}
				cursor_pos_col = session_u16_add(col, session_u16_mul(w, u16(scale.scale())))
				cursor_pos_row = row
			} else {
				if vx.caps.explicit_width && w > 1 {
					out.write_string('\x1b]66;w=${w};${cell.char_.grapheme}\x1b\\')
				} else {
					out.write_string(cell.char_.grapheme)
				}
				cursor_pos_col = session_u16_add(col, w)
				cursor_pos_row = row
			}
			cursor_style = cell.style
			link = cell.link
		}
		mut j := session_usize_add(i, 1)
		for j < session_usize_add(i, uint(w)) {
			if j >= uint(vx.screen_last.buf.len) {
				break
			}
			vx.screen_last.buf[int(j)].skipped = true
			j = session_usize_add(j, 1)
		}
		col = session_u16_add(col, w)
		i = session_usize_add(i, uint(w))
	}
	if vx.screen.cursor_vis {
		if vx.state.alt_screen {
			out.write_string('\x1b[${session_u16_add(vx.screen.cursor_row, 1)};${session_u16_add(vx.screen.cursor_col,
				1)}H')
		} else {
			out.write_u8(`\r`)
			if vx.screen.cursor_row >= cursor_pos_row {
				for _ in 0 .. int(session_u16_sub(vx.screen.cursor_row, cursor_pos_row)) {
					out.write_u8(`\n`)
				}
			} else {
				for _ in 0 .. int(session_u16_sub(cursor_pos_row, vx.screen.cursor_row)) {
					out.write_string('\x1bM')
				}
			}
			if vx.screen.cursor_col > 0 {
				out.write_string('\x1b[${vx.screen.cursor_col}C')
			}
		}
		vx.state.cursor.row = vx.screen.cursor_row
		vx.state.cursor.col = vx.screen.cursor_col
		out.write_string('\x1b[?25h')
	} else {
		vx.state.cursor.row = cursor_pos_row
		vx.state.cursor.col = cursor_pos_col
	}
	if vx.screen.mouse_shape != vx.screen_last.mouse_shape {
		out.write_string('\x1b]22;${session_mouse_shape_name(vx.screen.mouse_shape)}\x1b\\')
		vx.screen_last.mouse_shape = vx.screen.mouse_shape
	}
	if vx.screen.cursor_shape != vx.screen_last.cursor_shape {
		out.write_string('\x1b[${u8(vx.screen.cursor_shape)} q')
		vx.screen_last.cursor_shape = vx.screen.cursor_shape
	}
	out.write_string('\x1b[?2026l')
	return out.str()
}

fn render_image_placement(img ImagePlacement) string {
	mut out := strings.new_builder(80)
	out.write_string('\x1b_Ga=p,i=${img.img_id}')
	if offset := img.options.pixel_offset {
		out.write_string(',X=${offset.x},Y=${offset.y}')
	}
	if clip := img.options.clip_region {
		if x := clip.x { out.write_string(',x=${x}') }
		if y := clip.y { out.write_string(',y=${y}') }
		if width := clip.width { out.write_string(',w=${width}') }
		if height := clip.height { out.write_string(',h=${height}') }
	}
	if size := img.options.size {
		if rows := size.rows { out.write_string(',r=${rows}') }
		if cols := size.cols { out.write_string(',c=${cols}') }
	}
	if z := img.options.z_index { out.write_string(',z=${z}') }
	out.write_string(',C=1\x1b\\')
	return out.str()
}

fn render_color(color Color, channel int, sgr SgrMode, workarounds bool) string {
	base := match channel {
		0 { 30 }
		1 { 40 }
		else { 0 }
	}

	return match color {
		ColorDefault {
			'\x1b[${match channel {
				0 { 39 }
				1 { 49 }
				else { 59 }
			}}m'
		}
		ColorIndex {
			idx := color.index
			if channel != 2 && idx <= 7 {
				'\x1b[${base + int(idx)}m'
			} else if channel != 2 && idx <= 15 {
				'\x1b[${base + 60 + int(idx) - 8}m'
			} else {
				prefix := match channel {
					0 { 38 }
					1 { 48 }
					else { 58 }
				}

				if sgr == .standard {
					'\x1b[${prefix}:5:${idx}m'
				} else {
					'\x1b[${prefix};5;${idx}m'
				}
			}
		}
		ColorRgb {
			rgb := color.rgb
			prefix := match channel {
				0 { 38 }
				1 { 48 }
				else { 58 }
			}

			if channel == 2 && workarounds {
				'\x1b[58:2::${rgb[0]}:${rgb[1]}:${rgb[2]}m'
			} else if sgr == .standard {
				'\x1b[${prefix}:2:${rgb[0]}:${rgb[1]}:${rgb[2]}m'
			} else {
				'\x1b[${prefix};2;${rgb[0]};${rgb[1]};${rgb[2]}m'
			}
		}
	}
}

fn render_style_delta(before Style, after Style, sgr SgrMode, workarounds bool) string {
	mut out := strings.new_builder(96)
	if !before.fg.eql(after.fg) { out.write_string(render_color(after.fg, 0, sgr, workarounds)) }
	if !before.bg.eql(after.bg) { out.write_string(render_color(after.bg, 1, sgr, workarounds)) }
	if !before.ul.eql(after.ul) { out.write_string(render_color(after.ul, 2, sgr, workarounds)) }
	if before.ul_style != after.ul_style {
		out.write_string(match after.ul_style {
			.off { '\x1b[24m' }
			.single { '\x1b[4m' }
			.double_ { '\x1b[4:2m' }
			.curly { '\x1b[4:3m' }
			.dotted { '\x1b[4:4m' }
			.dashed { '\x1b[4:5m' }
		})
	}
	if before.bold != after.bold {
		out.write_string(if after.bold { '\x1b[1m' } else { '\x1b[22m' })
		if after.dim { out.write_string('\x1b[2m') }
	}
	if before.dim != after.dim {
		out.write_string(if after.dim { '\x1b[2m' } else { '\x1b[22m' })
		if after.bold { out.write_string('\x1b[1m') }
	}
	if before.italic != after.italic {
		out.write_string(if after.italic { '\x1b[3m' } else { '\x1b[23m' })
	}
	if before.blink != after.blink {
		out.write_string(if after.blink { '\x1b[5m' } else { '\x1b[25m' })
	}
	if before.reverse != after.reverse {
		out.write_string(if after.reverse { '\x1b[7m' } else { '\x1b[27m' })
	}
	if before.invisible != after.invisible {
		out.write_string(if after.invisible { '\x1b[8m' } else { '\x1b[28m' })
	}
	if before.strikethrough != after.strikethrough {
		out.write_string(if after.strikethrough { '\x1b[9m' } else { '\x1b[29m' })
	}
	return out.str()
}
