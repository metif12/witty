module vaxis

fn test_terminal_screen_print_styles_and_cursor() {
	mut screen := TerminalScreen.new(4, 2) or { panic(err) }
	screen.cursor.uri = 'x'
	screen.sgr(TerminalCsi{ params: '1;38;2;3;4;5'.bytes(), final: `m` })
	screen.print('a', 1, true) or { panic(err) }
	assert screen.buf[0].char_ == 'a'
	assert screen.buf[0].style.bold
	assert screen.buf[0].style.fg == Color(ColorRgb{
		rgb: [u8(3), 4, 5]!
	})
	assert screen.cursor.col == 1
	screen.deinit()
}

fn test_terminal_screen_pending_wrap_and_print_metadata() {
	mut screen := TerminalScreen.new(3, 2) or { panic(err) }
	screen.cursor.col = 2
	screen.cursor.uri = 'link'
	screen.buf[2].wrapped = true
	screen.print('界', 2, true) or { panic(err) }
	assert screen.cursor.col == 4
	assert screen.cursor.pending_wrap
	assert screen.buf[2].wrapped
	assert screen.buf[2].uri == 'link'
	screen.print('x', 1, false) or { panic(err) }
	assert screen.cursor.row == 1
	assert screen.cursor.col == 1
	assert !screen.cursor.pending_wrap
	assert screen.buf[3].char_ == 'x'
	screen.deinit()
}

fn test_terminal_screen_character_deletion_preserves_source_first_row_indexing() {
	mut screen := TerminalScreen.new(3, 2) or { panic(err) }
	for i, byte in 'abcdef'.bytes() {
		screen.buf[i].char_ = byte.ascii_str().clone()
	}
	screen.cursor.row = 1
	screen.cursor.col = 1
	screen.delete_characters(1) or { panic(err) }
	assert screen.buf[1].char_ == 'c'
	assert screen.buf[2].char_ == ' '
	assert screen.buf[3].char_ == 'd'
	assert screen.buf[4].char_ == 'e'
	assert screen.buf[5].char_ == 'f'
	screen.deinit()
}

fn test_terminal_screen_dirty_copy_preserves_destination_uri_wrap_and_dirty_fields() {
	mut screen := TerminalScreen.new(2, 2) or { panic(err) }
	mut destination := TerminalScreen.new(2, 2) or { panic(err) }
	for i in 0 .. screen.buf.len {
		screen.buf[i].dirty = false
	}
	screen.buf[0] = TerminalScreenCell{
		char_:   's'
		style:   Style{
			bold: true
		}
		uri:     'source'
		uri_id:  'source-id'
		width:   2
		wrapped: true
		dirty:   true
	}
	destination.buf[0].uri = 'keep'
	destination.buf[0].uri_id = 'keep-id'
	destination.buf[0].dirty = false
	screen.cursor.uri = 'cursor'
	screen.copy_to(mut destination) or { panic(err) }
	assert destination.buf[0].char_ == 's'
	assert destination.buf[0].style.bold
	assert destination.buf[0].width == 2
	assert destination.buf[0].uri == 'keep'
	assert destination.buf[0].uri_id == 'keep-id'
	assert !destination.buf[0].wrapped
	assert !destination.buf[0].dirty
	assert !screen.buf[0].dirty
	assert destination.cursor.uri == 'cursor'
	screen.deinit()
	destination.deinit()
}

fn test_terminal_screen_self_cell_copy_clears_text_and_uri_in_source_order() {
	mut screen := TerminalScreen.new(2, 2) or { panic(err) }
	screen.buf[0] = TerminalScreenCell{
		char_:   'abc'
		uri:     'uri'
		uri_id:  'id'
		width:   2
		wrapped: true
		dirty:   false
		style:   Style{
			bold: true
		}
	}
	screen.buf[0].copy_from(screen.buf[0]) or { panic(err) }
	assert screen.buf[0].char_ == ''
	assert screen.buf[0].uri == ''
	assert screen.buf[0].uri_id == ''
	assert screen.buf[0].width == 2
	assert screen.buf[0].wrapped
	assert screen.buf[0].dirty
	assert screen.buf[0].style.bold
	screen.deinit()
}

fn test_terminal_screen_scrolling_early_returns_and_saved_cursor() {
	mut screen := TerminalScreen.new(4, 4) or { panic(err) }
	screen.scrolling_region = TerminalScrollingRegion{
		top:    1
		bottom: 3
		left:   1
		right:  2
	}
	screen.cursor.pending_wrap = true
	screen.delete_line(1) or { panic(err) }
	assert screen.cursor.pending_wrap
	screen.insert_line(1) or { panic(err) }
	assert !screen.cursor.pending_wrap
	screen.cursor_down(100)
	assert screen.cursor.row == 3
	screen.cursor_right(1)
	assert screen.cursor.col == 1
	screen.cursor_up(10)
	assert screen.cursor.row == 1
	screen.cursor.pending_wrap = true
	screen.scroll_down(1) or { panic(err) }
	assert screen.cursor.row == 1
	assert screen.cursor.col == 1
	assert screen.cursor.pending_wrap
	screen.deinit()
}

fn test_terminal_screen_read_cell_retains_source_equal_width_boundary() {
	mut screen := TerminalScreen.new(2, 2) or { panic(err) }
	screen.buf[2].char_ = 'next row'
	cell := screen.read_cell(2, 0) or { panic('missing source boundary cell') }
	assert cell.char_.grapheme == 'next row'
	assert screen.read_cell(3, 0) == none
	screen.deinit()
}

fn test_terminal_screen_required_region_literal_and_source_defaults() {
	region := TerminalScrollingRegion{
		top:    0
		bottom: 1
		left:   0
		right:  1
	}
	screen := TerminalScreen{
		scrolling_region: region
	}
	assert screen.width == 0
	assert screen.height == 0
	assert screen.scrolling_region == region
	assert screen.csi_u_flags.int() == 0
}
