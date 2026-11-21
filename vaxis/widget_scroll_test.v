module vaxis

fn test_alignment_uses_source_half_sizes_and_window_clipping() {
	mut screen := Screen.new(Winsize{ cols: 16, rows: 8 })
	root := Window.new(&screen)
	centered := alignment_center(root, 5, 3)
	assert centered.x_off == 6 && centered.y_off == 3
	assert centered.width == 5 && centered.height == 3
	assert alignment_top_left(root, 30, 30).width == 16
	assert alignment_top_right(root, 5, 3).x_off == 11
	assert alignment_bottom_left(root, 5, 3).y_off == 5
	corner := alignment_bottom_right(root, 5, 3)
	assert corner.x_off == 11 && corner.y_off == 5
	clipped := root.child(WindowChildOptions{ x_off: -2, y_off: -1, width: 6, height: 5 })
	inside := alignment_center(clipped, 3, 3)
	assert inside.x_off == 0 && inside.y_off == 0
	assert inside.parent_x_off == 0 && inside.parent_y_off == 0
}

fn test_scrollbar_rounds_height_up_and_clips_at_window_edge() {
	mut screen := Screen.new(Winsize{ cols: 2, rows: 10 })
	win := Window.new(&screen)
	style := Style{
		fg:   ColorIndex{
			index: 3
		}
		bold: true
	}
	bar := Scrollbar{
		total:     8
		view_size: 3
		top:       2
		style:     style
	}
	bar.draw(win)
	for row in 0 .. 10 {
		cell := screen.read_cell(0, u16(row)) or { panic('cell') }
		if row >= 2 && row < 6 {
			assert cell.char_.grapheme == '▐' && cell.style.eql(style)
		} else {
			assert cell.char_.grapheme == ' '
		}
		assert (screen.read_cell(1, u16(row)) or { panic('cell') }).char_.grapheme == ' '
	}
	screen.clear()

	Scrollbar{
		total:     8
		view_size: 3
		top:       7
	}.draw(win)
	assert (screen.read_cell(0, 8) or { panic('cell') }).char_.grapheme == '▐'
	assert (screen.read_cell(0, 9) or { panic('cell') }).char_.grapheme == '▐'
	screen.clear()

	Scrollbar{
		total:     0
		view_size: 0
	}.draw(win)

	Scrollbar{
		total:     8
		view_size: 8
	}.draw(win)
	for cell in screen.buf {
		assert cell.char_.grapheme == ' '
	}
}

fn test_scroll_view_input_saturates_and_draw_restricts_before_content_io() {
	mut screen := Screen.new(Winsize{ cols: 6, rows: 4 })
	win := Window.new(&screen)
	mut view := ScrollView{
		scroll: ScrollViewScroll{
			x: ~uint(0)
			y: ~uint(0)
		}
	}
	view.input(Key{ codepoint: right, mods: Modifiers.from_int(1) })
	view.input(Key{ codepoint: down })
	assert view.scroll.x == ~uint(0) && view.scroll.y == ~uint(0)
	view.draw(win, ScrollViewContentSize{ cols: 12, rows: 10 })
	assert view.scroll == ScrollViewScroll{
		x: 7
		y: 6
	}
	bounds := view.bounds(win)
	assert bounds == ScrollViewBoundingBox{
		x1: 7
		y1: 6
		x2: 12
		y2: 10
	}
	assert bounds.below(5) && bounds.above(10)
	assert bounds.inside(7, 6) && !bounds.inside(12, 6)
	view.write_cell(win, 7, 6, Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	view.write_cell(win, 12, 6, Cell{
		char_: CellCharacter{
			grapheme: '!'
		}
	})
	assert (screen.read_cell(0, 0) or { panic('content') }).char_.grapheme == 'x'
	assert !view.bounds(win).inside(12, 6)
	assert (screen.read_cell(5, 0) or { panic('bar') }).style.eql(Style{
		fg: ColorIndex{
			index: 8
		}
	})
	assert (screen.read_cell(5, 3) or { panic('bar') }).char_.grapheme == '▐'
	view.input(Key{ codepoint: home })
	assert view.scroll.y == 0
	view.input(Key{ codepoint: left, mods: Modifiers.from_int(1) })
	assert view.scroll.x == 0
	view.input(Key{ codepoint: page_up })
	assert view.scroll.y == 0
	view.input(Key{ codepoint: page_down })
	assert view.scroll.y == 32
	view.input(Key{ codepoint: right, mods: Modifiers.from_int(4) })
	assert view.scroll.x == 0
}

fn test_scroll_view_custom_bar_width_retains_single_column_content_padding() {
	mut screen := Screen.new(Winsize{ cols: 5, rows: 4 })
	win := Window.new(&screen)
	mut view := ScrollView{
		vertical_scrollbar: ScrollViewVerticalScrollbar{
			character: CellCharacter{
				grapheme: 'X'
				width:    2
			}
			bg:        Style{
				dim: true
			}
		}
	}
	view.draw(win, ScrollViewContentSize{ cols: 2, rows: 8 })
	assert view.bounds(win).x2 == 4
	view.write_cell(win, 3, 0, Cell{
		char_: CellCharacter{
			grapheme: 'c'
		}
	})
	assert (screen.read_cell(3, 0) or { panic('content') }).char_.grapheme == 'c'
	cell := screen.read_cell(4, 0) or { panic('bar background') }
	assert cell.char_.grapheme == 'X' && cell.char_.width == 2 && cell.style.dim
	view.vertical_scrollbar = none
	assert view.bounds(win).x2 == 5
	view.write_cell(win, 4, 0, Cell{
		char_: CellCharacter{
			grapheme: 'r'
		}
	})
	assert (win.read_cell(4, 0) or { panic('content') }).char_.grapheme == 'r'
}
