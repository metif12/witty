module terminal

fn test_flat_pages_scrollbar() {
	mut no_scrollback := Pages.init(4, 2, 0)
	no_scrollback.screen_rows << RowData.init(4)
	no_scrollback.active_start = 1
	no_scrollback.viewport_start = 1
	assert no_scrollback.scrollbar() == Scrollbar{ total: 2, offset: 0, len: 2 }

	mut pages := Pages.init(4, 2, 10)
	assert pages.scrollbar() == Scrollbar{ total: 2, offset: 0, len: 2 }
	pages.screen_rows << RowData.init(4)
	pages.active_start = 1
	pages.viewport = .active
	pages.viewport_start = 1
	assert pages.scrollbar() == Scrollbar{ total: 3, offset: 1, len: 2 }
	pages.viewport = .top
	pages.viewport_start = 0
	assert pages.scrollbar() == Scrollbar{ total: 3, offset: 0, len: 2 }
}

// Tests translated from ghostty's Screen.zig

fn test_screen_read_and_write() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }
	assert s.cursor.style_id == u32(0)

	s.test_write_string('hello, world') or { assert false }
	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str == 'hello, world'
}

fn test_screen_read_and_write_newline() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }
	assert s.cursor.style_id == u32(0)

	s.test_write_string('hello\nworld') or { assert false }
	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str == 'hello\nworld'
}

fn test_screen_read_and_write_scrollback() {
	mut s := Screen.init(80, 2, 1000)
	defer { s.deinit() }

	s.test_write_string('hello\nworld\ntest') or { assert false }

	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == 'hello\nworld\ntest'

	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == 'world\ntest'
}

fn test_screen_read_and_write_no_scrollback_small() {
	mut s := Screen.init(80, 2, 0)
	defer { s.deinit() }

	s.test_write_string('hello\nworld\ntest') or { assert false }

	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == 'world\ntest'

	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == 'world\ntest'
}

fn test_screen_read_and_write_no_scrollback_large() {
	mut s := Screen.init(80, 2, 0)
	defer { s.deinit() }

	for i in 0 .. 1000 {
		s.test_write_string('${i}\n') or { assert false }
	}
	s.test_write_string('1000') or { assert false }

	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
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
	s2.cursor_copy(s.cursor, CursorCopyOptions{}) or { assert false }
	assert s2.cursor.x == 2
	assert s2.cursor.y == 3
	s2.test_write_string('Hello') or { assert false }

	str := s2.dump_string_alloc(.screen) or {
		assert false
		return
	}
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

// The fg color and the underline color are stored independently: setting an
// SGR 58 underline color must NOT corrupt the fg color (and vice versa). This
// mirrors ghostty's separate Style.underline_color union.
fn test_screen_style_underline_color_independent_from_fg() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	// Set an RGB fg color and a DIFFERENT RGB underline color.
	s.set_attribute(SgrAttribute{ kind: .direct_color_fg, r: 255, g: 0, b: 0 }) or { assert false }
	s.set_attribute(SgrAttribute{ kind: .underline_color, r: 0, g: 255, b: 0 }) or { assert false }

	// The fg color must be preserved unchanged.
	assert s.cursor.style.fg_color == .rgb
	assert s.cursor.style.fg_r == 255
	assert s.cursor.style.fg_g == 0
	assert s.cursor.style.fg_b == 0

	// The underline color is stored in its own fields.
	assert s.cursor.style.underline_color == .rgb
	assert s.cursor.style.underline_r == 0
	assert s.cursor.style.underline_g == 255
	assert s.cursor.style.underline_b == 0

	// Resolution reads back the correct, independent colors.
	mut palette := [256]RGB{}
	fg := s.cursor.style.fg_rgb(FgOpts{
		default_color: RGB{}
		palette: palette
	})
	assert fg.r == 255 && fg.g == 0 && fg.b == 0
	ul := s.cursor.style.underline_color_rgb(palette) or { panic('expected underline color') }
	assert ul.r == 0 && ul.g == 255 && ul.b == 0

	// Palette underline color must read from underline_palette, not fg_palette.
	palette[7] = RGB{ r: 11, g: 22, b: 33 }
	s.set_attribute(SgrAttribute{ kind: .underline_color_256, index: 7 }) or { assert false }
	assert s.cursor.style.underline_color == .palette
	assert s.cursor.style.underline_palette == 7
	// fg is still the RGB red we set earlier, untouched by the palette write.
	assert s.cursor.style.fg_color == .rgb
	assert s.cursor.style.fg_r == 255
	ul2 := s.cursor.style.underline_color_rgb(palette) or { panic('expected underline color') }
	assert ul2.r == 11 && ul2.g == 22 && ul2.b == 33

	// Reset clears only the underline color.
	s.set_attribute(SgrAttribute{ kind: .reset_underline_color }) or { assert false }
	assert s.cursor.style.underline_color == .none
	assert s.cursor.style.fg_color == .rgb
	assert s.cursor.style.fg_r == 255

	// Two styles differing only in underline color must be distinct.
	a := CellStyle{
		underline_color: .rgb
		underline_r: 1
	}
	b := CellStyle{
		underline_color: .rgb
		underline_r: 2
	}
	assert !a.eql(&b)
	assert a.hash() != b.hash()
}

fn test_screen_clear_rows_active_one_line() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.test_write_string('hello, world') or { assert false }
	s.clear_rows(Point.new(.active, Coordinate{}), ?Point(none), false)
	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str == ''
}

fn test_screen_clear_rows_active_multi_line() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.test_write_string('hello\nworld') or { assert false }
	s.clear_rows(Point.new(.active, Coordinate{}), ?Point(none), false)
	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str == ''
}

fn test_screen_clear_rows_active_styled_line() {
	mut s := Screen.init(80, 24, 1000)
	defer { s.deinit() }

	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	s.test_write_string('hello world') or { assert false }
	s.set_attribute(SgrAttribute{ kind: .unset }) or { assert false }

	s.clear_rows(Point.new(.active, Coordinate{}), ?Point(none), false)
	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
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

	s.clear_rows(Point.new(.active, Coordinate{}), ?Point(none), true)

	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str == '           PROTECTED\nPROTECTED           PROTECTED'
}

fn test_screen_clear_cells_updates_managed_row_flags() {
	mut s := Screen.init(5, 1, 0)
	defer { s.deinit() }

	mut row := &s.pages.screen_rows[0]
	row.grapheme = true
	row.styled = true
	row.hyperlink = true
	for x in [0, 4] {
		row.cells[x] = CellData{
			content_tag: .codepoint_grapheme
			codepoint: u32(`x`)
			has_grapheme: true
			graphemes: [u32(0x0301)]
			style_id: 1
			has_hyperlink: true
		}
	}

	// A partial clear must retain each aggregate flag while another matching
	// cell remains in the row.
	s.clear_cells(0, 0, 1)
	assert row.grapheme
	assert row.styled
	assert row.hyperlink

	// Clearing the final matching cell must update all three flags.
	s.clear_cells(0, 4, 5)
	assert !row.grapheme
	assert !row.styled
	assert !row.hyperlink
}

fn test_screen_clear_rows_protected_preserves_managed_flags() {
	mut s := Screen.init(5, 1, 0)
	defer { s.deinit() }

	mut row := &s.pages.screen_rows[0]
	row.wrap = true
	row.wrap_continuation = true
	row.semantic_prompt = .prompt
	row.grapheme = true
	row.styled = true
	row.hyperlink = true
	row.cells[0] = CellData{
		content_tag: .codepoint_grapheme
		codepoint: u32(`u`)
		has_grapheme: true
		graphemes: [u32(0x0301)]
		style_id: 1
		has_hyperlink: true
	}
	row.cells[1] = CellData{
		content_tag: .codepoint_grapheme
		codepoint: u32(`p`)
		is_protected: true
		has_grapheme: true
		graphemes: [u32(0x0301)]
		style_id: 1
		has_hyperlink: true
	}

	s.clear_rows(Point.new(.active, Coordinate{}), ?Point(none), true)

	assert row.cells[0].is_zero()
	assert row.cells[1].codepoint == `p`
	assert row.grapheme
	assert row.styled
	assert row.hyperlink
	assert row.wrap
	assert row.wrap_continuation
	assert row.semantic_prompt == .prompt
}

fn test_screen_erase_rows_history() {
	mut s := Screen.init(5, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3\n4\n5\n6') or { assert false }

	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == '2\n3\n4\n5\n6'

	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '1\n2\n3\n4\n5\n6'

	s.erase_rows(Point.new(.history, Coordinate{}), ?Point(none))

	str_active2 := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active2 == '2\n3\n4\n5\n6'

	str_screen2 := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen2 == '2\n3\n4\n5\n6'
}

fn test_screen_erase_rows_history_with_more_lines() {
	mut s := Screen.init(5, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('A\nB\nC\n1\n2\n3\n4\n5\n6') or { assert false }

	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == '2\n3\n4\n5\n6'

	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == 'A\nB\nC\n1\n2\n3\n4\n5\n6'

	s.erase_rows(Point.new(.history, Coordinate{}), ?Point(none))

	str_active2 := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active2 == '2\n3\n4\n5\n6'

	str_screen2 := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen2 == '2\n3\n4\n5\n6'
}

fn test_screen_erase_rows_active_partial() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3') or { assert false }
	assert s.cursor.x == 1
	assert s.cursor.y == 2
	s.selection = Selection.init(Pin{ x: 2, y: 0 }, Pin{ x: 3, y: 2 }, false)
	s.erase_rows(Point.new(.active, Coordinate{}), Point.new(.active, Coordinate{ y: 1 }))

	active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert active == '3'
	screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert screen == '3'
	assert s.pages.screen_rows.len == 5
	assert s.cursor.x == 1
	assert s.cursor.y == 0
	selection := s.selection or { panic('missing selection') }
	assert selection.start_pin == Pin{ x: 0, y: 0 }
	assert selection.end_pin == Pin{ x: 3, y: 0 }
}

fn test_screen_scrolling() {
	mut s := Screen.init(5, 3, 1000)
	defer { s.deinit() }

	s.test_write_string('1ABCD\n2EFGH\n3IJKL\n4ABCD\n5EFGH\n6IJKL') or { assert false }

	active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert active == '4ABCD\n5EFGH\n6IJKL'

	s.scroll(ScrollTop{})
	top := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert top == '1ABCD\n2EFGH\n3IJKL'

	s.scroll_delta_rows(2)
	middle := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert middle == '3IJKL\n4ABCD\n5EFGH'

	s.scroll(ScrollActive{})
	bottom := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert bottom == active
}

fn test_screen_scroll_payload_variants() {
	mut s := Screen.init(5, 3, 3)
	defer { s.deinit() }
	s.test_write_string('1\n2\n3\n4\n5\n6') or { assert false }
	assert s.pages.active_start == 3

	s.scroll(ScrollTop{})
	assert s.pages.viewport == .top
	assert s.pages.viewport_start == 0

	s.scroll(ScrollRow{ n: 2 })
	assert s.pages.viewport == .pinned
	assert s.pages.viewport_start == 2

	s.scroll(ScrollDeltaRow{ delta: 10 })
	assert s.pages.viewport == .active
	assert s.pages.viewport_start == 3

	s.scroll(ScrollPin{ pin: Pin{ x: 4, y: 1 } })
	assert s.pages.viewport == .pinned
	assert s.pages.viewport_start == 1

	s.scroll(ScrollPin{ pin: Pin{ x: 0, y: 4 } })
	assert s.pages.viewport == .active
	assert s.pages.viewport_start == 3
}

fn test_screen_scroll_no_scrollback_stays_active() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1\n2\n3') or { assert false }
	s.scroll(ScrollTop{})
	assert s.pages.viewport == .active
	s.scroll(ScrollDeltaRow{ delta: -1 })
	assert s.pages.viewport == .active
}

fn test_screen_scroll_prompt_overshoot_uses_furthest_prompt() {
	mut s := Screen.init(5, 3, 3)
	defer { s.deinit() }
	s.test_write_string('1\n2\n3\n4\n5\n6') or { assert false }
	s.pages.screen_rows[1].semantic_prompt = .prompt
	s.pages.screen_rows[3].semantic_prompt = .prompt

	s.scroll(ScrollDeltaPrompt{ delta: -10 })
	assert s.pages.viewport == .pinned
	assert s.pages.viewport_start == 1

	s.scroll(ScrollDeltaPrompt{ delta: 10 })
	assert s.pages.viewport == .active
	assert s.pages.viewport_start == s.pages.active_start
}

fn test_screen_scrolling_moves_selection() {
	mut s := Screen.init(5, 3, 1)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.select(Selection.init(Pin{ x: 0, y: 1 }, Pin{ x: 4, y: 1 }, false)) or {
		panic(err)
	}

	s.cursor_down_scroll() or { panic(err) }
	first := s.selection or { panic('selection was dropped') }
	assert first.start_pin.eql(Pin{ x: 0, y: u32(s.pages.active_start) })
	assert first.end_pin.eql(Pin{ x: 4, y: u32(s.pages.active_start) })

	s.cursor_down_scroll() or { panic(err) }
	second := s.selection or { panic('selection was dropped') }
	assert int(second.start_pin.y) < s.pages.active_start
	assert int(second.end_pin.y) < s.pages.active_start
}

fn test_screen_scrollback_empty() {
	mut s := Screen.init(5, 5, 1000)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3\n4\n5') or { assert false }

	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == '1\n2\n3\n4\n5'

	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
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

fn test_flat_pages_highlight_semantic_content() {
	mut pages := Pages.init(10, 8, 0)
	pages.screen_rows[2].semantic_prompt = .prompt
	pages.screen_rows[6].semantic_prompt = .prompt
	for x in 0 .. 2 {
		pages.screen_rows[2].cells[x] = CellData{
			codepoint: u32(`$`)
			semantic_content: .prompt
		}
	}
	for x in 2 .. 5 {
		pages.screen_rows[2].cells[x] = CellData{
			codepoint: u32(`i`)
			semantic_content: .input
		}
	}
	for x in 0 .. 3 {
		pages.screen_rows[3].cells[x] = CellData{
			codepoint: u32(`o`)
			semantic_content: .output
		}
	}
	pages.screen_rows[4].cells[1] = CellData{
		codepoint: u32(`z`)
		semantic_content: .output
	}

	prompt := pages.highlight_semantic_content(Pin{ x: 0, y: 2 }, .prompt) or {
		assert false
		return
	}
	assert prompt.start == Pin{ x: 0, y: 2 }
	assert prompt.end == Pin{ x: 4, y: 2 }
	input := pages.highlight_semantic_content(Pin{ x: 0, y: 2 }, .input) or {
		assert false
		return
	}
	assert input.start == Pin{ x: 2, y: 2 }
	assert input.end == Pin{ x: 4, y: 2 }
	output := pages.highlight_semantic_content(Pin{ x: 0, y: 2 }, .output) or {
		assert false
		return
	}
	assert output.start == Pin{ x: 0, y: 3 }
	assert output.end == Pin{ x: 1, y: 4 }
}

fn test_screen_select_output() {
	mut s := Screen.init(10, 15, 0)
	defer { s.deinit() }

	s.cursor_set_semantic_content_output()
	s.test_write_string('output1\n') or { assert false }
	s.test_write_string('output1\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('prompt2\n') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('input2\n') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('output2output2output2output2\n') or { assert false }
	s.test_write_string('output2\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('\$ ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('input3\n') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('output3\n') or { assert false }
	s.test_write_string('output3\n') or { assert false }
	s.test_write_string('output3') or { assert false }

	first := s.select_output(Pin{ x: 1, y: 1 }) or {
		assert false, 'first output selection missing'
		return
	}
	first_text := s.selection_string(SelectionString{ sel: first }) or {
		assert false
		return
	}
	assert first_text == 'output1\noutput1'

	second := s.select_output(Pin{ x: 3, y: 7 }) or {
		assert false, 'second output selection missing'
		return
	}
	second_text := s.selection_string(SelectionString{ sel: second }) or {
		assert false
		return
	}
	assert second_text == 'output2output2output2output2\noutput2'

	third := s.select_output(Pin{ x: 2, y: 10 }) or {
		assert false, 'third output selection missing'
		return
	}
	assert third.start() == Pin{ x: 0, y: 9 }
	assert third.end() == Pin{ x: 6, y: 11 }
	assert s.select_output(Pin{ x: 1, y: 8 }) == none
	assert s.select_output(Pin{ x: 5, y: 8 }) == none
}

fn test_screen_selection_string_basic() {
	mut s := Screen.init(20, 10, 0)
	defer { s.deinit() }

	s.test_write_string('hello, world') or { assert false }

	start_pin := Pin{ x: 0, y: u32(s.pages.active_start) }
	end_pin := Pin{ x: 11, y: u32(s.pages.active_start) }
	sel := Selection.init(start_pin, end_pin, false)

	str := s.selection_string(SelectionString{ sel: sel }) or {
		assert false
		return
	}
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
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3') or { assert false }

	s.resize(ScreenResize{ cols: 5, rows: 5, reflow: false }) or { assert false }
	assert s.pages.rows == 5

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '1\n2\n3'
}

fn test_screen_resize_no_reflow_more_cols() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }

	s.test_write_string('1\n2\n3') or { assert false }

	s.resize(ScreenResize{ cols: 10, rows: 3, reflow: false }) or { assert false }
	assert s.pages.cols == 10

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
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

	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
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

fn test_screen_cursor_vertical_movement_marks_old_and_new_rows_dirty() {
	mut s := Screen.init(10, 4, 0)
	defer { s.deinit() }
	s.cursor_absolute(2, 1)
	for mut row in s.pages.screen_rows {
		row.dirty = false
	}

	s.cursor_down(2)
	assert s.pages.get_active_row(1).dirty
	assert !s.pages.get_active_row(2).dirty
	assert s.pages.get_active_row(3).dirty

	for mut row in s.pages.screen_rows {
		row.dirty = false
	}
	s.cursor_up(1)
	assert !s.pages.get_active_row(1).dirty
	assert s.pages.get_active_row(2).dirty
	assert s.pages.get_active_row(3).dirty
}

fn test_screen_zero_distance_cursor_movement_stays_clean() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.cursor_absolute(2, 1)
	for mut row in s.pages.screen_rows {
		row.dirty = false
	}

	s.cursor_up(0)
	s.cursor_down(0)
	s.cursor_absolute(2, 1)
	for row in s.pages.screen_rows {
		assert !row.dirty
	}
}

fn test_screen_cursor_cell_left_right() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.cursor_absolute(5, 1)
	row_idx := s.pages.active_start + 1
	s.pages.screen_rows[row_idx].cells[3].codepoint = u32(`L`)
	s.pages.screen_rows[row_idx].cells[7].codepoint = u32(`R`)

	left := s.cursor_cell_left(2)
	right := s.cursor_cell_right(2)
	assert left.codepoint == u32(`L`)
	assert right.codepoint == u32(`R`)
	assert voidptr(left) == voidptr(&s.pages.screen_rows[row_idx].cells[3])
	assert voidptr(right) == voidptr(&s.pages.screen_rows[row_idx].cells[7])
}

fn test_screen_cursor_previous_cell_and_row_up_reference_page_storage() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.cursor_absolute(5, 2)
	previous_row_idx := s.pages.active_start + 1
	s.pages.screen_rows[previous_row_idx].cells[9].codepoint = u32(`P`)

	previous_cell := s.cursor_cell_end_of_prev()
	previous_row := s.cursor_row_up(1)
	assert previous_cell.codepoint == u32(`P`)
	assert voidptr(previous_cell) == voidptr(&s.pages.screen_rows[previous_row_idx].cells[9])
	assert voidptr(previous_row) == voidptr(&s.pages.screen_rows[previous_row_idx])
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

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
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

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '2\n3'
}

fn test_screen_scroll_above_same_page() {
	mut s := Screen.init(10, 3, 10)
	defer { s.deinit() }
	s.set_attribute(SgrAttribute{ kind: .direct_color_bg, r: 155 }) or { panic(err) }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { panic(err) }
	s.cursor_absolute(0, 1)
	for i in 0 .. s.pages.screen_rows.len {
		s.pages.screen_rows[i].dirty = false
	}

	s.cursor_scroll_above() or { panic(err) }
	contents := s.dump_string_alloc(.viewport) or { panic(err) }
	assert contents == '2EFGH\n\n3IJKL'
	blank := s.pages.get_active_row(1).cells[0]
	assert blank.content_tag == .bg_color_rgb
	assert blank.color_rgb_r == 155
	assert blank.color_rgb_g == 0
	assert blank.color_rgb_b == 0
	assert !s.pages.get_active_row(1).styled
	for y in u32(0) .. s.pages.rows {
		assert s.pages.get_active_row(y).dirty
	}
}

fn test_screen_scroll_above_no_scrollback_bottom_of_page() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.set_attribute(SgrAttribute{ kind: .direct_color_bg, r: 155 }) or { panic(err) }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { panic(err) }
	s.cursor_absolute(0, 1)
	for i in 0 .. s.pages.screen_rows.len {
		s.pages.screen_rows[i].dirty = false
	}

	s.cursor_scroll_above() or { panic(err) }
	contents := s.dump_string_alloc(.viewport) or { panic(err) }
	assert contents == '2EFGH\n\n3IJKL'
	assert s.dump_string_alloc(.screen) or { panic(err) } == contents
	blank := s.pages.get_active_row(1).cells[0]
	assert blank.content_tag == .bg_color_rgb
	assert blank.color_rgb_r == 155
	for y in u32(0) .. s.pages.rows {
		assert s.pages.get_active_row(y).dirty
	}
}

fn test_screen_clone() {
	mut s := Screen.init(10, 3, 10)
	defer { s.deinit() }

	s.test_write_string('1ABCD\n2EFGH') or { assert false }

	mut cloned := s.clone(Point.new(.screen, Coordinate{}), ?Point(none)) or {
		assert false
		return
	}
	defer { cloned.deinit() }

	str := cloned.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '1ABCD\n2EFGH'
	assert cloned.cursor.x == s.cursor.x
	assert cloned.cursor.y == s.cursor.y

	// The clone owns its rows; subsequent writes cannot affect it.
	s.test_write_string('\n34567') or { assert false }
	assert (cloned.dump_string_alloc(.active) or { panic(err) }) == '1ABCD\n2EFGH'
}

fn test_screen_clone_partial() {
	mut s := Screen.init(10, 3, 10)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH') or { assert false }

	mut cloned := s.clone(Point.new(.active, Coordinate{ y: 1 }), ?Point(none)) or {
		panic(err)
	}
	defer { cloned.deinit() }
	assert cloned.dump_string_alloc(.active) or { panic(err) } == '2EFGH'
	assert cloned.cursor.x == 5
	assert cloned.cursor.y == 0
}

fn test_screen_clone_partial_cursor_out_of_bounds() {
	mut s := Screen.init(10, 3, 10)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH') or { assert false }

	mut cloned := s.clone(Point.new(.active, Coordinate{}), Point.new(.active, Coordinate{})) or { panic(err) }
	defer { cloned.deinit() }
	assert cloned.dump_string_alloc(.active) or { panic(err) } == '1ABCD'
	assert cloned.cursor.x == 0
	assert cloned.cursor.y == 0
}

fn test_screen_clone_selection_source_boundaries() {
	// A selection fully inside the cloned range is remapped without clipping.
	mut full := Screen.init(5, 3, 1)
	defer { full.deinit() }
	full.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	full.selection = Selection.init(Pin{ x: 0, y: 1 }, Pin{ x: 4, y: 1 }, false)
	mut full_clone := full.clone(Point.new(.active, Coordinate{}), ?Point(none)) or {
		panic(err)
	}
	defer { full_clone.deinit() }
	full_sel := full_clone.selection or { panic('selection was dropped') }
	assert full_sel.start_pin.eql(Pin{ x: 0, y: 1 })
	assert full_sel.end_pin.eql(Pin{ x: 4, y: 1 })

	// A selection wholly above the cloned range is removed.
	full.selection = Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 4, y: 0 }, false)
	mut none_clone := full.clone(Point.new(.active, Coordinate{ y: 1 }), ?Point(none)) or {
		panic(err)
	}
	defer { none_clone.deinit() }
	assert none_clone.selection == none

	// A clipped start moves to the first cell in the clone.
	full.selection = Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 4, y: 1 }, false)
	mut start_clone := full.clone(Point.new(.active, Coordinate{ y: 1 }), ?Point(none)) or {
		panic(err)
	}
	defer { start_clone.deinit() }
	start_sel := start_clone.selection or { panic('selection was dropped') }
	assert start_sel.start_pin.eql(Pin{ x: 0, y: 0 })
	assert start_sel.end_pin.eql(Pin{ x: 4, y: 0 })

	// A clipped end extends through the blank rows added to fill the viewport.
	full.selection = Selection.init(Pin{ x: 0, y: 1 }, Pin{ x: 2, y: 2 }, false)
	mut end_clone := full.clone(Point.new(.active, Coordinate{}), Point.new(.active, Coordinate{ y: 1 })) or { panic(err) }
	defer { end_clone.deinit() }
	end_sel := end_clone.selection or { panic('selection was dropped') }
	assert end_sel.start_pin.eql(Pin{ x: 0, y: 1 })
	assert end_sel.end_pin.eql(Pin{ x: 4, y: 2 })

	// Reverse selections are ordered while being remapped.
	full.selection = Selection.init(Pin{ x: 2, y: 2 }, Pin{ x: 0, y: 1 }, false)
	mut reverse_clone := full.clone(Point.new(.active, Coordinate{}), Point.new(.active, Coordinate{ y: 1 })) or { panic(err) }
	defer { reverse_clone.deinit() }
	reverse_sel := reverse_clone.selection or { panic('selection was dropped') }
	assert reverse_sel.start_pin.eql(Pin{ x: 0, y: 1 })
	assert reverse_sel.end_pin.eql(Pin{ x: 4, y: 2 })
}

fn test_screen_clone_selection_contains_subset() {
	mut s := Screen.init(5, 4, 1)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL\n4ABCD') or { assert false }

	s.selection = Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 0, y: 3 }, false)
	mut cloned := s.clone(Point.new(.active, Coordinate{ y: 1 }), Point.new(.active, Coordinate{ y: 2 })) or { panic(err) }
	defer { cloned.deinit() }
	sel := cloned.selection or { panic('selection was dropped') }
	assert sel.start_pin.eql(Pin{ x: 0, y: 0 })
	assert sel.end_pin.eql(Pin{ x: 4, y: 3 })

	s.selection = Selection.init(Pin{ x: 1, y: 0 }, Pin{ x: 3, y: 3 }, true)
	mut rectangle := s.clone(Point.new(.active, Coordinate{ y: 1 }), Point.new(.active, Coordinate{ y: 2 })) or { panic(err) }
	defer { rectangle.deinit() }
	rect_sel := rectangle.selection or { panic('selection was dropped') }
	assert rect_sel.rectangle
	assert rect_sel.start_pin.eql(Pin{ x: 1, y: 0 })
	assert rect_sel.end_pin.eql(Pin{ x: 3, y: 3 })
}

fn test_screen_clone_basic_regions() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }

	mut one := s.clone(Point.new(.active, Coordinate{ y: 1 }), Point.new(.active, Coordinate{ y: 1 })) or { panic(err) }
	defer { one.deinit() }
	assert one.dump_string_alloc(.active) or { panic(err) } == '2EFGH'

	mut two := s.clone(Point.new(.active, Coordinate{ y: 1 }), Point.new(.active, Coordinate{ y: 2 })) or { panic(err) }
	defer { two.deinit() }
	assert two.dump_string_alloc(.active) or { panic(err) } == '2EFGH\n3IJKL'
}

fn test_screen_clone_empty_and_one_line_regions() {
	mut empty := Screen.init(10, 3, 0)
	defer { empty.deinit() }
	mut empty_viewport := empty.clone(Point.new(.viewport, Coordinate{}), Point.new(.viewport, Coordinate{})) or { panic(err) }
	defer { empty_viewport.deinit() }
	assert empty_viewport.dump_string_alloc(.viewport) or { panic(err) } == ''

	mut empty_active := empty.clone(Point.new(.active, Coordinate{}), Point.new(.active, Coordinate{})) or { panic(err) }
	defer { empty_active.deinit() }
	assert empty_active.dump_string_alloc(.active) or { panic(err) } == ''

	mut one := Screen.init(10, 3, 0)
	defer { one.deinit() }
	one.test_write_string('1ABC') or { assert false }
	mut one_viewport := one.clone(Point.new(.viewport, Coordinate{}), Point.new(.viewport, Coordinate{})) or { panic(err) }
	defer { one_viewport.deinit() }
	assert one_viewport.dump_string_alloc(.viewport) or { panic(err) } == '1ABC'

	mut one_active := one.clone(Point.new(.active, Coordinate{}), ?Point(none)) or {
		panic(err)
	}
	defer { one_active.deinit() }
	assert one_active.dump_string_alloc(.active) or { panic(err) } == '1ABC'
}

fn test_screen_clone_deep_copies_managed_cells_and_resets_cursor_state() {
	mut s := Screen.init(3, 2, 10)
	defer { s.deinit() }
	style := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	link := Hyperlink{
		id: HyperlinkExplicitId{
			value: 'screen-clone'
		}
		uri: 'https://example.com/screen-clone'
	}
	s.pages.screen_rows[0].grapheme = true
	s.pages.screen_rows[0].styled = true
	s.pages.screen_rows[0].hyperlink = true
	s.pages.screen_rows[0].cells[0] = CellData{
		content_tag: .codepoint_grapheme
		codepoint: u32(`x`)
		has_grapheme: true
		graphemes: [u32(0x0301)]
		style_id: 1
		style: style
		has_hyperlink: true
		hyperlink: link.dupe()
	}
	s.cursor = Cursor{
		x: 1
		y: 1
		pending_wrap: true
		is_protected: true
		style: style
		style_id: 1
		hyperlink_id: 7
		hyperlink_implicit_id: 6
		hyperlink_state: link.dupe()
		semantic_content: .input
		semantic_content_clear_eol: true
	}

	mut cloned := s.clone(Point.new(.screen, Coordinate{}), ?Point(none)) or {
		assert false, 'screen clone failed'
		return
	}
	defer { cloned.deinit() }
	cell := cloned.pages.screen_rows[0].cells[0]
	assert cell.graphemes == [u32(0x0301)]
	assert cell.style.eql(&style)
	assert cell.hyperlink.eql(&link)
	assert cloned.cursor.x == 1
	assert cloned.cursor.y == 1
	assert !cloned.cursor.pending_wrap
	assert !cloned.cursor.is_protected
	assert cloned.cursor.style.default()
	assert cloned.cursor.style_id == default_style_id
	assert cloned.cursor.hyperlink_id == 0
	assert cloned.cursor.hyperlink_implicit_id == 0
	assert cloned.cursor.hyperlink_state == none
	assert cloned.cursor.semantic_content == .output
	assert !cloned.cursor.semantic_content_clear_eol

	// The clone owns nested managed values, not only the outer cell array.
	s.pages.screen_rows[0].cells[0].graphemes[0] = u32(0x0302)
	s.pages.screen_rows[0].cells[0].style.flags.bold = false
	s.pages.screen_rows[0].cells[0].hyperlink.uri = 'https://example.com/changed'
	assert cloned.pages.screen_rows[0].cells[0].graphemes == [u32(0x0301)]
	assert cloned.pages.screen_rows[0].cells[0].style.flags.bold
	assert cloned.pages.screen_rows[0].cells[0].hyperlink.uri == 'https://example.com/screen-clone'
}

fn test_screen_clone_clips_and_orders_selection() {
	mut s := Screen.init(4, 3, 10)
	defer { s.deinit() }
	for _ in 0 .. 3 {
		s.pages.screen_rows << RowData.init(4)
	}
	s.pages.active_start = 3
	s.pages.viewport_start = 3
	s.selection = Selection.init(Pin{ x: 1, y: 5 }, Pin{ x: 2, y: 0 }, false)

	mut active_clone := s.clone(Point.new(.active, Coordinate{}), ?Point(none)) or {
		assert false, 'active clone failed'
		return
	}
	defer { active_clone.deinit() }
	active_selection := active_clone.selection or {
		assert false, 'clipped active selection was dropped'
		return
	}
	assert active_selection.start_pin.eql(Pin{ x: 0, y: 0 })
	assert active_selection.end_pin.eql(Pin{ x: 1, y: 2 })

	mut history_clone := s.clone(Point.new(.history, Coordinate{}), ?Point(none)) or {
		assert false, 'history clone failed'
		return
	}
	defer { history_clone.deinit() }
	history_selection := history_clone.selection or {
		assert false, 'clipped history selection was dropped'
		return
	}
	assert history_selection.start_pin.eql(Pin{ x: 2, y: 0 })
	assert history_selection.end_pin.eql(Pin{ x: 3, y: 2 })
}

fn test_screen_clone_preserves_rectangle_selection_edges() {
	mut s := Screen.init(4, 3, 10)
	defer { s.deinit() }
	for _ in 0 .. 3 {
		s.pages.screen_rows << RowData.init(4)
	}
	s.pages.active_start = 3
	s.pages.viewport_start = 3
	s.selection = Selection.init(Pin{ x: 2, y: 0 }, Pin{ x: 1, y: 5 }, true)

	mut cloned := s.clone(Point.new(.active, Coordinate{}), ?Point(none)) or {
		assert false, 'rectangle clone failed'
		return
	}
	defer { cloned.deinit() }
	selection := cloned.selection or {
		assert false, 'clipped rectangle selection was dropped'
		return
	}
	assert selection.rectangle
	assert selection.start_pin.eql(Pin{ x: 2, y: 0 })
	assert selection.end_pin.eql(Pin{ x: 1, y: 2 })
}

fn test_screen_soft_wrap_write() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }

	s.test_write_string('helloworld') or { assert false }

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
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

fn test_screen_cursor_reset_wrap_clears_wide_spacer_head() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	row_idx := s.pages.active_start
	s.pages.screen_rows[row_idx].wrap = true
	s.pages.screen_rows[row_idx].cells[4] = CellData{
		wide: .spacer_head
	}
	s.pages.screen_rows[row_idx + 1].wrap_continuation = true

	s.cursor_reset_wrap()

	assert !s.pages.screen_rows[row_idx].wrap
	assert !s.pages.screen_rows[row_idx + 1].wrap_continuation
	assert s.pages.screen_rows[row_idx].cells[4].is_zero()
}

fn test_screen_cursor_reset_wrap_preserves_next_row_without_wrap() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	row_idx := s.pages.active_start
	s.pages.screen_rows[row_idx + 1].wrap_continuation = true

	s.cursor_reset_wrap()

	assert s.pages.screen_rows[row_idx + 1].wrap_continuation
}

fn test_screen_split_cell_boundary_clears_wrapped_wide_spacer_head() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	row_idx := s.pages.active_start
	s.pages.screen_rows[row_idx].wrap = true
	s.pages.screen_rows[row_idx].cells[4] = CellData{
		wide: .spacer_head
	}

	s.split_cell_boundary(5)

	assert s.pages.screen_rows[row_idx].cells[4].is_zero()
}

fn test_screen_split_cell_boundary_clears_previous_wrapped_wide_spacer_head() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.cursor_absolute(0, 1)
	row_idx := s.pages.active_start + 1
	s.pages.screen_rows[row_idx].wrap_continuation = true
	s.pages.screen_rows[row_idx].cells[0] = CellData{
		codepoint: u32(0x1f600)
		wide: .wide
	}
	s.pages.screen_rows[row_idx - 1].cells[4] = CellData{
		wide: .spacer_head
	}

	s.split_cell_boundary(0)

	assert s.pages.screen_rows[row_idx - 1].cells[4].is_zero()
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

fn test_screen_cursor_set_semantic_content_union() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	s.cursor_set_semantic_content(CursorSemanticPrompt{ kind: .continuation })
	assert s.semantic_prompt.seen
	assert s.cursor.semantic_content == .prompt
	assert s.pages.get_active_row(0).semantic_prompt == .prompt_continuation

	s.cursor_set_semantic_content(CursorSemanticInput{ clear: .clear_eol })
	assert s.cursor.semantic_content == .input
	assert s.cursor.semantic_content_clear_eol

	s.cursor_set_semantic_content(CursorSemanticInput{ clear: .clear_explicit })
	assert !s.cursor.semantic_content_clear_eol
	s.cursor_set_semantic_content(CursorSemanticOutput{})
	assert s.cursor.semantic_content == .output
}

fn test_screen_first_implicit_hyperlink_uses_zero_offset() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	s.start_hyperlink('https://example.com/', none) or { panic(err) }
	link := s.cursor.hyperlink_state or {
		assert false
		return
	}
	match link.id {
		HyperlinkImplicitId {
			assert link.id.offset == 0
		}
		HyperlinkExplicitId {
			assert false
		}
	}
	assert s.cursor.hyperlink_implicit_id == 1
}

fn test_screen_cursor_set_hyperlink_updates_cursor_cell_and_row() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.cursor_absolute(2, 1)
	s.start_hyperlink('https://example.com/cursor', 'cursor') or { panic(err) }

	s.cursor_set_hyperlink() or { panic(err) }

	row := s.pages.get_active_row(1)
	assert row.hyperlink
	assert row.cells[2].has_hyperlink
	assert row.cells[2].hyperlink.uri == 'https://example.com/cursor'
}

fn test_screen_append_grapheme_updates_cursor_row_cell() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.cursor_absolute(2, 1)
	row_idx := s.pages.active_start + 1
	s.pages.screen_rows[row_idx].cells[2] = CellData.init(u32(`a`))

	s.append_grapheme(2, u32(0x0301)) or { panic(err) }

	row := s.pages.get_active_row(1)
	assert row.grapheme
	assert row.cells[2].content_tag == .codepoint_grapheme
	assert row.cells[2].has_grapheme
	assert row.cells[2].graphemes == [u32(0x0301)]
}

// ============================================================
// Additional tests translated from ghostty Screen.zig
// ============================================================

fn wsdef_all() []u32 {
	return [u32(0), u32(` `), u32(`\t`), u32(`'`), u32(`"`), u32(`\``), u32(`|`), u32(`:`), u32(`;`),
		u32(`,`), u32(`(`), u32(`)`), u32(`[`), u32(`]`), u32(`{`), u32(`}`), u32(`<`), u32(`>`),
		u32(`$`)]
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
	s2.cursor_copy(s.cursor, CursorCopyOptions{}) or { assert false }
	assert s2.cursor.style.flags.bold
}

fn test_screen_cursor_copy_hyperlink_deref() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	mut s2 := Screen.init(10, 10, 0)
	defer { s2.deinit() }
	s2.start_hyperlink('https://example.com/', ?string(none)) or { assert false }
	assert s2.cursor.hyperlink_id != 0
	assert s2.cursor.hyperlink_state != none

	// Copying a cursor without a hyperlink releases the active hyperlink.
	s2.cursor_copy(s.cursor, CursorCopyOptions{}) or { assert false }
	assert s2.cursor.hyperlink_id == 0
	assert s2.cursor.hyperlink_state == none
}

fn test_screen_cursor_copy_hyperlink_copy() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.start_hyperlink('https://example.com/', ?string(none)) or { assert false }
	source := s.cursor.hyperlink_state or {
		assert false
		return
	}
	source_id := match source.id {
		HyperlinkImplicitId { source.id.offset }
		HyperlinkExplicitId { u32(0) }
	}

	mut s2 := Screen.init(10, 10, 0)
	defer { s2.deinit() }
	s2.cursor_copy(s.cursor, CursorCopyOptions{}) or { assert false }
	assert s2.cursor.hyperlink_id != 0
	link := s2.cursor.hyperlink_state or {
		assert false
		return
	}
	assert link.uri == 'https://example.com/'
	match link.id {
		HyperlinkImplicitId {
			assert link.id.offset > source_id
		}
		HyperlinkExplicitId {
			assert false
		}
	}
}

fn test_screen_cursor_copy_explicit_hyperlink_id() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.start_hyperlink('https://example.com/', 'same-id') or { assert false }

	mut s2 := Screen.init(10, 10, 0)
	defer { s2.deinit() }
	s2.cursor_copy(s.cursor, CursorCopyOptions{}) or { assert false }
	link := s2.cursor.hyperlink_state or {
		assert false
		return
	}
	match link.id {
		HyperlinkExplicitId {
			assert link.id.value == 'same-id'
		}
		HyperlinkImplicitId {
			assert false
		}
	}
}

fn test_screen_cursor_copy_hyperlink_copy_disabled() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.start_hyperlink('https://example.com/', ?string(none)) or { assert false }

	mut s2 := Screen.init(10, 10, 0)
	defer { s2.deinit() }
	s2.cursor_copy(s.cursor, CursorCopyOptions{
		hyperlink: false
	}) or { assert false }
	assert s2.cursor.hyperlink_id == 0
	assert s2.cursor.hyperlink_state == none
}

// --- eraseRows / clear history ---

fn test_screen_clear_history_with_no_history() {
	mut s := Screen.init(10, 3, 3)
	defer { s.deinit() }
	s.test_write_string('4ABCD\n5EFGH\n6IJKL') or { assert false }
	s.erase_rows(Point.new(.history, Coordinate{}), ?Point(none))
	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == '4ABCD\n5EFGH\n6IJKL'
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '4ABCD\n5EFGH\n6IJKL'
}

fn test_screen_clear_history() {
	mut s := Screen.init(10, 3, 3)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL\n4ABCD\n5EFGH\n6IJKL') or { assert false }
	s.erase_rows(Point.new(.history, Coordinate{}), ?Point(none))
	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == '4ABCD\n5EFGH\n6IJKL'
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '4ABCD\n5EFGH\n6IJKL'
}

// --- scroll and clear ---

fn test_screen_scroll_and_clear_full_screen() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }

	str0 := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str0 == '1ABCD\n2EFGH\n3IJKL'

	s.scroll_clear() or { assert false }
	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == ''
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_scroll_and_clear_partial_screen() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH') or { assert false }

	str0 := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str0 == '1ABCD\n2EFGH'

	s.scroll_clear() or { assert false }
	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == ''
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '1ABCD\n2EFGH'
}

fn test_screen_scroll_and_clear_empty_screen() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }
	s.scroll_clear() or { assert false }
	str_active := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str_active == ''
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == ''
}

fn test_screen_scroll_and_clear_ignores_blank_lines() {
	mut s := Screen.init(10, 3, 10)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH') or { assert false }
	s.scroll_clear() or { panic(err) }
	assert s.dump_string_alloc(.viewport) or { panic(err) } == ''

	s.cursor_absolute(0, 0)
	s.test_write_string('3ABCD\n') or { assert false }
	assert s.dump_string_alloc(.active) or { panic(err) } == '3ABCD'
	s.scroll_clear() or { panic(err) }
	assert s.dump_string_alloc(.viewport) or { panic(err) } == ''

	s.cursor_absolute(0, 0)
	s.test_write_string('X') or { assert false }
	assert s.dump_string_alloc(.screen) or { panic(err) } == '1ABCD\n2EFGH\n3ABCD\nX'
}

// --- scrolling ---

fn test_screen_scroll_down_from_0() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }

	// Scrolling up does nothing, but allows it.
	s.scroll(ScrollDeltaRow{ delta: -1 })
	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_cursor_down_scroll_preserves_style() {
	mut s := Screen.init(10, 3, 1)
	defer { s.deinit() }
	s.set_attribute(SgrAttribute{ kind: .bold }) or { assert false }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.cursor_down_scroll() or { assert false }

	assert s.cursor.style.flags.bold

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '2EFGH\n3IJKL'
}

// --- resize (no reflow) ---

fn test_screen_resize_no_reflow_more_rows_full() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 10, rows: 10, reflow: false }) or { assert false }
	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_resize_no_reflow_more_cols_full() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 20, rows: 3, reflow: false }) or { assert false }
	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '1ABCD\n2EFGH\n3IJKL'
}

fn test_screen_resize_no_reflow_less_cols_full() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 4, rows: 3, reflow: false }) or { assert false }
	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '1ABC\n2EFG\n3IJK'
}

fn test_screen_resize_no_reflow_less_rows_keeps_bottom_and_cursor() {
	mut s := Screen.init(2, 4, 10)
	defer { s.deinit() }
	s.test_write_string('1\n2\n3\n4') or { assert false }
	assert s.cursor.x == 1
	assert s.cursor.y == 3

	s.resize(ScreenResize{ cols: 2, rows: 2, reflow: false }) or { assert false }

	assert s.pages.active_start == 2
	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '3\n4'
	assert s.cursor.x == 1
	assert s.cursor.y == 1
}

fn test_screen_resize_no_reflow_does_not_trim_cursor_row() {
	mut s := Screen.init(3, 4, 10)
	defer { s.deinit() }
	s.cursor_absolute(1, 3)

	s.resize(ScreenResize{ cols: 3, rows: 2, reflow: false }) or { assert false }

	assert s.pages.screen_rows.len == 4
	assert s.pages.active_start == 2
	assert s.cursor.x == 1
	assert s.cursor.y == 1
}

fn test_screen_resize_no_reflow_does_not_trim_selection_row() {
	mut s := Screen.init(3, 4, 10)
	defer { s.deinit() }
	s.select(Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 2, y: 3 }, false)) or {
		assert false
	}

	s.resize(ScreenResize{ cols: 3, rows: 2, reflow: false }) or { assert false }

	assert s.pages.screen_rows.len == 4
	assert s.pages.active_start == 2
	if sel := s.selection {
		assert sel.start_pin == Pin{ x: 0, y: 0 }
		assert sel.end_pin == Pin{ x: 2, y: 3 }
	} else {
		assert false
	}
}

fn test_screen_resize_no_reflow_less_cols_clamps_cursor() {
	mut s := Screen.init(5, 2, 10)
	defer { s.deinit() }
	s.cursor_absolute(4, 1)

	s.resize(ScreenResize{ cols: 3, rows: 2, reflow: false }) or { assert false }

	assert s.cursor.x == 2
	assert s.cursor.y == 1
}

fn test_screen_resize_no_reflow_more_rows_pulls_cursor_with_history() {
	mut s := Screen.init(2, 2, 10)
	defer { s.deinit() }
	s.test_write_string('1\n2\n3\n4') or { assert false }
	assert s.pages.active_start == 2
	assert s.cursor.y == 1

	s.resize(ScreenResize{ cols: 2, rows: 4, reflow: false }) or { assert false }

	assert s.pages.active_start == 0
	assert s.cursor.x == 1
	assert s.cursor.y == 3
	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '1\n2\n3\n4'
}

fn test_screen_resize_no_reflow_more_rows_contains_pinned_viewport() {
	mut s := Screen.init(2, 2, 10)
	defer { s.deinit() }
	s.test_write_string('1\n2\n3\n4') or { assert false }
	s.scroll_to_row(1)
	assert s.pages.viewport == .pinned
	assert s.pages.viewport_start == 1

	s.resize(ScreenResize{ cols: 2, rows: 4, reflow: false }) or { assert false }

	assert s.pages.active_start == 0
	assert s.pages.viewport == .active
	assert s.pages.viewport_start == 0
}

fn test_screen_resize_no_reflow_trims_background_only_rows() {
	mut less := Screen.init(10, 3, 0)
	defer { less.deinit() }
	less.test_write_string('1ABCD') or { assert false }
	for y in 1 .. int(less.pages.rows) {
		less.pages.screen_rows[y].cells[0] = CellData{
			content_tag: .bg_color_rgb
			color_rgb_r: 0xff
		}
	}
	old_cursor := less.cursor
	less.resize(ScreenResize{ cols: 6, rows: 2, reflow: false }) or { panic(err) }
	assert less.cursor.x == old_cursor.x
	assert less.cursor.y == old_cursor.y
	assert less.dump_string_alloc(.viewport) or { panic(err) } == '1ABCD'

	mut more := Screen.init(10, 3, 0)
	defer { more.deinit() }
	more.test_write_string('1ABCD') or { assert false }
	for y in 1 .. int(more.pages.rows) {
		more.pages.screen_rows[y].cells[0] = CellData{
			content_tag: .bg_color_rgb
			color_rgb_r: 0xff
		}
	}
	more_cursor := more.cursor
	more.resize(ScreenResize{ cols: 10, rows: 7, reflow: false }) or { panic(err) }
	assert more.cursor.x == more_cursor.x
	assert more.cursor.y == more_cursor.y
	assert more.dump_string_alloc(.viewport) or { panic(err) } == '1ABCD'
}

fn test_screen_resize_no_reflow_scrollback_row_changes() {
	text := '1ABCD\n2EFGH\n3IJKL\n4ABCD\n5EFGH'
	mut grow := Screen.init(7, 3, 2)
	defer { grow.deinit() }
	grow.test_write_string(text) or { assert false }
	grow.resize(ScreenResize{ cols: 7, rows: 10, reflow: false }) or { panic(err) }
	assert grow.dump_string_alloc(.viewport) or { panic(err) } == text

	mut shrink := Screen.init(7, 3, 2)
	defer { shrink.deinit() }
	shrink.test_write_string(text) or { assert false }
	shrink.resize(ScreenResize{ cols: 7, rows: 2, reflow: false }) or { panic(err) }
	assert shrink.dump_string_alloc(.viewport) or { panic(err) } == '4ABCD\n5EFGH'
}

fn test_screen_resize_no_reflow_less_rows_with_empty_trailing() {
	mut s := Screen.init(5, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1\n2\n3\n4\n5\n6\n7\n8') or { assert false }
	s.scroll_clear() or { panic(err) }
	s.cursor_absolute(0, 0)
	s.test_write_string('A\nB') or { assert false }
	old_cursor := s.cursor
	s.resize(ScreenResize{ cols: 5, rows: 2, reflow: false }) or { panic(err) }
	assert s.cursor.x == old_cursor.x
	assert s.cursor.y == old_cursor.y
	assert s.dump_string_alloc(.viewport) or { panic(err) } == 'A\nB'
}

fn test_screen_resize_no_reflow_more_rows_preserves_soft_wraps() {
	mut s := Screen.init(2, 3, 3)
	defer { s.deinit() }
	s.test_write_string('1A2B\n3C4E\n5F6G') or { assert false }
	for y in 0 .. 6 {
		assert s.pages.screen_rows[y].wrap == (y % 2 == 0)
	}
	s.resize(ScreenResize{ cols: 2, rows: 10, reflow: false }) or { panic(err) }
	assert s.dump_string_alloc(.viewport) or { panic(err) } == '1A\n2B\n3C\n4E\n5F\n6G'
	for y in 0 .. 6 {
		assert s.pages.screen_rows[y].wrap == (y % 2 == 0)
	}
}

fn test_screen_resize_more_rows_no_scrollback() {
	mut s := Screen.init(10, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 10, rows: 10, reflow: true }) or { assert false }
	assert s.cursor.x == 5
	assert s.cursor.y == 2
	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
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

fn test_screen_select_line_semantic_prompt_to_input_boundary() {
	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('\$>') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('command') or { assert false }

	prompt := s.select_line(SelectLine{ pin: Pin{ x: 0, y: 0 } }) or { panic('no prompt selection') }
	assert prompt.start() == Pin{ x: 0, y: 0 }
	assert prompt.end() == Pin{ x: 1, y: 0 }
	input := s.select_line(SelectLine{ pin: Pin{ x: 5, y: 0 } }) or { panic('no input selection') }
	assert input.start() == Pin{ x: 2, y: 0 }
	assert input.end() == Pin{ x: 8, y: 0 }
}

fn test_screen_select_line_semantic_prompt_boundary() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string('ABCDE\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('A    ') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('> ') or { assert false }

	prompt := s.select_line(SelectLine{ pin: Pin{ x: 1, y: 1 } }) or { panic('no prompt selection') }
	assert s.selection_string(SelectionString{ sel: prompt, trim: false }) or { panic(err) } == 'A'
	output := s.select_line(SelectLine{ pin: Pin{ x: 1, y: 2 } }) or { panic('no output selection') }
	assert output.start() == Pin{ x: 0, y: 2 }
	assert output.end() == Pin{ x: 0, y: 2 }
}

fn test_screen_select_line_semantic_input_to_output_boundary() {
	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('ls -la\n') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('file.txt') or { assert false }

	input := s.select_line(SelectLine{ pin: Pin{ x: 2, y: 0 } }) or { panic('no input selection') }
	assert s.selection_string(SelectionString{ sel: input, trim: false }) or { panic(err) } == 'ls -la'
	output := s.select_line(SelectLine{ pin: Pin{ x: 2, y: 1 } }) or { panic('no output selection') }
	assert s.selection_string(SelectionString{ sel: output, trim: false }) or { panic(err) } == 'file.txt'
}

fn test_screen_select_line_semantic_mid_row_boundary() {
	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }
	s.cursor_set_semantic_content_output()
	s.test_write_string('out') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('\$>') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('cmd') or { assert false }

	output := s.select_line(SelectLine{ pin: Pin{ x: 1, y: 0 } }) or { panic('no output selection') }
	assert output.start() == Pin{ x: 0, y: 0 }
	assert output.end() == Pin{ x: 2, y: 0 }
	prompt := s.select_line(SelectLine{ pin: Pin{ x: 3, y: 0 } }) or { panic('no prompt selection') }
	assert prompt.start() == Pin{ x: 3, y: 0 }
	assert prompt.end() == Pin{ x: 4, y: 0 }
	input := s.select_line(SelectLine{ pin: Pin{ x: 6, y: 0 } }) or { panic('no input selection') }
	assert input.start() == Pin{ x: 5, y: 0 }
	assert input.end() == Pin{ x: 7, y: 0 }
}

fn test_screen_select_line_semantic_boundary_soft_wrap_with_mid_row_transition() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('\$ ') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('cmd12') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('out') or { assert false }

	for pin in [Pin{ x: 3, y: 0 }, Pin{ x: 0, y: 1 }] {
		sel := s.select_line(SelectLine{ pin: pin }) or { panic('no input selection') }
		assert s.selection_string(SelectionString{ sel: sel, trim: false }) or { panic(err) } == 'cmd12'
	}
	output := s.select_line(SelectLine{ pin: Pin{ x: 3, y: 1 } }) or { panic('no output selection') }
	assert s.selection_string(SelectionString{ sel: output, trim: false }) or { panic(err) } == 'out'
}

fn test_screen_select_line_semantic_boundary_disabled() {
	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('\$ ') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('command') or { assert false }

	sel := s.select_line(SelectLine{
		pin: Pin{ x: 0, y: 0 }
		semantic_prompt_boundary: false
	}) or { panic('no line selection') }
	assert s.selection_string(SelectionString{ sel: sel, trim: false }) or { panic(err) } == '\$ command'
}

fn test_screen_select_line_semantic_boundary_first_cell_of_row() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('12345') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('ABCDE') or { assert false }

	input := s.select_line(SelectLine{ pin: Pin{ x: 2, y: 0 } }) or { panic('no input selection') }
	assert input.start() == Pin{ x: 0, y: 0 }
	assert input.end() == Pin{ x: 4, y: 0 }
	output := s.select_line(SelectLine{ pin: Pin{ x: 2, y: 1 } }) or { panic('no output selection') }
	assert output.start() == Pin{ x: 0, y: 1 }
	assert output.end() == Pin{ x: 4, y: 1 }
}

fn test_screen_select_line_semantic_all_same_content() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('prompt text') or { assert false }

	sel := s.select_line(SelectLine{ pin: Pin{ x: 2, y: 1 } }) or { panic('no prompt selection') }
	assert s.selection_string(SelectionString{ sel: sel, trim: false }) or { panic(err) } == 'prompt text'
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

	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
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
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or {
		assert false
		return
	}
	assert str == '2EFGH\n3IJ'
}

fn test_screen_selection_string_start_outside() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 5 }, Pin{ x: 2, y: 6 }, false)
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or {
		assert false
		return
	}
	assert str == ''
}

fn test_screen_selection_string_end_outside() {
	mut s := Screen.init(5, 10, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 2 }, Pin{ x: 2, y: 6 }, false)
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or {
		assert false
		return
	}
	assert str == '3IJKL'
}

fn test_screen_selection_string_trim_space() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1AB  \n2EFGH\n3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 2, y: 1 }, false)

	str_trim := s.selection_string(SelectionString{ sel: sel, trim: true }) or {
		assert false
		return
	}
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

	str_trim := s.selection_string(SelectionString{ sel: sel, trim: true }) or {
		assert false
		return
	}
	assert str_trim == '1AB\n\n2EF'
}

fn test_screen_selection_string_soft_wrap() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH3IJKL') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 1 }, Pin{ x: 2, y: 2 }, false)
	str := s.selection_string(SelectionString{ sel: sel, trim: true }) or {
		assert false
		return
	}
	assert str == '2EFGH3IJ'
}

fn test_screen_selection_string_wide_char() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1A⚡') or { assert false }

	full := Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 3, y: 0 }, false)
	assert s.selection_string(SelectionString{ sel: full }) or { panic(err) } == '1A⚡'
	head := Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 2, y: 0 }, false)
	assert s.selection_string(SelectionString{ sel: head }) or { panic(err) } == '1A⚡'
	tail := Selection.init(Pin{ x: 3, y: 0 }, Pin{ x: 3, y: 0 }, false)
	assert s.selection_string(SelectionString{ sel: tail }) or { panic(err) } == '⚡'
}

fn test_screen_selection_string_wide_char_with_spacer_head() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABC⚡') or { assert false }
	sel := Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 4, y: 0 }, false)
	assert s.selection_string(SelectionString{ sel: sel }) or { panic(err) } == '1ABC⚡'
}

fn test_screen_selection_string_empty_with_soft_wrap() {
	mut s := Screen.init(5, 2, 0)
	defer { s.deinit() }
	s.test_write_string('👨      ') or { assert false }
	sel := Selection.init(Pin{ x: 1, y: 0 }, Pin{ x: 2, y: 0 }, false)
	assert s.selection_string(SelectionString{ sel: sel }) or { panic(err) } == '👨'
}

fn test_screen_selection_string_with_zero_width_joiner() {
	mut s := Screen.init(10, 1, 0)
	defer { s.deinit() }
	s.test_write_string('👨‍') or { assert false }
	assert s.pages.screen_rows[0].cells[0].graphemes == [u32(0x200d)]
	sel := Selection.init(Pin{ x: 0, y: 0 }, Pin{ x: 1, y: 0 }, false)
	assert s.selection_string(SelectionString{ sel: sel }) or { panic(err) } == '👨‍'
}

fn test_screen_selection_string_rectangle_basic() {
	mut s := Screen.init(30, 5, 0)
	defer { s.deinit() }
	s.test_write_string('Lorem ipsum dolor\nsit amet, consectetur\nadipiscing elit, sed do\neiusmod tempor incididunt\nut labore et dolore') or {
		assert false
	}
	sel := Selection.init(Pin{ x: 2, y: 1 }, Pin{ x: 6, y: 3 }, true)
	assert s.selection_string(SelectionString{ sel: sel }) or { panic(err) } == 't ame\nipisc\nusmod'
}

fn test_screen_selection_string_rectangle_with_eol() {
	mut s := Screen.init(30, 5, 0)
	defer { s.deinit() }
	s.test_write_string('Lorem ipsum dolor\nsit amet, consectetur\nadipiscing elit, sed do\neiusmod tempor incididunt\nut labore et dolore') or {
		assert false
	}
	sel := Selection.init(Pin{ x: 12, y: 0 }, Pin{ x: 26, y: 4 }, true)
	assert s.selection_string(SelectionString{ sel: sel }) or { panic(err) } == 'dolor\nnsectetur\nlit, sed do\nor incididunt\n dolore'
}

fn test_screen_selection_string_rectangle_more_complex_with_breaks() {
	mut s := Screen.init(30, 8, 0)
	defer { s.deinit() }
	s.test_write_string('Lorem ipsum dolor\nsit amet, consectetur\nadipiscing elit, sed do\neiusmod tempor incididunt\nut labore et dolore\n\nmagna aliqua. Ut enim\nad minim veniam, quis') or {
		assert false
	}
	sel := Selection.init(Pin{ x: 11, y: 2 }, Pin{ x: 26, y: 7 }, true)
	assert s.selection_string(SelectionString{ sel: sel }) or { panic(err) } == 'elit, sed do\npor incididunt\nt dolore\n\na. Ut enim\nniam, quis'
}

// --- lineIterator ---

fn test_screen_line_iterator_basic() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH') or { assert false }
	mut it := s.line_iterator(Pin{ x: 0, y: u32(s.pages.active_start) })

	sel1 := it.next() or {
		assert false
		return
	}
	str1 := s.selection_string(SelectionString{ sel: sel1, trim: false }) or {
		assert false
		return
	}
	assert str1 == '1ABCD'

	sel2 := it.next() or {
		assert false
		return
	}
	str2 := s.selection_string(SelectionString{ sel: sel2, trim: false }) or {
		assert false
		return
	}
	assert str2 == '2EFGH'
}

fn test_screen_line_iterator_soft_wrap() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH\n3ABCD') or { assert false }
	mut it := s.line_iterator(Pin{ x: 0, y: u32(s.pages.active_start) })

	sel1 := it.next() or {
		assert false
		return
	}
	str1 := s.selection_string(SelectionString{ sel: sel1, trim: false }) or {
		assert false
		return
	}
	assert str1 == '1ABCD2EFGH'

	sel2 := it.next() or {
		assert false
		return
	}
	str2 := s.selection_string(SelectionString{ sel: sel2, trim: false }) or {
		assert false
		return
	}
	assert str2 == '3ABCD'
}

fn test_screen_line_iterator_invalid_start_is_exhausted() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	mut it := s.line_iterator(Pin{ x: 0, y: 99 })

	assert it.next() == none
	assert it.current == none
	assert it.next() == none
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

fn test_screen_prompt_click_move_uses_input_under_cursor() {
	mut s := pcm_setup()
	defer { s.deinit() }
	// The pending pen state is output, but the cursor is moved onto an input
	// cell that was already written. Ghostty permits prompt navigation here.
	s.cursor_set_semantic_content_output()
	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 4, y: u32(s.pages.active_start) })
	assert r.right == 2
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

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
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

fn test_screen_prompt_click_move_line_right_stops_at_hard_wrap() {
	mut s := Screen.init(20, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('hello\nworld') or { assert false }

	s.cursor_absolute(2, 0)
	r := s.prompt_click_move(Pin{ x: 0, y: u32(s.pages.active_start) + 1 })
	assert r.right == 5
	assert r.left == 0
}

fn test_screen_prompt_click_move_line_right_stops_at_non_continuation_row() {
	mut s := Screen.init(20, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('hello\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.continuation)
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('world\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('again') or { assert false }

	s.cursor_absolute(0, 1)
	r := s.prompt_click_move(Pin{ x: 2, y: u32(s.pages.active_start) + 2 })
	assert r.right == 5
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

	str := s.dump_string_alloc(.active) or {
		assert false
		return
	}
	assert str == '> abcdefgh\nij'

	s.cursor_absolute(1, 1)
	r := s.prompt_click_move(Pin{ x: 2, y: u32(s.pages.active_start) })
	assert r.left == 9
	assert r.right == 0
}

fn test_screen_prompt_click_move_line_left_stops_at_hard_wrap() {
	mut s := Screen.init(20, 5, 0)
	defer { s.deinit() }
	s.semantic_prompt.click = .cl_line
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(false)
	s.test_write_string('hello\nworld') or { assert false }

	s.cursor_absolute(4, 1)
	r := s.prompt_click_move(Pin{ x: 2, y: u32(s.pages.active_start) })
	assert r.left == 4
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

// ============================================================
// Resize + reflow tests (translated from ghostty Screen.zig)
// ============================================================

// Helper: read the codepoint of the cell at active coordinate (x, y).
fn active_codepoint(s &Screen, x u32, y u32) u32 {
	idx := s.pages.active_start + int(y)
	if idx < 0 || idx >= s.pages.screen_rows.len {
		return 0
	}
	row := s.pages.screen_rows[idx]
	if int(x) >= row.cells.len {
		return 0
	}
	return row.cells[int(x)].codepoint
}

// --- resize more cols ---

fn test_screen_resize_more_cols_perfect_split() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH3IJKL') or { assert false }
	s.resize(ScreenResize{ cols: 10, rows: 3, reflow: true }) or { assert false }

	str := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str == '1ABCD2EFGH\n3IJKL'
}

fn test_screen_resize_more_cols_no_reflow_preserves_semantic_prompt() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }

	// Set one of the rows to be a prompt
	s.cursor_set_semantic_content_output()
	s.test_write_string('1ABCD\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('2EFGH') or { assert false }
	s.cursor_set_semantic_content_output()
	s.test_write_string('\n3IJKL') or { assert false }

	s.resize(ScreenResize{ cols: 10, rows: 3, reflow: false }) or { assert false }

	expected := '1ABCD\n2EFGH\n3IJKL'
	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == expected
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == expected

	// Our one row should still be a semantic prompt, the others should not.
	assert s.pages.get_active_row(0).semantic_prompt == .unknown
	assert s.pages.get_active_row(1).semantic_prompt == .prompt
	assert s.pages.get_active_row(2).semantic_prompt == .unknown
}

fn test_screen_resize_more_cols_reflow_fits_full_width() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	str := '1ABCD2EFGH\n3IJKL'
	s.test_write_string(str) or { assert false }

	// Verify we soft wrapped
	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == '1ABCD\n2EFGH\n3IJKL'

	// Put our cursor on row 2, where the soft wrap is
	s.cursor_absolute(0, 1)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`2`)

	// Resize and verify we undid the soft wrap because we have space now
	s.resize(ScreenResize{ cols: 10, rows: 3, reflow: true }) or { assert false }
	str_view1 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view1 == str

	// Our cursor should've moved
	assert s.cursor.x == 5
	assert s.cursor.y == 0
}

fn test_screen_resize_more_cols_reflows_saved_cursor() {
	mut s := Screen.init(2, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1A2B') or { assert false }
	s.saved_cursor = SavedCursor{
		x: 1
		y: 1
	}

	s.resize(ScreenResize{ cols: 5, rows: 3, reflow: true }) or { assert false }

	if sc := s.saved_cursor {
		assert sc.x == 3
		assert sc.y == 0
		assert !sc.pending_wrap
	} else {
		assert false
	}
}

fn test_screen_resize_more_cols_reflows_selection() {
	mut s := Screen.init(2, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1A2B') or { assert false }
	s.select(Selection.init(Pin{ x: 1, y: 1 }, Pin{ x: 0, y: 0 }, false)) or {
		assert false
	}

	s.resize(ScreenResize{ cols: 5, rows: 3, reflow: true }) or { assert false }

	if sel := s.selection {
		// Preserve the backwards orientation while remapping B and 1.
		assert sel.start_pin == Pin{ x: 3, y: 0 }
		assert sel.end_pin == Pin{ x: 0, y: 0 }
	} else {
		assert false
	}
}

fn test_screen_resize_more_cols_reflows_pinned_viewport() {
	mut s := Screen.init(2, 2, 10)
	defer { s.deinit() }
	s.test_write_string('ABCD\nEF\nGH') or { assert false }
	assert s.pages.active_start == 2
	s.scroll_to_row(1)
	assert s.pages.viewport == .pinned

	s.resize(ScreenResize{ cols: 4, rows: 2, reflow: true }) or { assert false }

	// The old row 1 was the continuation "CD". It was unwrapped into row 0,
	// so the tracked viewport follows it instead of jumping to active row 1.
	assert s.pages.active_start == 1
	assert s.pages.viewport == .pinned
	assert s.pages.viewport_start == 0
}

fn test_screen_resize_more_cols_reflow_ends_in_newline() {
	mut s := Screen.init(6, 3, 0)
	defer { s.deinit() }
	str := '1ABCD2EFGH\n3IJKL'
	s.test_write_string(str) or { assert false }

	// Verify we soft wrapped
	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == '1ABCD2\nEFGH\n3IJKL'

	// Put our cursor on the last row
	s.cursor_absolute(0, 2)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`3`)

	// Resize and verify we undid the soft wrap because we have space now
	s.resize(ScreenResize{ cols: 10, rows: 3, reflow: true }) or { assert false }
	str_view1 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view1 == str

	// Our cursor should still be on the 3
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`3`)
}

fn test_screen_resize_more_cols_reflow_forces_more_wrapping() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH\n3IJKL') or { assert false }

	// Put our cursor on row 2, where the soft wrap is
	s.cursor_absolute(0, 1)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`2`)

	// Verify we soft wrapped
	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == '1ABCD\n2EFGH\n3IJKL'

	// Resize
	s.resize(ScreenResize{ cols: 7, rows: 3, reflow: true }) or { assert false }
	str_view1 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view1 == '1ABCD2E\nFGH\n3IJKL'

	// Our cursor should've moved
	assert s.cursor.x == 5
	assert s.cursor.y == 0
}

fn test_screen_resize_more_cols_reflow_unwraps_multiple_times() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH3IJKL') or { assert false }

	// Put our cursor on row 3, where the soft wrap is
	s.cursor_absolute(0, 2)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`3`)

	// Verify we soft wrapped
	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == '1ABCD\n2EFGH\n3IJKL'

	// Resize
	s.resize(ScreenResize{ cols: 15, rows: 3, reflow: true }) or { assert false }
	str_view1 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view1 == '1ABCD2EFGH3IJKL'

	// Our cursor should've moved
	assert s.cursor.x == 10
	assert s.cursor.y == 0
}

fn test_screen_resize_more_cols_with_populated_scrollback() {
	mut s := Screen.init(5, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH\n3IJKL\n4ABCD5EFGH') or { assert false }
	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == '3IJKL\n4ABCD\n5EFGH'

	// Set our cursor to be on the "5"
	s.cursor_absolute(0, 2)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`5`)

	// Resize
	s.resize(ScreenResize{ cols: 10, rows: 3, reflow: true }) or { assert false }
	str_view1 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view1 == '2EFGH\n3IJKL\n4ABCD5EFGH'

	// Cursor should still be on the "5"
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`5`)
}

fn test_screen_resize_more_cols_with_reflow() {
	mut s := Screen.init(2, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1ABC\n2DEF\n3ABC\n4DEF') or { assert false }

	// Put our cursor on row 3, where the soft wrap is
	s.cursor_absolute(0, 2)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`E`)

	// Verify we soft wrapped
	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == 'BC\n4D\nEF'

	// Resize
	s.resize(ScreenResize{ cols: 7, rows: 3, reflow: true }) or { assert false }
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '1ABC\n2DEF\n3ABC\n4DEF'

	// Our cursor should've moved
	assert s.cursor.x == 2
	assert s.cursor.y == 2
}

// --- resize less cols ---

fn test_screen_resize_less_cols_reflow_but_row_space() {
	mut s := Screen.init(5, 3, 1)
	defer { s.deinit() }
	s.test_write_string('1ABCD') or { assert false }

	// Put our cursor on the end
	s.cursor_absolute(4, 0)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`D`)

	s.resize(ScreenResize{ cols: 3, rows: 3, reflow: true }) or { assert false }
	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == '1AB\nCD'
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '1AB\nCD'

	// Cursor should be on the last line
	assert s.cursor.x == 1
	assert s.cursor.y == 1
}

fn test_screen_resize_less_cols_reflow_with_trimmed_rows() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('3IJKL\n4ABCD\n5EFGH') or { assert false }
	s.resize(ScreenResize{ cols: 3, rows: 3, reflow: true }) or { assert false }

	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == 'CD\n5EF\nGH'
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == 'CD\n5EF\nGH'
}

fn test_screen_resize_less_cols_reflow_with_trimmed_rows_and_scrollback() {
	mut s := Screen.init(5, 3, 1)
	defer { s.deinit() }
	s.test_write_string('3IJKL\n4ABCD\n5EFGH') or { assert false }
	s.resize(ScreenResize{ cols: 3, rows: 3, reflow: true }) or { assert false }

	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == 'CD\n5EF\nGH'
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '3IJ\nKL\n4AB\nCD\n5EF\nGH'
}

fn test_screen_resize_less_cols_reflow_previously_wrapped() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }
	s.test_write_string('3IJKL4ABCD5EFGH') or { assert false }

	str_screen0 := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen0 == '3IJKL\n4ABCD\n5EFGH'

	s.resize(ScreenResize{ cols: 3, rows: 3, reflow: true }) or { assert false }

	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == 'ABC\nD5E\nFGH'
}

fn test_screen_resize_less_cols_reflow_and_scrollback() {
	mut s := Screen.init(5, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1A\n2B\n3C\n4D\n5E') or { assert false }

	// Put our cursor on the end
	s.cursor_absolute(1, s.pages.rows - 1)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`E`)

	s.resize(ScreenResize{ cols: 3, rows: 3, reflow: true }) or { assert false }

	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == '3C\n4D\n5E'

	// Cursor should be on the last line
	assert s.cursor.x == 1
	assert s.cursor.y == 2
}

fn test_screen_resize_less_cols_reflow_previously_wrapped_and_scrollback() {
	mut s := Screen.init(5, 3, 2)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH3IJKL4ABCD5EFGH') or { assert false }

	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == '3IJKL\n4ABCD\n5EFGH'

	// Put our cursor on the end
	s.cursor_absolute(s.pages.cols - 1, s.pages.rows - 1)
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`H`)

	s.resize(ScreenResize{ cols: 3, rows: 3, reflow: true }) or { assert false }

	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == 'CD5\nEFG\nH'
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '1AB\nCD2\nEFG\nH3I\nJKL\n4AB\nCD5\nEFG\nH'

	// Cursor should be on the last line
	assert s.cursor.x == 0
	assert s.cursor.y == 2
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`H`)
}

fn test_screen_resize_less_cols_with_scrollback_keeps_cursor_row() {
	mut s := Screen.init(5, 3, 5)
	defer { s.deinit() }
	s.test_write_string('1A\n2B\n3C\n4D\n5E') or { assert false }

	// Scroll and clear operation
	s.scroll_clear() or { assert false }

	// Move our cursor to the beginning
	s.cursor_absolute(0, 0)

	s.resize(ScreenResize{ cols: 3, rows: 3, reflow: true }) or { assert false }

	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == ''

	// Cursor should be on the last line
	assert s.cursor.x == 0
	assert s.cursor.y == 0
}

fn test_screen_resize_more_rows_less_cols_reflow_with_scrollback() {
	mut s := Screen.init(5, 3, 3)
	defer { s.deinit() }
	s.test_write_string('1ABCD\n2EFGH3IJKL\n4MNOP') or { assert false }

	str_screen0 := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen0 == '1ABCD\n2EFGH\n3IJKL\n4MNOP'
	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == '2EFGH\n3IJKL\n4MNOP'

	s.resize(ScreenResize{ cols: 2, rows: 10, reflow: true }) or { assert false }

	str_view := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view == 'BC\nD\n2E\nFG\nH3\nIJ\nKL\n4M\nNO\nP'
	str_screen := s.dump_string_alloc(.screen) or {
		assert false
		return
	}
	assert str_screen == '1A\nBC\nD\n2E\nFG\nH3\nIJ\nKL\n4M\nNO\nP'
	// The live cursor is a tracked pin independent from the resize helper's
	// active-relative cursor hint, so it must continue to point at P.
	assert s.cursor.x == 0
	assert s.cursor.y == 9
	assert active_codepoint(s, s.cursor.x, s.cursor.y) == u32(`P`)
}

fn test_screen_resize_less_cols_eliminates_wide_char() {
	mut s := Screen.init(2, 1, 0)
	defer { s.deinit() }
	s.test_write_string('😀') or { assert false }
	assert s.dump_string_alloc(.screen) or { panic(err) } == '😀'
	assert s.pages.screen_rows[0].cells[0].wide == .wide
	assert s.pages.screen_rows[0].cells[0].codepoint == u32(`😀`)

	s.resize(ScreenResize{ cols: 1, rows: 1 }) or { panic(err) }
	assert s.dump_string_alloc(.screen) or { panic(err) } == ''
	assert s.pages.screen_rows[0].cells[0].codepoint == 0
	assert s.pages.screen_rows[0].cells[0].wide == .narrow
}

fn test_screen_resize_less_cols_wraps_wide_char() {
	mut s := Screen.init(3, 3, 0)
	defer { s.deinit() }
	s.test_write_string('x😀') or { assert false }
	assert s.pages.screen_rows[0].cells[1].wide == .wide
	assert s.pages.screen_rows[0].cells[2].wide == .spacer_tail

	s.resize(ScreenResize{ cols: 2, rows: 3 }) or { panic(err) }
	assert s.dump_string_alloc(.screen) or { panic(err) } == 'x\n😀'
	assert s.pages.screen_rows[0].cells[1].wide == .spacer_head
	assert s.pages.screen_rows[0].wrap
}

fn test_screen_resize_less_cols_eliminates_wide_char_with_row_space() {
	mut s := Screen.init(2, 2, 0)
	defer { s.deinit() }
	s.test_write_string('😀') or { assert false }
	assert s.pages.screen_rows[0].cells[0].wide == .wide
	assert s.pages.screen_rows[0].cells[1].wide == .spacer_tail

	s.resize(ScreenResize{ cols: 1, rows: 2 }) or { panic(err) }
	assert s.dump_string_alloc(.screen) or { panic(err) } == ''
}

fn test_screen_resize_more_cols_unwraps_wide_spacer_head() {
	mut s := Screen.init(3, 2, 0)
	defer { s.deinit() }
	s.test_write_string('  😀') or { assert false }
	assert s.dump_string_alloc(.screen) or { panic(err) } == '  \n😀'
	assert s.pages.screen_rows[0].cells[2].wide == .spacer_head
	assert s.pages.screen_rows[1].cells[0].wide == .wide
	assert s.pages.screen_rows[1].cells[1].wide == .spacer_tail

	s.resize(ScreenResize{ cols: 4, rows: 2 }) or { panic(err) }
	assert s.dump_string_alloc(.screen) or { panic(err) } == '  😀'
	assert s.pages.screen_rows[0].cells[2].wide == .wide
	assert s.pages.screen_rows[0].cells[2].codepoint == u32(`😀`)
	assert s.pages.screen_rows[0].cells[3].wide == .spacer_tail
}

fn test_screen_resize_more_cols_unwraps_multiple_lines_with_wide_spacer_head() {
	mut s := Screen.init(3, 3, 0)
	defer { s.deinit() }
	s.test_write_string('xxxyy😀') or { assert false }
	assert s.dump_string_alloc(.screen) or { panic(err) } == 'xxx\nyy\n😀'
	assert s.pages.screen_rows[1].cells[2].wide == .spacer_head
	assert s.pages.screen_rows[2].cells[0].wide == .wide
	assert s.pages.screen_rows[2].cells[1].wide == .spacer_tail

	s.resize(ScreenResize{ cols: 8, rows: 2 }) or { panic(err) }
	assert s.dump_string_alloc(.screen) or { panic(err) } == 'xxxyy😀'
	assert s.pages.screen_rows[0].cells[5].wide == .wide
	assert s.pages.screen_rows[0].cells[5].codepoint == u32(`😀`)
	assert s.pages.screen_rows[0].cells[6].wide == .spacer_tail
}

fn test_screen_resize_more_cols_creates_required_wide_spacer_head() {
	mut s := Screen.init(2, 2, 0)
	defer { s.deinit() }
	s.test_write_string('xx😀') or { assert false }
	assert s.dump_string_alloc(.screen) or { panic(err) } == 'xx\n😀'
	assert s.pages.screen_rows[1].cells[0].wide == .wide
	assert s.pages.screen_rows[1].cells[1].wide == .spacer_tail

	s.resize(ScreenResize{ cols: 3, rows: 2 }) or { panic(err) }
	assert s.dump_string_alloc(.screen) or { panic(err) } == 'xx\n😀'
	assert s.pages.screen_rows[0].cells[2].wide == .spacer_head
	assert s.pages.screen_rows[1].cells[0].wide == .wide
	assert s.pages.screen_rows[1].cells[0].codepoint == u32(`😀`)
	assert s.pages.screen_rows[1].cells[1].wide == .spacer_tail
}

// --- resize more cols with cursor at/not at prompt ---

fn test_screen_resize_more_cols_with_cursor_at_prompt() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }

	s.test_write_string('ABCDE\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('echo') or { assert false }

	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == 'ABCDE\n> echo'

	s.resize(ScreenResize{ cols: 20, rows: 3, reflow: true, prompt_redraw: .true_ }) or {
		assert false
	}

	// Cursor should not move
	assert s.cursor.x == 6
	assert s.cursor.y == 1

	str_view1 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view1 == 'ABCDE'
}

fn test_screen_resize_more_cols_with_cursor_not_at_prompt() {
	mut s := Screen.init(10, 3, 5)
	defer { s.deinit() }

	s.test_write_string('ABCDE\n') or { assert false }
	s.cursor_set_semantic_content_prompt(.initial)
	s.test_write_string('> ') or { assert false }
	s.cursor_set_semantic_content_input(true)
	s.test_write_string('echo\n') or { assert false }
	s.test_write_string('output') or { assert false }

	str_view0 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view0 == 'ABCDE\n> echo\noutput'

	s.resize(ScreenResize{ cols: 20, rows: 3, reflow: true, prompt_redraw: .true_ }) or {
		assert false
	}

	// Cursor should not move
	assert s.cursor.x == 6
	assert s.cursor.y == 2

	str_view1 := s.dump_string_alloc(.viewport) or {
		assert false
		return
	}
	assert str_view1 == 'ABCDE\n> echo\noutput'
}

fn test_screen_test_write_string_wide_and_grapheme() {
	mut s := Screen.init(4, 2, 0)
	defer { s.deinit() }

	s.test_write_string('A界́') or { assert false }
	row := s.pages.screen_rows[s.pages.active_start]
	assert row.cells[0].codepoint == u32(`A`)
	assert row.cells[1].codepoint == u32(`界`)
	assert row.cells[1].wide == .wide
	assert row.cells[1].content_tag == .codepoint_grapheme
	assert row.cells[1].graphemes == [u32(0x0301)]
	assert row.cells[2].wide == .spacer_tail
	assert row.grapheme
	assert s.cursor.x == 3
}

fn test_screen_test_write_string_wide_wraps_with_spacer_head() {
	mut s := Screen.init(3, 2, 0)
	defer { s.deinit() }

	s.test_write_string('AB界') or { assert false }
	first := s.pages.screen_rows[s.pages.active_start]
	second := s.pages.screen_rows[s.pages.active_start + 1]
	assert first.cells[2].wide == .spacer_head
	assert first.wrap
	assert second.wrap_continuation
	assert second.cells[0].codepoint == u32(`界`)
	assert second.cells[0].wide == .wide
	assert second.cells[1].wide == .spacer_tail
	assert s.cursor.x == 2
	assert s.cursor.y == 1
}

fn test_screen_test_write_string_preserves_style_and_hyperlink() {
	mut s := Screen.init(4, 2, 0)
	defer { s.deinit() }

	s.cursor.style.flags.bold = true
	s.manual_style_update() or { assert false }
	s.start_hyperlink('https://example.com/', 'test') or { assert false }
	s.test_write_string('界') or { assert false }
	row := s.pages.screen_rows[s.pages.active_start]
	assert row.styled
	assert row.hyperlink
	assert row.cells[0].style.flags.bold
	assert row.cells[0].has_hyperlink
	assert row.cells[1].has_hyperlink
}

fn test_screen_dump_string_bounded_region() {
	mut s := Screen.init(5, 3, 0)
	defer { s.deinit() }

	s.test_write_string('ABCDE\nFGHIJ\nKLMNO') or { assert false }
	result := s.dump_string(DumpStringOptions{
		tl: Pin{ x: 1, y: 0 }
		br: Pin{ x: 2, y: 1 }
		unwrap: false
	}) or {
		assert false
		return
	}
	assert result == 'BCDE\nFGH'
}

fn test_key_flag_stack_wraps_at_capacity() {
	mut stack := KeyFlagStack{}
	for value in 1 .. 9 {
		stack.push(u32(value))
	}
	assert stack.idx == 0
	assert stack.current() == 8

	stack.pop(1)
	assert stack.idx == 7
	assert stack.current() == 7
}

fn test_key_flag_stack_pop_zero_is_noop() {
	mut stack := KeyFlagStack{}
	stack.push(5)
	stack.pop(0)
	assert stack.current() == 5
}

fn test_key_flag_stack_large_pop_resets_all_entries() {
	mut stack := KeyFlagStack{}
	stack.set(.set_, 3)
	stack.push(5)
	stack.pop(256)
	assert stack.idx == 0
	assert stack.current() == 0
	assert stack.flags == [8]u32{}
}
