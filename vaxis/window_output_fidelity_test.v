module vaxis

fn test_window_print_borrows_graphemes_in_all_wrap_modes() {
	for wrap in [PrintWrap.grapheme, .word, .none] {
		mut bytes := 'a b'.bytes()
		text := unsafe { tos(bytes.data, bytes.len) }
		mut screen := Screen.new(Winsize{ cols: 5, rows: 2 })
		result := Window.new(&screen).print_segment(CellSegment{ text: text }, PrintOptions{
			wrap: wrap
		})
		assert result.col == 3 && result.row == 0 && !result.overflow
		assert screen.buf[0].char_.grapheme.str == text.str
		assert screen.buf[2].char_.grapheme.str == unsafe { text.str + 2 }
		bytes[0] = `Z`
		bytes[2] = `Q`
		assert screen.buf[0].char_.grapheme == 'Z'
		assert screen.buf[2].char_.grapheme == 'Q'
	}
}

fn test_window_full_width_fill_retains_source_negative_row_behavior() {
	mut screen := Screen.new(Winsize{ cols: 2, rows: 3 })

	Window{
		x_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        2
		height:       2
		y_off:        -1
		screen:       &screen
	}.fill(Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	// Source uses height rows from the clamped start in its contiguous path.
	assert screen.buf[0].char_.grapheme == 'x'
	assert screen.buf[3].char_.grapheme == 'x'
	assert screen.buf[4].char_.grapheme == ' '
}

fn test_window_fill_keeps_usize_products_before_buffer_clamping() {
	mut screen := Screen{
		width:  65535
		height: 65535
	}

	Window{
		x_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        65535
		height:       0
		y_off:        65535
		screen:       &screen
	}.clear()

	Window{
		x_off:        0
		y_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        65535
		height:       65535
		screen:       &screen
	}.clear()
	assert screen.buf.len == 0
}

fn test_window_fill_left_clip_short_circuits_vertical_overflow() {
	mut screen := Screen{
		width:  1
		height: 1
		buf:    [Cell{}]
	}
	before := screen.buf.clone()

	Window{
		parent_x_off: 0
		parent_y_off: 0
		width:        0
		height:       1
		x_off:        -1
		y_off:        65535
		screen:       &screen
	}.clear()
	assert screen.buf == before
}

fn test_window_unwrapped_columns_saturate_and_measurement_skips_writes() {
	mut screen := Screen{
		width_method: .unicode
	}
	window := Window{
		x_off:        0
		y_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        65535
		height:       1
		screen:       &screen
	}
	result := window.print_segment(CellSegment{ text: '界' }, PrintOptions{
		wrap:       .none
		col_offset: 65534
		commit:     false
	})
	assert result.col == 65535 && result.row == 0 && !result.overflow
	assert screen.buf.len == 0
}
