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
	assert Key{ codepoint: left_shift }.is_modifier()
	assert !Key{ codepoint: f1 }.is_modifier()
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
	assert release.event == none
	unknown := parse_input('\x1b[999z'.bytes()) or { panic('unknown CSI should be consumed') }
	assert unknown.consumed == 6
	assert unknown.event == none
	unknown_ss3 := parse_input('\x1bOZ'.bytes()) or { panic('unknown SS3 should be consumed') }
	assert unknown_ss3.consumed == 3
	assert unknown_ss3.event == none
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
	default_position := parse_input('\x1b[<0;;M'.bytes()) or { panic('default mouse position should decode') }
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
}

fn test_text_input_edits_unicode_by_codepoint() {
	mut input := TextInput.new()
	input.update(Key{ codepoint: u32(`a`) })
	input.update(Key{ codepoint: 0x1f642 })
	assert input.get_text() == 'a🙂'
	assert input.real_length() == 2
	input.update(Key{ codepoint: backspace })
	assert input.get_text() == 'a'
	input.clear_retaining_capacity()
	assert input.get_text() == ''
}

fn test_style_and_hyperlink_emit_terminal_sequences() {
	style := Style{
		fg:       Color{ rgb: [u8(1), 2, 3]! }
		bg:       Color{ rgb: [u8(4), 5, 6]! }
		bold:     true
		ul_style: .curly
	}
	styled_text := styled('hello', style)
	assert styled_text.contains('\x1b[38;2;1;2;3;48;2;4;5;6;1;4:3m')
	assert styled_text.ends_with('\x1b[0m')
	assert hyperlink('hello', 'file:///tmp/theme', style).contains('\x1b]8;;file:///tmp/theme')
}
