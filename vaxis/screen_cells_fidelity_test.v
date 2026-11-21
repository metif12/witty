module vaxis

fn test_screen_cells_keep_borrowed_text_and_all_metadata() {
	mut data := 'abcURIid0'.bytes()
	mut s := Screen.new(Winsize{ cols: 1, rows: 1, x_pixel: 3, y_pixel: 4 })
	value := Cell{
		char_:    CellCharacter{
			grapheme: unsafe { tos(data.data, 3) }
			width:    2
		}
		link:     CellHyperlink{
			uri:    unsafe { tos(&u8(data.data) + 3, 3) }
			params: unsafe { tos(&u8(data.data) + 6, 3) }
		}
		style:    Style{
			fg:       ColorIndex{
				index: 123
			}
			bold:     true
			ul_style: .curly
		}
		image:    ImagePlacement{
			img_id:  9
			options: ImageDrawOptions{
				z_index: -4
				scale:   .fit
			}
		}
		default_: true
		wrapped:  true
		scale:    CellScale.init(7, 0, 15, .bottom)
	}
	s.write_cell(0, 0, value)
	read := s.read_cell(0, 0) or { panic('missing cell') }
	assert uint(read.char_.grapheme.str) == uint(data.data)
	assert uint(read.link.uri.str) == uint(data.data) + 3
	assert read.style.eql(value.style)
	assert read.char_.width == 2 && read.default_ && read.wrapped
	assert read.scale.eql(value.scale)
	assert (read.image or { panic('missing image') }).img_id == 9
	data[0] = 88
	data[3] = 89
	data[6] = 90
	assert read.char_.grapheme == 'Xbc'
	assert read.link.uri == 'YRI'
	assert read.link.params == 'Zd0'
	assert (s.read_cell(0, 0) or { panic('missing cell') }).char_.grapheme == 'Xbc'
}

fn test_screen_cells_clip_before_indexing_even_with_large_dimensions() {
	mut s := Screen{
		width:  65535
		height: 65535
		buf:    [Cell{}]
	}
	s.write_cell(0, 0, Cell{
		char_: CellCharacter{
			grapheme: 'a'
		}
	})
	assert (s.read_cell(0, 0) or { panic('missing cell') }).char_.grapheme == 'a'
	s.write_cell(65535, 65534, Cell{})
	s.write_cell(65534, 65535, Cell{})
	assert s.read_cell(65535, 65534) == none
	assert s.read_cell(65534, 65535) == none
	mut empty := Screen{
		width:  0
		height: 65535
	}
	empty.write_cell(0, 65534, Cell{})
	assert empty.read_cell(0, 65534) == none
}

fn test_screen_cells_clear_entire_backing_buffer_and_keep_screen_state() {
	mut backing := [Cell{
		char_: CellCharacter{
			grapheme: 'a'
		}
	}, Cell{ wrapped: true }]
	mut s := Screen{
		width:        1
		height:       1
		buf:          backing
		width_pix:    30
		height_pix:   40
		cursor_col:   65535
		cursor_row:   65535
		cursor_vis:   true
		width_method: .unicode
		cursor_shape: .beam
		mouse_shape:  .help
	}
	read := s.read_cell(0, 0) or { panic('missing cell') }
	s.clear()
	assert backing[0].char_.grapheme == ' '
	assert !backing[1].wrapped
	assert read.char_.grapheme == 'a'
	assert s.width == 1 && s.height == 1 && s.width_pix == 30 && s.height_pix == 40
	assert s.cursor_col == 65535 && s.cursor_row == 65535 && s.cursor_vis
	assert s.width_method == .unicode && s.cursor_shape == .beam && s.mouse_shape == .help
}

fn test_screen_cells_creation_defaults_and_zero_area_high_dimensions() {
	default := Screen{}
	assert default.buf.len == 0 && default.width == 0 && default.height == 0
	assert !default.cursor_vis && default.cursor_col == 0 && default.cursor_row == 0
	assert default.width_method == .wcwidth && default.mouse_shape == .default
	mut s := Screen.new(Winsize{ cols: 2, rows: 3, x_pixel: 10, y_pixel: 20 })
	for c in s.buf {
		assert c.char_.grapheme == ' ' && c.char_.width == 1
		assert c.style.eql(Style{}) && c.link.uri == '' && c.link.params == ''
		assert c.image == none && !c.default_ && !c.wrapped && c.scale.eql(CellScale{})
	}
	a := Screen.new(Winsize{ cols: 65535, rows: 0, x_pixel: 0, y_pixel: 65535 })
	b := Screen.new(Winsize{ cols: 0, rows: 65535, x_pixel: 65535, y_pixel: 0 })
	assert a.buf.len == 0 && a.width == 65535 && a.height == 0
	assert b.buf.len == 0 && b.width == 0 && b.height == 65535
}
