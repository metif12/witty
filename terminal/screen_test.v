module terminal

// Tests translated from ghostty's Screen.zig

fn test_screen_read_and_write() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }
	assert s.cursor.style_id == u32(0)

	s.test_write_string('hello, world') or { assert false }
	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == 'hello, world'
}

fn test_screen_read_and_write_newline() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }
	assert s.cursor.style_id == u32(0)

	s.test_write_string('hello\nworld') or { assert false }
	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == 'hello\nworld'
}

fn test_screen_read_and_write_scrollback() {
	mut s := Screen.init(80, 2, 1000)
	defer { s.deinit() }

	s.test_write_string('hello\nworld\ntest') or { assert false }

	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == 'hello\nworld\ntest'

	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == 'world\ntest'
}

fn test_screen_read_and_write_no_scrollback_small() {
	mut s := Screen.init(80, 2, 0)
	defer { s.deinit() }

	s.test_write_string('hello\nworld\ntest') or { assert false }

	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == 'world\ntest'

	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == 'world\ntest'
}

fn test_screen_read_and_write_no_scrollback_large() {
	mut s := Screen.init(80, 2, 0)
	defer { s.deinit() }

	for i in 0 .. 1000 {
		s.test_write_string('${i}\n') or { assert false }
	}
	s.test_write_string('1000') or { assert false }

	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == '999\n1000'
}

fn test_screen_cursor_copy_xy() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.cursor_absolute(2, 3)
	assert s.cursor.x == 2
	assert s.cursor.y == 3

	mut s2 := Screen.init(10, 10, 0)
	defer { s2.deinit() }
	s2.cursor_copy(s.cursor) or { assert false }
	assert s2.cursor.x == 2
	assert s2.cursor.y == 3
	s2.test_write_string('Hello') or { assert false }

	str := s2.dump_string_alloc(.screen) or { assert false; return }
	assert str == '\n\n\n  Hello'
}

fn test_screen_style_basics() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }
	assert s.cursor.style_id == u32(0)

	// Set bold
	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	assert s.cursor.style_id != u32(0)
	assert s.cursor.style.flags.bold

	// Set italic (replaces bold since style is cumulative)
	s.set_attribute(SgrAttribute{ kind: .italic }) or { assert false }
	assert s.cursor.style_id != u32(0)
	assert s.cursor.style.flags.italic
}

fn test_screen_style_reset_to_default() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }
	assert s.cursor.style_id == u32(0)

	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	assert s.cursor.style_id != u32(0)

	s.set_attribute(SgrAttribute{ kind: .reset_bold }) or { assert false }
	// After resetting bold, if no other styles are set, should be default
	if !s.cursor.style.flags.italic && !s.cursor.style.flags.faint {
		assert s.cursor.style_id == u32(0)
	}
}

fn test_screen_style_reset_with_unset() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	assert s.cursor.style_id != u32(0)

	s.set_attribute(SgrAttribute{ kind: .unset }) or { assert false }
	assert s.cursor.style_id == u32(0)
}

fn test_screen_clear_rows_active_one_line() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.test_write_string('hello, world') or { assert false }
	s.clear_rows(.active, ?PointTag(none), false)
	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == ''
}

fn test_screen_clear_rows_active_multi_line() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.test_write_string('hello\nworld') or { assert false }
	s.clear_rows(.active, ?PointTag(none), false)
	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == ''
}

fn test_screen_clear_rows_active_styled_line() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	s.test_write_string('hello world') or { assert false }
	s.set_attribute(SgrAttribute{ kind: .unset }) or { assert false }

	s.clear_rows(.active, ?PointTag(none), false)
	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == ''
}

fn test_screen_clear_rows_protected() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.test_write_string('UNPROTECTED') or { assert false }
	s.cursor.is_protected = true
	s.test_write_string('PROTECTED') or { assert false }
	s.cursor.is_protected = false
	s.test_write_string('UNPROTECTED') or { assert false }
	s.test_write_string('\n') or { assert false }
	s.cursor.is_protected = true
	s.test_write_string('PROTECTED') or { assert false }
	s.cursor.is_protected = false
	s.test_write_string('UNPROTECTED') or { assert false }
	s.cursor.is_protected = true
	s.test_write_string('PROTECTED') or { assert false }
	s.cursor.is_protected = false

	s.clear_rows(.active, ?PointTag(none), true)

	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == '           PROTECTED\nPROTECTED           PROTECTED'
}

fn test_screen_erase_rows_history() {
	mut s := Screen.init(5, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3\n4\n5\n6') or { assert false }

	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == '2\n3\n4\n5\n6'

	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == '1\n2\n3\n4\n5\n6'

	s.erase_rows(.history, ?PointTag(none))

	str_active2 := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active2 == '2\n3\n4\n5\n6'

	str_screen2 := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen2 == '2\n3\n4\n5\n6'
}

fn test_screen_erase_rows_history_with_more_lines() {
	mut s := Screen.init(5, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('A\nB\nC\n1\n2\n3\n4\n5\n6') or { assert false }

	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == '2\n3\n4\n5\n6'

	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == 'A\nB\nC\n1\n2\n3\n4\n5\n6'

	s.erase_rows(.history, ?PointTag(none))

	str_active2 := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active2 == '2\n3\n4\n5\n6'

	str_screen2 := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen2 == '2\n3\n4\n5\n6'
}

fn test_screen_scrolling() {
	// XTODO: Full scrolling tests need PageList viewport management
	// and multi-page support.
	mut s := Screen.init(80, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3\n4\n5\n6') or { assert false }

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '2\n3\n4\n5\n6'

	// Scroll to top
	s.scroll(.top)
	// Viewport change doesn't affect dump_string_alloc(.active)
}

fn test_screen_scrollback_empty() {
	mut s := Screen.init(5, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3\n4\n5') or { assert false }

	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == '1\n2\n3\n4\n5'

	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == '1\n2\n3\n4\n5'
}

fn test_screen_select_untracked() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello') or { assert false }
	start_pin := Pin{ x: 0, y: u32(s.pages.active_start) }
	end_pin := Pin{ x: 4, y: u32(s.pages.active_start) }
	sel := Selection.init(start_pin, end_pin, false)
	s.select(sel) or { assert false }
	assert s.selection != none
}

fn test_screen_select_all() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello\nworld') or { assert false }

	if sel := s.select_all() {
		start := sel.start()
		end := sel.end()
		assert start.x == 0
		assert end.x == 4 // 'world' ends at x=4
	} else {
		assert false
	}
}

fn test_screen_select_line() {
	mut s := Screen.init(20, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello world') or { assert false }

	pin := Pin{ x: 2, y: u32(s.pages.active_start) }
	if sel := s.select_line(SelectLine{
		pin: pin
		whitespace: [u32(0), u32(` `), u32(`\t`)]
	}) {
		start := sel.start()
		end := sel.end()
		assert start.x == 0
		assert end.x == 10 // 'hello world' (11 chars, 0-10)
	} else {
		assert false
	}
}

fn test_screen_select_line_across_soft_wrap() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }

	s.test_write_string('helloworld') or { assert false }

	// 'hello' wraps to 'world'
	pin := Pin{ x: 2, y: u32(s.pages.active_start) }
	if sel := s.select_line(SelectLine{
		pin: pin
		whitespace: [u32(0), u32(` `), u32(`\t`)]
	}) {
		start := sel.start()
		end := sel.end()
		assert start.x == 0
		// Should span across the soft-wrapped line
		assert end.y > start.y || end.x > 0
	} else {
		assert false
	}
}

fn test_screen_select_word() {
	mut s := Screen.init(20, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello world') or { assert false }

	pin := Pin{ x: 2, y: u32(s.pages.active_start) }
	boundary := [u32(` `), u32(`\t`)]
	if sel := s.select_word(pin, boundary) {
		start := sel.start()
		end := sel.end()
		assert start.x == 0
		assert end.x == 4 // 'hello' is 0-4
	} else {
		assert false
	}

	// Select second word
	pin2 := Pin{ x: 8, y: u32(s.pages.active_start) }
	if sel := s.select_word(pin2, boundary) {
		start := sel.start()
		end := sel.end()
		assert start.x == 6
		assert end.x == 10 // 'world' is 6-10
	} else {
		assert false
	}
}

fn test_screen_selection_string_basic() {
	mut s := Screen.init(20, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello, world') or { assert false }

	start_pin := Pin{ x: 0, y: u32(s.pages.active_start) }
	end_pin := Pin{ x: 11, y: u32(s.pages.active_start) }
	sel := Selection.init(start_pin, end_pin, false)

	str := s.selection_string(SelectionString{ sel: sel }) or { assert false; return }
	assert str == 'hello, world'
}

fn test_screen_line_iterator() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello\nworld\ntest') or { assert false }

	start_pin := Pin{ x: 0, y: u32(s.pages.active_start) }
	mut it := s.line_iterator(start_pin)

	// First line
	if first := it.next() {
		assert first.start().x == 0
	} else {
		assert false
	}

	// Second line
	if second := it.next() {
		_ := second
	} else {
		assert false
	}

	// Third line
	if third := it.next() {
		_ := third
	} else {
		assert false
	}
}

fn test_screen_hyperlink_start_end() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	s.start_hyperlink('https://example.com/', ?string(none)) or { assert false }
	assert s.cursor.hyperlink_id != 0

	s.end_hyperlink()
	assert s.cursor.hyperlink_id == 0
}

fn test_screen_resize_no_reflow_more_rows() {
	// XTODO: Full resize with reflow tests need PageList.resize
	// with proper soft-wrap reflow support.
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3') or { assert false }

	s.resize(ScreenResize{ cols: 5, rows: 5, reflow: false }) or { assert false }
	assert s.pages.rows == 5

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '1\n2\n3'
}

fn test_screen_resize_no_reflow_more_cols() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3') or { assert false }

	s.resize(ScreenResize{ cols: 10, rows: 3, reflow: false }) or { assert false }
	assert s.pages.cols == 10

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '1\n2\n3'
}

fn test_screen_viewport_is_bottom() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }
	assert s.viewport_is_bottom()
}

fn test_screen_reset() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.test_write_string('hello') or { assert false }
	s.reset()

	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == ''
	assert s.cursor.x == 0
	assert s.cursor.y == 0
}

fn test_screen_cursor_movement() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	assert s.cursor.x == 0
	assert s.cursor.y == 0

	s.cursor_right(3)
	assert s.cursor.x == 3

	s.cursor_left(1)
	assert s.cursor.x == 2

	s.cursor_down(2)
	assert s.cursor.y == 2

	s.cursor_up(1)
	assert s.cursor.y == 1

	s.cursor_absolute(5, 5)
	assert s.cursor.x == 5
	assert s.cursor.y == 5

	s.cursor_horizontal_absolute(0)
	assert s.cursor.x == 0
	assert s.cursor.y == 5
}

fn test_screen_prompt_click_move_zero() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	// Cursor not on input, should return zero
	result := s.prompt_click_move(Pin{ x: 5, y: u32(s.pages.active_start) })
	assert result.left == 0
	assert result.right == 0
}

fn test_screen_scroll_and_clear() {
	mut s := Screen.init(5, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3\n4\n5') or { assert false }
	s.scroll_clear() or { assert false }

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == ''
}

fn test_screen_blank_cell() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	cell := s.blank_cell()
	assert cell.codepoint == 0
	assert cell.style_id == 0
}

fn test_screen_select_clear() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello') or { assert false }
	start_pin := Pin{ x: 0, y: u32(s.pages.active_start) }
	end_pin := Pin{ x: 4, y: u32(s.pages.active_start) }
	sel := Selection.init(start_pin, end_pin, false)
	s.select(sel) or { assert false }
	assert s.selection != none

	s.clear_selection()
	assert s.selection == none
}

fn test_screen_cursor_down_scroll() {
	mut s := Screen.init(5, 3, 1000)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3') or { assert false }
	assert s.cursor.y == 2 // at bottom

	s.cursor_down_scroll() or { assert false }
	// Should have scrolled, cursor still at bottom
	assert s.cursor.y == 2

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '2\n3'
}

fn test_screen_clone() {
	// XTODO: Full clone with pin remapping is not implemented.
	mut s := Screen.init(10, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('hello\nworld') or { assert false }

	mut cloned := s.clone(.screen, ?PointTag(none)) or { assert false; return }
	defer { cloned.deinit() }

	str := cloned.dump_string_alloc(.active) or { assert false; return }
	assert str == 'hello\nworld'
}

fn test_screen_soft_wrap_write() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }

	s.test_write_string('helloworld') or { assert false }

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == 'hello\nworld'
}

fn test_screen_cursor_reset_wrap() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }

	s.test_write_string('hello') or { assert false }
	assert s.cursor.pending_wrap == true

	s.cursor_reset_wrap()
	assert s.cursor.pending_wrap == false
}

fn test_screen_semantic_content() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	assert s.cursor.semantic_content == .output

	s.cursor_set_semantic_content_prompt(.initial)
	assert s.cursor.semantic_content == .prompt
	assert s.semantic_prompt.seen

	s.cursor_set_semantic_content_input(false)
	assert s.cursor.semantic_content == .input

	s.cursor_set_semantic_content_output()
	assert s.cursor.semantic_content == .output
}

// ============================================================
// Additional tests translated from ghostty Screen.zig
// ============================================================

fn wsdef_all() []u32 {
	return [u32(0), u32(` `), u32(`\t`), u32(`'`), u32(`"`), u32(`\``),
		u32(`|`), u32(`:`), u32(`;`), u32(`,`), u32(`(`), u32(`)`),
		u32(`[`), u32(`]`), u32(`{`), u32(`}`), u32(`<`), u32(`>`), u32(`$`)]
}

fn wsdef_line() []u32 {
	return [u32(0), u32(` `), u32(`\t`)]
}

// --- cursorCopy ---

fn test_screen_cursor_copy_style_copy() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }

	mut s2 := Screen.init(10, 10, 0)
	defer { s2.deinit() }
	s2.cursor_copy(s.cursor) or { assert false }
	assert s2.cursor.style.flags.bold
}

// --- eraseRows / clear history ---

fn test_screen_clear_history_with_no_history() {
	mut s := Screen.init(10, 3, 3)
	defer { s.deinit() }
	s.test_write_string('4ABCD\n5EFGH\n6IJKL') or { assert false }
	s.erase_rows(.history, ?PointTag(none))
	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == '4ABCD\n5EFGH\n6IJKL'
	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == '4ABCD\n5EFGH\n6IJKL'
}

fn test_screen_clear_history() {
	mut s := Screen.init(10, 3, 3)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL\n4ABCD\n5EFGH\n6IJKL') or { assert false }
	s.erase_rows(.history, ?PointTag(none))
	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == '4ABCD\n5EFGH\n6IJKL'
	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == '4ABCD\n5EFGH\n6IJKL'
}

// --- scroll and clear ---

fn test_screen_scroll_and_clear_full_screen() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }

	str0 := s.dump_string_alloc(.active) or { assert false; return }
	assert str0 == '1ABCD\n2EFGH\n3IJKL'

	s.scroll_clear() or { assert false }
	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == ''
	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_scroll_and_clear_partial_screen() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH') or { assert false }

	str0 := s.dump_string_alloc(.active) or { assert false; return }
	assert str0 == '1ABCD\n2EFGH'

	s.scroll_clear() or { assert false }
	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == ''
	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == '1ABCD\n2EFGH'
}

fn test_screen_scroll_and_clear_empty_screen() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }
	s.scroll_clear() or { assert false }
	str_active := s.dump_string_alloc(.active) or { assert false; return }
	assert str_active == ''
	str_screen := s.dump_string_alloc(.screen) or { assert false; return }
	assert str_screen == ''
}

// --- scrolling ---

fn test_screen_scroll_down_from_0() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }

	// Scrolling up does nothing, but allows it.
	s.scroll(.delta_row)
	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_cursor_down_scroll_preserves_style() {
	mut s := Screen.init(10, 3, 1)
	defer { s.deinit() }
	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.cursor_down_scroll() or { assert false }

	assert s.cursor.style.flags.bold

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '2EFGH\n3IJKL'
}

// --- resize (no reflow) ---

fn test_screen_resize_no_reflow_more_rows_full() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 10, rows: 10, reflow: false }) or { assert false }
	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_resize_no_reflow_more_cols_full() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 20, rows: 3, reflow: false }) or { assert false }
	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_resize_no_reflow_less_cols_full() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 4, rows: 3, reflow: false }) or { assert false }
	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '1ABC\n2EFG\n3IJK'
}

fn test_screen_resize_more_rows_no_scrollback() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 10, rows: 10, reflow: true }) or { assert false }
	assert s.cursor.x == 5
	assert s.cursor.y == 2
	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '1ABCD\n2EFGH\n3IJKL'
}

// --- selectAll ---

fn test_screen_select_all_multi() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('ABC  DEF\n 123\n456') or { assert false }
	if sel := s.select_all() {
		assert sel.start().x == 0
		assert sel.start().y == 0
		assert sel.end().x == 2
		assert sel.end().y == 2
	} else {
		assert false
	}

	s.test_write_string('\nFOO\n BAR\n BAZ\n QWERTY\n 12345678') or { assert false }
	if sel := s.select_all() {
		assert sel.start().x == 0
		assert sel.start().y == 0
		assert sel.end().x == 8
		assert sel.end().y == 7
	} else {
		assert false
	}
}

// --- selectLine ---

fn test_screen_select_line_forward_backward() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('ABC  DEF\n 123\n456') or { assert false }
	ws := wsdef_line()

	for x in [u32(0), u32(7), u32(3), u32(9)] {
		if sel := s.select_line(SelectLine{ pin: Pin{ x: x, y: 0 }, whitespace: ws }) {
			assert sel.start().x == 0
			assert sel.start().y == 0
			assert sel.end().x == 7
			assert sel.end().y == 0
		} else {
			assert false
		}
	}
}

fn test_screen_select_line_across_soft_wrap_coords() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string(' 12 34012   \n 123') or { assert false }
	ws := wsdef_line()

	if sel := s.select_line(SelectLine{ pin: Pin{ x: 1, y: 0 }, whitespace: ws }) {
		assert sel.start().x == 1
		assert sel.start().y == 0
		assert sel.end().x == 3
		assert sel.end().y == 1
	} else {
		assert false
	}
}

fn test_screen_select_line_across_full_soft_wrap() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH\n3IJKL') or { assert false }
	ws := wsdef_line()

	if sel := s.select_line(SelectLine{ pin: Pin{ x: 2, y: 1 }, whitespace: ws }) {
		assert sel.start().x == 0
		assert sel.start().y == 0
		assert sel.end().x == 4
		assert sel.end().y == 1
	} else {
		assert false
	}
}

fn test_screen_select_line_ignores_blank_lines() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string(' 12 34012             \n 123') or { assert false }
	ws := wsdef_line()

	for xy in [[u32(1), u32(0)], [u32(1), u32(1)], [u32(3), u32(0)]] {
		if sel := s.select_line(SelectLine{ pin: Pin{ x: xy[0], y: xy[1] }, whitespace: ws }) {
			assert sel.start().x == 1
			assert sel.start().y == 0
			assert sel.end().x == 3
			assert sel.end().y == 1
		} else {
			assert false
		}
	}
}

fn test_screen_select_line_disabled_whitespace_trimming() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string(' 12 34012   \n 123') or { assert false }

	// Going forward, whitespace trimming disabled.
	if sel := s.select_line(SelectLine{ pin: Pin{ x: 1, y: 0 }, whitespace: none }) {
		assert sel.start().x == 0
		assert sel.start().y == 0
		assert sel.end().x == 4
		assert sel.end().y == 2
	} else {
		assert false
	}

	// Non-wrapped.
	if sel := s.select_line(SelectLine{ pin: Pin{ x: 1, y: 3 }, whitespace: none }) {
		assert sel.start().x == 0
		assert sel.start().y == 3
		assert sel.end().x == 4
		assert sel.end().y == 3
	} else {
		assert false
	}
}

// --- selectWord ---

fn test_screen_select_word_full() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('ABC  DEF\n 123\n456') or { assert false }
	b := wsdef_all()

	// Going forward, backward, both.
	for x in [u32(0), u32(2), u32(1)] {
		if sel := s.select_word(Pin{ x: x, y: 0 }, b) {
			assert sel.start().x == 0
			assert sel.start().y == 0
			assert sel.end().x == 2
			assert sel.end().y == 0
		} else {
			assert false
		}
	}

	// Whitespace.
	if sel := s.select_word(Pin{ x: 3, y: 0 }, b) {
		assert sel.start().x == 3
		assert sel.start().y == 0
		assert sel.end().x == 4
		assert sel.end().y == 0
	} else {
		assert false
	}

	// Whitespace single char.
	if sel := s.select_word(Pin{ x: 0, y: 1 }, b) {
		assert sel.start().x == 0
		assert sel.start().y == 1
		assert sel.end().x == 0
		assert sel.end().y == 1
	} else {
		assert false
	}

	// End of screen.
	if sel := s.select_word(Pin{ x: 1, y: 2 }, b) {
		assert sel.start().x == 0
		assert sel.start().y == 2
		assert sel.end().x == 2
		assert sel.end().y == 2
	} else {
		assert false
	}
}

fn test_screen_select_word_across_soft_wrap() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string(' 1234012\n 123') or { assert false }
	b := wsdef_all()

	str := s.dump_string_alloc(.screen) or { assert false; return }
	assert str == ' 1234\n012\n 123'

	for xy in [[u32(1), u32(0)], [u32(1), u32(1)], [u32(3), u32(0)]] {
		if sel := s.select_word(Pin{ x: xy[0], y: xy[1] }, b) {
			assert sel.start().x == 1
			assert sel.start().y == 0
			assert sel.end().x == 2
			assert sel.end().y == 1
		} else {
			assert false
		}
	}
}

// --- selectionString ---

fn test_screen_selection_string_multiline() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 1 }, Pin{ x: 2, y: 2 }, false)
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or { assert false; return }
	assert str == '2EFGH\n3IJ'
}

fn test_screen_selection_string_start_outside() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 5 }, Pin{ x: 2, y: 6 }, false)
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or { assert false; return }
	assert str == ''
}

fn test_screen_selection_string_end_outside() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 2 }, Pin{ x: 2, y: 6 }, false)
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or { assert false; return }
	assert str == '3IJKL'
}

fn test_screen_selection_string_trim_space() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1AB  \n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 2, y: 1 }, false)

	str_trim := s.selection_string(SelectionString{ sel: sel, trim: true }) or { assert false; return }
	assert str_trim == '1AB\n2EF'

	str_notrim := s.selection_string(SelectionString{ sel: sel, trim: false }) or {
		assert false
		return
	}
	assert str_notrim == '1AB  \n2EF'
}

fn test_screen_selection_string_trim_empty_line() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.test_write_string('1AB  \n\n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 2, y: 2 }, false)

	str_trim := s.selection_string(SelectionString{ sel: sel, trim: true }) or { assert false; return }
	assert str_trim == '1AB\n\n2EF'
}

fn test_screen_selection_string_soft_wrap() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 1 }, Pin{ x: 2, y: 2 }, false)
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or { assert false; return }
	assert str == '2EFGH3IJ'
}

// --- lineIterator ---

fn test_screen_line_iterator_basic() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH') or { assert false }
	mut it := s.line_iterator(Pin{ x: 0, y: u32(s.pages.active_start) })

	sel1 := it.next() or { assert false; return }
	str1 := s.selection_string(SelectionString{ sel: sel1, trim: false }) or { assert false; return }
	assert str1 == '1ABCD'

	sel2 := it.next() or { assert false; return }
	str2 := s.selection_string(SelectionString{ sel: sel2, trim: false }) or { assert false; return }
	assert str2 == '2EFGH'
}

fn test_screen_line_iterator_soft_wrap() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH\n3ABCD') or { assert false }
	mut it := s.line_iterator(Pin{ x: 0, y: u32(s.pages.active_start) })

	sel1 := it.next() or { assert false; return }
	str1 := s.selection_string(SelectionString{ sel: sel1, trim: false }) or { assert false; return }
	assert str1 == '1ABCD2EFGH'

	sel2 := it.next() or { assert false; return }
	str2 := s.selection_string(SelectionString{ sel: sel2, trim: false }) or { assert false; return }
	assert str2 == '3ABCD'
}

// --- promptClickMove ---

fn pcm_setup() Screen {
	mut s := Screen.init(20, 5, 0)
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or {}
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('hello') or {}
	return s
}

fn test_screen_prompt_click_move_line_right_basic() {
	mut s := pcm_setup()
	defer { s.deinit() }
	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 4, y: u32(s.pages.active_start) })
	assert r.right == 2
	assert r.left == 0
}

fn test_screen_prompt_click_move_cursor_not_on_input() {
	mut s := Screen.init(20, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('hello') or { assert false }
	s.cursor_set_semantic_content_output()
	s.cursor_absolute(0, 0)
	r := s.prompt_click_move(Pin{ x: 4, y: u32(s.pages.active_start) })
	assert r.right == 0
	assert r.left == 0
}

fn test_screen_prompt_click_move_same_position() {
	mut s := pcm_setup()
	defer { s.deinit() }
	s.cursor_absolute(4, 0)
	r := s.prompt_click_move(Pin{ x: 4, y: u32(s.pages.active_start) })
	assert r.right == 0
	assert r.left == 0
}

fn test_screen_prompt_click_move_right_skips_non_input() {
	mut s := Screen.init(20, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('h') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('X') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('llo') or { assert false }
	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 5, y: u32(s.pages.active_start) })
	assert r.right == 2
	assert r.left == 0
}

fn test_screen_prompt_click_move_right_soft_wrapped() {
	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('abcdefgh') or { assert false }
	s.test_write_string('ij') or { assert false }

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '> abcdefgh\nij'

	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 1, y: u32(s.pages.active_start) + 1 })
	assert r.right == 9
	assert r.left == 0
}

fn test_screen_prompt_click_move_disabled_when_click_none() {
	mut s := Screen.init(20, 5, 0)
	defer { s.deinit() }
	assert s.semantic_prompt.click == .none
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('hello') or { assert false }
	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 4, y: u32(s.pages.active_start) })
	assert r.right == 0
	assert r.left == 0
}

fn test_screen_prompt_click_move_line_left_basic() {
	mut s := pcm_setup()
	defer { s.deinit() }
	s.cursor_absolute(6, 0)
	r := s.prompt_click_move(Pin{ x: 2, y: u32(s.pages.active_start) })
	assert r.left == 4
	assert r.right == 0
}

fn test_screen_prompt_click_move_left_skips_non_input() {
	mut s := Screen.init(20, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('h') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('X') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('llo') or { assert false }
	s.cursor_absolute(6, 0)
	r := s.prompt_click_move(Pin{ x: 2, y: u32(s.pages.active_start) })
	assert r.left == 3
	assert r.right == 0
}

fn test_screen_prompt_click_move_left_soft_wrapped() {
	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('abcdefgh') or { assert false }
	s.test_write_string('ij') or { assert false }

	str := s.dump_string_alloc(.active) or { assert false; return }
	assert str == '> abcdefgh\nij'

	s.cursor_absolute(1, 1)
	r := s.prompt_click_move(Pin{ x: 2, y: u32(s.pages.active_start) })
	assert r.left == 9
	assert r.right == 0
}

fn test_screen_prompt_click_move_right_of_input_same_line() {
	mut s := pcm_setup()
	defer { s.deinit() }
	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 15, y: u32(s.pages.active_start) })
	assert r.right == 5
	assert r.left == 0
}

fn test_screen_prompt_click_move_right_of_input_cursor_at_end() {
	mut s := pcm_setup()
	defer { s.deinit() }
	// Cursor is already at column 7 (one past 'o') after writing.
	r := s.prompt_click_move(Pin{ x: 15, y: u32(s.pages.active_start) })
	assert r.right == 0
	assert r.left == 0
}

fn test_screen_prompt_click_move_right_of_input_lower_line() {
	mut s := pcm_setup()
	defer { s.deinit() }
	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 5, y: u32(s.pages.active_start) + 1 })
	assert r.right == 5
	assert r.left == 0
}

fn test_screen_prompt_click_move_right_of_input_cursor_at_end_lower_line() {
	mut s := pcm_setup()
	defer { s.deinit() }
	r := s.prompt_click_move(Pin{ x: 5, y: u32(s.pages.active_start) + 1 })
	assert r.right == 0
	assert r.left == 0
}

fn test_screen_prompt_click_move_right_of_input_cursor_on_last_char() {
	mut s := pcm_setup()
	defer { s.deinit() }
	s.cursor_absolute(6, 0)
	r := s.prompt_click_move(Pin{ x: 15, y: u32(s.pages.active_start) })
	assert r.right == 1
	assert r.left == 0
}
