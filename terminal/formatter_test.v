module terminal

import strings

// Tests translated from Ghostty's src/terminal/formatter.zig.
//
// Like Ghostty, these build a real Terminal and feed it through
// `t.vt_stream()` / `s.next_slice(...)`, then format the terminal's real
// PageList pages. Ghostty's `std.Io.Writer.Allocating` builder maps to the
// returned string, `std.ArrayList(Coordinate)` point maps to `PointMap`, and
// `std.ArrayList(Pin)` pin maps to `PinMap`.

// Helper: Ghostty's `pages.pages.first.?`.
fn formatter_first_node(list &PageList) &PageNode {
	return list.pages.first or { panic('page list has no first page') }
}

// Helper: Ghostty's `pages.pages.last.?`.
fn formatter_last_node(list &PageList) &PageNode {
	return list.pages.last or { panic('page list has no last page') }
}

// Helper: Ghostty's `pages.pages.first == pages.pages.last`.
fn formatter_single_page(list &PageList) bool {
	return voidptr(formatter_first_node(list)) == voidptr(formatter_last_node(list))
}

// Helper: Ghostty's `pages.pin(.{ .<tag> = .{ .x = x, .y = y } }).?`.
fn formatter_pin(list &PageList, tag PointTag, x u16, y u32) Pin {
	return list.pin(Point.new(tag, Coordinate{ x: x, y: y })) or {
		panic('point is outside the page list')
	}
}

// Helper: Ghostty's `testing.expectEqual(Pin{ ... }, pin)`.
fn formatter_pin_eql(expected Pin, actual Pin) bool {
	return expected.eql(actual) && expected.garbage == actual.garbage
}

// Helper: Ghostty's `t.screens.active.cursor.hyperlink != null`.
fn formatter_cursor_has_hyperlink(screen &Screen) bool {
	if _ := screen.cursor.hyperlink_state {
		return true
	}
	return false
}

fn test_page_plain_single_line() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello, world'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	// Test our point map.
	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello, world'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 12

	// Verify our point map
	assert output.len == point_map.points.len
	for i in 0 .. output.len {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_plain_single_line_soft_wrapped_unwrapped() ! {
	mut t := Terminal.init(Options{ cols: 3, rows: 5 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello!'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, FormatOptions{
		emit:   .plain
		unwrap: true
	})

	// Test our point map.
	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output
	// Note: we don't test the trailing state, which may have bugs
	// with unwrap...
	output := formatter.format_with_state().output
	assert output == 'hello!'

	// Verify our point map
	assert output.len == point_map.points.len
	assert point_map.points[0] == Coordinate{
		x: 0
		y: 0
	}
	assert point_map.points[1] == Coordinate{
		x: 1
		y: 0
	}
	assert point_map.points[2] == Coordinate{
		x: 2
		y: 0
	}
	assert point_map.points[3] == Coordinate{
		x: 0
		y: 1
	}
	assert point_map.points[4] == Coordinate{
		x: 1
		y: 1
	}
	assert point_map.points[5] == Coordinate{
		x: 2
		y: 1
	}
}

fn test_page_plain_single_wide_char() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('1A⚡'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	// Test our point map.
	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Full string
	{
		point_map.points.clear()
		result := formatter.format_with_state()
		state := result.state
		output := result.output
		assert output == '1A⚡'
		assert state.rows == usize(page.size.rows)
		assert state.cells == usize(page.size.cols) - 4

		// Verify our point map
		assert output.len == point_map.points.len
		for i in 2 .. output.len {
			assert point_map.points[i] == Coordinate{
				x: 2
				y: 0
			}
		}
	}

	// Wide only (from start)
	{
		point_map.points.clear()

		formatter.start_x = 2
		result := formatter.format_with_state()
		state := result.state
		output := result.output
		assert output == '⚡'
		assert state.rows == usize(page.size.rows)
		assert state.cells == usize(page.size.cols) - 4

		// Verify our point map
		assert output.len == point_map.points.len
		for i in 0 .. output.len {
			assert point_map.points[i] == Coordinate{
				x: 2
				y: 0
			}
		}
	}

	// Wide only (from tail)
	{
		point_map.points.clear()

		formatter.start_x = 3
		result := formatter.format_with_state()
		state := result.state
		output := result.output
		assert output == '⚡'
		assert state.rows == usize(page.size.rows)
		assert state.cells == usize(page.size.cols) - 4

		// Verify our point map
		assert output.len == point_map.points.len
		for i in 0 .. output.len {
			assert point_map.points[i] == Coordinate{
				x: 2
				y: 0
			}
		}
	}
}

fn test_page_plain_single_wide_char_soft_wrapped_unwrapped() ! {
	mut t := Terminal.init(Options{ cols: 3, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('1A⚡'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)
	formatter.opts.unwrap = true

	// Test our point map.
	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Full string
	{
		point_map.points.clear()
		result := formatter.format_with_state()
		state := result.state
		output := result.output
		assert output == '1A⚡'
		assert state.rows == usize(page.size.rows) - 1
		assert state.cells == usize(page.size.cols) - 2

		// Verify our point map
		assert output.len == point_map.points.len
		for i in 2 .. output.len {
			assert point_map.points[i] == Coordinate{
				x: 0
				y: 1
			}
		}
	}

	// Full string (ending on spacer head)
	{
		point_map.points.clear()

		formatter.end_x = 2
		formatter.end_y = 0
		output := formatter.format_with_state().output
		formatter.end_x = none
		formatter.end_y = none

		assert output == '1A⚡'

		// Verify our point map
		assert output.len == point_map.points.len
		for i in 2 .. output.len {
			assert point_map.points[i] == Coordinate{
				x: 0
				y: 1
			}
		}
	}

	// Wide only (from start)
	{
		point_map.points.clear()

		formatter.start_x = 2
		result := formatter.format_with_state()
		state := result.state
		output := result.output
		assert output == '⚡'
		assert state.rows == usize(page.size.rows) - 1
		assert state.cells == usize(page.size.cols) - 2

		// Verify our point map
		assert output.len == point_map.points.len
		for i in 0 .. output.len {
			assert point_map.points[i] == Coordinate{
				x: 0
				y: 1
			}
		}
	}

	// Wide only (from tail)
	{
		point_map.points.clear()

		formatter.start_y = 1
		formatter.start_x = 1
		result := formatter.format_with_state()
		state := result.state
		output := result.output
		assert output == '⚡'
		assert state.rows == usize(page.size.rows) - 1
		assert state.cells == usize(page.size.cols) - 2

		// Verify our point map
		assert output.len == point_map.points.len
		for i in 0 .. output.len {
			assert point_map.points[i] == Coordinate{
				x: 0
				y: 1
			}
		}
	}
}

fn test_page_plain_multiline() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello\nworld'
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 0
	} // \n
	for i in 0 .. 5 {
		assert point_map.points[6 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_multiline_rectangle() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_x = 1
	formatter.end_x = 3
	formatter.rectangle = true

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'ell\norl'
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(0)

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 3 {
		assert point_map.points[i] == Coordinate{
			x: u16(i + 1)
			y: 0
		}
	}
	assert point_map.points[3] == Coordinate{
		x: 3
		y: 0
	} // \n
	for i in 0 .. 3 {
		assert point_map.points[4 + i] == Coordinate{
			x: u16(i + 1)
			y: 1
		}
	}
}

fn test_page_plain_multi_blank_lines() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\n\r\n\r\nworld'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello\n\n\nworld'
	assert state.rows == usize(page.size.rows) - 3
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 0
	} // \n after row 0
	assert point_map.points[6] == Coordinate{
		x: 0
		y: 1
	} // \n after blank row 1
	assert point_map.points[7] == Coordinate{
		x: 0
		y: 2
	} // \n after blank row 2
	for i in 0 .. 5 {
		assert point_map.points[8 + i] == Coordinate{
			x: u16(i)
			y: 3
		}
	}
}

fn test_page_plain_trailing_blank_lines() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld\r\n\r\n'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output. We expect there to be no trailing newlines because
	// we can't differentiate trailing blank lines as being meaningful because
	// the page formatter can't see the cursor position.
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello\nworld'
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 0
	} // \n
	for i in 0 .. 5 {
		assert point_map.points[6 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_trailing_whitespace() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello   \r\nworld   '.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output. We expect there to be no trailing newlines because
	// we can't differentiate trailing blank lines as being meaningful because
	// the page formatter can't see the cursor position.
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello\nworld'
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 0
	} // \n
	for i in 0 .. 5 {
		assert point_map.points[6 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_trailing_whitespace_no_trim() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello   \r\nworld  '.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, FormatOptions{
		emit: .plain
		trim: false
	})

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output. We expect there to be no trailing newlines because
	// we can't differentiate trailing blank lines as being meaningful because
	// the page formatter can't see the cursor position.
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello   \nworld  '
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(page.size.cols) - 7

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 8 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[8] == Coordinate{
		x: 7
		y: 0
	} // \n
	for i in 0 .. 7 {
		assert point_map.points[9 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_with_prior_trailing_state_rows() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)
	formatter.trailing_state = TrailingState{
		rows:  2
		cells: 0
	}

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == '\n\nhello'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	assert point_map.points[0] == Coordinate{
		x: 0
		y: 0
	} // \n first blank row
	assert point_map.points[1] == Coordinate{
		x: 0
		y: 1
	} // \n second blank row
	for i in 0 .. 5 {
		assert point_map.points[2 + i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_plain_with_prior_trailing_state_cells_no_wrapped_line() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)
	formatter.trailing_state = TrailingState{
		rows:  0
		cells: 3
	}

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// Blank cells are reset when row is not a wrap continuation
	assert output == 'hello'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_plain_with_prior_trailing_state_cells_with_wrap_continuation() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('world'.bytes())!

	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	last := formatter_last_node(pages)
	page := &last.data

	// Surgically modify the first row to be a wrap continuation
	mut row := page.get_row(0)
	row.wrap_continuation = true

	mut formatter := PageFormatter.init(page, FormatOptions{
		emit:   .plain
		unwrap: true
	})
	formatter.trailing_state = TrailingState{
		rows:  0
		cells: 3
	}

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// Blank cells are preserved when row is a wrap continuation with unwrap enabled
	assert output == '   world'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map - 3 spaces from prior trailing state + "world"
	assert output.len == point_map.points.len
	// The 3 blank cells can't go back beyond (0,0) so they all map to (0,0)
	assert point_map.points[0] == Coordinate{
		x: 0
		y: 0
	} // space
	assert point_map.points[1] == Coordinate{
		x: 0
		y: 0
	} // space
	assert point_map.points[2] == Coordinate{
		x: 0
		y: 0
	} // space
	for i in 0 .. 5 {
		assert point_map.points[3 + i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_plain_soft_wrapped_without_unwrap() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world test'.bytes())!

	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// Without unwrap, wrapped lines show as separate lines
	assert output == 'hello worl\nd test'
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(page.size.cols) - 6

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 10 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[10] == Coordinate{
		x: 9
		y: 0
	} // \n
	for i in 0 .. 6 {
		assert point_map.points[11 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_soft_wrapped_with_unwrap() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world test'.bytes())!

	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, FormatOptions{
		emit:   .plain
		unwrap: true
	})

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// With unwrap, wrapped lines are joined together
	assert output == 'hello world test'
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(page.size.cols) - 6

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 10 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	for i in 0 .. 6 {
		assert point_map.points[10 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_soft_wrapped_3_lines_without_unwrap() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world this is a test'.bytes())!

	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// Without unwrap, wrapped lines show as separate lines
	assert output == 'hello worl\nd this is\na test'
	assert state.rows == usize(page.size.rows) - 2
	assert state.cells == usize(page.size.cols) - 6

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 10 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[10] == Coordinate{
		x: 9
		y: 0
	} // \n
	for i in 0 .. 9 {
		assert point_map.points[11 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
	assert point_map.points[20] == Coordinate{
		x: 8
		y: 1
	} // \n
	for i in 0 .. 6 {
		assert point_map.points[21 + i] == Coordinate{
			x: u16(i)
			y: 2
		}
	}
}

fn test_page_plain_soft_wrapped_3_lines_with_unwrap() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world this is a test'.bytes())!

	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, FormatOptions{
		emit:   .plain
		unwrap: true
	})

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// With unwrap, wrapped lines are joined together
	assert output == 'hello world this is a test'
	assert state.rows == usize(page.size.rows) - 2
	assert state.cells == usize(page.size.cols) - 6

	// Verify point map - unwrapped text spans 3 rows
	assert output.len == point_map.points.len
	for i in 0 .. 10 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	for i in 0 .. 10 {
		assert point_map.points[10 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
	for i in 0 .. 6 {
		assert point_map.points[20 + i] == Coordinate{
			x: u16(i)
			y: 2
		}
	}
}

fn test_page_plain_start_y_subset() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld\r\ntest'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_y = 1

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'world\ntest'
	assert state.rows == usize(page.size.rows) - 2
	assert state.cells == usize(page.size.cols) - 4

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 1
	} // \n
	for i in 0 .. 4 {
		assert point_map.points[6 + i] == Coordinate{
			x: u16(i)
			y: 2
		}
	}
}

fn test_page_plain_end_y_subset() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld\r\ntest'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.end_y = 1

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello\nworld'
	assert state.rows == usize(1)
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 0
	} // \n
	for i in 0 .. 5 {
		assert point_map.points[6 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_start_y_and_end_y_range() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld\r\ntest\r\nfoo'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_y = 1
	formatter.end_y = 2

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'world\ntest'
	assert state.rows == usize(1)
	assert state.cells == usize(page.size.cols) - 4

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 1
	} // \n
	for i in 0 .. 4 {
		assert point_map.points[6 + i] == Coordinate{
			x: u16(i)
			y: 2
		}
	}
}

fn test_page_plain_start_y_out_of_bounds() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_y = 30

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == ''
	assert state.rows == usize(0)
	assert state.cells == usize(0)

	// Verify point map is empty
	assert point_map.points.len == 0
}

fn test_page_plain_end_y_greater_than_rows() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.end_y = 30

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// Should clamp to page.size.rows and work normally
	assert output == 'hello'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_plain_end_y_less_than_start_y() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_y = 5
	formatter.end_y = 2

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == ''
	assert state.rows == usize(0)
	assert state.cells == usize(0)

	// Verify point map is empty
	assert point_map.points.len == 0
}

fn test_page_plain_start_x_on_first_row_only() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_x = 6

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'world'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 11

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i + 6)
			y: 0
		}
	}
}

fn test_page_plain_end_x_on_last_row_only() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('first line\r\nsecond line\r\nthird line'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.end_y = 2
	formatter.end_x = 4

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'first line\nsecond line\nthird'
	assert state.rows == usize(1)
	assert state.cells == usize(0)

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 10 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	assert point_map.points[10] == Coordinate{
		x: 9
		y: 0
	} // \n
	for i in 0 .. 11 {
		assert point_map.points[11 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
	assert point_map.points[22] == Coordinate{
		x: 10
		y: 1
	} // \n
	for i in 0 .. 5 {
		assert point_map.points[23 + i] == Coordinate{
			x: u16(i)
			y: 2
		}
	}
}

fn test_page_plain_start_x_and_end_x_multiline() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world\r\ntest case\r\nfoo bar'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_x = 6
	formatter.end_y = 2
	formatter.end_x = 2

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// First row: "world" (start_x=6 to end of row)
	// Second row: "test case" (full row)
	// Third row: "foo" (start to end_x=2, inclusive)
	assert output == 'world\ntest case\nfoo'
	assert state.rows == usize(1)
	assert state.cells == usize(0)

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i + 6)
			y: 0
		}
	}
	assert point_map.points[5] == Coordinate{
		x: 10
		y: 0
	} // \n
	for i in 0 .. 9 {
		assert point_map.points[6 + i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
	assert point_map.points[15] == Coordinate{
		x: 8
		y: 1
	} // \n
	for i in 0 .. 3 {
		assert point_map.points[16 + i] == Coordinate{
			x: u16(i)
			y: 2
		}
	}
}

fn test_page_plain_start_x_out_of_bounds() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_x = 100

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == ''
	assert state.rows == usize(0)
	assert state.cells == usize(0)

	// Verify point map is empty
	assert point_map.points.len == 0
}

fn test_page_plain_end_x_greater_than_cols() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.end_x = 100

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_plain_end_x_less_than_start_x_single_row() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_x = 10
	formatter.end_y = 0
	formatter.end_x = 5

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == ''
	assert state.rows == usize(0)
	assert state.cells == usize(0)

	// Verify point map is empty
	assert point_map.points.len == 0
}

fn test_page_plain_start_y_non_zero_ignores_trailing_state() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_y = 1
	formatter.trailing_state = TrailingState{
		rows:  5
		cells: 10
	}

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// Should NOT output the 5 newlines from trailing_state because start_y is non-zero
	assert output == 'world'
	assert state.rows == usize(page.size.rows) - 1
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 1
		}
	}
}

fn test_page_plain_start_x_non_zero_ignores_trailing_state() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_x = 6
	formatter.trailing_state = TrailingState{
		rows:  2
		cells: 8
	}

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// Should NOT output the 2 newlines or 8 spaces from trailing_state because start_x is non-zero
	assert output == 'world'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 11

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i + 6)
			y: 0
		}
	}
}

fn test_page_plain_start_y_and_start_x_zero_uses_trailing_state() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_plain)
	formatter.start_y = 0
	formatter.start_x = 0
	formatter.trailing_state = TrailingState{
		rows:  2
		cells: 0
	}

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	result := formatter.format_with_state()
	state := result.state
	output := result.output
	// SHOULD output the 2 newlines from trailing_state because both start_y and start_x are 0
	assert output == '\n\nhello'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 5

	// Verify point map
	assert output.len == point_map.points.len
	assert point_map.points[0] == Coordinate{
		x: 0
		y: 0
	} // \n first blank row
	assert point_map.points[1] == Coordinate{
		x: 0
		y: 1
	} // \n second blank row
	for i in 0 .. 5 {
		assert point_map.points[2 + i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_plain_single_line_with_styling() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello, \x1b[1mworld\x1b[0m'.bytes())!

	// Verify we have only a single page
	pages := &t.screens.active.pages
	assert pages.pages.first != none
	assert formatter_single_page(pages)

	// Create the formatter
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	// Verify output
	result := formatter.format_with_state()
	state := result.state
	output := result.output
	assert output == 'hello, world'
	assert state.rows == usize(page.size.rows)
	assert state.cells == usize(page.size.cols) - 12

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 12 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_vt_single_line_plain_text() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_vt)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == 'hello'

	// Verify point map
	assert output.len == point_map.points.len
	for i in 0 .. 5 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_vt_single_line_with_bold() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[1mhello\x1b[0m'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_vt)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == '\x1b[0m\x1b[1mhello\x1b[0m'

	// Verify point map - style sequences should point to first character they style
	assert output.len == point_map.points.len
	// \x1b[0m = 4 bytes, \x1b[1m = 4 bytes, total 8 bytes of style sequences
	// All style bytes should map to the first styled character at (0, 0)
	for i in 0 .. 8 {
		assert point_map.points[i] == Coordinate{
			x: 0
			y: 0
		}
	}
	// Then "hello" maps to its respective positions
	for i in 0 .. 5 {
		assert point_map.points[8 + i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_vt_multiple_styles() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[1mhello \x1b[3mworld\x1b[0m'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_vt)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == '\x1b[0m\x1b[1mhello \x1b[0m\x1b[1m\x1b[3mworld\x1b[0m'

	// Verify point map matches output length
	assert output.len == point_map.points.len
}

fn test_page_vt_with_foreground_color() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[31mred\x1b[0m'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_vt)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == '\x1b[0m\x1b[38;5;1mred\x1b[0m'

	// Verify point map - style sequences should point to first character they style
	assert output.len == point_map.points.len
	// \x1b[0m = 4 bytes, \x1b[38;5;1m = 9 bytes, total 13 bytes of style sequences
	// All style bytes should map to the first styled character at (0, 0)
	for i in 0 .. 13 {
		assert point_map.points[i] == Coordinate{
			x: 0
			y: 0
		}
	}
	// Then "red" maps to its respective positions
	for i in 0 .. 3 {
		assert point_map.points[13 + i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_vt_with_background_and_foreground_colors() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	formatter := PageFormatter.init(page, FormatOptions{
		emit:       .vt
		background: RGB{
			r: 0x12
			g: 0x34
			b: 0x56
		}
		foreground: RGB{
			r: 0xab
			g: 0xcd
			b: 0xef
		}
	})

	output := formatter.format()

	// Should emit OSC 10 for foreground, OSC 11 for background, then the text
	assert output == '\x1b]10;rgb:ab/cd/ef\x1b\\\x1b]11;rgb:12/34/56\x1b\\hello'
}

fn test_page_vt_multi_line_with_styles() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[1mfirst\x1b[0m\r\n\x1b[3msecond\x1b[0m'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_vt)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	// Note: style is reset before newline to prevent background colors from
	// bleeding to the next line's leading cells.
	assert output == '\x1b[0m\x1b[1mfirst\x1b[0m\r\n\x1b[0m\x1b[3msecond\x1b[0m'

	// Verify point map matches output length
	assert output.len == point_map.points.len
}

fn test_page_vt_duplicate_style_not_emitted_twice() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[1mhel\x1b[1mlo\x1b[0m'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_vt)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == '\x1b[0m\x1b[1mhello\x1b[0m'

	// Verify point map matches output length
	assert output.len == point_map.points.len
}

fn test_page_list_plain_single_line() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello, world'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(&t.screens.active.pages, format_plain)
	formatter.pin_map = &pin_map
	output := formatter.format()
	assert output == 'hello, world'

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert formatter_pin_eql(Pin{ node: node, x: u16(i), y: 0 }, pin_map.pins[i])
	}
}

fn test_page_list_plain_spanning_two_pages() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	pages := &t.screens.active.pages
	first_page_rows := formatter_first_node(pages).data.capacity.rows

	// Fill the first page almost completely
	for _ in 0 .. int(first_page_rows) - 1 {
		s.next_slice('\r\n'.bytes())!
	}
	s.next_slice('page one'.bytes())!

	// Verify we're still on one page
	assert formatter_single_page(pages)

	// Add one more newline to push content to a second page
	s.next_slice('\r\n'.bytes())!
	assert !formatter_single_page(pages)

	// Write content on the second page
	s.next_slice('page two'.bytes())!

	// Format the entire PageList
	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.pin_map = &pin_map
	full_output := formatter.format()
	output := full_output.trim_left('\n')
	assert output == 'page one\npage two'

	// Verify pin map
	assert full_output.len == pin_map.pins.len
	first_node := formatter_first_node(pages)
	last_node := formatter_last_node(pages)
	trimmed_count := full_output.len - output.len

	// First part (trimmed blank lines) maps to first node
	for i in 0 .. trimmed_count {
		assert voidptr(first_node) == voidptr(pin_map.pins[i].node)
	}

	// "page one" (8 chars) maps to first node
	for i in 0 .. 8 {
		idx := trimmed_count + i
		assert voidptr(first_node) == voidptr(pin_map.pins[idx].node)
		assert u16(i) == pin_map.pins[idx].x
	}

	// \n - maps to last node as it represents the transition to new page
	assert voidptr(last_node) == voidptr(pin_map.pins[trimmed_count + 8].node)

	// "page two" (8 chars) maps to last node
	for i in 0 .. 8 {
		idx := trimmed_count + 9 + i
		assert voidptr(last_node) == voidptr(pin_map.pins[idx].node)
		assert u16(i) == pin_map.pins[idx].x
	}
}

fn test_page_list_soft_wrapped_line_spanning_two_pages_without_unwrap() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 3 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	pages := &t.screens.active.pages
	first_page_rows := formatter_first_node(pages).data.capacity.rows

	// Fill the first page with soft-wrapped content
	for _ in 0 .. int(first_page_rows) - 1 {
		s.next_slice('\r\n'.bytes())!
	}
	s.next_slice('hello world test'.bytes())!

	// Verify we're on two pages due to wrapping
	assert !formatter_single_page(pages)

	// Format without unwrap - should show line breaks
	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.pin_map = &pin_map
	full_output := formatter.format()
	output := full_output.trim_left('\n')
	assert output == 'hello worl\nd test'

	// Verify pin map
	assert full_output.len == pin_map.pins.len
	first_node := formatter_first_node(pages)
	last_node := formatter_last_node(pages)
	trimmed_count := full_output.len - output.len

	// First part (trimmed blank lines) maps to first node
	for i in 0 .. trimmed_count {
		assert voidptr(first_node) == voidptr(pin_map.pins[i].node)
	}

	// First line maps to first node
	for i in 0 .. 10 {
		idx := trimmed_count + i
		assert voidptr(first_node) == voidptr(pin_map.pins[idx].node)
	}

	// \n - maps to last node as it represents the transition to new page
	assert voidptr(last_node) == voidptr(pin_map.pins[trimmed_count + 10].node)

	// "d test" (6 chars) maps to last node
	for i in 0 .. 6 {
		idx := trimmed_count + 11 + i
		assert voidptr(last_node) == voidptr(pin_map.pins[idx].node)
	}
}

fn test_page_list_soft_wrapped_line_spanning_two_pages_with_unwrap() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 3 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	pages := &t.screens.active.pages
	first_page_rows := formatter_first_node(pages).data.capacity.rows

	// Fill the first page with soft-wrapped content
	for _ in 0 .. int(first_page_rows) - 1 {
		s.next_slice('\r\n'.bytes())!
	}
	s.next_slice('hello world test'.bytes())!

	// Verify we're on two pages due to wrapping
	assert !formatter_single_page(pages)

	// Format with unwrap - should join the wrapped lines
	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, FormatOptions{
		emit:   .plain
		unwrap: true
	})
	formatter.pin_map = &pin_map
	full_output := formatter.format()
	output := full_output.trim_left('\r\n')
	assert output == 'hello world test'

	// Verify pin map
	assert full_output.len == pin_map.pins.len
	first_node := formatter_first_node(pages)
	last_node := formatter_last_node(pages)
	trimmed_count := full_output.len - output.len

	// First part (trimmed blank lines) maps to first node
	for i in 0 .. trimmed_count {
		assert voidptr(first_node) == voidptr(pin_map.pins[i].node)
	}

	// First line from first page
	for i in 0 .. 10 {
		idx := trimmed_count + i
		assert voidptr(first_node) == voidptr(pin_map.pins[idx].node)
	}

	// "d test" (6 chars) from last page
	for i in 0 .. 6 {
		idx := trimmed_count + 10 + i
		assert voidptr(last_node) == voidptr(pin_map.pins[idx].node)
	}
}

fn test_page_list_vt_spanning_two_pages() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	pages := &t.screens.active.pages
	first_page_rows := formatter_first_node(pages).data.capacity.rows

	// Fill the first page almost completely
	for _ in 0 .. int(first_page_rows) - 1 {
		s.next_slice('\r\n'.bytes())!
	}
	s.next_slice('\x1b[1mpage one'.bytes())!

	// Verify we're still on one page
	assert formatter_single_page(pages)

	// Add one more newline to push content to a second page
	s.next_slice('\r\n'.bytes())!
	assert !formatter_single_page(pages)

	// New content is still styled
	s.next_slice('page two'.bytes())!

	// Format the entire PageList with VT
	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, format_vt)
	formatter.pin_map = &pin_map
	full_output := formatter.format()
	output := full_output.trim_left('\r\n')
	assert output == '\x1b[0m\x1b[1mpage one\x1b[0m\r\n\x1b[0m\x1b[1mpage two\x1b[0m'

	// Verify pin map
	assert full_output.len == pin_map.pins.len
	first_node := formatter_first_node(pages)
	last_node := formatter_last_node(pages)

	// Just verify we have entries for both pages in the pin map
	mut first_count := usize(0)
	mut last_count := usize(0)
	for pin in pin_map.pins {
		if voidptr(pin.node) == voidptr(first_node) {
			first_count += 1
		}
		if voidptr(pin.node) == voidptr(last_node) {
			last_count += 1
		}
	}
	assert first_count > 0
	assert last_count > 0
}

fn test_page_list_plain_with_x_offset_on_single_page() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world\r\ntest case\r\nfoo bar'.bytes())!

	pages := &t.screens.active.pages
	node := formatter_first_node(pages)

	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.top_left = Pin{
		node: node
		y:    0
		x:    6
	}
	formatter.bottom_right = Pin{
		node: node
		y:    2
		x:    2
	}
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'world\ntest case\nfoo'

	// Verify pin map
	assert output.len == pin_map.pins.len
	for pin in pin_map.pins {
		assert voidptr(node) == voidptr(pin.node)
	}

	// "world" starts at x=6, y=0
	for i in 0 .. 5 {
		assert u16(6 + i) == pin_map.pins[i].x
		assert u16(0) == pin_map.pins[i].y
	}
}

fn test_page_list_plain_with_x_offset_spanning_two_pages() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	pages := &t.screens.active.pages
	first_page_rows := formatter_first_node(pages).data.capacity.rows

	// Fill first page almost completely
	for _ in 0 .. int(first_page_rows) - 1 {
		s.next_slice('\r\n'.bytes())!
	}
	s.next_slice('hello world'.bytes())!

	// Verify we're still on one page
	assert formatter_single_page(pages)

	// Push to second page
	s.next_slice('\r\n'.bytes())!
	assert !formatter_single_page(pages)

	s.next_slice('foo bar test'.bytes())!

	first_node := formatter_first_node(pages)
	last_node := formatter_last_node(pages)

	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.top_left = Pin{
		node: first_node
		y:    first_node.data.size.rows - 1
		x:    6
	}
	formatter.bottom_right = Pin{
		node: last_node
		y:    1
		x:    2
	}
	formatter.pin_map = &pin_map

	full_output := formatter.format()
	output := full_output.trim_left('\n')
	assert output == 'world\nfoo'

	// Verify pin map
	assert full_output.len == pin_map.pins.len
	trimmed_count := full_output.len - output.len

	// "world" (5 chars) from first page
	for i in 0 .. 5 {
		idx := trimmed_count + i
		assert voidptr(first_node) == voidptr(pin_map.pins[idx].node)
		assert u16(6 + i) == pin_map.pins[idx].x
	}

	// \n - maps to last node as it represents the transition to new page
	assert voidptr(last_node) == voidptr(pin_map.pins[trimmed_count + 5].node)

	// "foo" (3 chars) from last page
	for i in 0 .. 3 {
		idx := trimmed_count + 6 + i
		assert voidptr(last_node) == voidptr(pin_map.pins[idx].node)
		assert u16(i) == pin_map.pins[idx].x
	}
}

fn test_page_list_plain_with_start_x_only() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world'.bytes())!

	pages := &t.screens.active.pages
	node := formatter_first_node(pages)

	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.top_left = Pin{
		node: node
		y:    0
		x:    6
	}
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'world'

	// Verify pin map
	assert output.len == pin_map.pins.len
	for i in 0 .. 5 {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
		assert u16(6 + i) == pin_map.pins[i].x
		assert u16(0) == pin_map.pins[i].y
	}
}

fn test_page_list_plain_with_end_x_only() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world\r\ntest'.bytes())!

	pages := &t.screens.active.pages
	node := formatter_first_node(pages)

	mut pin_map := PinMap{}

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.bottom_right = Pin{
		node: node
		y:    1
		x:    2
	}
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'hello world\ntes'

	// Verify pin map
	assert output.len == pin_map.pins.len

	// "hello world" (11 chars) on y=0
	for i in 0 .. 11 {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
		assert u16(i) == pin_map.pins[i].x
		assert u16(0) == pin_map.pins[i].y
	}

	// \n
	assert voidptr(node) == voidptr(pin_map.pins[11].node)

	// "tes" (3 chars) on y=1
	for i in 0 .. 3 {
		assert voidptr(node) == voidptr(pin_map.pins[12 + i].node)
		assert u16(i) == pin_map.pins[12 + i].x
		assert u16(1) == pin_map.pins[12 + i].y
	}
}

fn test_page_list_plain_rectangle_basic() ! {
	mut t := Terminal.init(Options{ cols: 30, rows: 5 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('Lorem ipsum dolor\r\n'.bytes())!
	s.next_slice('sit amet, consectetur\r\n'.bytes())!
	s.next_slice('adipiscing elit, sed do\r\n'.bytes())!
	s.next_slice('eiusmod tempor incididunt\r\n'.bytes())!
	s.next_slice('ut labore et dolore'.bytes())!

	pages := &t.screens.active.pages

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.top_left = formatter_pin(pages, .screen, 2, 1)
	formatter.bottom_right = formatter_pin(pages, .screen, 6, 3)
	formatter.rectangle = true

	output := formatter.format()

	expected := 't ame\nipisc\nusmod'
	assert output == expected
}

fn test_page_list_plain_rectangle_with_eol() ! {
	mut t := Terminal.init(Options{ cols: 30, rows: 5 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('Lorem ipsum dolor\r\n'.bytes())!
	s.next_slice('sit amet, consectetur\r\n'.bytes())!
	s.next_slice('adipiscing elit, sed do\r\n'.bytes())!
	s.next_slice('eiusmod tempor incididunt\r\n'.bytes())!
	s.next_slice('ut labore et dolore'.bytes())!

	pages := &t.screens.active.pages

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.top_left = formatter_pin(pages, .screen, 12, 0)
	formatter.bottom_right = formatter_pin(pages, .screen, 26, 4)
	formatter.rectangle = true

	output := formatter.format()

	expected := 'dolor\nnsectetur\nlit, sed do\nor incididunt\n dolore'
	assert output == expected
}

fn test_page_list_plain_rectangle_more_complex_with_breaks() ! {
	mut t := Terminal.init(Options{ cols: 30, rows: 8 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('Lorem ipsum dolor\r\n'.bytes())!
	s.next_slice('sit amet, consectetur\r\n'.bytes())!
	s.next_slice('adipiscing elit, sed do\r\n'.bytes())!
	s.next_slice('eiusmod tempor incididunt\r\n'.bytes())!
	s.next_slice('ut labore et dolore\r\n'.bytes())!
	s.next_slice('\r\n'.bytes())!
	s.next_slice('magna aliqua. Ut enim\r\n'.bytes())!
	s.next_slice('ad minim veniam, quis'.bytes())!

	pages := &t.screens.active.pages

	mut formatter := PageListFormatter.init(pages, format_plain)
	formatter.top_left = formatter_pin(pages, .screen, 11, 2)
	formatter.bottom_right = formatter_pin(pages, .screen, 26, 7)
	formatter.rectangle = true

	output := formatter.format()

	expected := 'elit, sed do\npor incididunt\nt dolore\n\na. Ut enim\nniam, quis'
	assert output == expected
}

fn test_terminal_formatter_plain_no_selection() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld'.bytes())!

	formatter := TerminalFormatter.init(&t, format_plain)

	assert formatter.format() == 'hello\nworld'
}

fn test_terminal_formatter_vt_with_palette() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Modify some palette colors using VT sequences
	s.next_slice('\x1b]4;0;rgb:12/34/56\x1b\\'.bytes())!
	s.next_slice('\x1b]4;1;rgb:ab/cd/ef\x1b\\'.bytes())!
	s.next_slice('\x1b]4;255;rgb:ff/00/ff\x1b\\'.bytes())!
	s.next_slice('test'.bytes())!

	formatter := TerminalFormatter.init(&t, format_vt)

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify the palettes match
	assert t.colors.palette.current[0] == t2.colors.palette.current[0]
	assert t.colors.palette.current[1] == t2.colors.palette.current[1]
	assert t.colors.palette.current[255] == t2.colors.palette.current[255]
}

fn test_terminal_formatter_with_selection() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('line1\r\nline2\r\nline3'.bytes())!

	mut formatter := TerminalFormatter.init(&t, format_plain)
	formatter.content = ScreenContent(ScreenContentSelection{
		sel: Selection.init(formatter_pin(&t.screens.active.pages, .active, 0, 1),
			formatter_pin(&t.screens.active.pages, .active, 4, 1), false)
	})

	assert formatter.format() == 'line2'
}

fn test_terminal_formatter_plain_with_pin_map() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello, world'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := TerminalFormatter.init(&t, format_plain)
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'hello, world'

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert formatter_pin_eql(Pin{ node: node, x: u16(i), y: 0 }, pin_map.pins[i])
	}
}

fn test_terminal_formatter_plain_multiline_with_pin_map() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := TerminalFormatter.init(&t, format_plain)
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'hello\nworld'

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	// "hello" (5 chars)
	for i in 0 .. 5 {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
		assert u16(i) == pin_map.pins[i].x
		assert u16(0) == pin_map.pins[i].y
	}
	// "\n" maps to end of first line
	assert voidptr(node) == voidptr(pin_map.pins[5].node)
	// "world" (5 chars)
	for i in 0 .. 5 {
		idx := 6 + i
		assert voidptr(node) == voidptr(pin_map.pins[idx].node)
		assert u16(i) == pin_map.pins[idx].x
		assert u16(1) == pin_map.pins[idx].y
	}
}

fn test_terminal_formatter_vt_with_palette_and_pin_map() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Modify some palette colors using VT sequences
	s.next_slice('\x1b]4;0;rgb:12/34/56\x1b\\'.bytes())!
	s.next_slice('test'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.pin_map = &pin_map

	output := formatter.format()

	// Verify pin map - palette bytes should be mapped to top left
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
}

fn test_terminal_formatter_with_selection_and_pin_map() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('line1\r\nline2\r\nline3'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := TerminalFormatter.init(&t, format_plain)
	formatter.content = ScreenContent(ScreenContentSelection{
		sel: Selection.init(formatter_pin(&t.screens.active.pages, .active, 0, 1),
			formatter_pin(&t.screens.active.pages, .active, 4, 1), false)
	})
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'line2'

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	// "line2" (5 chars) from row 1
	for i in 0 .. 5 {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
		assert u16(i) == pin_map.pins[i].x
		assert u16(1) == pin_map.pins[i].y
	}
}

fn test_screen_plain_single_line() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello, world'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_plain)
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'hello, world'

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert formatter_pin_eql(Pin{ node: node, x: u16(i), y: 0 }, pin_map.pins[i])
	}
}

fn test_screen_plain_multiline() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_plain)
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'hello\nworld'

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	// "hello" (5 chars)
	for i in 0 .. 5 {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
		assert u16(i) == pin_map.pins[i].x
		assert u16(0) == pin_map.pins[i].y
	}
	// "\n" maps to end of first line
	assert voidptr(node) == voidptr(pin_map.pins[5].node)
	// "world" (5 chars)
	for i in 0 .. 5 {
		idx := 6 + i
		assert voidptr(node) == voidptr(pin_map.pins[idx].node)
		assert u16(i) == pin_map.pins[idx].x
		assert u16(1) == pin_map.pins[idx].y
	}
}

fn test_screen_plain_with_selection() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('line1\r\nline2\r\nline3'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_plain)
	formatter.content = ScreenContent(ScreenContentSelection{
		sel: Selection.init(formatter_pin(&t.screens.active.pages, .active, 0, 1),
			formatter_pin(&t.screens.active.pages, .active, 4, 1), false)
	})
	formatter.pin_map = &pin_map

	output := formatter.format()
	assert output == 'line2'

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	// "line2" (5 chars) from row 1
	for i in 0 .. 5 {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
		assert u16(i) == pin_map.pins[i].x
		assert u16(1) == pin_map.pins[i].y
	}
}

fn test_screen_vt_with_cursor_position() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Position cursor at a specific location
	s.next_slice('hello\r\nworld'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_vt)
	formatter.extra.set_cursor(true)
	formatter.pin_map = &pin_map

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify cursor positions match
	assert t.screens.active.cursor.x == t2.screens.active.cursor.x
	assert t.screens.active.cursor.y == t2.screens.active.cursor.y

	// Verify pin map - the extras should be mapped to the last pin
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	content_len := 'hello\r\nworld'.len
	// Content bytes map to their positions
	for i in 0 .. content_len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
	// Extra bytes (cursor position) map to last content pin
	for i in content_len .. output.len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
}

fn test_screen_vt_with_style() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set some style attributes
	s.next_slice('\x1b[1;31mhello'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_vt)
	formatter.extra.set_style(true)
	formatter.pin_map = &pin_map

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify styles match
	assert t.screens.active.cursor.style.eql(&t2.screens.active.cursor.style)

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
}

fn test_screen_vt_with_hyperlink() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set a hyperlink
	s.next_slice('\x1b]8;;http://example.com\x1b\\hello'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_vt)
	formatter.extra.set_hyperlink(true)
	formatter.pin_map = &pin_map

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify hyperlinks match
	has_link1 := formatter_cursor_has_hyperlink(t.screens.active)
	has_link2 := formatter_cursor_has_hyperlink(t2.screens.active)
	assert has_link1 == has_link2

	if has_link1 {
		link1 := t.screens.active.cursor.hyperlink_state or { panic('missing hyperlink') }
		link2 := t2.screens.active.cursor.hyperlink_state or { panic('missing hyperlink') }
		assert link1.uri == link2.uri
	}

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
}

fn test_screen_vt_with_protection() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Enable protection mode
	s.next_slice('\x1b[1"qhello'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_vt)
	formatter.extra.set_protection(true)
	formatter.pin_map = &pin_map

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify protection state matches
	assert t.screens.active.cursor.is_protected == t2.screens.active.cursor.is_protected

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
}

fn test_screen_vt_with_kitty_keyboard() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set kitty keyboard flags (disambiguate + report_events = 3)
	s.next_slice('\x1b[=3;1uhello'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_vt)
	formatter.extra.set_kitty_keyboard(true)
	formatter.pin_map = &pin_map

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify kitty keyboard state matches
	flags1 := t.screens.active.kitty_keyboard.current().int()
	flags2 := t2.screens.active.kitty_keyboard.current().int()
	assert flags1 == flags2

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
}

fn test_screen_vt_with_charsets() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set G0 to DEC special and shift to G1
	s.next_slice('\x1b(0\x0ehello'.bytes())!

	mut pin_map := PinMap{}

	mut formatter := ScreenFormatter.init(t.screens.active, format_vt)
	formatter.extra.set_charsets(true)
	formatter.pin_map = &pin_map

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify charset state matches
	assert t.screens.active.charset.gl == t2.screens.active.charset.gl
	assert t.screens.active.charset.gr == t2.screens.active.charset.gr
	assert t.screens.active.charset.charsets.get(.g0) == t2.screens.active.charset.charsets.get(.g0)

	// Verify pin map
	assert output.len == pin_map.pins.len
	node := formatter_first_node(&t.screens.active.pages)
	for i in 0 .. output.len {
		assert voidptr(node) == voidptr(pin_map.pins[i].node)
	}
}

fn test_terminal_vt_with_scrolling_region() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set scrolling region: top=5, bottom=20
	s.next_slice('\x1b[6;21rhello'.bytes())!

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra.set_scrolling_region(true)

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify scrolling regions match
	assert t.scrolling_region.top == t2.scrolling_region.top
	assert t.scrolling_region.bottom == t2.scrolling_region.bottom
	assert t.scrolling_region.left == t2.scrolling_region.left
	assert t.scrolling_region.right == t2.scrolling_region.right
}

fn test_terminal_vt_with_modes() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Enable some modes that differ from defaults
	s.next_slice('\x1b[?2004h'.bytes())! // Bracketed paste
	s.next_slice('\x1b[?1000h'.bytes())! // Mouse event normal
	s.next_slice('\x1b[?7l'.bytes())! // Disable wraparound (default is true)
	s.next_slice('hello'.bytes())!

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra.set_modes(true)

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify modes match
	assert t.modes.get(.bracketed_paste) == t2.modes.get(.bracketed_paste)
	assert t.modes.get(.mouse_event_normal) == t2.modes.get(.mouse_event_normal)
	assert t.modes.get(.wraparound) == t2.modes.get(.wraparound)
}

fn test_terminal_vt_with_tabstops() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Clear all tabs and set custom tabstops
	s.next_slice('\x1b[3g'.bytes())! // Clear all tabs
	s.next_slice('\x1b[5G\x1bH'.bytes())! // Set tab at column 5
	s.next_slice('\x1b[15G\x1bH'.bytes())! // Set tab at column 15
	s.next_slice('\x1b[30G\x1bH'.bytes())! // Set tab at column 30
	s.next_slice('hello'.bytes())!

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra.set_tabstops(true)

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify tabstops match (columns are 0-indexed in the API)
	assert t.tabstops.get(4) == t2.tabstops.get(4)
	assert t.tabstops.get(14) == t2.tabstops.get(14)
	assert t.tabstops.get(29) == t2.tabstops.get(29)
	assert t2.tabstops.get(4) // Column 5 (1-indexed)
	assert t2.tabstops.get(14) // Column 15 (1-indexed)
	assert t2.tabstops.get(29) // Column 30 (1-indexed)
	assert !t2.tabstops.get(8) // Not a tab
}

fn test_terminal_vt_with_keyboard_modes() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set modify other keys mode 2
	s.next_slice('\x1b[>4;2m'.bytes())!
	s.next_slice('hello'.bytes())!

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra.set_keyboard(true)

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify keyboard mode matches
	assert t.flags.modify_other_keys_2() == t2.flags.modify_other_keys_2()
	assert t2.flags.modify_other_keys_2()
}

fn test_terminal_vt_with_pwd() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set pwd using OSC 7
	s.next_slice('\x1b]7;file://host/home/user\x1b\\hello'.bytes())!

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra.set_pwd(true)

	output := formatter.format()

	// Create a second terminal and apply the output
	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t2.deinit()
	}

	mut s2 := t2.vt_stream()
	defer {
		s2.deinit()
	}

	s2.next_slice(output.bytes())!

	// Verify pwd matches
	assert t.pwd == t2.pwd
}

fn test_page_html_with_multiple_styles() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set bold, then italic, then reset
	s.next_slice('\x1b[1mbold\x1b[3mitalic\x1b[0mnormal'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, FormatOptions{ emit: .html })

	output := formatter.format()

	assert output == '<div style="font-family: monospace; white-space: pre;">' +
		'<div style="display: inline;font-weight: bold;">bold</div>' +
		'<div style="display: inline;font-weight: bold;font-style: italic;">italic</div>' +
		'normal' + '</div>'
}

fn test_page_html_plain_text() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello, world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, FormatOptions{ emit: .html })

	output := formatter.format()

	// Plain text without styles should be wrapped in monospace div
	assert output == '<div style="font-family: monospace; white-space: pre;">hello, world</div>'
}

fn test_page_html_with_colors() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set red foreground, blue background
	s.next_slice('\x1b[31;44mcolored'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, FormatOptions{ emit: .html })

	output := formatter.format()

	assert output == '<div style="font-family: monospace; white-space: pre;">' +
		'<div style="display: inline;color: var(--vt-palette-1);background-color: var(--vt-palette-4);">colored</div>' +
		'</div>'
}

fn test_terminal_formatter_html_with_palette() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Modify some palette colors
	s.next_slice('\x1b]4;0;rgb:12/34/56\x1b\\'.bytes())!
	s.next_slice('\x1b]4;1;rgb:ab/cd/ef\x1b\\'.bytes())!
	s.next_slice('\x1b]4;255;rgb:ff/00/ff\x1b\\'.bytes())!
	s.next_slice('test'.bytes())!

	mut formatter := TerminalFormatter.init(&t, FormatOptions{ emit: .html })
	formatter.extra.set_palette(true)

	output := formatter.format()

	// Verify palette CSS variables are emitted
	assert output.contains('<style>:root{')
	assert output.contains('--vt-palette-0: #123456;')
	assert output.contains('--vt-palette-1: #abcdef;')
	assert output.contains('--vt-palette-255: #ff00ff;')
	assert output.contains('}</style>')
	assert output.contains('test')
}

fn test_page_html_with_background_and_foreground_colors() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, FormatOptions{
		emit:       .html
		background: RGB{
			r: 0x12
			g: 0x34
			b: 0x56
		}
		foreground: RGB{
			r: 0xab
			g: 0xcd
			b: 0xef
		}
	})

	output := formatter.format()

	assert output == '<div style="font-family: monospace; white-space: pre;background-color: #123456;color: #abcdef;">hello</div>'
}

fn test_page_html_with_escaping() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('<tag>&"\'text'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, FormatOptions{ emit: .html })

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()

	assert output == '<div style="font-family: monospace; white-space: pre;">&lt;tag&gt;&amp;&quot;&#39;text</div>'

	// Verify point map length matches output
	assert output.len == point_map.points.len

	// Opening wrapper div
	wrapper_start := '<div style="font-family: monospace; white-space: pre;">'
	wrapper_start_len := wrapper_start.len
	for i in 0 .. wrapper_start_len {
		assert point_map.points[i] == Coordinate{
			x: 0
			y: 0
		}
	}

	// Verify each character maps correctly, accounting for escaping
	offset := wrapper_start_len
	// < (4 bytes: &lt;) -> x=0
	for i in 0 .. 4 {
		assert point_map.points[offset + i] == Coordinate{
			x: 0
			y: 0
		}
	}
	// t (1 byte) -> x=1
	assert point_map.points[offset + 4] == Coordinate{
		x: 1
		y: 0
	}
	// a (1 byte) -> x=2
	assert point_map.points[offset + 5] == Coordinate{
		x: 2
		y: 0
	}
	// g (1 byte) -> x=3
	assert point_map.points[offset + 6] == Coordinate{
		x: 3
		y: 0
	}
	// > (4 bytes: &gt;) -> x=4
	for i in 0 .. 4 {
		assert point_map.points[offset + 7 + i] == Coordinate{
			x: 4
			y: 0
		}
	}
	// & (5 bytes: &amp;) -> x=5
	for i in 0 .. 5 {
		assert point_map.points[offset + 11 + i] == Coordinate{
			x: 5
			y: 0
		}
	}
	// " (6 bytes: &quot;) -> x=6
	for i in 0 .. 6 {
		assert point_map.points[offset + 16 + i] == Coordinate{
			x: 6
			y: 0
		}
	}
	// ' (5 bytes: &#39;) -> x=7
	for i in 0 .. 5 {
		assert point_map.points[offset + 22 + i] == Coordinate{
			x: 7
			y: 0
		}
	}
	// t (1 byte) -> x=8
	assert point_map.points[offset + 27] == Coordinate{
		x: 8
		y: 0
	}
	// e (1 byte) -> x=9
	assert point_map.points[offset + 28] == Coordinate{
		x: 9
		y: 0
	}
	// x (1 byte) -> x=10
	assert point_map.points[offset + 29] == Coordinate{
		x: 10
		y: 0
	}
	// t (1 byte) -> x=11
	assert point_map.points[offset + 30] == Coordinate{
		x: 11
		y: 0
	}
}

fn test_page_html_with_unicode_as_numeric_entities() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Box drawing characters that caused issue #9426
	s.next_slice('╰─ ❯'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, FormatOptions{ emit: .html })

	output := formatter.format()

	// Expected: box drawing chars as numeric entities
	// ╰ = U+2570 = 9584, ─ = U+2500 = 9472, ❯ = U+276F = 10095
	assert output == '<div style="font-family: monospace; white-space: pre;">&#9584;&#9472; &#10095;</div>'
}

fn test_page_html_ascii_characters_unchanged() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, FormatOptions{ emit: .html })

	output := formatter.format()

	// ASCII should be emitted directly
	assert output == '<div style="font-family: monospace; white-space: pre;">hello world</div>'
}

fn test_page_html_mixed_ascii_and_unicode() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('test ╰─❯ ok'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, FormatOptions{ emit: .html })

	output := formatter.format()

	// Mix of ASCII and Unicode entities
	assert output == '<div style="font-family: monospace; white-space: pre;">test &#9584;&#9472;&#10095; ok</div>'
}

fn test_page_vt_with_palette_option_emits_rgb() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set a custom palette color and use it
	s.next_slice('\x1b]4;1;rgb:ab/cd/ef\x1b\\'.bytes())!
	s.next_slice('\x1b[31mred'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Without palette option - should emit palette index
	{
		formatter := PageFormatter.init(page, format_vt)
		output := formatter.format()
		assert output == '\x1b[0m\x1b[38;5;1mred\x1b[0m'
	}

	// With palette option - should emit RGB directly
	{
		opts := FormatOptions{
			emit:    .vt
			palette: t.colors.palette.current[..]
		}
		formatter := PageFormatter.init(page, opts)
		output := formatter.format()
		assert output == '\x1b[0m\x1b[38;2;171;205;239mred\x1b[0m'
	}
}

fn test_page_html_with_palette_option_emits_rgb() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set a custom palette color and use it
	s.next_slice('\x1b]4;1;rgb:ab/cd/ef\x1b\\'.bytes())!
	s.next_slice('\x1b[31mred'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Without palette option - should emit CSS variable
	{
		formatter := PageFormatter.init(page, FormatOptions{ emit: .html })
		output := formatter.format()
		assert output == '<div style="font-family: monospace; white-space: pre;">' +
			'<div style="display: inline;color: var(--vt-palette-1);">red</div>' + '</div>'
	}

	// With palette option - should emit RGB directly
	{
		opts := FormatOptions{
			emit:    .html
			palette: t.colors.palette.current[..]
		}
		formatter := PageFormatter.init(page, opts)
		output := formatter.format()
		assert output == '<div style="font-family: monospace; white-space: pre;">' +
			'<div style="display: inline;color: rgb(171, 205, 239);">red</div>' + '</div>'
	}
}

fn test_page_vt_style_reset_properly_closes_styles() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Set bold, then reset with SGR 0
	s.next_slice('\x1b[1mbold\x1b[0mnormal'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	formatter := PageFormatter.init(page, format_vt)
	output := formatter.format()

	// The reset should properly close the bold style
	assert output == '\x1b[0m\x1b[1mbold\x1b[0mnormal'
}

fn test_page_codepoint_map_single_replacement() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Replace 'o' with 'x'
	cp_map := [
		CodepointMap{
			range_start: u32(`o`)
			range_end:   u32(`o`)
			replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`x`) })
		},
	]

	opts := FormatOptions{
		emit:          .plain
		codepoint_map: cp_map
	}
	mut formatter := PageFormatter.init(page, opts)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == 'hellx wxrld'

	// Verify point map - each output byte should map to original cell position
	assert output.len == point_map.points.len
	// "hello world" -> "hellx wxrld"
	// h e l l o   w o r l d
	// 0 1 2 3 4 5 6 7 8 9 10
	for i in 0 .. 11 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
}

fn test_page_codepoint_map_conflicting_replacement_prefers_last() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Replace 'o' with 'x', then with 'y' - should prefer last
	cp_map := [
		CodepointMap{
			range_start: u32(`o`)
			range_end:   u32(`o`)
			replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`x`) })
		},
		CodepointMap{
			range_start: u32(`o`)
			range_end:   u32(`o`)
			replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`y`) })
		},
	]

	opts := FormatOptions{
		emit:          .plain
		codepoint_map: cp_map
	}
	formatter := PageFormatter.init(page, opts)

	output := formatter.format()
	assert output == 'helly'
}

fn test_page_codepoint_map_replace_with_string() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Replace 'o' with a multi-byte string
	cp_map := [
		CodepointMap{
			range_start: u32(`o`)
			range_end:   u32(`o`)
			replacement: CodepointReplacement(StringRepl{ str: 'XYZ' })
		},
	]

	opts := FormatOptions{
		emit:          .plain
		codepoint_map: cp_map
	}
	mut formatter := PageFormatter.init(page, opts)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == 'hellXYZ'

	// Verify point map - string replacements should all map to the original cell
	assert output.len == point_map.points.len
	// "hello" -> "hellXYZ"
	// h e l l o
	// 0 1 2 3 4
	assert point_map.points[0] == Coordinate{
		x: 0
		y: 0
	} // h
	assert point_map.points[1] == Coordinate{
		x: 1
		y: 0
	} // e
	assert point_map.points[2] == Coordinate{
		x: 2
		y: 0
	} // l
	assert point_map.points[3] == Coordinate{
		x: 3
		y: 0
	} // l
	// All bytes of the replacement string "XYZ" should point to position 4 (where 'o' was)
	assert point_map.points[4] == Coordinate{
		x: 4
		y: 0
	} // X
	assert point_map.points[5] == Coordinate{
		x: 4
		y: 0
	} // Y
	assert point_map.points[6] == Coordinate{
		x: 4
		y: 0
	} // Z
}

fn test_page_codepoint_map_range_replacement() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('abcdefg'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Replace 'b' through 'e' with 'X'
	cp_map := [
		CodepointMap{
			range_start: u32(`b`)
			range_end:   u32(`e`)
			replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`X`) })
		},
	]

	opts := FormatOptions{
		emit:          .plain
		codepoint_map: cp_map
	}
	formatter := PageFormatter.init(page, opts)

	output := formatter.format()
	assert output == 'aXXXXfg'
}

fn test_page_codepoint_map_multiple_ranges() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Replace 'a'-'m' with 'A' and 'n'-'z' with 'Z'
	cp_map := [
		CodepointMap{
			range_start: u32(`a`)
			range_end:   u32(`m`)
			replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`A`) })
		},
		CodepointMap{
			range_start: u32(`n`)
			range_end:   u32(`z`)
			replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`Z`) })
		},
	]

	opts := FormatOptions{
		emit:          .plain
		codepoint_map: cp_map
	}
	formatter := PageFormatter.init(page, opts)

	output := formatter.format()
	// h e l l o   w o r l d
	// A A A A Z   Z Z Z A A
	assert output == 'AAAAZ ZZZAA'
}

fn test_page_codepoint_map_unicode_replacement() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello ⚡ world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Replace lightning bolt with fire emoji
	cp_map := [
		CodepointMap{
			range_start: u32(`⚡`)
			range_end:   u32(`⚡`)
			replacement: CodepointReplacement(StringRepl{ str: '🔥' })
		},
	]

	opts := FormatOptions{
		emit:          .plain
		codepoint_map: cp_map
	}
	mut formatter := PageFormatter.init(page, opts)

	mut point_map := PointMap{}
	formatter.point_map = &point_map

	output := formatter.format()
	assert output == 'hello 🔥 world'

	// Verify point map
	assert output.len == point_map.points.len
	// "hello ⚡ world"
	// h e l l o   ⚡   w o r l  d
	// 0 1 2 3 4 5 6   8 9 10 11 12
	// Note: ⚡ is a wide character occupying cells 6-7
	for i in 0 .. 6 {
		assert point_map.points[i] == Coordinate{
			x: u16(i)
			y: 0
		}
	}
	// 🔥 is 4 UTF-8 bytes, all should map to cell 6 (where ⚡ was)
	fire_start := 6 // "hello " is 6 bytes
	for i in 0 .. 4 {
		assert point_map.points[fire_start + i] == Coordinate{
			x: 6
			y: 0
		}
	}
	// " world" follows
	world_start := fire_start + 4
	for i in 0 .. 6 {
		assert point_map.points[world_start + i] == Coordinate{
			x: u16(8 + i)
			y: 0
		}
	}
}

fn test_page_codepoint_map_with_styled_formats() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[31mred text\x1b[0m'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Replace 'e' with 'X' in styled text
	cp_map := [
		CodepointMap{
			range_start: u32(`e`)
			range_end:   u32(`e`)
			replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`X`) })
		},
	]

	opts := FormatOptions{
		emit:          .vt
		codepoint_map: cp_map
	}
	formatter := PageFormatter.init(page, opts)

	output := formatter.format()
	// Should preserve styles while replacing text
	// "red text" becomes "rXd tXxt"
	// VT format uses \x1b[38;5;1m for palette color 1
	assert output == '\x1b[0m\x1b[38;5;1mrXd tXxt\x1b[0m'
}

fn test_page_codepoint_map_empty_map() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello world'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	// Empty map should not change anything
	cp_map := []CodepointMap{}

	opts := FormatOptions{
		emit:          .plain
		codepoint_map: cp_map
	}
	formatter := PageFormatter.init(page, opts)

	output := formatter.format()
	assert output == 'hello world'
}

fn test_page_vt_background_color_on_trailing_blank_cells() ! {
	// This test reproduces a bug where trailing cells with background color
	// but no text are emitted as plain spaces without SGR sequences.
	// This causes TUIs like htop to lose background colors on rehydration.
	mut t := Terminal.init(Options{ cols: 20, rows: 5 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	// Simulate a TUI row: "CPU:" with text, then trailing cells with red background
	// to end of line (no text after the colored region).
	// \x1b[41m sets red background, then EL fills rest of row with that bg.
	s.next_slice('CPU:\x1b[41m\x1b[K'.bytes())!
	// Reset colors and move to next line with different content
	s.next_slice('\x1b[0m\r\nline2'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data

	mut formatter := PageFormatter.init(page, format_vt)
	formatter.opts.trim = false // Don't trim so we can see the trailing behavior

	output := formatter.format()

	// The output should preserve the red background SGR for trailing cells on line 1.
	// Bug: the first row outputs "CPU:\r\n" only - losing the background color fill.
	// The red background should appear BEFORE the newline, not after.

	// Find position of CRLF
	crlf_pos := output.index('\r\n') or {
		// No CRLF found, fail the test
		return error('TestUnexpectedResult')
	}

	// Check that red background (48;5;1) appears BEFORE the newline (on line 1)
	line1 := output[0..crlf_pos]
	has_red_bg_line1 := line1.contains('\x1b[41m') || line1.contains('\x1b[48;5;1m')

	// This should be true but currently fails due to the bug
	assert has_red_bg_line1
}

// ============================================================
// Witty-only tests. These have no Ghostty counterpart; they cover the V
// enum layout, the formatter's private helpers, and point-map edge cases
// that the Ghostty tests above do not assert.
// ============================================================

fn test_format_styled() {
	assert sizeof(Format) == 1
	assert u8(Format.plain) == 0
	assert u8(Format.vt) == 1
	assert u8(Format.html) == 2
	assert Format.plain.styled() == false
	assert Format.vt.styled() == true
	assert Format.html.styled() == true
}

fn test_hex02() {
	assert hex02(0x00) == '00'
	assert hex02(0x0f) == '0f'
	assert hex02(0x10) == '10'
	assert hex02(0xff) == 'ff'
	assert hex02(0xab) == 'ab'
	assert hex02(0x12) == '12'
}

fn test_write_utf8() {
	mut sb := strings.new_builder(16)

	// ASCII
	write_utf8(mut sb, u32(`A`))
	assert sb.str() == 'A'

	// 2-byte: ñ = U+00F1
	sb = strings.new_builder(16)
	write_utf8(mut sb, 0x00F1)
	assert sb.str() == 'ñ'

	// 3-byte: ⚡ = U+26A1
	sb = strings.new_builder(16)
	write_utf8(mut sb, 0x26A1)
	assert sb.str() == '⚡'

	// 4-byte: 🔥 = U+1F525
	sb = strings.new_builder(16)
	write_utf8(mut sb, 0x1F525)
	assert sb.str() == '🔥'
}

fn test_has_text_any() {
	// Empty cells
	cells := []CellData{len: 5}
	assert has_text_any(cells) == false

	// One cell with text
	mut cells2 := []CellData{len: 5}
	cells2[2] = CellData.init(u32(`x`))
	assert has_text_any(cells2) == true
}

fn test_cell_style_default() {
	assert CellStyle{}.default() == true
	assert CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false,
			.none)
	}.default() == false
	assert CellStyle{
		fg_color: .palette
	}.default() == false
	assert CellStyle{
		bg_color: .rgb
	}.default() == false
}

fn test_format_style_vt() {
	// Default style: just reset
	assert format_style_vt(CellStyle{}) == '\x1b[0m'

	// Bold
	assert format_style_vt(CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false,
			.none)
	}) == '\x1b[0m\x1b[1m'

	// Bold + italic
	assert format_style_vt(CellStyle{
		flags: StyleFlags.init(true, true, false, false, false, false, false, false,
			.none)
	}) == '\x1b[0m\x1b[1m\x1b[3m'

	// Palette foreground color
	assert format_style_vt(CellStyle{
		fg_color:   .palette
		fg_palette: 1
	}) == '\x1b[0m\x1b[38;5;1m'

	// RGB foreground color
	assert format_style_vt(CellStyle{
		fg_color: .rgb
		fg_r:     0xab
		fg_g:     0xcd
		fg_b:     0xef
	}) == '\x1b[0m\x1b[38;2;171;205;239m'
}

fn test_format_style_close() {
	assert format_style_close(.plain) == ''
	assert format_style_close(.vt) == '\x1b[0m'
	assert format_style_close(.html) == '</div>'
}

fn test_screen_extra_is_set() {
	assert screen_extra_none.is_set() == false
	assert screen_extra_styles.is_set() == true
	assert screen_extra_all.is_set() == true
	mut extra := screen_extra_none
	extra.set_cursor(true)
	assert extra.is_set() == true
	assert sizeof(ScreenExtra) == 1
	assert screen_extra_styles.int() == 0b00_0110
	assert screen_extra_all.int() == 0b11_1111
	assert sizeof(TerminalExtra) == 2
	assert terminal_extra_styles.int() == 0b000110_000001
	assert terminal_extra_all.int() == 0b111111_111111
	mut terminal_extra := terminal_extra_all
	terminal_extra.set_palette(false)
	terminal_extra.set_screen(screen_extra_styles)
	assert !terminal_extra.palette()
	assert terminal_extra.screen() == screen_extra_styles
	assert terminal_extra.int() == 0b000110_111110
}

// VT output separates rows with CRLF so a raw pty returns to column 0.
fn test_page_vt_multiline_crlf() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nworld'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, format_vt)
	assert formatter.format() == 'hello\r\nworld'
}

// A change to only the underline color is a new style and must be emitted.
fn test_page_vt_underline_color_change_emits_new_style() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[4;58;5;1mA\x1b[58;5;2mB\x1b[0m'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	formatter := PageFormatter.init(page, format_vt)
	assert formatter.format() == '\x1b[0m\x1b[4m\x1b[58;5;1mA\x1b[0m\x1b[4m\x1b[58;5;2mB\x1b[0m'
}

// Every byte of a multi-byte replacement maps to the replaced cell, and the
// row's newline maps to the last cell written on that row.
fn test_page_point_map_replacement_and_newline() ! {
	mut t := Terminal.init(Options{ cols: 8, rows: 2 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('hello\r\nz'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, FormatOptions{
		emit:          .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`o`)
				range_end:   u32(`o`)
				replacement: CodepointReplacement(StringRepl{ str: 'XYZ' })
			},
		]
	})
	mut point_map := PointMap{}
	formatter.point_map = &point_map
	output := formatter.format()

	assert output == 'hellXYZ\nz'
	assert point_map.points.len == output.len
	assert point_map.points[0] == Coordinate{
		x: 0
		y: 0
	}
	assert point_map.points[3] == Coordinate{
		x: 3
		y: 0
	}
	for i in 4 .. 7 {
		assert point_map.points[i] == Coordinate{
			x: 4
			y: 0
		}
	}
	assert point_map.points[7] == Coordinate{
		x: 4
		y: 0
	}
	assert point_map.points[8] == Coordinate{
		x: 0
		y: 1
	}
}

// Accumulated interior blank cells are mapped walking backwards from the
// next non-blank cell, as Ghostty's PageFormatter does.
fn test_page_point_map_accumulated_blank_cells_match_source_order() ! {
	mut t := Terminal.init(Options{ cols: 4, rows: 1 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('a  b'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_plain)
	mut point_map := PointMap{}
	formatter.point_map = &point_map

	assert formatter.format() == 'a  b'
	assert point_map.points == [
		Coordinate{
			x: 0
			y: 0
		},
		Coordinate{
			x: 2
			y: 0
		},
		Coordinate{
			x: 1
			y: 0
		},
		Coordinate{
			x: 3
			y: 0
		},
	]
}

// A style close emitted before an unstyled cell maps to the previous cell.
fn test_page_point_map_style_close_uses_previous_cell() ! {
	mut t := Terminal.init(Options{ cols: 2, rows: 1 })!
	defer {
		t.deinit()
	}

	mut s := t.vt_stream()
	defer {
		s.deinit()
	}

	s.next_slice('\x1b[1mA\x1b[0mB'.bytes())!

	pages := &t.screens.active.pages
	last := formatter_last_node(pages)
	page := &last.data
	mut formatter := PageFormatter.init(page, format_vt)
	mut point_map := PointMap{}
	formatter.point_map = &point_map
	output := formatter.format()

	assert output == '\x1b[0m\x1b[1mA\x1b[0mB'
	assert point_map.points.len == output.len
	for i in 0 .. 13 {
		assert point_map.points[i] == Coordinate{
			x: 0
			y: 0
		}
	}
	assert point_map.points[13] == Coordinate{
		x: 1
		y: 0
	}
}
