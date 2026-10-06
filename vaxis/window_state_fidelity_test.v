module vaxis

fn state_screen() Screen {
	mut screen := Screen.new(Winsize{ cols: 3, rows: 5 })
	for row in 0 .. 5 {
		for col in 0 .. 3 {
			screen.buf[row * 3 + col] = Cell{
				char_:   CellCharacter{
					grapheme: '${row}'
					width:    u8(col + 1)
				}
				style:   Style{
					fg:   ColorIndex{
						index: u8(row)
					}
					bold: true
				}
				link:    CellHyperlink{
					uri:    'row${row}'
					params: 'id=${col}'
				}
				wrapped: true
			}
		}
	}
	return screen
}

fn test_window_scroll_retains_source_absolute_row_limit_and_whole_cells() {
	mut screen := state_screen()
	win := Window{
		x_off:        1
		y_off:        1
		parent_x_off: 0
		parent_y_off: 0
		width:        1
		height:       3
		screen:       &screen
	}
	original := screen.buf[7]
	win.scroll(1)
	assert screen.buf[4] == original
	assert screen.buf[7] == original
	assert screen.buf[10].default_
	assert screen.buf[3].char_.grapheme == '1'
	assert screen.buf[9].char_.grapheme == '3'
}

fn test_window_scroll_ignores_parent_clipping_like_source() {
	mut screen := state_screen()
	win := Window{
		x_off:        1
		y_off:        0
		parent_x_off: -2
		parent_y_off: -2
		width:        1
		height:       3
		screen:       &screen
	}
	win.scroll(1)
	assert screen.buf[1].char_.grapheme == '1'
	assert screen.buf[4].char_.grapheme == '2'
	assert screen.buf[7].default_
}

fn test_window_scroll_over_height_returns_before_copy_and_clear() {
	mut screen := state_screen()
	before := screen.buf.clone()
	win := Window{
		x_off:        65535
		y_off:        65535
		parent_x_off: 65535
		parent_y_off: 65535
		width:        65535
		height:       1
		screen:       &screen
	}
	win.scroll(2)
	assert screen.buf == before
}

fn test_window_scroll_keeps_borrowed_graphemes_after_copy() {
	mut bytes := [u8(`a`), `b`, `c`]
	text := unsafe { tos(bytes.data, bytes.len) }
	mut screen := Screen.new(Winsize{ cols: 1, rows: 3 })
	for i in 0 .. 3 {
		screen.buf[i] = Cell{
			char_: CellCharacter{
				grapheme: text.substr_unsafe(i, i + 1)
			}
		}
	}
	Window.new(&screen).scroll(1)
	bytes[1] = `X`
	bytes[2] = `Y`
	assert screen.buf[0].char_.grapheme == 'X'
	assert screen.buf[1].char_.grapheme == 'Y'
	assert screen.buf[2].default_
}

fn test_window_mouse_returns_value_without_coordinate_normalization() {
	mut screen := Screen{}
	win := Window{
		x_off:        2
		y_off:        3
		parent_x_off: -65536
		parent_y_off: -65536
		width:        4
		height:       5
		screen:       &screen
	}
	mut event := Mouse{
		col:     4
		row:     6
		xoffset: 65535
		yoffset: 17
		button:  .button_11
		type_:   .drag
	}
	snapshot := win.has_mouse(event) or { panic('missing mouse') }
	event = Mouse{
		...event
		col: 99
	}
	assert snapshot.col == 4 && snapshot.row == 6
	assert snapshot.xoffset == 65535 && snapshot.yoffset == 17
	assert snapshot.button == .button_11 && snapshot.type_ == .drag
	assert win.has_mouse(Mouse{ col: 6, row: 6 }) == none
	assert win.has_mouse(Mouse{ col: 4, row: 8 }) == none
}

fn test_window_mouse_short_circuits_overflowing_endpoints() {
	mut screen := Screen{}
	mut win := Window{
		x_off:        65535
		y_off:        65535
		parent_x_off: 0
		parent_y_off: 0
		width:        1
		height:       1
		screen:       &screen
	}
	assert win.has_mouse(none) == none
	assert win.has_mouse(Mouse{ col: 0, row: 65535 }) == none
	win.x_off = 0
	assert win.has_mouse(Mouse{ col: 1, row: 65535 }) == none
	assert win.has_mouse(Mouse{ col: 0, row: 0 }) == none
}
