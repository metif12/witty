module terminal

import strings

// ============================================================
// Tests for the formatter module.
//
// These tests work directly with Pages/RowData/CellData rather
// than through a VT stream parser, since the V terminal doesn't
// have a full VT stream parser yet.
// ============================================================

// Helper: create a Pages with some text on a row.
fn make_pages_with_text(cols u32, rows u32, text string, row_idx int) Pages {
	mut pages := Pages.init(cols, rows, 0)
	for i, ch in text.runes() {
		if i >= int(cols) {
			break
		}
		idx := pages.active_start + row_idx
		if idx < pages.screen_rows.len {
			pages.screen_rows[idx].cells[i].codepoint = u32(ch)
			pages.screen_rows[idx].cells[i].content_tag = .codepoint
		}
	}
	return pages
}

// Helper: set a cell in the pages.
fn set_cell(mut pages Pages, row int, col int, cp u32) {
	idx := pages.active_start + row
	if idx < pages.screen_rows.len && col < int(pages.cols) {
		pages.screen_rows[idx].cells[col].codepoint = cp
		pages.screen_rows[idx].cells[col].content_tag = .codepoint
	}
}

fn set_page_list_line(mut list PageList, row u16, text string) {
	for x, cp in text.runes() {
		if x >= int(list.cols) {
			break
		}
		pin := list.pin(Point.new(.screen, Coordinate{ x: u16(x), y: row })) or { break }
		mut page_row := &pin.node.data.rows[int(pin.y)]
		page_row.cells[int(pin.x)] = CellData.init(u32(cp))
	}
}

fn append_formatter_page(mut list PageList, rows u16) &PageNode {
	first := list.pages.first or { panic('expected first page') }
	mut node := &PageNode{
		data: Page.init(first.data.capacity)
		serial: list.page_serial
	}
	list.page_serial++
	node.data.size.rows = rows
	list.pages.append(node)
	list.total_rows += usize(rows)
	return node
}

// ============================================================
// Page plain single line
// ============================================================

fn test_page_plain_single_line() {
	mut pages := make_pages_with_text(80, 24, 'hello, world', 0)
	formatter := PageFormatter.init(&pages, format_plain)

	result := formatter.format_with_state()
	assert result.output == 'hello, world', 'expected "hello, world", got "${result.output}"'
}

// ============================================================
// Page plain multiline
// ============================================================

fn test_page_plain_multiline() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_plain)
	result := formatter.format_with_state()
	assert result.output == 'hello\nworld', 'expected "hello\\nworld", got "${result.output}"'
}

// ============================================================
// Page plain trailing blank lines
// ============================================================

fn test_page_plain_trailing_blank_lines() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	// Rows 2+ are blank and should be trimmed

	formatter := PageFormatter.init(&pages, format_plain)
	result := formatter.format_with_state()
	assert result.output == 'hello\nworld', 'trailing blank lines should be trimmed'
}

// ============================================================
// Page plain trailing whitespace trimmed
// ============================================================

fn test_page_plain_trailing_whitespace() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello   '.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world   '.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_plain)
	result := formatter.format_with_state()
	assert result.output == 'hello\nworld', 'trailing whitespace should be trimmed'
}

// ============================================================
// Page plain trailing whitespace no trim
// ============================================================

fn test_page_plain_trailing_whitespace_no_trim() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello   '.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world  '.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		trim: false
	})
	result := formatter.format_with_state()
	assert result.output == 'hello   \nworld  ', 'trailing whitespace should be preserved when trim=false'
}

// ============================================================
// Page plain multi blank lines in the middle
// ============================================================

fn test_page_plain_multi_blank_lines() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	// Rows 1, 2 are blank
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 3, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_plain)
	result := formatter.format_with_state()
	assert result.output == 'hello\n\n\nworld', 'blank lines in the middle should be preserved'
}

// ============================================================
// Page plain start_y subset
// ============================================================

fn test_page_plain_start_y_subset() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}
	for i, ch in 'test'.runes() {
		set_cell(mut pages, 2, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_y = 1

	result := formatter.format_with_state()
	assert result.output == 'world\ntest', 'start_y should skip first rows'
}

// ============================================================
// Page plain end_y subset
// ============================================================

fn test_page_plain_end_y_subset() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}
	for i, ch in 'test'.runes() {
		set_cell(mut pages, 2, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.end_y = 1

	result := formatter.format_with_state()
	assert result.output == 'hello\nworld', 'end_y should limit rows'
}

// ============================================================
// Page plain start_y and end_y range
// ============================================================

fn test_page_plain_start_y_end_y_range() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}
	for i, ch in 'test'.runes() {
		set_cell(mut pages, 2, i, u32(ch))
	}
	for i, ch in 'foo'.runes() {
		set_cell(mut pages, 3, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_y = 1
	formatter.end_y = 2

	result := formatter.format_with_state()
	assert result.output == 'world\ntest', 'start_y/end_y range should work'
}

// ============================================================
// Page plain start_y out of bounds
// ============================================================

fn test_page_plain_start_y_out_of_bounds() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_y = 30

	result := formatter.format_with_state()
	assert result.output == '', 'out of bounds start_y should return empty'
	assert result.state.rows == 0
	assert result.state.cells == 0
}

// ============================================================
// Page plain end_y greater than rows
// ============================================================

fn test_page_plain_end_y_greater_than_rows() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.end_y = 30

	result := formatter.format_with_state()
	assert result.output == 'hello', 'end_y greater than rows should clamp'
}

// ============================================================
// Page plain end_y less than start_y
// ============================================================

fn test_page_plain_end_y_less_than_start_y() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_y = 5
	formatter.end_y = 2

	result := formatter.format_with_state()
	assert result.output == '', 'end_y < start_y should return empty'
}

// ============================================================
// Page plain start_x on first row
// ============================================================

fn test_page_plain_start_x_on_first_row() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello world'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_x = 6

	result := formatter.format_with_state()
	assert result.output == 'world', 'start_x should trim first row'
}

// ============================================================
// Page plain end_x on last row
// ============================================================

fn test_page_plain_end_x_on_last_row() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'first line'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'second line'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}
	for i, ch in 'third line'.runes() {
		set_cell(mut pages, 2, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.end_y = 2
	formatter.end_x = 4

	result := formatter.format_with_state()
	assert result.output == 'first line\nsecond line\nthird', 'end_x should limit last row'
}

// ============================================================
// Page plain start_x and end_x multiline
// ============================================================

fn test_page_plain_start_x_and_end_x_multiline() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello world'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'test case'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}
	for i, ch in 'foo bar'.runes() {
		set_cell(mut pages, 2, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_x = 6
	formatter.end_y = 2
	formatter.end_x = 2

	result := formatter.format_with_state()
	// First row: "world" (start_x=6 to end of row)
	// Second row: "test case" (full row)
	// Third row: "foo" (start to end_x=2, inclusive)
	assert result.output == 'world\ntest case\nfoo', 'start_x and end_x should work with multiline'
}

// ============================================================
// Page plain start_x out of bounds
// ============================================================

fn test_page_plain_start_x_out_of_bounds() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_x = 100

	result := formatter.format_with_state()
	assert result.output == '', 'start_x out of bounds should return empty'
}

// ============================================================
// Page plain with prior trailing state rows
// ============================================================

fn test_page_plain_with_prior_trailing_state_rows() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.trailing_state = TrailingState{ rows: 2, cells: 0 }

	result := formatter.format_with_state()
	assert result.output == '\n\nhello', 'trailing state rows should emit newlines before content'
}

// ============================================================
// Page plain start_y non-zero ignores trailing state
// ============================================================

fn test_page_plain_start_y_nonzero_ignores_trailing_state() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_y = 1
	formatter.trailing_state = TrailingState{ rows: 5, cells: 10 }

	result := formatter.format_with_state()
	// Should NOT output the 5 newlines from trailing_state because start_y is non-zero
	assert result.output == 'world', 'trailing state should be ignored when start_y is non-zero'
}

// ============================================================
// Page plain start_x non-zero ignores trailing state
// ============================================================

fn test_page_plain_start_x_nonzero_ignores_trailing_state() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello world'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_x = 6
	formatter.trailing_state = TrailingState{ rows: 2, cells: 8 }

	result := formatter.format_with_state()
	// Should NOT output the 2 newlines or 8 spaces from trailing_state because start_x is non-zero
	assert result.output == 'world', 'trailing state should be ignored when start_x is non-zero'
}

// ============================================================
// Page plain rectangle selection
// ============================================================

fn test_page_plain_rectangle_selection() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.start_x = 1
	formatter.end_x = 3
	formatter.end_y = 1
	formatter.rectangle = true

	result := formatter.format_with_state()
	assert result.output == 'ell\norl', 'rectangle selection should select columns across rows'
}

// ============================================================
// Page plain soft-wrapped without unwrap
// ============================================================

fn test_page_plain_soft_wrapped_no_unwrap() {
	mut pages := Pages.init(10, 24, 0)
	// Write "hello worl" on row 0 (10 cols), "d test" on row 1
	for i, ch in 'hello worl'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	pages.screen_rows[0].wrap = true
	pages.screen_rows[1].wrap_continuation = true
	for i, ch in 'd test'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_plain)
	result := formatter.format_with_state()
	// Without unwrap, wrapped lines show as separate lines
	assert result.output == 'hello worl\nd test', 'wrapped lines without unwrap should have newlines'
}

// ============================================================
// Page plain soft-wrapped with unwrap
// ============================================================

fn test_page_plain_soft_wrapped_with_unwrap() {
	mut pages := Pages.init(10, 24, 0)
	for i, ch in 'hello worl'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	pages.screen_rows[0].wrap = true
	pages.screen_rows[1].wrap_continuation = true
	for i, ch in 'd test'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		unwrap: true
	})
	result := formatter.format_with_state()
	// With unwrap, wrapped lines are joined together
	assert result.output == 'hello world test', 'wrapped lines with unwrap should be joined'
}

// ============================================================
// Page VT single line plain text
// ============================================================

fn test_page_vt_single_line_plain() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_vt)
	output := formatter.format()
	assert output == 'hello', 'VT plain text should be identical to plain'
}

// ============================================================
// Page VT with background and foreground colors
// ============================================================

fn test_page_vt_background_foreground_colors() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .vt
		background: RGB{ r: 0x12, g: 0x34, b: 0x56 }
		foreground: RGB{ r: 0xab, g: 0xcd, b: 0xef }
	})

	output := formatter.format()
	// Should emit OSC 10 for foreground, OSC 11 for background, then the text
	assert output.contains('\x1b]10;rgb:ab/cd/ef\x1b\\'), 'should contain foreground OSC 10'
	assert output.contains('\x1b]11;rgb:12/34/56\x1b\\'), 'should contain background OSC 11'
	assert output.contains('hello'), 'should contain the text'
}

// ============================================================
// Page VT multiline uses \\r\\n
// ============================================================

fn test_page_vt_multiline_crlf() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	for i, ch in 'world'.runes() {
		set_cell(mut pages, 1, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_vt)
	output := formatter.format()
	assert output == 'hello\r\nworld', 'VT multiline should use \\r\\n'
}

fn test_page_vt_single_line_with_bold() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b[1mhello\x1b[0m') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_vt)
	assert f.format() == '\x1b[0m\x1b[1mhello\x1b[0m'
}

fn test_page_vt_multiple_styles() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b[1mhello \x1b[3mworld\x1b[0m') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_vt)
	assert f.format() == '\x1b[0m\x1b[1mhello \x1b[0m\x1b[1m\x1b[3mworld\x1b[0m'
}

fn test_page_vt_with_foreground_color() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b[31mred\x1b[0m') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_vt)
	assert f.format() == '\x1b[0m\x1b[38;5;1mred\x1b[0m'
}

fn test_page_vt_multiline_with_styles() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b[1mfirst\x1b[0m\r\n\x1b[3msecond\x1b[0m') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_vt)
	assert f.format() == '\x1b[0m\x1b[1mfirst\x1b[0m\r\n\x1b[0m\x1b[3msecond\x1b[0m'
}

fn test_page_vt_duplicate_style_not_emitted_twice() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b[1mhel\x1b[1mlo\x1b[0m') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_vt)
	assert f.format() == '\x1b[0m\x1b[1mhello\x1b[0m'
}

fn test_page_vt_underline_color_change_emits_new_style() {
	mut pages := Pages.init(2, 1, 0)
	mut row := &pages.screen_rows[pages.active_start]
	row.cells[0] = CellData{
		codepoint: u32(`A`)
		style_id: 1
		style: CellStyle{
			flags: StyleFlags.init(false, false, false, false, false, false, false, false, .single)
			underline_color: .palette
			underline_palette: 1
		}
	}
	row.cells[1] = CellData{
		codepoint: u32(`B`)
		style_id: 1
		style: CellStyle{
			flags: StyleFlags.init(false, false, false, false, false, false, false, false, .single)
			underline_color: .palette
			underline_palette: 2
		}
	}

	f := PageFormatter.init(&pages, format_vt)
	assert f.format() == '\x1b[0m\x1b[4m\x1b[58;5;1mA\x1b[0m\x1b[4m\x1b[58;5;2mB\x1b[0m'
}

fn test_page_vt_palette_option_emits_rgb() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b]4;1;rgb:ab/cd/ef\x1b\\\x1b[31mred') or { panic(err) }

	deferred := PageFormatter.init(&t.screens.active.pages, format_vt)
	assert deferred.format() == '\x1b[0m\x1b[38;5;1mred\x1b[0m'

	resolved := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .vt
		palette: t.colors.palette.current[..]
	})
	assert resolved.format() == '\x1b[0m\x1b[38;2;171;205;239mred\x1b[0m'
}

fn test_page_html_palette_option_emits_rgb() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b]4;1;rgb:ab/cd/ef\x1b\\\x1b[31mred') or { panic(err) }

	deferred := PageFormatter.init(&t.screens.active.pages, format_html)
	assert deferred.format() == '<div style="font-family: monospace; white-space: pre;"><div style="display: inline;color: var(--vt-palette-1);">red</div></div>'

	resolved := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .html
		palette: t.colors.palette.current[..]
	})
	assert resolved.format() == '<div style="font-family: monospace; white-space: pre;"><div style="display: inline;color: rgb(171, 205, 239);">red</div></div>'
}

fn test_page_vt_style_reset_properly_closes_styles() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('\x1b[1mbold\x1b[0mnormal') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_vt)
	assert f.format() == '\x1b[0m\x1b[1mbold\x1b[0mnormal'
}

fn test_page_vt_background_color_on_trailing_blank_cells() {
	mut t := Terminal.init(Options{ cols: 20, rows: 5 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }
	s.next_slice('CPU:\x1b[41m\x1b[K\x1b[0m\r\nline2') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .vt
		trim: false
	})
	output := f.format()
	crlf := output.index('\r\n') or {
		assert false, 'expected CRLF in VT output'
		return
	}
	line1 := output[..crlf]
	assert line1.contains('\x1b[41m') || line1.contains('\x1b[48;5;1m')
}

// ============================================================
// Page HTML plain text
// ============================================================

fn test_page_html_plain_text() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello, world'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_html)
	output := formatter.format()
	assert output == '<div style="font-family: monospace; white-space: pre;">hello, world</div>', 'HTML should wrap in monospace div'
}

// ============================================================
// Page HTML with background and foreground colors
// ============================================================

fn test_page_html_background_foreground_colors() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .html
		background: RGB{ r: 0x12, g: 0x34, b: 0x56 }
		foreground: RGB{ r: 0xab, g: 0xcd, b: 0xef }
	})

	output := formatter.format()
	assert output.contains('background-color: #123456;'), 'should contain background color'
	assert output.contains('color: #abcdef;'), 'should contain foreground color'
	assert output.contains('hello'), 'should contain the text'
}

// ============================================================
// Page HTML with escaping
// ============================================================

fn test_page_html_with_escaping() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in '<tag>&"\'text'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_html)
	output := formatter.format()
	assert output.contains('&lt;'), 'should escape <'
	assert output.contains('&gt;'), 'should escape >'
	assert output.contains('&amp;'), 'should escape &'
	assert output.contains('&quot;'), 'should escape "'
	assert output.contains('&#39;'), "should escape '"
	assert output.contains('text'), 'should contain text'
}

// ============================================================
// Page HTML with unicode as numeric entities
// ============================================================

fn test_page_html_unicode_numeric_entities() {
	mut pages := Pages.init(80, 24, 0)
	// ╰ = U+2570 = 9584
	set_cell(mut pages, 0, 0, 0x2570)
	// ─ = U+2500 = 9472
	set_cell(mut pages, 0, 1, 0x2500)
	// space
	set_cell(mut pages, 0, 2, u32(` `))
	// ❯ = U+276F = 10095
	set_cell(mut pages, 0, 3, 0x276F)

	formatter := PageFormatter.init(&pages, format_html)
	output := formatter.format()
	assert output.contains('&#9584;'), 'should contain numeric entity for ╰'
	assert output.contains('&#9472;'), 'should contain numeric entity for ─'
	assert output.contains('&#10095;'), 'should contain numeric entity for ❯'
}

// ============================================================
// Page HTML ascii characters unchanged
// ============================================================

fn test_page_html_ascii_unchanged() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello world'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, format_html)
	output := formatter.format()
	assert output.contains('hello world'), 'ASCII should be emitted directly'
}

// ============================================================
// Format.styled()
// ============================================================

fn test_format_styled() {
	assert Format.plain.styled() == false
	assert Format.vt.styled() == true
	assert Format.html.styled() == true
}

// ============================================================
// hex02 helper
// ============================================================

fn test_hex02() {
	assert hex02(0x00) == '00'
	assert hex02(0x0f) == '0f'
	assert hex02(0x10) == '10'
	assert hex02(0xff) == 'ff'
	assert hex02(0xab) == 'ab'
	assert hex02(0x12) == '12'
}

// ============================================================
// write_utf8 helper
// ============================================================

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
}

// ============================================================
// has_text_any helper
// ============================================================

fn test_has_text_any() {
	// Empty cells
	cells := []CellData{len: 5}
	assert has_text_any(cells) == false

	// One cell with text
	mut cells2 := []CellData{len: 5}
	cells2[2].codepoint = u32(`x`)
	cells2[2].content_tag = .codepoint
	assert has_text_any(cells2) == true
}

// ============================================================
// CellStyle.default()
// ============================================================

fn test_cell_style_default() {
	assert CellStyle{}.default() == true
	assert CellStyle{ flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none) }.default() == false
	assert CellStyle{ fg_color: .palette }.default() == false
	assert CellStyle{ bg_color: .rgb }.default() == false
}

// ============================================================
// format_style_vt
// ============================================================

fn test_format_style_vt() {
	// Default style: just reset
	s := format_style_vt(CellStyle{})
	assert s == '\x1b[0m'

	// Bold
	s2 := format_style_vt(CellStyle{ flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none) })
	assert s2 == '\x1b[0m\x1b[1m'

	// Bold + italic
	s3 := format_style_vt(CellStyle{
		flags: StyleFlags.init(true, true, false, false, false, false, false, false, .none)
	})
	assert s3 == '\x1b[0m\x1b[1m\x1b[3m'

	// Palette foreground color
	s4 := format_style_vt(CellStyle{
		fg_color: .palette
		fg_palette: 1
	})
	assert s4 == '\x1b[0m\x1b[38;5;1m'

	// RGB foreground color
	s5 := format_style_vt(CellStyle{
		fg_color: .rgb
		fg_r: 0xab
		fg_g: 0xcd
		fg_b: 0xef
	})
	assert s5 == '\x1b[0m\x1b[38;2;171;205;239m'
}

// ============================================================
// format_style_close
// ============================================================

fn test_format_style_close() {
	assert format_style_close(.plain) == ''
	assert format_style_close(.vt) == '\x1b[0m'
	assert format_style_close(.html) == '</div>'
}

// ============================================================
// ScreenExtra.is_set()
// ============================================================

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

// ============================================================
// ScreenFormatter plain single line
// ============================================================

fn test_screen_formatter_plain_single_line() {
	mut screen := Screen.init(80, 24, 0)
	for i, ch in 'hello, world'.runes() {
		if i < int(screen.pages.cols) {
			idx := screen.pages.active_start
			screen.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
			screen.pages.screen_rows[idx].cells[i].content_tag = .codepoint
		}
	}

	formatter := ScreenFormatter.init(&screen, format_plain)
	output := formatter.format()
	assert output == 'hello, world'
}

// ============================================================
// ScreenFormatter plain multiline
// ============================================================

fn test_screen_formatter_plain_multiline() {
	mut screen := Screen.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		idx := screen.pages.active_start
		screen.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		screen.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}
	for i, ch in 'world'.runes() {
		idx := screen.pages.active_start + 1
		screen.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		screen.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	formatter := ScreenFormatter.init(&screen, format_plain)
	output := formatter.format()
	assert output == 'hello\nworld'
}

// ============================================================
// TerminalFormatter plain
// ============================================================

fn test_terminal_formatter_plain() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut primary := t.screens.get(.primary) or { panic('primary screen must be initialized') }
	for i, ch in 'hello'.runes() {
		idx := primary.pages.active_start
		primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}
	for i, ch in 'world'.runes() {
		idx := primary.pages.active_start + 1
		primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	formatter := TerminalFormatter.init(&t, format_plain)
	output := formatter.format()
	assert output == 'hello\nworld'
}

// ============================================================
// TerminalFormatter VT with palette
// ============================================================

fn test_terminal_formatter_vt_palette() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut primary := t.screens.get(.primary) or { panic('primary screen must be initialized') }
	// Modify a palette color
	t.colors.palette.current[0] = RGB{ r: 0x12, g: 0x34, b: 0x56 }
	t.colors.palette.current[1] = RGB{ r: 0xab, g: 0xcd, b: 0xef }

	for i, ch in 'test'.runes() {
		idx := primary.pages.active_start
		primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	formatter := TerminalFormatter.init(&t, format_vt)
	output := formatter.format()

	// Should contain palette entries
	assert output.contains('\x1b]4;0;rgb:12/34/56\x1b\\'), 'should contain palette entry 0'
	assert output.contains('\x1b]4;1;rgb:ab/cd/ef\x1b\\'), 'should contain palette entry 1'
	assert output.contains('test'), 'should contain the text'
}

// ============================================================
// TerminalFormatter HTML with palette
// ============================================================

fn test_terminal_formatter_html_palette() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut primary := t.screens.get(.primary) or { panic('primary screen must be initialized') }
	t.colors.palette.current[0] = RGB{ r: 0x12, g: 0x34, b: 0x56 }
	t.colors.palette.current[1] = RGB{ r: 0xab, g: 0xcd, b: 0xef }
	t.colors.palette.current[255] = RGB{ r: 0xff, g: 0x00, b: 0xff }

	for i, ch in 'test'.runes() {
		idx := primary.pages.active_start
		primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, FormatOptions{ emit: .html })
	formatter.extra = terminal_extra_none
	formatter.extra.set_palette(true)
	output := formatter.format()

	// Verify palette CSS variables are emitted
	assert output.contains('<style>:root{'), 'should contain style block'
	assert output.contains('--vt-palette-0: #123456;'), 'should contain palette 0'
	assert output.contains('--vt-palette-1: #abcdef;'), 'should contain palette 1'
	assert output.contains('--vt-palette-255: #ff00ff;'), 'should contain palette 255'
	assert output.contains('}</style>'), 'should close style block'
	assert output.contains('test'), 'should contain the text'
}

// ============================================================
// Terminal VT with scrolling region
// ============================================================

fn test_terminal_vt_scrolling_region() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut primary := t.screens.get(.primary) or { panic('primary screen must be initialized') }
	// Set scrolling region: top=5, bottom=20
	t.scrolling_region.top = 5
	t.scrolling_region.bottom = 20

	for i, ch in 'hello'.runes() {
		idx := primary.pages.active_start
		primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra = terminal_extra_none
	formatter.extra.set_scrolling_region(true)
	output := formatter.format()

	// Should contain DECSTBM sequence
	assert output.contains('\x1b[6;21r'), 'should contain DECSTBM with 1-indexed values'
}

// Terminal VT with modes preserves every non-default ANSI/DEC mode through a
// formatter round trip.
fn test_terminal_vt_modes() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut stream := ReadonlyStream.init(mut t)
	defer {
		stream.deinit()
	}
	stream.next_slice('\x1b[?2004h\x1b[?1000h\x1b[?7lhello')!

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra = terminal_extra_none
	formatter.extra.set_modes(true)
	output := formatter.format()
	assert output.contains('\x1b[?2004h')
	assert output.contains('\x1b[?1000h')
	assert output.contains('\x1b[?7l')

	mut restored := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut restored_stream := ReadonlyStream.init(mut restored)
	defer {
		restored_stream.deinit()
	}
	restored_stream.next_slice(output)!
	assert restored.modes.get(.bracketed_paste) == t.modes.get(.bracketed_paste)
	assert restored.modes.get(.mouse_event_normal) == t.modes.get(.mouse_event_normal)
	assert restored.modes.get(.wraparound) == t.modes.get(.wraparound)
}

// ============================================================
// Terminal VT with keyboard modes
// ============================================================

fn test_terminal_vt_keyboard_modes() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut primary := t.screens.get(.primary) or { panic('primary screen must be initialized') }
	t.flags.set_modify_other_keys_2(true)

	for i, ch in 'hello'.runes() {
		idx := primary.pages.active_start
		primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra = terminal_extra_none
	formatter.extra.set_keyboard(true)
	output := formatter.format()

	assert output.contains('\x1b[>4;2m'), 'should contain modify other keys mode 2'
}

// ============================================================
// Terminal VT with pwd
// ============================================================

fn test_terminal_vt_pwd() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	mut primary := t.screens.get(.primary) or { panic('primary screen must be initialized') }
	t.pwd = 'file://host/home/user'

	for i, ch in 'hello'.runes() {
		idx := primary.pages.active_start
		primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra = terminal_extra_none
	formatter.extra.set_pwd(true)
	output := formatter.format()

	assert output.contains('\x1b]7;file://host/home/user\x1b\\'), 'should contain OSC 7 pwd'
}

// ============================================================
// Codepoint map: single replacement
// ============================================================

fn test_codepoint_map_single_replacement() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello world'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	// Replace 'o' with 'x'
	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`o`)
				range_end: u32(`o`)
				replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`x`) })
			},
		]
	})

	output := formatter.format()
	assert output == 'hellx wxrld', 'codepoint replacement should work'
}

// ============================================================
// Codepoint map: replace with string
// ============================================================

fn test_codepoint_map_replace_with_string() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	// Replace 'o' with "XYZ"
	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`o`)
				range_end: u32(`o`)
				replacement: CodepointReplacement(StringRepl{ str: 'XYZ' })
			},
		]
	})

	output := formatter.format()
	assert output == 'hellXYZ', 'string replacement should work'
}

fn test_page_point_map_replacement_and_newline() {
	mut pages := Pages.init(8, 2, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}
	set_cell(mut pages, 1, 0, u32(`z`))

	mut points := PointMap{}
	mut formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`o`)
				range_end: u32(`o`)
				replacement: CodepointReplacement(StringRepl{ str: 'XYZ' })
			},
		]
	})
	formatter.point_map = &points
	output := formatter.format()

	assert output == 'hellXYZ\nz'
	assert points.points.len == output.len
	assert points.points[0].eql(Coordinate{ x: 0, y: 0 })
	assert points.points[3].eql(Coordinate{ x: 3, y: 0 })
	for i in 4 .. 7 {
		assert points.points[i].eql(Coordinate{ x: 4, y: 0 })
	}
	assert points.points[7].eql(Coordinate{ x: 4, y: 0 })
	assert points.points[8].eql(Coordinate{ x: 0, y: 1 })
}

fn test_page_point_map_multibyte_replacement() {
	mut pages := make_pages_with_text(8, 1, 'x', 0)
	mut points := PointMap{}
	mut formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`x`)
				range_end: u32(`x`)
				replacement: CodepointReplacement(StringRepl{ str: '🔥' })
			},
		]
	})
	formatter.point_map = &points
	output := formatter.format()

	assert output == '🔥'
	assert points.points.len == output.len
	for point in points.points {
		assert point.eql(Coordinate{ x: 0, y: 0 })
	}
}

fn test_page_point_map_accumulated_blank_cells_match_source_order() {
	mut pages := make_pages_with_text(4, 1, 'a  b', 0)
	mut points := PointMap{}
	mut formatter := PageFormatter.init(&pages, format_plain)
	formatter.point_map = &points

	assert formatter.format() == 'a  b'
	assert points.points == [
		Coordinate{ x: 0, y: 0 },
		Coordinate{ x: 2, y: 0 },
		Coordinate{ x: 1, y: 0 },
		Coordinate{ x: 3, y: 0 },
	]
}

fn test_page_point_map_style_close_uses_previous_cell() {
	mut pages := make_pages_with_text(2, 1, 'AB', 0)
	mut row := &pages.screen_rows[pages.active_start]
	row.cells[0].style_id = 1
	row.cells[0].style = CellStyle{ flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none) }

	mut points := PointMap{}
	mut formatter := PageFormatter.init(&pages, format_vt)
	formatter.point_map = &points
	output := formatter.format()

	assert output == '\x1b[0m\x1b[1mA\x1b[0mB'
	assert points.points.len == output.len
	for i in 0 .. 13 {
		assert points.points[i] == Coordinate{ x: 0, y: 0 }
	}
	assert points.points[13] == Coordinate{ x: 1, y: 0 }
}

fn test_screen_pin_map() {
	mut screen := Screen.init(8, 2, 0)
	for i, ch in 'abc'.runes() {
		set_cell(mut screen.pages, 0, i, u32(ch))
	}
	mut pins := PinMap{}
	mut formatter := ScreenFormatter.init(&screen, format_plain)
	formatter.pin_map = &pins
	output := formatter.format()

	assert output == 'abc'
	assert pins.pins.len == output.len
	for i, pin in pins.pins {
		assert pin.x == i
		assert pin.y == 0
	}
}

// ============================================================
// Codepoint map: range replacement
// ============================================================

fn test_codepoint_map_range_replacement() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'abcdefg'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	// Replace 'b' through 'e' with 'X'
	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`b`)
				range_end: u32(`e`)
				replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`X`) })
			},
		]
	})

	output := formatter.format()
	assert output == 'aXXXXfg', 'range replacement should work'
}

// ============================================================
// Codepoint map: conflicting replacement prefers last
// ============================================================

fn test_codepoint_map_conflicting_prefers_last() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	// Replace 'o' with 'x', then with 'y' - should prefer last
	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`o`)
				range_end: u32(`o`)
				replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`x`) })
			},
			CodepointMap{
				range_start: u32(`o`)
				range_end: u32(`o`)
				replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`y`) })
			},
		]
	})

	output := formatter.format()
	assert output == 'helly', 'conflicting replacement should prefer last'
}

// ============================================================
// Codepoint map: empty map
// ============================================================

fn test_codepoint_map_empty() {
	mut pages := Pages.init(80, 24, 0)
	for i, ch in 'hello world'.runes() {
		set_cell(mut pages, 0, i, u32(ch))
	}

	formatter := PageFormatter.init(&pages, FormatOptions{
		emit: .plain
		codepoint_map: []
	})

	output := formatter.format()
	assert output == 'hello world', 'empty map should not change anything'
}

// ============================================================
// Additional ghostty-parity tests (driven via ReadonlyStream)
//
// These translate ghostty formatter.zig `test "..."` blocks that fill the
// terminal via the VT stream and then format. The point_map/pin_map
// assertions from ghostty are omitted because pin/point tracking is not
// implemented in this port (see formatter.v notes).
// ============================================================

// Page plain single line with styling: styling does not affect plain output.
fn test_page_plain_single_line_with_styling() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello, \x1b[1mworld\x1b[0m') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_plain)
	r := f.format_with_state()
	assert r.output == 'hello, world'
	assert r.state.rows == usize(t.screens.active.pages.rows)
	assert r.state.cells == usize(t.screens.active.pages.cols) - 12
}

// Page plain multiline rectangle.
fn test_page_plain_multiline_rectangle() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello\r\nworld') or { panic(err) }

	mut f := PageFormatter.init(&t.screens.active.pages, format_plain)
	f.start_x = 1
	f.end_x = 3
	f.rectangle = true
	r := f.format_with_state()
	assert r.output == 'ell\norl'
	assert r.state.rows == usize(t.screens.active.pages.rows) - 1
	assert r.state.cells == 0
}

// Page plain end_x greater than cols clamps.
fn test_page_plain_end_x_greater_than_cols() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello') or { panic(err) }

	mut f := PageFormatter.init(&t.screens.active.pages, format_plain)
	f.end_x = 100
	r := f.format_with_state()
	assert r.output == 'hello'
	assert r.state.rows == usize(t.screens.active.pages.rows)
	assert r.state.cells == usize(t.screens.active.pages.cols) - 5
}

// Page plain end_x less than start_x on a single row returns empty.
fn test_page_plain_end_x_less_than_start_x_single_row() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello') or { panic(err) }

	mut f := PageFormatter.init(&t.screens.active.pages, format_plain)
	f.start_x = 10
	f.end_y = 0
	f.end_x = 5
	r := f.format_with_state()
	assert r.output == ''
	assert r.state.rows == 0
	assert r.state.cells == 0
}

// Page plain soft-wrapped 3 lines without unwrap.
fn test_page_plain_soft_wrapped_3_lines_no_unwrap() {
	mut t := Terminal.init(Options{ cols: 10, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello world this is a test') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_plain)
	r := f.format_with_state()
	// Without unwrap, wrapped lines show as separate lines
	assert r.output == 'hello worl\nd this is\na test'
	assert r.state.rows == usize(t.screens.active.pages.rows) - 2
	assert r.state.cells == usize(t.screens.active.pages.cols) - 6
}

// Page plain soft-wrapped 3 lines with unwrap.
fn test_page_plain_soft_wrapped_3_lines_with_unwrap() {
	mut t := Terminal.init(Options{ cols: 10, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello world this is a test') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .plain
		unwrap: true
	})
	r := f.format_with_state()
	// With unwrap, wrapped lines are joined together
	assert r.output == 'hello world this is a test'
	assert r.state.rows == usize(t.screens.active.pages.rows) - 2
	assert r.state.cells == usize(t.screens.active.pages.cols) - 6
}

// Page plain single line soft-wrapped unwrapped.
fn test_page_plain_single_line_soft_wrapped_unwrapped() {
	mut t := Terminal.init(Options{ cols: 3, rows: 5 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello!') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .plain
		unwrap: true
	})
	output := f.format()
	assert output == 'hello!'
}

// Page plain single wide char.
fn test_page_plain_single_wide_char() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('1A⚡') or { panic(err) }

	mut points := PointMap{}

	// Full string.
	mut f := PageFormatter.init(&t.screens.active.pages, format_plain)
	f.point_map = &points
	result := f.format_with_state()
	assert result.output == '1A⚡'
	assert result.state.rows == usize(t.screens.active.pages.screen_rows.len)
	assert result.state.cells == usize(t.screens.active.pages.cols) - 4
	assert points.points.len == result.output.len
	for i in 2 .. result.output.len {
		assert points.points[i] == Coordinate{ x: 2, y: 0 }
	}

	// Wide only (from start of the wide char).
	points.points.clear()
	mut f2 := PageFormatter.init(&t.screens.active.pages, format_plain)
	f2.start_x = 2
	f2.point_map = &points
	result2 := f2.format_with_state()
	assert result2.output == '⚡'
	assert result2.state.rows == usize(t.screens.active.pages.screen_rows.len)
	assert result2.state.cells == usize(t.screens.active.pages.cols) - 4
	assert points.points.len == result2.output.len
	for point in points.points {
		assert point == Coordinate{ x: 2, y: 0 }
	}

	// Starting from the spacer tail must include the owning wide cell.
	points.points.clear()
	mut f3 := PageFormatter.init(&t.screens.active.pages, format_plain)
	f3.start_x = 3
	f3.point_map = &points
	result3 := f3.format_with_state()
	assert result3.output == '⚡'
	assert result3.state.rows == usize(t.screens.active.pages.screen_rows.len)
	assert result3.state.cells == usize(t.screens.active.pages.cols) - 4
	assert points.points.len == result3.output.len
	for point in points.points {
		assert point == Coordinate{ x: 2, y: 0 }
	}
}

fn test_page_list_plain_spanning_two_pages_with_pin_map() {
	mut list := PageList.init(8, 2, none)
	defer {
		list.deinit()
	}
	mut first := list.pages.first or {
		assert false, 'expected first page'
		return
	}
	first.data.rows[1].cells[0] = CellData.init(u32(`o`))
	first.data.rows[1].cells[1] = CellData.init(u32(`n`))
	first.data.rows[1].cells[2] = CellData.init(u32(`e`))

	mut second := &PageNode{
		data: Page.init(first.data.capacity)
		serial: list.page_serial
	}
	list.page_serial++
	second.data.size.rows = 2
	second.data.rows[0].cells[0] = CellData.init(u32(`t`))
	second.data.rows[0].cells[1] = CellData.init(u32(`w`))
	second.data.rows[0].cells[2] = CellData.init(u32(`o`))
	list.pages.append(second)
	list.total_rows += 2

	mut pins := PagePinMap{}
	mut formatter := PageListFormatter.init(&list, format_plain)
	formatter.top_left = PagePin{
		node: first
		x: 0
		y: 1
	}
	formatter.bottom_right = PagePin{
		node: second
		x: 2
		y: 0
	}
	formatter.pin_map = &pins
	output := formatter.format()
	assert output == 'one\ntwo'
	assert pins.pins.len == output.len
	for i in 0 .. 3 {
		assert voidptr(pins.pins[i].node) == voidptr(first)
		assert pins.pins[i].x == i
		assert pins.pins[i].y == 1
	}
	// The newline is deferred as trailing state and emitted by the second
	// page, so it maps to that page just like Ghostty's formatter.
	assert voidptr(pins.pins[3].node) == voidptr(second)
	for i in 4 .. output.len {
		assert voidptr(pins.pins[i].node) == voidptr(second)
		assert pins.pins[i].x == i - 4
		assert pins.pins[i].y == 0
	}
}

fn test_page_list_plain_single_line_with_pin_map() {
	mut list := PageList.init(16, 1, none)
	defer {
		list.deinit()
	}
	set_page_list_line(mut list, 0, 'hello, world')

	mut pins := PagePinMap{}
	mut formatter := PageListFormatter.init(&list, format_plain)
	formatter.pin_map = &pins
	output := formatter.format()
	assert output == 'hello, world'
	assert pins.pins.len == output.len
	first := list.pages.first or {
		assert false
		return
	}
	for i, pin in pins.pins {
		assert voidptr(pin.node) == voidptr(first)
		assert pin.x == i
		assert pin.y == 0
	}
}

fn test_page_list_soft_wrap_spanning_pages() {
	mut list := PageList.init(10, 1, none)
	defer {
		list.deinit()
	}
	mut first := list.pages.first or {
		assert false
		return
	}
	mut second := append_formatter_page(mut list, 1)
	set_page_list_line(mut list, 0, 'hello worl')
	first.data.rows[0].wrap = true
	second.data.rows[0].wrap_continuation = true
	for i, cp in 'd test'.runes() {
		second.data.rows[0].cells[i] = CellData.init(u32(cp))
	}

	mut pins := PagePinMap{}
	mut formatter := PageListFormatter.init(&list, format_plain)
	formatter.pin_map = &pins
	output := formatter.format()
	assert output == 'hello worl\nd test'
	assert pins.pins.len == output.len
	for i in 0 .. 10 {
		assert voidptr(pins.pins[i].node) == voidptr(first)
	}
	assert voidptr(pins.pins[10].node) == voidptr(second)
	for i in 11 .. output.len {
		assert voidptr(pins.pins[i].node) == voidptr(second)
	}

	pins.pins.clear()
	mut unwrapped := PageListFormatter.init(&list, FormatOptions{
		emit: .plain
		unwrap: true
	})
	unwrapped.pin_map = &pins
	output_unwrapped := unwrapped.format()
	assert output_unwrapped == 'hello world test'
	assert pins.pins.len == output_unwrapped.len
	for i in 0 .. 10 {
		assert voidptr(pins.pins[i].node) == voidptr(first)
	}
	for i in 10 .. output_unwrapped.len {
		assert voidptr(pins.pins[i].node) == voidptr(second)
	}
}

fn test_page_list_plain_x_bounds_single_page() {
	mut list := PageList.init(16, 3, none)
	defer {
		list.deinit()
	}
	set_page_list_line(mut list, 0, 'hello world')
	set_page_list_line(mut list, 1, 'test case')
	set_page_list_line(mut list, 2, 'foo bar')
	first := list.pages.first or {
		assert false
		return
	}

	mut pins := PagePinMap{}
	mut formatter := PageListFormatter.init(&list, format_plain)
	formatter.top_left = PagePin{
		node: first
		y: 0
		x: 6
	}
	formatter.bottom_right = PagePin{
		node: first
		y: 2
		x: 2
	}
	formatter.pin_map = &pins
	output := formatter.format()
	assert output == 'world\ntest case\nfoo'
	assert pins.pins.len == output.len
	for i in 0 .. 5 {
		assert pins.pins[i].x == 6 + i
		assert pins.pins[i].y == 0
	}
}

fn test_page_list_plain_x_bounds_spanning_pages() {
	mut list := PageList.init(16, 1, none)
	defer {
		list.deinit()
	}
	first := list.pages.first or {
		assert false
		return
	}
	mut second := append_formatter_page(mut list, 1)
	set_page_list_line(mut list, 0, 'hello world')
	for i, cp in 'foo bar test'.runes() {
		second.data.rows[0].cells[i] = CellData.init(u32(cp))
	}

	mut pins := PagePinMap{}
	mut formatter := PageListFormatter.init(&list, format_plain)
	formatter.top_left = PagePin{
		node: first
		y: 0
		x: 6
	}
	formatter.bottom_right = PagePin{
		node: second
		y: 0
		x: 2
	}
	formatter.pin_map = &pins
	output := formatter.format()
	assert output == 'world\nfoo'
	assert pins.pins.len == output.len
	for i in 0 .. 5 {
		assert voidptr(pins.pins[i].node) == voidptr(first)
		assert pins.pins[i].x == 6 + i
	}
	assert voidptr(pins.pins[5].node) == voidptr(second)
	for i in 0 .. 3 {
		assert voidptr(pins.pins[6 + i].node) == voidptr(second)
		assert pins.pins[6 + i].x == i
	}
}

fn test_page_list_plain_start_or_end_x_only() {
	mut list := PageList.init(16, 2, none)
	defer {
		list.deinit()
	}
	set_page_list_line(mut list, 0, 'hello world')
	set_page_list_line(mut list, 1, 'test')
	first := list.pages.first or {
		assert false
		return
	}

	mut start := PageListFormatter.init(&list, format_plain)
	start.top_left = PagePin{
		node: first
		y: 0
		x: 6
	}
	assert start.format() == 'world\ntest'

	mut end := PageListFormatter.init(&list, format_plain)
	end.bottom_right = PagePin{
		node: first
		y: 1
		x: 2
	}
	assert end.format() == 'hello world\ntes'
}

fn test_page_list_plain_rectangles() {
	mut list := PageList.init(30, 8, none)
	defer {
		list.deinit()
	}
	lines := [
		'Lorem ipsum dolor',
		'sit amet, consectetur',
		'adipiscing elit, sed do',
		'eiusmod tempor incididunt',
		'ut labore et dolore',
		'',
		'magna aliqua. Ut enim',
		'ad minim veniam, quis',
	]
	for y, line in lines {
		set_page_list_line(mut list, u16(y), line)
	}
	first := list.pages.first or {
		assert false
		return
	}

	mut basic := PageListFormatter.init(&list, format_plain)
	basic.top_left = PagePin{
		node: first
		y: 1
		x: 2
	}
	basic.bottom_right = PagePin{
		node: first
		y: 3
		x: 6
	}
	basic.rectangle = true
	assert basic.format() == 't ame\nipisc\nusmod'

	mut eol := PageListFormatter.init(&list, format_plain)
	eol.top_left = PagePin{
		node: first
		y: 0
		x: 12
	}
	eol.bottom_right = PagePin{
		node: first
		y: 4
		x: 26
	}
	eol.rectangle = true
	assert eol.format() == 'dolor\nnsectetur\nlit, sed do\nor incididunt\n dolore'

	mut breaks := PageListFormatter.init(&list, format_plain)
	breaks.top_left = PagePin{
		node: first
		y: 2
		x: 11
	}
	breaks.bottom_right = PagePin{
		node: first
		y: 7
		x: 26
	}
	breaks.rectangle = true
	assert breaks.format() == 'elit, sed do\npor incididunt\nt dolore\n\na. Ut enim\nniam, quis'
}

fn test_page_list_vt_uses_each_pages_style_table() {
	mut list := PageList.init(4, 1, none)
	defer {
		list.deinit()
	}
	mut first := list.pages.first or {
		assert false, 'expected first page'
		return
	}
	bold := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	first_style_id := first.data.styles.add(bold)!
	first.data.rows[0].cells[0] = CellData{
		codepoint: u32(`A`)
		style_id: first_style_id
	}

	mut second := &PageNode{
		data: Page.init(first.data.capacity)
		serial: list.page_serial
	}
	list.page_serial++
	second.data.size.rows = 1
	italic := CellStyle{
		flags: StyleFlags.init(false, true, false, false, false, false, false, false, .none)
	}
	second_style_id := second.data.styles.add(italic)!
	second.data.rows[0].cells[0] = CellData{
		codepoint: u32(`B`)
		style_id: second_style_id
	}
	list.pages.append(second)
	list.total_rows++

	mut formatter := PageListFormatter.init(&list, format_vt)
	formatter.top_left = PagePin{
		node: first
	}
	formatter.bottom_right = PagePin{
		node: second
	}
	output := formatter.format()
	assert output == '\x1b[0m\x1b[1mA\x1b[0m\r\n\x1b[0m\x1b[3mB\x1b[0m'
}

// Page plain start_y and start_x zero uses trailing state.
fn test_page_plain_start_y_and_start_x_zero_uses_trailing_state() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello') or { panic(err) }

	mut f := PageFormatter.init(&t.screens.active.pages, format_plain)
	f.start_y = 0
	f.start_x = 0
	f.trailing_state = TrailingState{ rows: 2, cells: 0 }
	r := f.format_with_state()
	// SHOULD output the 2 newlines because both start_y and start_x are 0
	assert r.output == '\n\nhello'
	assert r.state.rows == usize(t.screens.active.pages.rows)
	assert r.state.cells == usize(t.screens.active.pages.cols) - 5
}

// Page plain with prior trailing state cells, no wrapped line.
fn test_page_plain_with_prior_trailing_state_cells_no_wrap() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello') or { panic(err) }

	mut f := PageFormatter.init(&t.screens.active.pages, format_plain)
	f.trailing_state = TrailingState{ rows: 0, cells: 3 }
	r := f.format_with_state()
	// Blank cells are reset when row is not a wrap continuation
	assert r.output == 'hello'
	assert r.state.rows == usize(t.screens.active.pages.rows)
	assert r.state.cells == usize(t.screens.active.pages.cols) - 5
}

// Page plain with prior trailing state cells, with wrap continuation.
fn test_page_plain_with_prior_trailing_state_cells_wrap_continuation() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('world') or { panic(err) }

	// Surgically modify the first row to be a wrap continuation
	idx := t.screens.active.pages.active_start
	t.screens.active.pages.screen_rows[idx].wrap_continuation = true

	mut f := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .plain
		unwrap: true
	})
	f.trailing_state = TrailingState{ rows: 0, cells: 3 }
	r := f.format_with_state()
	// Blank cells are preserved when the row is a wrap continuation with unwrap
	assert r.output == '   world'
	assert r.state.rows == usize(t.screens.active.pages.rows)
	assert r.state.cells == usize(t.screens.active.pages.cols) - 5
}

// Page html mixed ascii and unicode.
fn test_page_html_mixed_ascii_and_unicode() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('test ╰─❯ ok') or { panic(err) }

	f := PageFormatter.init(&t.screens.active.pages, format_html)
	output := f.format()
	assert output == '<div style="font-family: monospace; white-space: pre;">test &#9584;&#9472;&#10095; ok</div>'
}

// Page codepoint_map multiple ranges.
fn test_codepoint_map_multiple_ranges() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello world') or { panic(err) }

	// Replace 'a'-'m' with 'A' and 'n'-'z' with 'Z'
	f := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: u32(`a`)
				range_end: u32(`m`)
				replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`A`) })
			},
			CodepointMap{
				range_start: u32(`n`)
				range_end: u32(`z`)
				replacement: CodepointReplacement(CodepointRepl{ codepoint: u32(`Z`) })
			},
		]
	})
	// h e l l o   w o r l d
	// A A A A Z   Z Z Z A A
	assert f.format() == 'AAAAZ ZZZAA'
}

// Page codepoint_map unicode replacement.
fn test_codepoint_map_unicode_replacement() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello ⚡ world') or { panic(err) }

	// Replace lightning bolt (U+26A1) with fire emoji
	f := PageFormatter.init(&t.screens.active.pages, FormatOptions{
		emit: .plain
		codepoint_map: [
			CodepointMap{
				range_start: 0x26A1
				range_end: 0x26A1
				replacement: CodepointReplacement(StringRepl{ str: '🔥' })
			},
		]
	})
	assert f.format() == 'hello 🔥 world'
}

// Screen plain single line.
fn test_screen_plain_single_line() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello, world') or { panic(err) }

	f := ScreenFormatter.init(t.screens.active, format_plain)
	assert f.format() == 'hello, world'
}

// Screen plain multiline.
fn test_screen_plain_multiline() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello\r\nworld') or { panic(err) }

	f := ScreenFormatter.init(t.screens.active, format_plain)
	assert f.format() == 'hello\nworld'
}

// Screen plain with selection.
fn test_screen_plain_with_selection() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('line1\r\nline2\r\nline3') or { panic(err) }

	start := t.screens.active.pages.pin(PinOpts{ tag: .active, x: 0, y: 1 }) or { panic('no start pin') }
	end := t.screens.active.pages.pin(PinOpts{ tag: .active, x: 4, y: 1 }) or { panic('no end pin') }

	mut f := ScreenFormatter.init(t.screens.active, format_plain)
	f.content = ScreenContent(ScreenContentSelection{ sel: Selection.init(start, end, false) })
	assert f.format() == 'line2'
}

// Screen vt with cursor position (roundtrip via a second terminal).
fn test_screen_vt_with_cursor_position() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('hello\r\nworld') or { panic(err) }

	mut f := ScreenFormatter.init(t.screens.active, format_vt)
	f.extra = screen_extra_none
	f.extra.set_cursor(true)
	output := f.format()

	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s2 := ReadonlyStream.init(mut t2)
	defer {
		s2.deinit()
	}
	s2.next_slice(output) or { panic(err) }

	assert t.screens.active.cursor.x == t2.screens.active.cursor.x
	assert t.screens.active.cursor.y == t2.screens.active.cursor.y
}

// Screen vt with style (roundtrip via a second terminal).
fn test_screen_vt_with_style() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	// Set some style attributes: bold + red foreground
	s.next_slice('\x1b[1;31mhello') or { panic(err) }

	mut f := ScreenFormatter.init(t.screens.active, format_vt)
	f.extra = screen_extra_none
	f.extra.set_style(true)
	output := f.format()

	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s2 := ReadonlyStream.init(mut t2)
	defer {
		s2.deinit()
	}
	s2.next_slice(output) or { panic(err) }

	assert t.screens.active.cursor.style.eql(&t2.screens.active.cursor.style)
}

// Screen vt with hyperlink (roundtrip via a second terminal).
fn test_screen_vt_with_hyperlink() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('\x1b]8;;http://example.com\x1b\\hello') or { panic(err) }

	mut f := ScreenFormatter.init(t.screens.active, format_vt)
	f.extra = screen_extra_none
	f.extra.set_hyperlink(true)
	output := f.format()

	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s2 := ReadonlyStream.init(mut t2)
	defer {
		s2.deinit()
	}
	s2.next_slice(output) or { panic(err) }

	l1 := t.screens.active.cursor.hyperlink_state
	l2 := t2.screens.active.cursor.hyperlink_state
	assert (l1 != none) == (l2 != none)
	if link1 := l1 {
		link2 := l2 or { panic('l2 missing') }
		assert link1.uri == link2.uri
	}
}

// Screen vt with protection (roundtrip via a second terminal).
fn test_screen_vt_with_protection() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	s.next_slice('\x1b[1"qhello') or { panic(err) }

	mut f := ScreenFormatter.init(t.screens.active, format_vt)
	f.extra = screen_extra_none
	f.extra.set_protection(true)
	output := f.format()

	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s2 := ReadonlyStream.init(mut t2)
	defer {
		s2.deinit()
	}
	s2.next_slice(output) or { panic(err) }

	assert t.screens.active.cursor.is_protected == t2.screens.active.cursor.is_protected
}

// Screen vt with kitty keyboard (roundtrip via a second terminal).
fn test_screen_vt_with_kitty_keyboard() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	// Set kitty keyboard flags (disambiguate + report_events = 3)
	s.next_slice('\x1b[=3;1uhello') or { panic(err) }

	mut f := ScreenFormatter.init(t.screens.active, format_vt)
	f.extra = screen_extra_none
	f.extra.set_kitty_keyboard(true)
	output := f.format()

	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s2 := ReadonlyStream.init(mut t2)
	defer {
		s2.deinit()
	}
	s2.next_slice(output) or { panic(err) }

	assert t.screens.active.kitty_keyboard.current() == t2.screens.active.kitty_keyboard.current()
}

// Screen vt with charsets (roundtrip via a second terminal).
fn test_screen_vt_with_charsets() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	// Set G0 to DEC special and shift to G1
	s.next_slice('\x1b(0\x0ehello') or { panic(err) }

	mut f := ScreenFormatter.init(t.screens.active, format_vt)
	f.extra = screen_extra_none
	f.extra.set_charsets(true)
	output := f.format()

	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s2 := ReadonlyStream.init(mut t2)
	defer {
		s2.deinit()
	}
	s2.next_slice(output) or { panic(err) }

	assert t.screens.active.charset.gl == t2.screens.active.charset.gl
	assert t.screens.active.charset.gr == t2.screens.active.charset.gr
	assert t.screens.active.charset.charsets.get(.g0) == t2.screens.active.charset.charsets.get(.g0)
}

// Terminal vt with tabstops (roundtrip via a second terminal).
fn test_terminal_vt_with_tabstops() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}
	// Clear all tabs and set custom tabstops
	s.next_slice('\x1b[3g') or { panic(err) }
	s.next_slice('\x1b[5G\x1bH') or { panic(err) }
	s.next_slice('\x1b[15G\x1bH') or { panic(err) }
	s.next_slice('\x1b[30G\x1bH') or { panic(err) }
	s.next_slice('hello') or { panic(err) }

	mut f := TerminalFormatter.init(&t, format_vt)
	f.extra = terminal_extra_none
	f.extra.set_tabstops(true)
	output := f.format()

	mut t2 := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s2 := ReadonlyStream.init(mut t2)
	defer {
		s2.deinit()
	}
	s2.next_slice(output) or { panic(err) }

	// Verify tabstops match (columns are 0-indexed in the API)
	for c in 0 .. int(t.cols) {
		assert t.tabstops.get(usize(c)) == t2.tabstops.get(usize(c))
	}
}
