module vaxis

fn test_dependency_enum_and_mouse_layouts_match_source() {
	assert sizeof(Scheme) == 1
	assert u8(Scheme.dark) == 0
	assert u8(Scheme.light) == 1

	assert sizeof(UnderlineStyle) == 1
	assert u8(UnderlineStyle.off) == 0
	assert u8(UnderlineStyle.single) == 1
	assert u8(UnderlineStyle.double_) == 2
	assert u8(UnderlineStyle.curly) == 3
	assert u8(UnderlineStyle.dotted) == 4
	assert u8(UnderlineStyle.dashed) == 5

	assert sizeof(MouseButton) == 1
	assert u8(MouseButton.left) == 0
	assert u8(MouseButton.middle) == 1
	assert u8(MouseButton.right) == 2
	assert u8(MouseButton.none_) == 3
	assert u8(MouseButton.wheel_up) == 64
	assert u8(MouseButton.wheel_down) == 65
	assert u8(MouseButton.wheel_right) == 66
	assert u8(MouseButton.wheel_left) == 67
	assert u8(MouseButton.button_8) == 128
	assert u8(MouseButton.button_9) == 129
	assert u8(MouseButton.button_10) == 130
	assert u8(MouseButton.button_11) == 131

	assert sizeof(MouseType) == 1
	assert u8(MouseType.press) == 0
	assert u8(MouseType.release) == 1
	assert u8(MouseType.motion) == 2
	assert u8(MouseType.drag) == 3
	assert sizeof(MouseModifiers) == 1
	assert sizeof(Mouse) == 12
	assert sizeof(Winsize) == 8
	assert sizeof(Modifiers) == 1
	assert Modifiers.init(true, true, true, true, true, true, true, true).int() == 0xff
	assert sizeof(KittyFlags) == 1
	assert KittyFlags{}.int() == 0b11101
	assert KittyFlags{}.disambiguate()
	assert !KittyFlags{}.report_events()
	assert KittyFlags{}.report_alternate_keys()
	assert KittyFlags{}.report_all_as_ctl_seqs()
	assert KittyFlags{}.report_text()
}

fn parsed_key_event(input string) Key {
	parsed := parse_input(input.bytes()) or { panic('input should decode') }
	event := parsed.event or { panic('input should produce an event') }
	match event {
		Key {
			return event
		}
		else {
			panic('expected key event')
		}
	}
}

fn test_key_decoder_handles_text_modifiers_and_navigation() {
	a := parsed_key_event('a')
	assert a.matches(u32(`a`), Modifiers{})
	assert a.text or { '' } == 'a'
	upper := parsed_key_event('C')
	assert upper.codepoint == `C`
	assert upper.mods.eql(Modifiers{})
	assert upper.text or { '' } == 'C'
	assert upper.matches(u32(`c`), Modifiers.from_int(1))
	assert parsed_key_event('\x03').matches(u32(`c`), Modifiers.from_int(4))
	assert parsed_key_event('\x00').matches(u32(`@`), Modifiers.from_int(4))
	assert parsed_key_event('\x0a').matches(u32(`j`), Modifiers.from_int(4))
	assert parsed_key_event('\x0d').codepoint == enter
	assert parsed_key_event('\x08').codepoint == backspace
	assert parsed_key_event('\x7f').codepoint == backspace
	assert parsed_key_event('\x09').codepoint == tab
	assert parsed_key_event('\x1b').codepoint == escape
	alt := parsed_key_event('\x1ba')
	assert alt.codepoint == `a`
	assert alt.mods.eql(Modifiers.from_int(2))
	assert parsed_key_event('\x1b[A').codepoint == up
	assert parsed_key_event('\x1b[B').codepoint == down
	assert parsed_key_event('\x1bOC').codepoint == right
	assert parsed_key_event('\x1bOD').codepoint == left
	assert parsed_key_event('\x1bOE').codepoint == kp_begin
	assert parsed_key_event('\x1bOQ').codepoint == f2
	assert parsed_key_event('\x1bOR').codepoint == f3
	assert parsed_key_event('\x1bOS').codepoint == f4
	assert parsed_key_event('\x1b[5~').codepoint == page_up
	assert parsed_key_event('\x1b[6~').codepoint == page_down
	assert parsed_key_event('\x1bOP').codepoint == f1
	shift_up := parsed_key_event('\x1b[1;2A')
	assert shift_up.codepoint == up
	assert shift_up.mods.eql(Modifiers.from_int(1))
	assert parsed_key_event('\x1b[2~').codepoint == insert
	assert parsed_key_event('\x1b[24~').codepoint == f12
}

fn test_key_model_matches_pinned_vaxis_rules_and_constants() {
	key_a := Key{
		codepoint: u32(`a`)
		text:      'a'
		mods:      Modifiers.from_int(128)
	}
	assert key_a.matches(u32(`a`), Modifiers{})
	assert !key_a.matches(u32(`a`), Modifiers.from_int(1))

	shift_a := Key{
		codepoint:         u32(`a`)
		shifted_codepoint: u32(`A`)
		text:              'A'
		mods:              Modifiers.from_int(1)
	}
	assert shift_a.matches(u32(`a`), Modifiers.from_int(1))
	assert !shift_a.matches(u32(`a`), Modifiers{})
	assert shift_a.matches(u32(`A`), Modifiers{})
	assert !shift_a.matches(u32(`A`), Modifiers.from_int(4))

	shift_semicolon := Key{
		codepoint:         u32(`;`)
		shifted_codepoint: u32(`:`)
		text:              ':'
		mods:              Modifiers.from_int(1)
	}
	assert shift_semicolon.matches(u32(`;`), Modifiers.from_int(1))
	assert shift_semicolon.matches(u32(`:`), Modifiers{})
	assert Key{
		codepoint: left_shift
	}.is_modifier()
	assert !Key{
		codepoint: f1
	}.is_modifier()
	assert name_map['insert'] == insert
	assert name_map['f32'] == f32_key
	assert backspace == 0x7f
	assert insert == 57348
	assert f1 == 57364
	assert kp_enter == 57414
	assert iso_level_5_shift == 57454
}

fn test_key_decoder_handles_kitty_fields_and_ignored_sequences() {
	shift_a := parsed_key_event('\x1b[97:65;2u')
	assert shift_a.codepoint == `a`
	assert shift_a.shifted_codepoint or { 0 } == `A`
	assert shift_a.text or { '' } == 'A'
	assert shift_a.mods.eql(Modifiers.from_int(1))

	alt_shift_a := parsed_key_event('\x1b[97:65:113;4;65u')
	assert alt_shift_a.base_layout_codepoint or { 0 } == `q`
	assert alt_shift_a.mods.eql(Modifiers.from_int(3))
	assert alt_shift_a.text or { '' } == 'A'

	release := parse_input('\x1b[97;1:3u'.bytes()) or { panic('release should be consumed') }
	assert release.consumed == 9
	release_event := release.event or { panic('release should produce an event') }
	match release_event {
		KeyRelease {
			assert release_event.key.codepoint == `a`
		}
		else {
			assert false
		}
	}

	unknown := parse_input('\x1b[999z'.bytes()) or { panic('unknown CSI should be consumed') }
	assert unknown.consumed == 6
	assert unknown.event == none
	unknown_ss3 := parse_input('\x1bOZ'.bytes()) or { panic('unknown SS3 should be consumed') }
	assert unknown_ss3.consumed == 3
	assert unknown_ss3.event == none
}

fn test_parser_restores_pinned_non_key_events() {
	focus_in_result := parse_input('\x1b[I'.bytes()) or { panic('focus-in should decode') }
	focus_in_event := focus_in_result.event or { panic('focus-in should produce an event') }
	assert focus_in_event is FocusIn
	focus_out_result := parse_input('\x1b[O'.bytes()) or { panic('focus-out should decode') }
	focus_out_event := focus_out_result.event or { panic('focus-out should produce an event') }
	assert focus_out_event is FocusOut

	paste_start_result := parse_input('\x1b[200~'.bytes()) or { panic('paste-start should decode') }
	paste_start_event := paste_start_result.event or {
		panic('paste-start should produce an event')
	}
	assert paste_start_event is PasteStart
	paste_end_result := parse_input('\x1b[201~'.bytes()) or { panic('paste-end should decode') }
	paste_end_event := paste_end_result.event or { panic('paste-end should produce an event') }
	assert paste_end_event is PasteEnd

	paste_result := parse_input('\x1b]52;c;b3NjNTIgcGFzdGU=\x1b\\'.bytes()) or {
		panic('OSC 52 should decode')
	}
	paste_event := paste_result.event or { panic('OSC 52 should produce an event') }
	match paste_event {
		Paste {
			assert paste_event.text == 'osc52 paste'
		}
		else {
			assert false
		}
	}

	color_result := parse_input('\x1b]11;rgb:aaaa/bbbb/cccc\x07'.bytes()) or {
		panic('color report should decode')
	}
	color_event := color_result.event or { panic('color report should produce an event') }
	match color_event {
		ColorReport {
			assert color_event.value == [u8(0xaa), 0xbb, 0xcc]!
			assert color_event.kind is ColorReportBg
		}
		else {
			assert false
		}
	}

	dark_result := parse_input('\x1b[?997;1n'.bytes()) or { panic('scheme should decode') }
	dark_event := dark_result.event or { panic('scheme should produce an event') }
	match dark_event {
		ColorScheme {
			assert dark_event.scheme == .dark
		}
		else {
			assert false
		}
	}

	resize_result := parse_input('\x1b[48;24;80;720;1280t'.bytes()) or {
		panic('resize should decode')
	}
	resize_event := resize_result.event or { panic('resize should produce an event') }
	match resize_event {
		Winsize {
			assert resize_event.rows == 24
			assert resize_event.cols == 80
			assert resize_event.y_pixel == 720
			assert resize_event.x_pixel == 1280
		}
		else {
			assert false
		}
	}
}

fn test_parser_restores_capability_and_control_string_events() {
	kitty_keyboard_result := parse_input('\x1b[?u'.bytes()) or {
		panic('Kitty query should decode')
	}
	kitty_keyboard := kitty_keyboard_result.event or {
		panic('Kitty query should produce an event')
	}
	match kitty_keyboard {
		CapabilityEvent {
			assert kitty_keyboard.capability == .kitty_keyboard
		}
		else {
			assert false
		}
	}

	kitty_graphics_result := parse_input('\x1b_Gi=1;OK\x1b\\'.bytes()) or {
		panic('Kitty graphics response should decode')
	}
	kitty_graphics := kitty_graphics_result.event or {
		panic('Kitty graphics response should produce an event')
	}

	match kitty_graphics {
		CapabilityEvent {
			assert kitty_graphics.capability == .kitty_graphics
		}
		else {
			assert false
		}
	}

	da_result := parse_input('\x1b[?1;2c'.bytes()) or { panic('DA should decode') }
	da := da_result.event or { panic('DA should produce an event') }
	match da {
		CapabilityEvent {
			assert da.capability == .da1
		}
		else {
			assert false
		}
	}

	pixels_result := parse_input('\x1b[?1016;1$y'.bytes()) or { panic('DECRPM should decode') }
	pixels := pixels_result.event or { panic('DECRPM should produce an event') }
	match pixels {
		CapabilityEvent {
			assert pixels.capability == .sgr_pixels
		}
		else {
			assert false
		}
	}

	cursor_result := parse_input('\x1b[>1;2;3;29;30;40;100;101 q'.bytes()) or {
		panic('cursor capability should decode')
	}
	cursor := cursor_result.event or { panic('cursor capability should produce an event') }
	match cursor {
		CapabilityEvent {
			assert cursor.capability == .multi_cursor
		}
		else {
			assert false
		}
	}

	skipped := parse_input('\x1bPignored\x1b\\'.bytes()) or { panic('DCS should be consumed') }
	assert skipped.consumed == '\x1bPignored\x1b\\'.len
	assert skipped.event == none
}

fn test_key_decoder_preserves_first_grapheme() {
	astronaut_input := '👩‍🚀abc'
	astronaut := parse_input(astronaut_input.bytes()) or { panic('grapheme should decode') }
	assert astronaut.consumed == '👩‍🚀'.len
	astronaut_event := astronaut.event or { panic('grapheme should produce an event') }
	match astronaut_event {
		Key {
			assert astronaut_event.codepoint == multicodepoint
			assert astronaut_event.text or { '' } == '👩‍🚀'
		}
		else {
			assert false
		}
	}

	flag := parsed_key_event('🇺🇸')
	assert flag.codepoint == multicodepoint
	assert flag.text or { '' } == '🇺🇸'
	combining := parsed_key_event('a\u0301')
	assert combining.codepoint == multicodepoint
	assert combining.text or { '' } == 'a\u0301'
	modifier_input := 'a🏿b'
	modifier := parse_input(modifier_input.bytes()) or { panic('modifier grapheme should decode') }
	assert modifier.consumed == 'a🏿'.len
	modifier_event := modifier.event or { panic('modifier grapheme should produce an event') }
	match modifier_event {
		Key {
			assert modifier_event.codepoint == multicodepoint
			assert modifier_event.text or { '' } == 'a🏿'
		}
		else {
			assert false
		}
	}
}

fn test_key_decoder_handles_sgr_mouse() {
	parsed := parse_input('\x1b[<0;12;7m'.bytes()) or { panic('mouse should decode') }
	event := parsed.event or { panic('mouse should produce an event') }
	match event {
		Mouse {
			assert event.button == .left
			assert event.type_ == .release
			assert event.col == 11
			assert event.row == 6
		}
		else {
			assert false, 'expected mouse event'
		}
	}

	wheel := parse_input('\x1b[<65;2;3M'.bytes()) or { panic('wheel should decode') }
	wheel_event := wheel.event or { panic('wheel should produce an event') }
	match wheel_event {
		Mouse {
			assert wheel_event.button == .wheel_down
			assert wheel_event.type_ == .press
		}
		else {
			assert false, 'expected mouse event'
		}
	}

	middle := parse_input('\x1b[<1;2;3M'.bytes()) or { panic('middle mouse should decode') }
	drag := parse_input('\x1b[<32;2;3M'.bytes()) or { panic('drag should decode') }
	motion := parse_input('\x1b[<35;2;3M'.bytes()) or { panic('motion should decode') }
	modified := parse_input('\x1b[<28;2;3M'.bytes()) or { panic('modified mouse should decode') }
	middle_event := middle.event or { panic('middle mouse should produce an event') }
	drag_event := drag.event or { panic('drag should produce an event') }
	motion_event := motion.event or { panic('motion should produce an event') }
	modified_event := modified.event or { panic('modified mouse should produce an event') }
	match middle_event {
		Mouse {
			assert middle_event.button == .middle
		}
		else {
			assert false
		}
	}

	match drag_event {
		Mouse {
			assert drag_event.type_ == .drag
		}
		else {
			assert false
		}
	}

	match motion_event {
		Mouse {
			assert motion_event.type_ == .motion
		}
		else {
			assert false
		}
	}

	match modified_event {
		Mouse {
			assert modified_event.mods.shift()
			assert modified_event.mods.alt()
			assert modified_event.mods.ctrl()
		}
		else {
			assert false
		}
	}

	default_position := parse_input('\x1b[<0;;M'.bytes()) or {
		panic('default mouse position should decode')
	}
	default_event := default_position.event or { panic('default mouse should produce an event') }
	match default_event {
		Mouse {
			assert default_event.col == 0
			assert default_event.row == 0
		}
		else {
			assert false
		}
	}

	xterm_result := parse_input([u8(0x1b), `[`, `M`, u8(32), u8(44), u8(39)]) or {
		panic('X10 mouse should decode')
	}
	xterm_event := xterm_result.event or { panic('X10 mouse should produce an event') }
	match xterm_event {
		Mouse {
			assert xterm_result.consumed == 6
			assert xterm_event.button == .left
			assert xterm_event.type_ == .press
			assert xterm_event.col == 11
			assert xterm_event.row == 6
		}
		else {
			assert false
		}
	}

	leave_result := parse_input('\x1b[<259;1;1M'.bytes()) or { panic('mouse leave should decode') }
	leave_event := leave_result.event or { panic('mouse leave should produce an event') }
	assert leave_event is MouseLeave
}

fn test_text_input_buffer_matches_source_gap_operations() {
	mut buffer := TextInputBuffer.new()
	defer {
		buffer.deinit()
	}
	buffer.insert_slice_at_cursor('abc')
	assert buffer.first_half().bytestr() == 'abc'
	assert buffer.second_half().bytestr() == ''
	buffer.move_gap_left(1)
	assert buffer.first_half().bytestr() == 'ab'
	assert buffer.second_half().bytestr() == 'c'
	buffer.insert_slice_at_cursor(' ')
	assert buffer.first_half().bytestr() == 'ab '
	assert buffer.second_half().bytestr() == 'c'
	buffer.grow_gap_left(1)
	assert buffer.first_half().bytestr() == 'ab'
	assert buffer.second_half().bytestr() == 'c'
	buffer.grow_gap_right(1)
	assert buffer.first_half().bytestr() == 'ab'
	assert buffer.second_half().bytestr() == ''
	assert buffer.real_length() == 2
}

fn test_text_input_edits_by_grapheme_and_source_bindings() {
	mut input := TextInput.new()
	input.update(Key{
		codepoint: multicodepoint
		text:      '👩‍🚀'
	})
	input.update(Key{
		codepoint: multicodepoint
		text:      '👩‍🚀'
	})
	assert input.get_text() == '👩‍🚀👩‍🚀'
	assert input.real_length() == usize('👩‍🚀👩‍🚀'.len)
	assert input.graphemes_before_cursor() == 2
	input.update(Key{ codepoint: backspace })
	assert input.get_text() == '👩‍🚀'

	input.clear_retaining_capacity()
	input.insert_slice_at_cursor('hello world')
	input.update(Key{
		codepoint: u32(`a`)
		mods:      Modifiers.from_int(4)
	})
	assert input.byte_offset_to_cursor() == 0
	input.update(Key{ codepoint: right })
	assert input.slice_to_cursor() == 'h'
	input.update(Key{
		codepoint: u32(`e`)
		mods:      Modifiers.from_int(4)
	})
	assert input.byte_offset_to_cursor() == usize('hello world'.len)
	input.update(Key{
		codepoint: u32(`b`)
		mods:      Modifiers.from_int(2)
	})
	assert input.slice_to_cursor() == 'hello '
	input.update(Key{
		codepoint: u32(`d`)
		mods:      Modifiers.from_int(2)
	})
	assert input.get_text() == 'hello '
	input.update(Key{
		codepoint: u32(`u`)
		mods:      Modifiers.from_int(4)
	})
	assert input.get_text() == ''

	input.insert_slice_at_cursor('one two three')
	input.update(Key{
		codepoint: u32(`w`)
		mods:      Modifiers.from_int(4)
	})
	assert input.get_text() == 'one two '
	input.update(Key{
		codepoint: u32(`k`)
		mods:      Modifiers.from_int(4)
	})
	assert input.get_text() == 'one two '
	assert input.to_owned_slice() == 'one two '
	assert input.get_text() == ''
	input.clear_retaining_capacity()
	assert input.get_text() == ''
}

fn test_style_and_hyperlink_emit_terminal_sequences() {
	style := Style{
		fg:            ColorRgb{
			rgb: [u8(1), 2, 3]!
		}
		bg:            ColorRgb{
			rgb: [u8(4), 5, 6]!
		}
		ul:            ColorIndex{
			index: 200
		}
		bold:          true
		dim:           true
		italic:        true
		blink:         true
		reverse:       true
		invisible:     true
		strikethrough: true
		ul_style:      .curly
	}
	styled_text := styled('hello', style)
	assert styled_text == '\x1b[38:2:1:2:3m\x1b[48:2:4:5:6m\x1b[58:5:200m\x1b[4:3m\x1b[1m\x1b[2m\x1b[3m\x1b[5m\x1b[7m\x1b[8m\x1b[9mhello\x1b[m'
	assert hyperlink('hello', 'file:///tmp/theme', style).contains('\x1b]8;;file:///tmp/theme')
}

fn test_color_and_style_match_pinned_vaxis_model() {
	assert color_rgb_from_uint(0x123456).eql(ColorRgb{ rgb: [u8(0x12), 0x34, 0x56]! })
	assert (color_rgb_from_spec('rgb:aaaa/bbbb/cccc') or { panic(err) }).eql(ColorRgb{
		rgb: [u8(0xaa), 0xbb, 0xcc]!
	})
	if _ := color_rgb_from_spec('RGB:aaaa/bbbb/cccc') {
		assert false
	} else {
		assert err.msg() == 'InvalidColorSpec'
	}
	assert Color(ColorDefault{}).eql(ColorDefault{})
	assert Color(ColorIndex{
		index: 42
	}).eql(ColorIndex{ index: 42 })
	assert !Color(ColorIndex{
		index: 42
	}).eql(ColorIndex{ index: 43 })
	assert !Color(ColorIndex{
		index: 42
	}).eql(ColorRgb{ rgb: [u8(0), 0, 42]! })
	assert Style{}.eql(Style{})
	assert !Style{}.eql(Style{ dim: true })
	assert styled('x', Style{
		fg: ColorIndex{
			index: 3
		}
	}) == '\x1b[33mx\x1b[m'
	assert styled('x', Style{
		fg: ColorIndex{
			index: 11
		}
	}) == '\x1b[93mx\x1b[m'
	assert styled('x', Style{
		bg: ColorIndex{
			index: 201
		}
	}) == '\x1b[48:5:201mx\x1b[m'
}

fn test_text_input_draw_scrolls_and_places_cursor_like_pinned_widget() {
	mut input := TextInput.new()
	input.insert_slice_at_cursor('abcdef')
	drawn := input.draw_with_style(4, Style{})
	assert input.draw_offset == 3
	assert drawn.cursor_col == 3
	assert drawn.cells.last() == TextInputCell{ col: 0, text: '…' }
	assert drawn.cells[1] == TextInputCell{ col: 1, text: 'e' }
	assert drawn.cells[2] == TextInputCell{ col: 2, text: 'f' }

	input.cursor_left()
	input.cursor_left()
	moved := input.draw_with_style(4, Style{})
	assert moved.cursor_col == 1
	assert moved.cells.last() == TextInputCell{ col: 0, text: '…' }
}

fn test_text_input_draw_counts_wide_and_combining_graphemes() {
	mut input := TextInput.new()
	input.insert_slice_at_cursor('界e\u0301')
	drawn := input.draw(5)
	assert drawn.cursor_col == 3
	assert drawn.cells[0] == TextInputCell{ col: 0, text: '界' }
	assert drawn.cells[1] == TextInputCell{ col: 2, text: 'e\u0301' }
}

fn test_pinned_vaxis_gwidth_methods_and_uucode_properties() {
	assert pinned_width_data.len == 4616
	assert width_data_u32(0) == 122
	assert width_data_u32(1) == 354
	assert width_data_u32(2) == 80
	assert width_data_u32(3) == 19
	assert gwidth('a', .unicode) == 1
	assert gwidth('a', .wcwidth) == 1
	assert gwidth('a', .no_zwj) == 1
	assert gwidth('👩‍🚀', .unicode) == 2
	assert gwidth('👩‍🚀', .wcwidth) == 4
	assert gwidth('👩‍🚀', .no_zwj) == 4
	assert gwidth('❤️', .unicode) == 2
	assert gwidth('❤️', .wcwidth) == 1
	assert gwidth('🇺🇸', .unicode) == 2
	assert gwidth('🇺🇸', .wcwidth) == 2
	assert gwidth('\u200b', .wcwidth) == 0
	assert gwidth('e\u0301', .wcwidth) == 1
	assert gwidth('👋🏿', .wcwidth) == 4
	assert gwidth('a🏿', .unicode) == 2
	assert gwidth('☝🏿', .unicode) == 2
	assert first_grapheme_byte_length('a🏿') == 'a🏿'.len
	assert first_grapheme_byte_length('\r\n') == 2
}
