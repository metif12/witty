module vaxis

fn test_window_complete_manual_record_keeps_screen_borrow_and_size_snapshot() {
	mut screen := Screen.new(Winsize{ cols: 7, rows: 3, x_pixel: 0, y_pixel: 0 })
	value := Window{
		x_off:        -65536
		y_off:        65535
		parent_x_off: -1
		parent_y_off: 0
		width:        7
		height:       3
		screen:       &screen
	}
	screen.width = 13
	screen.height = 9
	assert value.x_off == -65536 && value.y_off == 65535
	assert value.parent_x_off == -1 && value.parent_y_off == 0
	assert value.width == 7 && value.height == 3
	assert value.screen == &screen
	assert value.screen.width == 13 && value.screen.height == 9
	result := PrintResult{
		col:      65535
		row:      65535
		overflow: false
	}
	assert result.col == 65535 && result.row == 65535 && !result.overflow
}

fn test_window_public_session_factory_supplies_all_required_fields() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.screen = Screen.new(Winsize{ cols: 3, rows: 2, x_pixel: 640, y_pixel: 480 })
	window := vx.window()
	assert window.x_off == 0 && window.y_off == 0
	assert window.parent_x_off == 0 && window.parent_y_off == 0
	assert window.width == 3 && window.height == 2
	assert window.screen == &vx.screen
	assert window.screen.width_pix == 640 && window.screen.height_pix == 480
	assert window.screen.buf.len == 6
	manual := Window.new(&vx.screen)
	assert manual == window
}

fn test_window_optional_records_keep_source_defaults() {
	child := WindowChildOptions{}
	assert child.x_off == 0 && child.y_off == 0
	assert child.width == none && child.height == none
	assert child.border.style == Style{}
	assert child.border.where_ is BorderNone
	assert child.border.glyphs is BorderSingleRounded
	locations := BorderLocations{}
	assert !locations.top && !locations.right && !locations.bottom && !locations.left
	options := PrintOptions{}
	assert options.row_offset == 0 && options.col_offset == 0
	assert options.wrap == .grapheme && options.commit
	explicit := WindowChildOptions{
		width:  u16(0)
		height: u16(0)
	}
	assert (explicit.width or { u16(1) }) == 0
	assert (explicit.height or { u16(1) }) == 0
}

fn test_window_custom_border_copies_array_headers_and_borrows_glyph_bytes() {
	mut bytes := 'tl'.bytes()
	mut glyphs := [unsafe { tos(bytes.data, bytes.len) }, 'h', 'tr', 'v', 'br', 'bl']!
	custom := BorderCustom{
		glyphs: glyphs
	}
	glyphs[0] = 'replacement'
	bytes[0] = `Z`
	assert custom.glyphs[0] == 'Zl'
	assert custom.glyphs[0].str == bytes.data
	assert custom.glyphs[1..] == ['h', 'tr', 'v', 'br', 'bl']
	assert glyphs[0] == 'replacement'
}

fn test_window_public_record_mutation_preserves_value_copies() {
	mut screen := Screen{}
	mut window := Window.new(&screen)
	old_window := window
	window.x_off = -1
	window.y_off = 1
	window.parent_x_off = -2
	window.parent_y_off = -3
	window.width = 11
	window.height = 12
	mut other := Screen{}
	window.screen = &other
	assert window.x_off == -1 && window.y_off == 1
	assert window.parent_x_off == -2 && window.parent_y_off == -3
	assert window.width == 11 && window.height == 12 && window.screen == &other
	assert old_window.x_off == 0 && old_window.width == 0 && old_window.screen == &screen
	mut result := PrintResult{
		col:      1
		row:      2
		overflow: false
	}
	old_result := result
	result.col = 3
	result.row = 4
	result.overflow = true
	assert result == PrintResult{
		col:      3
		row:      4
		overflow: true
	}
	assert old_result == PrintResult{
		col:      1
		row:      2
		overflow: false
	}
	mut child := WindowChildOptions{}
	old_child := child
	child.x_off = -7
	child.y_off = 9
	child.width = u16(0)
	child.height = u16(65535)
	child.border = WindowBorderOptions{
		style:  Style{
			bold: true
		}
		where_: BorderAll{}
		glyphs: BorderSingleSquare{}
	}
	assert child.x_off == -7 && child.y_off == 9
	assert (child.width or { u16(1) }) == 0
	assert (child.height or { u16(0) }) == 65535
	assert child.border.style.bold && child.border.where_ is BorderAll
	assert child.border.glyphs is BorderSingleSquare
	assert old_child.width == none && old_child.border.where_ is BorderNone
	mut locations := BorderLocations{}
	old_locations := locations
	locations.top = true
	locations.right = true
	locations.bottom = true
	locations.left = true
	assert locations.top && locations.right && locations.bottom && locations.left
	assert !old_locations.top && !old_locations.right && !old_locations.bottom
		&& !old_locations.left
	mut custom := BorderCustom{
		glyphs: ['0', '1', '2', '3', '4', '5']!
	}
	old_custom := custom
	custom.glyphs[0] = 'new'
	assert custom.glyphs[0] == 'new' && old_custom.glyphs[0] == '0'
	mut border := WindowBorderOptions{}
	old_border := border
	border.style = Style{
		bold: true
	}
	border.where_ = BorderAll{}
	border.glyphs = BorderSingleSquare{}
	assert border.style.bold && border.where_ is BorderAll
	assert border.glyphs is BorderSingleSquare
	assert !old_border.style.bold && old_border.where_ is BorderNone
	mut options := PrintOptions{}
	old_options := options
	options.row_offset = 17
	options.col_offset = 19
	options.wrap = .word
	options.commit = false
	assert options.row_offset == 17 && options.col_offset == 19
	assert options.wrap == .word && !options.commit
	assert old_options.row_offset == 0 && old_options.col_offset == 0
	assert old_options.wrap == .grapheme && old_options.commit
}
