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
	assert output == '<div style="font-family: monospace; white-space: pre;">hello, world</div>',
		'HTML should wrap in monospace div'
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
	for i, ch in '<tag>&"\x27text'.runes() {
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
// cell_is_empty helper
// ============================================================

fn test_cell_is_empty() {
	// Default cell is empty
	assert cell_is_empty(CellData{}) == true

	// Cell with a codepoint tag but 0 codepoint and no style
	assert cell_is_empty(CellData{ content_tag: .codepoint, codepoint: 0, style_id: 0 }) == false

	// Cell with style
	assert cell_is_empty(CellData{ style_id: 1 }) == false
}

// ============================================================
// cell_style_eql helper
// ============================================================

fn test_cell_style_eql() {
	a := CellStyle{}
	b := CellStyle{}
	assert cell_style_eql(a, b) == true

	c := CellStyle{
		flags: StyleFlags{ bold: true }
	}
	assert cell_style_eql(a, c) == false
	assert cell_style_eql(c, c) == true
}

// ============================================================
// CellStyle.default()
// ============================================================

fn test_cell_style_default() {
	assert CellStyle{}.default() == true
	assert CellStyle{ flags: StyleFlags{ bold: true } }.default() == false
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
	s2 := format_style_vt(CellStyle{ flags: StyleFlags{ bold: true } })
	assert s2 == '\x1b[0m\x1b[1m'

	// Bold + italic
	s3 := format_style_vt(CellStyle{
		flags: StyleFlags{ bold: true, italic: true }
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
	assert ScreenExtra{ cursor: true }.is_set() == true
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
	for i, ch in 'hello'.runes() {
		idx := t.screens.primary.pages.active_start
		t.screens.primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		t.screens.primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}
	for i, ch in 'world'.runes() {
		idx := t.screens.primary.pages.active_start + 1
		t.screens.primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		t.screens.primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
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
	// Modify a palette color
	t.colors.palette.entries[0] = RGB{ r: 0x12, g: 0x34, b: 0x56 }
	t.colors.palette.entries[1] = RGB{ r: 0xab, g: 0xcd, b: 0xef }

	for i, ch in 'test'.runes() {
		idx := t.screens.primary.pages.active_start
		t.screens.primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		t.screens.primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
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
	t.colors.palette.entries[0] = RGB{ r: 0x12, g: 0x34, b: 0x56 }
	t.colors.palette.entries[1] = RGB{ r: 0xab, g: 0xcd, b: 0xef }
	t.colors.palette.entries[255] = RGB{ r: 0xff, g: 0x00, b: 0xff }

	for i, ch in 'test'.runes() {
		idx := t.screens.primary.pages.active_start
		t.screens.primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		t.screens.primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, FormatOptions{ emit: .html })
	formatter.extra = TerminalExtra{
		palette: true
		screen: screen_extra_none
	}
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
	// Set scrolling region: top=5, bottom=20
	t.scrolling_region.top = 5
	t.scrolling_region.bottom = 20

	for i, ch in 'hello'.runes() {
		idx := t.screens.primary.pages.active_start
		t.screens.primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		t.screens.primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra = TerminalExtra{
		scrolling_region: true
		screen: screen_extra_none
	}
	output := formatter.format()

	// Should contain DECSTBM sequence
	assert output.contains('\x1b[6;21r'), 'should contain DECSTBM with 1-indexed values'
}

// ============================================================
// Terminal VT with keyboard modes
// ============================================================

fn test_terminal_vt_keyboard_modes() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	t.flags.modify_other_keys_2 = true

	for i, ch in 'hello'.runes() {
		idx := t.screens.primary.pages.active_start
		t.screens.primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		t.screens.primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra = TerminalExtra{
		keyboard: true
		screen: screen_extra_none
	}
	output := formatter.format()

	assert output.contains('\x1b[>4;2m'), 'should contain modify other keys mode 2'
}

// ============================================================
// Terminal VT with pwd
// ============================================================

fn test_terminal_vt_pwd() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	t.pwd = 'file://host/home/user'

	for i, ch in 'hello'.runes() {
		idx := t.screens.primary.pages.active_start
		t.screens.primary.pages.screen_rows[idx].cells[i].codepoint = u32(ch)
		t.screens.primary.pages.screen_rows[idx].cells[i].content_tag = .codepoint
	}

	mut formatter := TerminalFormatter.init(&t, format_vt)
	formatter.extra = TerminalExtra{
		pwd: true
		screen: screen_extra_none
	}
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
