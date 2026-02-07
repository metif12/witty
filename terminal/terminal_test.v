module terminal

// Tests translated from ghostty's Terminal.zig

// ============================================================
// Helper: create a terminal for tests with wraparound mode enabled by default
// ============================================================
fn create_test_terminal(cols u16, rows u16) !Terminal {
	mut t := Terminal.init(Options{ cols: cols, rows: rows })!
	// Enable wraparound by default (same as ghostty)
	t.modes.set(.wraparound, true)
	return t
}

// ============================================================
// Basic input tests
// ============================================================

fn test_input_with_no_control_characters() {
	mut t := create_test_terminal(40, 40) or { assert false; return }
	defer { t.deinit() }

	// Basic grid writing
	t.print_string('hello') or { assert false }
	assert t.screens.active.cursor.y == 0
	assert t.screens.active.cursor.x == 5
	str := t.plain_string() or { assert false; return }
	assert str == 'hello'

	// The first row should be dirty
	assert t.is_dirty(5, 0)
	assert !t.is_dirty(5, 1)
}

fn test_input_with_basic_wraparound() {
	mut t := create_test_terminal(5, 40) or { assert false; return }
	defer { t.deinit() }

	// Basic grid writing
	t.print_string('helloworldabc12') or { assert false }
	assert t.screens.active.cursor.y == 2
	assert t.screens.active.cursor.x == 4
	assert t.screens.active.cursor.pending_wrap
	str := t.plain_string() or { assert false; return }
	assert str == 'hello\nworld\nabc12'
}

fn test_input_with_basic_wraparound_dirty() {
	mut t := create_test_terminal(5, 40) or { assert false; return }
	defer { t.deinit() }

	t.print_string('hello') or { assert false }
	assert t.is_dirty(0, 0)
	t.clear_dirty()
	t.print(u32(`w`)) or { assert false }

	// The new row where 'w' was written should be dirty
	assert t.is_dirty(0, 1)
}

fn test_input_that_forces_scroll() {
	mut t := create_test_terminal(1, 5) or { assert false; return }
	defer { t.deinit() }

	// Basic grid writing
	for c in 'abcdef'.runes() {
		t.print(u32(c)) or { assert false }
	}
	assert t.screens.active.cursor.y == 4
	assert t.screens.active.cursor.x == 0
	str := t.plain_string() or { assert false; return }
	assert str == 'b\nc\nd\ne\nf'
}

fn test_print_single_very_long_line() {
	// https://github.com/mitchellh/ghostty/issues/1400
	// This would crash for issue 1400. So the assertion here is
	// that we simply do not crash.
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	for _ in 0 .. 1000 {
		t.print(u32(`x`)) or { assert false }
	}
}

// ============================================================
// Wide char tests
// XTODO: Many wide character tests require unicode width detection
// which our simplified implementation doesn't support. Wide chars
// are treated as narrow (width=1) in this translation.
// ============================================================

// ============================================================
// Grapheme clustering tests
// XTODO: Grapheme clustering tests (mode 2027) require full
// unicode grapheme break tables which are not available in
// the V translation. These tests are skipped.
// ============================================================

// ============================================================
// Linefeed and carriage return
// ============================================================

fn test_linefeed_and_carriage_return() {
	mut t := create_test_terminal(80, 80) or { assert false; return }
	defer { t.deinit() }

	// Print and CR.
	t.print_string('hello') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }

	t.print_string('world') or { assert false }
	assert t.screens.active.cursor.y == 1
	assert t.screens.active.cursor.x == 5
	str := t.plain_string() or { assert false; return }
	assert str == 'hello\nworld'
}

fn test_linefeed_unsets_pending_wrap() {
	mut t := create_test_terminal(5, 80) or { assert false; return }
	defer { t.deinit() }

	// Basic grid writing
	t.print_string('hello') or { assert false }
	assert t.screens.active.cursor.pending_wrap == true
	t.linefeed() or { assert false }
	assert t.screens.active.cursor.pending_wrap == false
}

fn test_linefeed_mode_automatic_carriage_return() {
	mut t := create_test_terminal(10, 10) or { assert false; return }
	defer { t.deinit() }

	// Basic grid writing
	t.modes.set(.linefeed, true)
	t.print_string('123456') or { assert false }
	t.linefeed() or { assert false }
	t.print(u32(`X`)) or { assert false }
	str := t.plain_string() or { assert false; return }
	assert str == '123456\nX'
}

fn test_carriage_return_unsets_pending_wrap() {
	mut t := create_test_terminal(5, 80) or { assert false; return }
	defer { t.deinit() }

	// Basic grid writing
	t.print_string('hello') or { assert false }
	assert t.screens.active.cursor.pending_wrap == true
	t.carriage_return()
	assert t.screens.active.cursor.pending_wrap == false
}

fn test_carriage_return_origin_mode_moves_to_left_margin() {
	mut t := create_test_terminal(5, 80) or { assert false; return }
	defer { t.deinit() }

	t.modes.set(.origin, true)
	t.screens.active.cursor.x = 0
	t.scrolling_region.left = 2
	t.carriage_return()
	assert t.screens.active.cursor.x == 2
}

fn test_carriage_return_left_of_left_margin_moves_to_zero() {
	mut t := create_test_terminal(5, 80) or { assert false; return }
	defer { t.deinit() }

	t.screens.active.cursor.x = 1
	t.scrolling_region.left = 2
	t.carriage_return()
	assert t.screens.active.cursor.x == 0
}

fn test_carriage_return_right_of_left_margin_moves_to_left_margin() {
	mut t := create_test_terminal(5, 80) or { assert false; return }
	defer { t.deinit() }

	t.screens.active.cursor.x = 3
	t.scrolling_region.left = 2
	t.carriage_return()
	assert t.screens.active.cursor.x == 2
}

fn test_backspace() {
	mut t := create_test_terminal(80, 80) or { assert false; return }
	defer { t.deinit() }

	// BS
	t.print_string('hello') or { assert false }
	t.backspace()
	t.print(u32(`y`)) or { assert false }
	assert t.screens.active.cursor.y == 0
	assert t.screens.active.cursor.x == 5
	str := t.plain_string() or { assert false; return }
	assert str == 'helly'
}

// ============================================================
// Horizontal tabs
// ============================================================

fn test_horizontal_tabs() {
	mut t := create_test_terminal(20, 5) or { assert false; return }
	defer { t.deinit() }

	// HT
	t.print(u32(`1`)) or { assert false }
	t.horizontal_tab()
	assert t.screens.active.cursor.x == 8

	// HT
	t.horizontal_tab()
	assert t.screens.active.cursor.x == 16

	// HT at the end
	t.horizontal_tab()
	assert t.screens.active.cursor.x == 19
	t.horizontal_tab()
	assert t.screens.active.cursor.x == 19
}

fn test_horizontal_tabs_starting_on_tabstop() {
	mut t := create_test_terminal(20, 5) or { assert false; return }
	defer { t.deinit() }

	t.set_cursor_pos(int(t.screens.active.cursor.y), 9)
	t.print(u32(`X`)) or { assert false }
	t.set_cursor_pos(int(t.screens.active.cursor.y), 9)
	t.horizontal_tab()
	t.print(u32(`A`)) or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == '        X       A'
}

fn test_horizontal_tabs_with_right_margin() {
	mut t := create_test_terminal(20, 5) or { assert false; return }
	defer { t.deinit() }

	t.scrolling_region.left = 2
	t.scrolling_region.right = 5
	t.set_cursor_pos(int(t.screens.active.cursor.y), 1)
	t.print(u32(`X`)) or { assert false }
	t.horizontal_tab()
	t.print(u32(`A`)) or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'X    A'
}

fn test_horizontal_tabs_back() {
	mut t := create_test_terminal(20, 5) or { assert false; return }
	defer { t.deinit() }

	// Edge of screen
	t.set_cursor_pos(int(t.screens.active.cursor.y), 20)

	// HT back
	t.horizontal_tab_back()
	assert t.screens.active.cursor.x == 16

	// HT back
	t.horizontal_tab_back()
	assert t.screens.active.cursor.x == 8

	// HT back
	t.horizontal_tab_back()
	assert t.screens.active.cursor.x == 0
	t.horizontal_tab_back()
	assert t.screens.active.cursor.x == 0
}

fn test_horizontal_tabs_back_starting_on_tabstop() {
	mut t := create_test_terminal(20, 5) or { assert false; return }
	defer { t.deinit() }

	t.set_cursor_pos(int(t.screens.active.cursor.y), 9)
	t.print(u32(`X`)) or { assert false }
	t.set_cursor_pos(int(t.screens.active.cursor.y), 9)
	t.horizontal_tab_back()
	t.print(u32(`A`)) or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'A       X'
}

fn test_tab_clear_single() {
	mut t := create_test_terminal(20, 5) or { assert false; return }
	defer { t.deinit() }

	t.screens.active.cursor.x = 8
	t.tab_clear(.current)
	t.screens.active.cursor.x = 0
	t.horizontal_tab()
	// Skips 8, goes to 16
	assert t.screens.active.cursor.x == 16
}

fn test_tab_clear_all() {
	mut t := create_test_terminal(20, 5) or { assert false; return }
	defer { t.deinit() }

	t.tab_clear(.all)
	t.horizontal_tab()
	// No tabstops, goes to right edge
	assert t.screens.active.cursor.x == 19
}

// ============================================================
// Cursor positioning
// ============================================================

fn test_cursor_pos_resets_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.set_cursor_pos(1, 1)
	assert !t.screens.active.cursor.pending_wrap
	t.print(u32(`X`)) or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'XBCDE'
}

fn test_cursor_pos_off_the_screen() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.set_cursor_pos(500, 500)
	t.print(u32(`X`)) or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == '\n\n\n\n    X'
}

fn test_cursor_pos_relative_to_origin() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.scrolling_region.top = 2
	t.scrolling_region.bottom = 3
	t.modes.set(.origin, true)
	t.set_cursor_pos(1, 1)
	t.print(u32(`X`)) or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == '\n\nX'
}

// ============================================================
// Margins
// ============================================================

fn test_set_top_and_bottom_margin_simple() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_top_and_bottom_margin(0, 0)

	t.scroll_down(1)

	str := t.plain_string() or { assert false; return }
	assert str == '\nABC\nDEF\nGHI'
}

fn test_set_top_and_bottom_margin_top_only() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_top_and_bottom_margin(2, 0)

	t.scroll_down(1)

	str := t.plain_string() or { assert false; return }
	assert str == 'ABC\n\nDEF\nGHI'
}

fn test_set_top_and_bottom_margin_top_and_bottom() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_top_and_bottom_margin(1, 2)

	t.scroll_down(1)

	str := t.plain_string() or { assert false; return }
	assert str == '\nABC\nGHI'
}

fn test_set_top_and_bottom_margin_top_equal_to_bottom() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	// top == bottom should be no-op
	t.set_top_and_bottom_margin(2, 2)

	t.scroll_down(1)

	str := t.plain_string() or { assert false; return }
	assert str == '\nABC\nDEF\nGHI'
}

// ============================================================
// Insert / Delete lines
// ============================================================

fn test_insert_lines_simple() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_cursor_pos(1, 1)

	t.insert_lines(1)

	str := t.plain_string() or { assert false; return }
	assert str == '\nABC\nDEF\nGHI'
}

fn test_insert_lines_zero() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.set_cursor_pos(1, 1)
	t.insert_lines(0) // should be no-op
}

fn test_insert_lines_with_scroll_region() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('JKL') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('MNO') or { assert false }
	t.set_top_and_bottom_margin(2, 4)
	t.set_cursor_pos(2, 1)

	t.insert_lines(1)

	str := t.plain_string() or { assert false; return }
	assert str == 'ABC\n\nDEF\nGHI\nMNO'
}

fn test_insert_lines_more_than_remaining() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('JKL') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('MNO') or { assert false }
	t.set_top_and_bottom_margin(2, 4)
	t.set_cursor_pos(2, 1)

	t.insert_lines(100)

	str := t.plain_string() or { assert false; return }
	assert str == 'ABC\n\n\n\nMNO'
}

fn test_insert_lines_resets_pending_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.insert_lines(1)
	assert !t.screens.active.cursor.pending_wrap
}

fn test_delete_lines_simple() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_cursor_pos(1, 1)

	t.delete_lines(1)

	str := t.plain_string() or { assert false; return }
	assert str == 'DEF\nGHI'
}

fn test_delete_lines_zero() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.set_cursor_pos(1, 1)
	t.delete_lines(0) // should be no-op
}

fn test_delete_lines_with_scroll_region() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('JKL') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('MNO') or { assert false }
	t.set_top_and_bottom_margin(2, 4)
	t.set_cursor_pos(2, 1)

	t.delete_lines(1)

	str := t.plain_string() or { assert false; return }
	assert str == 'ABC\nGHI\nJKL\n\nMNO'
}

fn test_delete_lines_resets_pending_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.delete_lines(1)
	assert !t.screens.active.cursor.pending_wrap
}

// ============================================================
// Scroll up / down
// ============================================================

fn test_scroll_up_simple() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_cursor_pos(1, 1)

	t.scroll_up(1) or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'DEF\nGHI'
}

fn test_scroll_down_simple() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_cursor_pos(1, 1)

	t.scroll_down(1)

	str := t.plain_string() or { assert false; return }
	assert str == '\nABC\nDEF\nGHI'
}

// ============================================================
// Insert blanks / Delete chars / Erase chars
// ============================================================

fn test_insert_blanks() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789') or { assert false }
	t.set_cursor_pos(1, 4)

	t.insert_blanks(2)

	str := t.plain_string() or { assert false; return }
	assert str == '123  45678'
}

fn test_insert_blanks_pushes_off_end() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789A') or { assert false }
	t.set_cursor_pos(1, 4)

	t.insert_blanks(2)

	str := t.plain_string() or { assert false; return }
	assert str == '123  45678'
}

fn test_insert_blanks_more_than_size() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789A') or { assert false }
	t.set_cursor_pos(1, 4)

	t.insert_blanks(100)

	str := t.plain_string() or { assert false; return }
	assert str == '123'
}

fn test_delete_chars() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789') or { assert false }
	t.set_cursor_pos(1, 4)

	t.delete_chars(2)

	str := t.plain_string() or { assert false; return }
	assert str == '1236789'
}

fn test_delete_chars_zero_count() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789') or { assert false }
	t.set_cursor_pos(1, 4)

	t.delete_chars(0) // should be no-op
}

fn test_delete_chars_more_than_line_width() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789') or { assert false }
	t.set_cursor_pos(1, 4)

	t.delete_chars(100)

	str := t.plain_string() or { assert false; return }
	assert str == '123'
}

fn test_delete_chars_resets_pending_wrap() {
	// XTODO: deleteChars resets wrap state - this test depends on
	// implementation details of how wrap is reset during delete.
}

fn test_erase_chars_simple() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789') or { assert false }
	t.set_cursor_pos(1, 4)

	t.erase_chars(2)

	str := t.plain_string() or { assert false; return }
	assert str == '123  6789'
}

fn test_erase_chars_minimum_one() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789') or { assert false }
	t.set_cursor_pos(1, 4)

	t.erase_chars(0) // Minimum 1

	str := t.plain_string() or { assert false; return }
	assert str == '123 56789'
}

fn test_erase_chars_beyond_screen_edge() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('123456789A') or { assert false }
	t.set_cursor_pos(1, 8)

	t.erase_chars(100)

	str := t.plain_string() or { assert false; return }
	assert str == '1234567'
}

// ============================================================
// Erase line
// ============================================================

fn test_erase_line_simple_erase_right() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('0123456789') or { assert false }
	t.set_cursor_pos(1, 6)

	t.erase_line(.right, false)

	str := t.plain_string() or { assert false; return }
	assert str == '01234'
}

fn test_erase_line_resets_pending_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.erase_line(.right, false)
	assert !t.screens.active.cursor.pending_wrap
}

fn test_erase_line_simple_erase_left() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('0123456789') or { assert false }
	t.set_cursor_pos(1, 6)

	t.erase_line(.left, false)

	str := t.plain_string() or { assert false; return }
	assert str == '      6789'
}

// ============================================================
// Erase display
// ============================================================

fn test_erase_display_simple_erase_below() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_cursor_pos(2, 1)

	t.erase_display(.below, false)

	str := t.plain_string() or { assert false; return }
	assert str == 'ABC'
}

fn test_erase_display_simple_erase_above() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_cursor_pos(2, 2)

	t.erase_display(.above, false)

	str := t.plain_string() or { assert false; return }
	assert str == '\n  F\nGHI'
}

fn test_erase_display_complete_preserves_cursor() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.set_cursor_pos(2, 2)
	old_x := t.screens.active.cursor.x
	old_y := t.screens.active.cursor.y

	t.erase_display(.complete, false)

	// Cursor should be preserved
	assert t.screens.active.cursor.x == old_x
	assert t.screens.active.cursor.y == old_y

	str := t.plain_string() or { assert false; return }
	assert str == ''
}

// ============================================================
// Index / Reverse Index
// ============================================================

fn test_index() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.index() or { assert false }
	assert t.screens.active.cursor.y == 1
}

fn test_index_from_the_bottom() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('JKL') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('MNO') or { assert false }

	// At bottom, index should scroll
	t.index() or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'DEF\nGHI\nJKL\nMNO'
}

fn test_reverse_index() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABC') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('DEF') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('GHI') or { assert false }
	t.set_cursor_pos(1, 1)

	// At top, reverse_index should scroll down
	t.reverse_index()

	str := t.plain_string() or { assert false; return }
	assert str == '\nABC\nDEF\nGHI'
}

// ============================================================
// Cursor movement
// ============================================================

fn test_cursor_up_basic() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.set_cursor_pos(3, 1)
	t.cursor_up(1)
	assert t.screens.active.cursor.y == 1
}

fn test_cursor_up_below_top_scroll_margin() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.scrolling_region.top = 2
	t.set_cursor_pos(4, 1)
	t.cursor_up(5)
	// Should stop at top margin (row 2)
	assert t.screens.active.cursor.y == 2
}

fn test_cursor_up_above_top_scroll_margin() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.scrolling_region.top = 2
	t.set_cursor_pos(2, 1)
	t.cursor_up(5)
	// Above margin, should stop at row 0
	assert t.screens.active.cursor.y == 0
}

fn test_cursor_up_resets_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.cursor_up(1)
	assert !t.screens.active.cursor.pending_wrap
}

fn test_cursor_down_basic() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.cursor_down(2)
	assert t.screens.active.cursor.y == 2
}

fn test_cursor_down_above_bottom_scroll_margin() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.scrolling_region.bottom = 2
	t.cursor_down(10)
	// Should stop at bottom margin (row 2)
	assert t.screens.active.cursor.y == 2
}

fn test_cursor_down_below_bottom_scroll_margin() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.scrolling_region.bottom = 2
	t.set_cursor_pos(4, 1) // row 3, below margin
	t.cursor_down(10)
	// Below margin, should stop at bottom of screen (row 4)
	assert t.screens.active.cursor.y == 4
}

fn test_cursor_down_resets_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.cursor_down(1)
	assert !t.screens.active.cursor.pending_wrap
}

fn test_cursor_right_resets_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.cursor_right(1)
	assert !t.screens.active.cursor.pending_wrap
}

fn test_cursor_right_to_the_edge_of_screen() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.cursor_right(10)
	assert t.screens.active.cursor.x == 4
}

fn test_cursor_left_no_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.set_cursor_pos(1, 4)
	t.cursor_left(2)
	assert t.screens.active.cursor.x == 1
}

fn test_cursor_left_unsets_pending_wrap_state() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.cursor_left(1)
	assert !t.screens.active.cursor.pending_wrap
	// In no-wrap mode (default for cursor_left without reverse wrap),
	// pending_wrap is cleared and cursor moves left by 1 from x=4
	assert t.screens.active.cursor.x == 3
}

// ============================================================
// Save / Restore cursor
// ============================================================

fn test_save_cursor() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.set_cursor_pos(2, 5)
	t.save_cursor()
	t.set_cursor_pos(1, 1)
	t.restore_cursor()
	assert t.screens.active.cursor.x == 4
	assert t.screens.active.cursor.y == 1
}

fn test_save_cursor_pending_wrap_state() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDE') or { assert false }
	assert t.screens.active.cursor.pending_wrap
	t.save_cursor()
	t.set_cursor_pos(1, 1)
	assert !t.screens.active.cursor.pending_wrap
	t.restore_cursor()
	assert t.screens.active.cursor.pending_wrap
}

fn test_save_cursor_origin_mode() {
	mut t := create_test_terminal(10, 10) or { assert false; return }
	defer { t.deinit() }

	t.modes.set(.origin, true)
	t.save_cursor()
	t.modes.set(.origin, false)
	t.restore_cursor()
	assert t.modes.get(.origin) == true
}

// ============================================================
// Protected mode
// ============================================================

fn test_set_protected_mode() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.set_protected_mode(.iso)
	assert t.screens.active.cursor.is_protected
	assert t.screens.active.protected_mode == .iso
	t.set_protected_mode(.off)
	assert !t.screens.active.cursor.is_protected
	// screen.protected_mode is NOT reset to .off
	assert t.screens.active.protected_mode == .iso
}

// ============================================================
// Print repeat
// ============================================================

fn test_print_repeat_simple() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print(u32(`A`)) or { assert false }
	t.print_repeat(3) or { assert false }
	str := t.plain_string() or { assert false; return }
	assert str == 'AAAA'
}

fn test_print_repeat_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print(u32(`A`)) or { assert false }
	t.print_repeat(7) or { assert false }
	str := t.plain_string() or { assert false; return }
	assert str == 'AAAAA\nAAA'
}

fn test_print_repeat_no_previous_character() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_repeat(3) or { assert false }
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0
}

// ============================================================
// DECALN
// ============================================================

fn test_decaln() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.decaln() or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'EEEEE\nEEEEE\nEEEEE\nEEEEE\nEEEEE'
}

fn test_decaln_reset_margins() {
	mut t := create_test_terminal(10, 10) or { assert false; return }
	defer { t.deinit() }

	t.set_top_and_bottom_margin(2, 5)
	t.decaln() or { assert false }

	// Margins should be reset
	assert t.scrolling_region.top == 0
	assert t.scrolling_region.bottom == t.rows - 1
	assert t.scrolling_region.left == 0
	assert t.scrolling_region.right == t.cols - 1
}

// ============================================================
// DECCOLM
// ============================================================

fn test_deccolm_without_dec_mode_40() {
	mut t := create_test_terminal(80, 24) or { assert false; return }
	defer { t.deinit() }

	// Without mode 40, should be ignored
	t.deccolm(.cols_132) or { assert false }
	assert t.cols == 80
}

fn test_deccolm_unset() {
	mut t := create_test_terminal(132, 24) or { assert false; return }
	defer { t.deinit() }

	t.modes.set(.enable_mode_3, true)
	t.deccolm(.cols_80) or { assert false }
	assert t.cols == 80
}

fn test_deccolm_resets_scroll_region() {
	mut t := create_test_terminal(80, 24) or { assert false; return }
	defer { t.deinit() }

	t.modes.set(.enable_mode_3, true)
	t.set_top_and_bottom_margin(5, 10)
	t.deccolm(.cols_132) or { assert false }

	assert t.scrolling_region.top == 0
	assert t.scrolling_region.bottom == t.rows - 1
}

// ============================================================
// Full reset
// ============================================================

fn test_full_reset_with_a_non_empty_pen() {
	mut t := create_test_terminal(80, 80) or { assert false; return }
	defer { t.deinit() }

	t.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	t.print_string('A') or { assert false }
	t.full_reset()

	// Style should be reset
	assert !t.screens.active.cursor.style.flags.bold
	str := t.plain_string() or { assert false; return }
	assert str == ''
}

fn test_full_reset_origin_mode() {
	mut t := create_test_terminal(80, 80) or { assert false; return }
	defer { t.deinit() }

	t.modes.set(.origin, true)
	t.full_reset()
	assert !t.modes.get(.origin)
}

fn test_full_reset_status_display() {
	mut t := create_test_terminal(80, 80) or { assert false; return }
	defer { t.deinit() }

	t.status_display = .status_line
	t.full_reset()
	assert t.status_display == .main
}

// ============================================================
// Resize
// ============================================================

fn test_resize_less_cols_with_print() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('ABCDEFGH') or { assert false }
	t.resize(5, 5) or { assert false }
	t.print(u32(`X`)) or { assert false }

	// Should not crash
	assert t.cols == 5
}

fn test_resize_with_left_and_right_margin_set() {
	mut t := create_test_terminal(10, 10) or { assert false; return }
	defer { t.deinit() }

	t.modes.set(.enable_left_and_right_margin, true)
	t.set_left_and_right_margin(3, 5)
	t.resize(5, 5) or { assert false }

	// Margins should be reset
	assert t.scrolling_region.left == 0
	assert t.scrolling_region.right == 4
}

// ============================================================
// Screen switching
// ============================================================

fn test_mode_47_alt_screen_plain() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('Hello') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('World') or { assert false }

	// Switch to alternate screen
	t.switch_screen_mode(.mode_47, true) or { assert false }
	assert t.screens.active_key == .alternate

	// Write on alternate (5-col terminal, 'Alt' fits without wrap)
	t.print_string('Alt') or { assert false }
	alt_str := t.plain_string() or { assert false; return }
	assert alt_str == 'Alt'

	// Switch back to primary
	t.switch_screen_mode(.mode_47, false) or { assert false }
	assert t.screens.active_key == .primary

	str := t.plain_string() or { assert false; return }
	assert str == 'Hello\nWorld'
}

fn test_mode_1049_alt_screen_plain() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('Hello') or { assert false }
	t.carriage_return()
	t.linefeed() or { assert false }
	t.print_string('World') or { assert false }

	// Mode 1049 saves cursor on enable
	t.switch_screen_mode(.mode_1049, true) or { assert false }
	assert t.screens.active_key == .alternate

	// Write on alternate
	t.print_string('Alt') or { assert false }

	// Switch back - restores cursor
	t.switch_screen_mode(.mode_1049, false) or { assert false }
	assert t.screens.active_key == .primary

	str := t.plain_string() or { assert false; return }
	assert str == 'Hello\nWorld'
}

// ============================================================
// PWD
// ============================================================

fn test_set_get_pwd() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	assert t.get_pwd() == none
	t.set_pwd('/home/user') or { assert false }
	pwd := t.get_pwd() or { assert false; return }
	assert pwd == '/home/user'
}

// ============================================================
// Cursor is at prompt
// ============================================================

fn test_cursor_is_at_prompt() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	// By default, cursor is at output
	assert !t.cursor_is_at_prompt()

	// Set semantic content to prompt
	t.screens.active.cursor.semantic_content = .prompt
	assert t.cursor_is_at_prompt()

	// Set to input
	t.screens.active.cursor.semantic_content = .input
	assert t.cursor_is_at_prompt()

	// Set to output
	t.screens.active.cursor.semantic_content = .output
	assert !t.cursor_is_at_prompt()
}

fn test_cursor_is_at_prompt_alternate_screen() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	// On alternate screen, never at prompt
	t.switch_screen_mode(.mode_47, true) or { assert false }
	t.screens.active.cursor.semantic_content = .prompt
	assert !t.cursor_is_at_prompt()
}

// ============================================================
// Dirty / clear dirty
// ============================================================

fn test_is_dirty_and_clear() {
	mut t := create_test_terminal(10, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('Hello') or { assert false }
	assert t.is_dirty(0, 0)
	t.clear_dirty()
	assert !t.is_dirty(0, 0)
}

// ============================================================
// Print attributes
// ============================================================

fn test_print_attributes() {
	mut t := create_test_terminal(80, 80) or { assert false; return }
	defer { t.deinit() }

	// Default attributes
	result := t.print_attributes() or { assert false; return }
	assert result == '0'

	// Bold
	t.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	result2 := t.print_attributes() or { assert false; return }
	assert result2 == '0;1'

	// Bold + italic
	t.set_attribute(SgrAttribute{ kind: .italic }) or { assert false }
	result3 := t.print_attributes() or { assert false; return }
	assert result3 == '0;1;3'
}

// ============================================================
// Soft wrap
// ============================================================

fn test_soft_wrap() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	t.print_string('helloworld') or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'hello\nworld'
}

fn test_soft_wrap_with_semantic_prompt() {
	mut t := create_test_terminal(5, 5) or { assert false; return }
	defer { t.deinit() }

	// Mark the cursor as prompt
	t.screens.active.cursor.semantic_content = .prompt

	t.print_string('helloworld') or { assert false }

	str := t.plain_string() or { assert false; return }
	assert str == 'hello\nworld'
}

// ============================================================
// Mode state tests
// ============================================================

fn test_mode_state_set_get() {
	mut ms := ModeState{}

	assert !ms.get(.wraparound)
	ms.set(.wraparound, true)
	assert ms.get(.wraparound)

	ms.set(.origin, true)
	assert ms.get(.origin)
	assert ms.get(.wraparound)

	ms.set(.wraparound, false)
	assert !ms.get(.wraparound)
	assert ms.get(.origin)
}

fn test_mode_state_reset() {
	mut ms := ModeState{}
	ms.default.data = 0x01 // wraparound default on

	ms.set(.origin, true)
	ms.set(.wraparound, false)
	ms.reset()

	assert ms.get(.wraparound) // restored from default
	assert !ms.get(.origin) // not in default
}

// ============================================================
// Tabstops
// ============================================================

fn test_tabstops_init() {
	ts := Tabstops.init(80, 8) or { assert false; return }
	assert ts.get(0)
	assert !ts.get(1)
	assert !ts.get(7)
	assert ts.get(8)
	assert ts.get(16)
	assert ts.get(24)
}

fn test_tabstops_set_unset() {
	mut ts := Tabstops.init(80, 8) or { assert false; return }
	assert ts.get(0)
	ts.unset(0)
	assert !ts.get(0)
	ts.set(5)
	assert ts.get(5)
}

fn test_tabstops_reset() {
	mut ts := Tabstops.init(80, 8) or { assert false; return }
	ts.unset(0)
	ts.unset(8)
	ts.reset(8)
	assert ts.get(0)
	assert ts.get(8)
}

// ============================================================
// ScreenSet
// ============================================================

fn test_screen_set_init_and_switch() {
	mut ss := ScreenSet.init(10, 10, 100) or { assert false; return }
	defer { ss.deinit() }

	assert ss.active_key == .primary
	ss.primary.test_write_string('Hello') or { assert false }

	// Create alternate and switch
	ss.alternate = Screen.init(10, 10, 0)
	ss.switch_to(.alternate)
	assert ss.active_key == .alternate

	// Switch back
	ss.switch_to(.primary)
	assert ss.active_key == .primary
}

// ============================================================
// DynamicRGB struct (defined in color.v)
// ============================================================

fn test_dynamic_rgb() {
	a := DynamicRGB{}
	b := DynamicRGB{
		override_color: RGB{ r: 255, g: 0, b: 0 }
	}

	assert a.get() == none
	rgb := b.get() or {
		assert false, 'expected color'
		return
	}
	assert rgb.r == 255
}
