module vaxis

fn test_widget_view_and_buffer_smoke() {
	mut view := View.init(ViewConfig{ width: 8, height: 2 })
	view.clear()
	assert (view.read_cell(0, 0) or { panic('cell') }).default_
	view.print_segment(CellSegment{ text: 'abc' }, PrintOptions{})
	mut buffer := TextViewBuffer{}
	buffer.content = 'aé👩‍💻\n'
	buffer.grapheme = [TextViewGrapheme{ len: 1, offset: 0 },
		TextViewGrapheme{ len: 2, offset: 1 }, TextViewGrapheme{ len: 11, offset: 3 },
		TextViewGrapheme{ len: 1, offset: 14 }]
	buffer.rows = 1
	buffer.cols = 4
	mut text := TextView{}
	text.draw(view.window(), buffer)
	assert (view.read_cell(2, 0) or { panic('cell') }).char_.grapheme == '👩‍💻'
}

fn test_view_copies_retained_cells_and_bounds_render_origin() {
	mut source := View.init(ViewConfig{ width: 5, height: 3 })
	source.fill(Cell{
		char_:   CellCharacter{
			grapheme: 'x'
			width:    2
		}
		wrapped: true
		scale:   CellScale.init(2, 3, 4, .center)
		image:   ImagePlacement{
			img_id:  7
			options: ImageDrawOptions{}
		}
		link:    CellHyperlink{
			uri:    'u'
			params: 'p'
		}
	})
	source.write_cell(3, 1, Cell{
		char_: CellCharacter{
			grapheme: 'y'
		}
		style: Style{
			bold: true
		}
	})
	mut screen := Screen.new(Winsize{ cols: 2, rows: 2 })
	win := Window.new(&screen)
	x, y := source.to_win(win, ViewRenderConfig{ x: 65535, y: 65535 }) or { panic(err) }
	assert x == 3 && y == 1
	assert screen.buf[0].char_.grapheme == 'y' && screen.buf[0].style.bold
	assert screen.buf[1].scale.eql(CellScale.init(2, 3, 4, .center))
	assert (screen.buf[1].image or { panic('image') }).img_id == 7
	assert screen.buf[1].char_.grapheme == 'x' && screen.buf[1].wrapped
		&& screen.buf[1].link.params == 'p'
	source.clear()
	for cell in source.screen.buf {
		assert cell.default_ && cell.char_.grapheme == ' '
	}
}

fn test_line_numbers_retains_source_digit_limits_and_highlight_fill_order() {
	assert LineNumbers.num_digits(0) == 1 && LineNumbers.num_digits(99999999) == 8
	assert LineNumbers.num_digits(100000000) == 0
	assert LineNumbers.extract_digit(~usize(0), 19) == 1
	mut screen := Screen.new(Winsize{ cols: 6, rows: 3 })

	LineNumbers{
		num_lines:        4
		highlighted_line: 2
	}.draw(Window.new(&screen), 0)
	assert screen.buf[4].char_.grapheme == '1'
	assert screen.buf[10].char_.grapheme == ' '
	assert screen.buf[8].style.bg.eql(ColorIndex{ index: 0 })
	assert screen.buf[16].char_.grapheme == '3'
}

fn test_text_view_styles_deduplicate_and_use_grapheme_start_bytes() {
	mut buffer := TextViewBuffer{
		content:   'éx\nz'
		grapheme:  [TextViewGrapheme{ offset: 0, len: 3 }, TextViewGrapheme{ offset: 3, len: 1 },
			TextViewGrapheme{ offset: 4, len: 1 }, TextViewGrapheme{ offset: 5, len: 1 }]
		rows:      1
		cols:      2
		last_cols: 1
	}
	buffer.update_style(TextViewBufferStyle{
		begin: 1
		end:   3
		style: Style{
			bold: true
		}
	}) or { panic(err) }
	buffer.update_style(TextViewBufferStyle{
		begin: 3
		end:   4
		style: Style{
			bold: true
		}
	}) or { panic(err) }
	assert buffer.style_list.len == 1 && buffer.style_map.len == 3
	adapter := buffer.writer()
	assert adapter.buffer == &buffer && adapter.writer().buffer == &buffer
	mut screen := Screen.new(Winsize{ cols: 4, rows: 2 })
	screen.width_method = .unicode
	mut view := TextView{
		scroll_view: ScrollView{
			vertical_scrollbar: none
		}
	}
	view.draw(Window.new(&screen), buffer)
	assert screen.buf[0].char_.grapheme == 'é' && !screen.buf[0].style.bold
	assert screen.buf[1].char_.grapheme == 'x' && screen.buf[1].style.bold
	assert screen.buf[4].char_.grapheme == 'z'
	buffer.clear()
	assert buffer.content == '' && buffer.grapheme.len == 0 && buffer.style_map.len == 0
		&& buffer.rows == 0
}

fn test_code_view_runnable_defaults_and_input() {
	mut view := CodeView{}
	assert view.scroll_view.vertical_scrollbar == none
	assert view.indentation_cell.char_.grapheme == '┆' && view.indentation_cell.style.dim
	view.input(Key{ codepoint: page_down })
	assert view.scroll_view.scroll.y == 32
}
