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
}

fn parsed_key_event(input string) Key {
	parsed := parse_input(input.bytes()) or { panic('input should decode') }
	match parsed.event {
		Key {
			return parsed.event
		}
		else {
			panic('expected key event')
		}
	}
}

fn test_key_decoder_handles_text_modifiers_and_navigation() {
	assert parsed_key_event('a').matches(u32(`a`), Modifiers{})
	assert parsed_key_event('C').matches(u32(`c`), Modifiers{ shift: true })
	assert parsed_key_event('\x03').matches(u32(`c`), Modifiers{ ctrl: true })
	assert parsed_key_event('\x1b[A').codepoint == up
	assert parsed_key_event('\x1b[B').codepoint == down
	assert parsed_key_event('\x1b[5~').codepoint == page_up
	assert parsed_key_event('\x1b[6~').codepoint == page_down
	assert parsed_key_event('\x1bOP').codepoint == f1
}

fn test_key_decoder_handles_sgr_mouse() {
	parsed := parse_input('\x1b[<0;12;7m'.bytes()) or { panic('mouse should decode') }
	match parsed.event {
		Mouse {
			assert parsed.event.button == .left
			assert parsed.event.type_ == .release
			assert parsed.event.col == 11
			assert parsed.event.row == 6
		}
		else {
			assert false, 'expected mouse event'
		}
	}

	wheel := parse_input('\x1b[<65;2;3M'.bytes()) or { panic('wheel should decode') }
	match wheel.event {
		Mouse {
			assert wheel.event.button == .wheel_down
			assert wheel.event.type_ == .press
		}
		else {
			assert false, 'expected mouse event'
		}
	}

	middle := parse_input('\x1b[<1;2;3M'.bytes()) or { panic('middle mouse should decode') }
	drag := parse_input('\x1b[<32;2;3M'.bytes()) or { panic('drag should decode') }
	motion := parse_input('\x1b[<35;2;3M'.bytes()) or { panic('motion should decode') }
	modified := parse_input('\x1b[<28;2;3M'.bytes()) or { panic('modified mouse should decode') }
	match middle.event {
		Mouse {
			assert middle.event.button == .middle
		}
		else {
			assert false
		}
	}
	match drag.event {
		Mouse {
			assert drag.event.type_ == .drag
		}
		else {
			assert false
		}
	}
	match motion.event {
		Mouse {
			assert motion.event.type_ == .motion
		}
		else {
			assert false
		}
	}
	match modified.event {
		Mouse {
			assert modified.event.mods.shift()
			assert modified.event.mods.alt()
			assert modified.event.mods.ctrl()
		}
		else {
			assert false
		}
	}
	default_position := parse_input('\x1b[<0;;M'.bytes()) or { panic('default mouse position should decode') }
	match default_position.event {
		Mouse {
			assert default_position.event.col == 0
			assert default_position.event.row == 0
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
