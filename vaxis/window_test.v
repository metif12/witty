module vaxis

fn test_window_child_size_offsets_and_clipping() {
	mut screen := Screen.new(Winsize{ cols: 20, rows: 20 })
	root := Window.new(&screen)
	child := root.child(WindowChildOptions{ x_off: 10, y_off: 10, width: u16(21), height: u16(21) })
	assert child.width == 10
	assert child.height == 10
	assert child.x_off == 10
	assert child.y_off == 10
	nested := child.child(WindowChildOptions{ x_off: -4, y_off: -4 })
	assert nested.x_off == 6
	assert nested.y_off == 6
	assert nested.parent_x_off == -4
	assert nested.parent_y_off == -4
	assert nested.read_cell(0, 0) == none
	nested.write_cell(0, 0, Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	assert (screen.read_cell(6, 6) or { panic('missing cell') }).char_.grapheme == ' '
	nested.write_cell(4, 4, Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	assert (screen.read_cell(10, 10) or { panic('missing cell') }).char_.grapheme == 'x'
}

fn test_window_border_fill_and_cursor_contract() {
	mut screen := Screen.new(Winsize{ cols: 8, rows: 4 })
	root := Window.new(&screen)
	inside := root.child(WindowChildOptions{
		x_off:  1
		width:  u16(6)
		height: u16(4)
		border: WindowBorderOptions{
			where_: BorderAll{}
		}
	})
	assert inside.width == 4
	assert inside.height == 2
	assert inside.x_off == 2
	assert inside.y_off == 1
	assert (screen.read_cell(1, 0) or { panic('missing border') }).char_.grapheme == '╭'
	assert (screen.read_cell(6, 0) or { panic('missing border') }).char_.grapheme == '╮'
	assert (screen.read_cell(1, 3) or { panic('missing border') }).char_.grapheme == '╰'
	assert (screen.read_cell(6, 3) or { panic('missing border') }).char_.grapheme == '╯'
	inside.fill(Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	assert (screen.read_cell(2, 1) or { panic('missing fill') }).char_.grapheme == 'x'
	inside.clear()
	assert (screen.read_cell(2, 1) or { panic('missing clear') }).default_
	inside.show_cursor(3, 1)
	assert screen.cursor_vis
	assert screen.cursor_col == 5
	assert screen.cursor_row == 2
	inside.hide_cursor()
	assert !screen.cursor_vis
	inside.set_cursor_shape(.beam)
	assert screen.cursor_shape == .beam
}

fn test_window_width_and_mouse_use_source_screen_state() {
	mut screen := Screen.new(Winsize{ cols: 10, rows: 5 })
	root := Window.new(&screen)
	child := root.child(WindowChildOptions{ x_off: 2, y_off: 1, width: u16(4), height: u16(2) })
	assert child.gwidth('👩‍🚀') == 4
	screen.width_method = .unicode
	assert child.gwidth('👩‍🚀') == 2
	inside := Mouse{
		col:    3
		row:    2
		button: .left
	}
	assert child.has_mouse(inside) != none
	assert child.has_mouse(Mouse{ col: 6, row: 2, button: .left }) == none
}

fn test_window_print_grapheme_and_none_wrap_contract() {
	mut screen := Screen.new(Winsize{ cols: 4, rows: 2 })
	screen.width_method = .unicode
	win := Window.new(&screen)
	grapheme_opts := PrintOptions{
		commit: false
	}
	assert win.print_segment(CellSegment{ text: 'a' }, grapheme_opts) == PrintResult{
		overflow: false

		col: 1
		row: 0
	}
	assert win.print_segment(CellSegment{ text: 'abcd' }, grapheme_opts) == PrintResult{
		overflow: false

		col: 0
		row: 1
	}
	assert win.print_segment(CellSegment{ text: 'abcde' }, grapheme_opts) == PrintResult{
		overflow: false

		col: 1
		row: 1
	}
	assert win.print_segment(CellSegment{ text: 'abcdefgh' }, grapheme_opts) == PrintResult{
		overflow: false

		col: 0
		row: 2
	}
	assert win.print_segment(CellSegment{ text: 'abcdefghi' }, grapheme_opts) == PrintResult{
		col:      0
		row:      2
		overflow: true
	}
	assert win.print_segment(CellSegment{ text: '👩‍🚀x' }, grapheme_opts) == PrintResult{
		overflow: false

		col: 3
		row: 0
	}
	none_opts := PrintOptions{
		wrap:   .none
		commit: false
	}
	assert win.print_segment(CellSegment{ text: 'abcd' }, none_opts) == PrintResult{
		overflow: false

		col: 4
		row: 0
	}
	assert win.print_segment(CellSegment{ text: 'abcde' }, none_opts) == PrintResult{
		col:      4
		row:      0
		overflow: true
	}
	assert win.print_segment(CellSegment{ text: 'a\nb' }, none_opts) == PrintResult{
		col:      1
		row:      0
		overflow: true
	}
}

fn test_window_print_word_wrap_source_cases() {
	mut screen := Screen.new(Winsize{ cols: 4, rows: 2 })
	win := Window.new(&screen)
	opts := PrintOptions{
		wrap:   .word
		commit: false
	}
	assert win.print_segment(CellSegment{ text: 'a b' }, opts) == PrintResult{
		overflow: false

		col: 3
		row: 0
	}
	assert win.print_segment(CellSegment{ text: 'hello ti' }, opts) == PrintResult{
		overflow: false

		col: 0
		row: 2
	}
	assert win.print_segment(CellSegment{ text: 'he\n\n' }, opts) == PrintResult{
		overflow: false

		col: 0
		row: 2
	}
	assert win.print_segment(CellSegment{ text: 'not now' }, opts) == PrintResult{
		overflow: false

		col: 3
		row: 1
	}
	assert win.print_segment(CellSegment{ text: 'note now' }, opts) == PrintResult{
		overflow: false

		col: 3
		row: 1
	}
	assert win.print([
		CellSegment{ text: 'note ' },
		CellSegment{ text: 'now' },
	], opts) == PrintResult{
		overflow: false

		col: 3
		row: 1
	}
	mut committed := Screen.new(Winsize{ cols: 4, rows: 2 })
	committed_win := Window.new(&committed)
	committed_win.print_segment(CellSegment{ text: 'a\tb' }, PrintOptions{
		wrap: .word
	})
	assert (committed.read_cell(0, 0) or { panic('missing cell') }).char_.grapheme == 'a'
	assert (committed.read_cell(1, 0) or { panic('missing cell') }).char_.grapheme == ' '
}

fn test_window_scroll_moves_cells_and_clears_bottom() {
	mut screen := Screen.new(Winsize{ cols: 2, rows: 3 })
	win := Window.new(&screen)
	for row in 0 .. 3 {
		win.write_cell(0, u16(row), Cell{
			char_: CellCharacter{
				grapheme: '${row}'
			}
		})
	}
	win.scroll(1)
	assert (screen.read_cell(0, 0) or { panic('missing row') }).char_.grapheme == '1'
	assert (screen.read_cell(0, 1) or { panic('missing row') }).char_.grapheme == '2'
	assert (screen.read_cell(0, 2) or { panic('missing row') }).default_
	win.scroll(4)
	assert (screen.read_cell(0, 0) or { panic('missing row') }).char_.grapheme == '1'
}
