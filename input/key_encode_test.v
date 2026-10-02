module input

import terminal

// Tests for key encoding logic.
// Translated from ghostty/src/input/key_encode.zig

fn test_key_encode_options_from_terminal() ! {
	mut term := terminal.Terminal.init(terminal.Options{ cols: 2, rows: 2 })!
	defer {
		term.deinit()
	}
	term.modes.set(.cursor_keys, true)
	term.modes.set(.keypad_keys, true)
	term.modes.set(.ignore_keypad_with_numlock, true)
	term.modes.set(.alt_esc_prefix, true)
	term.flags.set_modify_other_keys_2(true)
	term.screens.active.kitty_keyboard.set(.set_, terminal.KeyFlags.init(true, false, false,
		false, false))

	opts := Options.from_terminal(&term)
	assert opts.cursor_key_application
	assert opts.keypad_key_application
	assert opts.ignore_keypad_with_numlock
	assert opts.alt_esc_prefix
	assert opts.modify_other_keys_state_2
	assert opts.kitty_flags.disambiguate()
	assert opts.macos_option_as_alt == .false_
}

fn test_kitty_event_storage() {
	assert $sizeof(KittyEvent) == 1
	assert u8(KittyEvent.none_) == 0
	assert u8(KittyEvent.release) == 3
}

// === CsiUMods tests ===

fn test_csiu_modifier_sequence_values() {
	// This is all sort of trivially seen by looking at the code but
	// we want to make sure we never regress this.
	mut mods := CsiUMods{}
	assert mods.seq_int() == 1

	mods = CsiUMods{ value: 1 }
	assert mods.seq_int() == 2

	mods = CsiUMods{ value: 2 }
	assert mods.seq_int() == 3

	mods = CsiUMods{ value: 4 }
	assert mods.seq_int() == 5

	mods = CsiUMods{ value: 3 }
	assert mods.seq_int() == 4

	mods = CsiUMods{ value: 5 }
	assert mods.seq_int() == 6

	mods = CsiUMods{ value: 6 }
	assert mods.seq_int() == 7

	mods = CsiUMods{ value: 7 }
	assert mods.seq_int() == 8
	assert sizeof(CsiUMods) == 1
}

// === KittyMods tests ===

fn test_kitty_modifier_sequence_values() {
	// This is all sort of trivially seen by looking at the code but
	// we want to make sure we never regress this.
	mut mods := KittyMods{}
	assert mods.seq_int() == 1

	mods = KittyMods{ value: 1 }
	assert mods.seq_int() == 2

	mods = KittyMods{ value: 2 }
	assert mods.seq_int() == 3

	mods = KittyMods{ value: 4 }
	assert mods.seq_int() == 5

	mods = KittyMods{ value: 3 }
	assert mods.seq_int() == 4

	mods = KittyMods{ value: 5 }
	assert mods.seq_int() == 6

	mods = KittyMods{ value: 6 }
	assert mods.seq_int() == 7

	mods = KittyMods{ value: 7 }
	assert mods.seq_int() == 8
	assert sizeof(KittyMods) == 1
}

// === KittySequence tests ===

fn test_kitty_sequence_backspace() {
	// Plain
	seq1 := KittySequence{ key_code: 127, final_byte: `u` }
	assert seq1.encode_seq() == '\x1b[127u'

	// Release event
	seq2 := KittySequence{ key_code: 127, final_byte: `u`, event: .release }
	assert seq2.encode_seq() == '\x1b[127;1:3u'

	// Shift
	seq3 := KittySequence{
		key_code: 127
		final_byte: `u`
		mods: KittyMods{ value: 1 }
	}
	assert seq3.encode_seq() == '\x1b[127;2u'
}

fn test_kitty_sequence_text() {
	// Plain
	seq1 := KittySequence{
		key_code: 127
		final_byte: `u`
		text: 'A'
	}
	assert seq1.encode_seq() == '\x1b[127;;65u'

	// Release
	seq2 := KittySequence{
		key_code: 127
		final_byte: `u`
		event: .release
		text: 'A'
	}
	assert seq2.encode_seq() == '\x1b[127;1:3;65u'

	// Shift
	seq3 := KittySequence{
		key_code: 127
		final_byte: `u`
		mods: KittyMods{ value: 1 }
		text: 'A'
	}
	assert seq3.encode_seq() == '\x1b[127;2;65u'
}

fn test_kitty_sequence_text_with_control_characters() {
	// By itself
	seq1 := KittySequence{
		key_code: 127
		final_byte: `u`
		text: '\n'
	}
	assert seq1.encode_seq() == '\x1b[127u'

	// With other printables
	seq2 := KittySequence{
		key_code: 127
		final_byte: `u`
		text: 'A\n'
	}
	assert seq2.encode_seq() == '\x1b[127;;65u'
}

fn test_kitty_sequence_special_no_mods() {
	seq := KittySequence{ key_code: 1, final_byte: `A` }
	assert seq.encode_seq() == '\x1b[A'
}

fn test_kitty_sequence_special_mods_only() {
	seq := KittySequence{ key_code: 1, final_byte: `A`, mods: KittyMods{ value: 1 } }
	assert seq.encode_seq() == '\x1b[1;2A'
}

fn test_kitty_sequence_special_mods_and_event() {
	seq := KittySequence{
		key_code: 1
		final_byte: `A`
		event: .release
		mods: KittyMods{ value: 1 }
	}
	assert seq.encode_seq() == '\x1b[1;2:3A'
}

// === Kitty encoding tests ===

fn test_kitty_plain_text() {
	result := kitty_encode(KeyEvent{
		key: .key_a
		utf8: 'abcd'
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == 'abcd'
}

fn test_kitty_repeat_with_just_disambiguate() {
	result := kitty_encode(KeyEvent{
		key: .key_a
		action: .repeat
		utf8: 'a'
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == 'a'
}

fn test_kitty_enter_backspace_tab() {
	// Enter
	r1 := kitty_encode(KeyEvent{ key: .enter, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert r1 == '\r'

	// Backspace
	r2 := kitty_encode(KeyEvent{ key: .backspace, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert r2 == '\x7f'

	// Tab
	r3 := kitty_encode(KeyEvent{ key: .tab, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert r3 == '\t'

	// No release events if "report_all" is not set
	r4 := kitty_encode(KeyEvent{ action: .release, key: .enter, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(3)
	})
	assert r4 == ''

	r5 := kitty_encode(KeyEvent{ action: .release, key: .backspace, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(3)
	})
	assert r5 == ''

	r6 := kitty_encode(KeyEvent{ action: .release, key: .tab, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(3)
	})
	assert r6 == ''

	// Release events if "report_all" is set
	r7 := kitty_encode(KeyEvent{ action: .release, key: .enter, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(11)
	})
	assert r7 == '\x1b[13;1:3u'

	r8 := kitty_encode(KeyEvent{ action: .release, key: .backspace, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(11)
	})
	assert r8 == '\x1b[127;1:3u'

	r9 := kitty_encode(KeyEvent{ action: .release, key: .tab, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(11)
	})
	assert r9 == '\x1b[9;1:3u'
}

fn test_kitty_shift_backspace_emits_csi_u() {
	// Backspace with shift modifier should emit CSI u sequence, not raw 0x7F.
	// This is important for programs that want to distinguish shift+backspace.
	result := kitty_encode(KeyEvent{
		key: .backspace
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == '\x1b[127;2u'
}

fn test_kitty_shift_enter_emits_csi_u() {
	result := kitty_encode(KeyEvent{
		key: .enter
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == '\x1b[13;2u'
}

fn test_kitty_shift_tab_emits_csi_u() {
	result := kitty_encode(KeyEvent{
		key: .tab
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == '\x1b[9;2u'
}

fn test_kitty_enter_with_all_flags() {
	result := kitty_encode(KeyEvent{ key: .enter, utf8: '' }, Options{
		kitty_flags: KittyFlags.from_int(31)
	})
	assert result[1..] == '[13u'
}

fn test_kitty_ctrl_with_all_flags() {
	result := kitty_encode(KeyEvent{
		key: .control_left
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(31)
	})
	assert result[1..] == '[57442;5u'
}

fn test_kitty_ctrl_release_with_ctrl_mod_set() {
	result := kitty_encode(KeyEvent{
		action: .release
		key: .control_left
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(31)
	})
	assert result[1..] == '[57442;5:3u'
}

fn test_kitty_delete() {
	result := kitty_encode(KeyEvent{
		key: .delete
		utf8: '\x7f'
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == '\x1b[3~'
}

fn test_kitty_composing_with_no_modifier() {
	result := kitty_encode(KeyEvent{
		key: .key_a
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		composing: true
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == ''
}

fn test_kitty_composing_with_modifier() {
	result := kitty_encode(KeyEvent{
		key: .shift_left
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		composing: true
	}, Options{
		kitty_flags: KittyFlags.from_int(9)
	})
	assert result == '\x1b[57441;2u'
}

fn test_kitty_shift_a_on_us_keyboard() {
	result := kitty_encode(KeyEvent{
		key: .key_a
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: 'A'
		unshifted_codepoint: 97 // lowercase A
	}, Options{
		kitty_flags: KittyFlags.from_int(5)
	})
	assert result == '\x1b[97:65;2u'
}

fn test_kitty_matching_unshifted_codepoint() {
	result := kitty_encode(KeyEvent{
		key: .key_a
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: 'A'
		unshifted_codepoint: 65
	}, Options{
		kitty_flags: KittyFlags.from_int(5)
	})
	// WARNING: This is not a valid encoding. This is a hypothetical encoding
	// just to test that our logic is correct around matching unshifted
	// codepoints. We get an alternate here because the unshifted_codepoint does
	// not match the base key
	assert result == '\x1b[65::97;2u'
}

fn test_kitty_report_alternates_with_caps() {
	result := kitty_encode(KeyEvent{
		key: .key_j
		mods: Mods.init(false, false, false, false, true, false, SideInfo{})
		utf8: 'J'
		unshifted_codepoint: 106
	}, Options{
		kitty_flags: KittyFlags.from_int(29)
	})
	assert result == '\x1b[106;65;74u'
}

fn test_kitty_report_alternates_colon() {
	// shift+';' produces ':'
	result := kitty_encode(KeyEvent{
		key: .semicolon
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: ':'
		unshifted_codepoint: u32(`;`)
	}, Options{
		kitty_flags: KittyFlags.from_int(29)
	})
	assert result == '\x1b[59:58;2;58u'
}

fn test_kitty_report_alternates_with_ru_layout() {
	result := kitty_encode(KeyEvent{
		key: .semicolon
		utf8: '\u0447' // ч
		unshifted_codepoint: 1095
	}, Options{
		kitty_flags: KittyFlags.from_int(29)
	})
	assert result == '\x1b[1095::59;;1095u'
}

fn test_kitty_report_alternates_with_ru_layout_shifted() {
	result := kitty_encode(KeyEvent{
		key: .semicolon
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: '\u0427' // Ч
		unshifted_codepoint: 1095
	}, Options{
		kitty_flags: KittyFlags.from_int(29)
	})
	assert result == '\x1b[1095:1063:59;2;1063u'
}

fn test_kitty_report_alternates_with_ru_layout_caps_lock() {
	result := kitty_encode(KeyEvent{
		key: .semicolon
		mods: Mods.init(false, false, false, false, true, false, SideInfo{})
		utf8: '\u0427' // Ч
		unshifted_codepoint: 1095
	}, Options{
		kitty_flags: KittyFlags.from_int(29)
	})
	assert result == '\x1b[1095::59;65;1063u'
}

fn test_kitty_report_alternates_with_hu_layout_release() {
	result := kitty_encode(KeyEvent{
		action: .release
		key: .bracket_left
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: ''
		unshifted_codepoint: 337
	}, Options{
		kitty_flags: KittyFlags.from_int(31)
	})
	assert result[1..] == '[337::91;5:3u'
}

fn test_kitty_up_arrow_with_utf8() {
	// macOS generates utf8 text for arrow keys.
	result := kitty_encode(KeyEvent{
		key: .arrow_up
		utf8: [u8(30)].bytestr()
	}, Options{
		kitty_flags: KittyFlags.from_int(1)
	})
	assert result == '\x1b[A'
}

fn test_kitty_shift_tab() {
	result := kitty_encode(KeyEvent{
		key: .tab
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(5)
	})
	assert result == '\x1b[9;2u'
}

fn test_kitty_left_shift() {
	result := kitty_encode(KeyEvent{
		key: .shift_left
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(5)
	})
	assert result == ''
}

fn test_kitty_left_shift_with_report_all() {
	result := kitty_encode(KeyEvent{
		key: .shift_left
		utf8: ''
	}, Options{
		kitty_flags: KittyFlags.from_int(9)
	})
	assert result == '\x1b[57441u'
}

fn test_kitty_report_associated_with_modifiers() {
	result := kitty_encode(KeyEvent{
		key: .key_j
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: 'j'
		unshifted_codepoint: 106
	}, Options{
		kitty_flags: KittyFlags.from_int(29)
	})
	assert result == '\x1b[106;5u'
}

fn test_kitty_report_associated() {
	result := kitty_encode(KeyEvent{
		key: .key_j
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: 'J'
		unshifted_codepoint: 106
	}, Options{
		kitty_flags: KittyFlags.from_int(29)
	})
	assert result == '\x1b[106:74;2;74u'
}

fn test_kitty_report_associated_on_release() {
	result := kitty_encode(KeyEvent{
		action: .release
		key: .key_j
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: 'J'
		unshifted_codepoint: 106
	}, Options{
		kitty_flags: KittyFlags.from_int(31)
	})
	assert result[1..] == '[106:74;2:3u'
}

fn test_kitty_alternates_omit_control_characters() {
	result := kitty_encode(KeyEvent{
		key: .delete
		utf8: '\x7f'
	}, Options{
		kitty_flags: KittyFlags.from_int(13)
	})
	assert result == '\x1b[3~'
}

fn test_kitty_enter_with_utf8_dead_key_state() {
	result := kitty_encode(KeyEvent{
		key: .enter
		utf8: 'A'
		unshifted_codepoint: 0x0D
	}, Options{
		kitty_flags: KittyFlags.from_int(13)
	})
	assert result == 'A'
}

fn test_kitty_keypad_number() {
	result := kitty_encode(KeyEvent{
		key: .numpad_1
		utf8: '1'
	}, Options{
		kitty_flags: KittyFlags.from_int(31)
	})
	assert result[1..] == '[57400;;49u'
}

fn test_kitty_backspace_with_utf8_dead_key_state() {
	result := kitty_encode(KeyEvent{
		key: .backspace
		utf8: 'A'
		unshifted_codepoint: 0x0D
	}, Options{
		kitty_flags: KittyFlags.from_int(31)
	})
	assert result == ''
}

// === Legacy encoding tests ===

fn test_legacy_backspace_with_utf8_dead_key_state() {
	result := legacy_encode(KeyEvent{
		key: .backspace
		utf8: 'A'
		unshifted_codepoint: 0x0D
	}, Options{})
	assert result == ''
}

fn test_legacy_enter_with_utf8_dead_key_state() {
	result := legacy_encode(KeyEvent{
		key: .enter
		utf8: 'A'
		unshifted_codepoint: 0x0D
	}, Options{})
	assert result == 'A'
}

fn test_legacy_esc_with_utf8_dead_key_state() {
	result := legacy_encode(KeyEvent{
		key: .escape
		utf8: 'A'
		unshifted_codepoint: 0x0D
	}, Options{})
	assert result == 'A'
}

fn test_legacy_ctrl_shift_minus() {
	result := legacy_encode(KeyEvent{
		key: .minus
		mods: Mods.init(true, true, false, false, false, false, SideInfo{})
		utf8: '_'
	}, Options{})
	assert result == '\x1f'
}

fn test_legacy_ctrl_alt_c() {
	result := legacy_encode(KeyEvent{
		key: .key_c
		mods: Mods.init(false, true, true, false, false, false, SideInfo{})
		utf8: 'c'
	}, Options{})
	assert result == '\x1b\x03'
}

fn test_legacy_alt_c() {
	result := legacy_encode(KeyEvent{
		key: .key_c
		utf8: 'c'
		mods: Mods.init(false, false, true, false, false, false, SideInfo{})
	}, Options{
		alt_esc_prefix: true
		macos_option_as_alt: .true_
	})
	assert result == '\x1bc'
}

fn test_legacy_alt_e_only_unshifted() {
	result := legacy_encode(KeyEvent{
		key: .key_e
		unshifted_codepoint: u32(`e`)
		mods: Mods.init(false, false, true, false, false, false, SideInfo{})
	}, Options{
		alt_esc_prefix: true
		macos_option_as_alt: .true_
	})
	assert result == '\x1be'
}

fn test_legacy_ctrl_c() {
	result := legacy_encode(KeyEvent{
		key: .key_c
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: 'c'
	}, Options{})
	assert result == '\x03'
}

fn test_legacy_ctrl_space() {
	result := legacy_encode(KeyEvent{
		key: .space
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: ' '
	}, Options{})
	assert result == '\x00'
}

fn test_legacy_ctrl_shift_backspace() {
	result := legacy_encode(KeyEvent{
		key: .backspace
		mods: Mods.init(true, true, false, false, false, false, SideInfo{})
	}, Options{})
	assert result == '\x08'
}

fn test_legacy_ctrl_shift_char_with_modify_other_state_2() {
	result := legacy_encode(KeyEvent{
		key: .key_h
		mods: Mods.init(true, true, false, false, false, false, SideInfo{})
		utf8: 'H'
	}, Options{
		modify_other_keys_state_2: true
	})
	assert result == '\x1b[27;6;72~'
}

fn test_legacy_ctrl_shift_char_with_modify_other_state_2_and_consumed_mods() {
	result := legacy_encode(KeyEvent{
		key: .key_h
		mods: Mods.init(true, true, false, false, false, false, SideInfo{})
		consumed_mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: 'H'
	}, Options{
		modify_other_keys_state_2: true
	})
	assert result == '\x1b[27;6;72~'
}

fn test_legacy_alt_digit_with_modify_other_state_2() {
	result := legacy_encode(KeyEvent{
		key: .digit_8
		mods: Mods.init(false, false, true, false, false, false, SideInfo{})
		utf8: '8'
	}, Options{
		modify_other_keys_state_2: true
		macos_option_as_alt: .true_
	})
	assert result == '\x1b[27;3;56~'
}

fn test_legacy_fixterm_awkward_letters() {
	// ctrl+i
	r1 := legacy_encode(KeyEvent{
		key: .key_i
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: 'i'
	}, Options{})
	assert r1 == '\x1b[105;5u'

	// ctrl+m
	r2 := legacy_encode(KeyEvent{
		key: .key_m
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: 'm'
	}, Options{})
	assert r2 == '\x1b[109;5u'

	// ctrl+[
	r3 := legacy_encode(KeyEvent{
		key: .bracket_left
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: '['
	}, Options{})
	assert r3 == '\x1b[91;5u'

	// ctrl+shift+2 -> '@'
	r4 := legacy_encode(KeyEvent{
		key: .digit_2
		mods: Mods.init(true, true, false, false, false, false, SideInfo{})
		utf8: '@'
		unshifted_codepoint: u32(`2`)
	}, Options{})
	assert r4 == '\x1b[64;5u'
}

fn test_legacy_ctrl_shift_letter_ascii() {
	// These tests apply Kitty's behavior to CSIu where ctrl+shift+letter
	// is sent as the unshifted letter with the shift modifier present.
	result := legacy_encode(KeyEvent{
		key: .key_m
		mods: Mods.init(true, true, false, false, false, false, SideInfo{})
		utf8: 'M'
		unshifted_codepoint: u32(`m`)
	}, Options{})
	assert result == '\x1b[109;6u'
}

fn test_legacy_shift_function_key_should_use_all_mods() {
	result := legacy_encode(KeyEvent{
		key: .arrow_up
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		consumed_mods: Mods.init(true, false, false, false, false, false, SideInfo{})
	}, Options{})
	assert result == '\x1b[1;2A'
}

fn test_legacy_keypad_enter() {
	result := legacy_encode(KeyEvent{
		key: .numpad_enter
	}, Options{})
	assert result == '\r'
}

fn test_legacy_keypad_1() {
	result := legacy_encode(KeyEvent{
		key: .numpad_1
		utf8: '1'
	}, Options{})
	assert result == '1'
}

fn test_legacy_keypad_1_with_application_keypad() {
	result := legacy_encode(KeyEvent{
		key: .numpad_1
		utf8: '1'
	}, Options{
		keypad_key_application: true
	})
	assert result == '\x1bOq'
}

fn test_legacy_keypad_1_with_application_keypad_and_numlock() {
	result := legacy_encode(KeyEvent{
		key: .numpad_1
		mods: Mods.init(false, false, false, false, false, true, SideInfo{})
		utf8: '1'
	}, Options{
		keypad_key_application: true
	})
	assert result == '\x1bOq'
}

fn test_legacy_keypad_1_with_application_keypad_and_numlock_ignore() {
	result := legacy_encode(KeyEvent{
		key: .numpad_1
		utf8: '1'
	}, Options{
		keypad_key_application: true
		ignore_keypad_with_numlock: true
	})
	assert result == '1'
}

fn test_legacy_f1() {
	// F1 with ctrl
	r1 := legacy_encode(KeyEvent{
		key: .f1
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}, Options{})
	assert r1 == '\x1b[1;5P'

	// F2 with ctrl
	r2 := legacy_encode(KeyEvent{
		key: .f2
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}, Options{})
	assert r2 == '\x1b[1;5Q'

	// F3 with ctrl
	r3 := legacy_encode(KeyEvent{
		key: .f3
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}, Options{})
	assert r3 == '\x1b[13;5~'

	// F4 with ctrl
	r4 := legacy_encode(KeyEvent{
		key: .f4
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}, Options{})
	assert r4 == '\x1b[1;5S'

	// F5 with ctrl uses new encoding
	r5 := legacy_encode(KeyEvent{
		key: .f5
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}, Options{})
	assert r5 == '\x1b[15;5~'
}

fn test_legacy_left_shift_tab() {
	result := legacy_encode(KeyEvent{
		key: .tab
		mods: Mods.init(true, false, false, false, false, false, SideInfo.init(.left, .left, .left, .left))
	}, Options{})
	assert result == '\x1b[Z'
}

fn test_legacy_right_shift_tab() {
	result := legacy_encode(KeyEvent{
		key: .tab
		mods: Mods.init(true, false, false, false, false, false, SideInfo.init(.right, .left, .left, .left))
	}, Options{})
	assert result == '\x1b[Z'
}

fn test_legacy_hu_layout_ctrl_o_sends_proper_codepoint() {
	result := legacy_encode(KeyEvent{
		key: .bracket_left
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: '\u0151' // ő
		unshifted_codepoint: 337
	}, Options{})
	assert result[1..] == '[337;5u'
}

fn test_legacy_backspace_with_del_utf8() {
	result := legacy_encode(KeyEvent{
		key: .backspace
		utf8: '\x7f'
		unshifted_codepoint: 0x08
	}, Options{})
	assert result == '\x7f'
}

// === ctrlSeq tests ===

fn test_ctrlseq_normal_ctrl_c() {
	seq := ctrl_seq(.unidentified, 'c', u32(`c`), Mods.init(false, true, false, false, false, false, SideInfo{}))
	assert seq != none
	assert seq or { 0 } == u8(0x03)
}

fn test_ctrlseq_normal_ctrl_c_right_control() {
	seq := ctrl_seq(.unidentified, 'c', u32(`c`), Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .right, .left, .left)))
	assert seq != none
	assert seq or { 0 } == u8(0x03)
}

fn test_ctrlseq_alt_should_be_allowed() {
	seq := ctrl_seq(.unidentified, 'c', u32(`c`), Mods.init(false, true, true, false, false, false, SideInfo{}))
	assert seq != none
	assert seq or { 0 } == u8(0x03)
}

fn test_ctrlseq_no_ctrl_does_nothing() {
	assert ctrl_seq(.unidentified, 'c', u32(`c`), Mods{}) == none
}

fn test_ctrlseq_shifted_non_character() {
	seq := ctrl_seq(.unidentified, '_', u32(`-`), Mods.init(true, true, false, false, false, false, SideInfo{}))
	assert seq != none
	assert seq or { 0 } == u8(0x1F)
}

fn test_ctrlseq_caps_ascii_letter() {
	seq := ctrl_seq(.unidentified, 'C', u32(`c`), Mods.init(false, true, false, false, true, false, SideInfo{}))
	assert seq != none
	assert seq or { 0 } == u8(0x03)
}

fn test_ctrlseq_shift_does_not_generate_ctrl_seq() {
	assert ctrl_seq(.unidentified, 'C', u32(`c`), Mods.init(true, false, false, false, false, false, SideInfo{})) == none
	assert ctrl_seq(.unidentified, 'C', u32(`c`), Mods.init(true, true, false, false, false, false, SideInfo{})) == none
}

fn test_ctrlseq_russian_ctrl_c() {
	seq := ctrl_seq(.key_c, '\u0441', 0x0441, Mods.init(false, true, false, false, false, false, SideInfo{}))
	assert seq != none
	assert seq or { 0 } == u8(0x03)
}

fn test_ctrlseq_russian_shifted_ctrl_c() {
	seq := ctrl_seq(.key_c, '\u0441', 0x0441, Mods.init(true, true, false, false, false, false, SideInfo{}))
	assert seq == none
}

fn test_ctrlseq_russian_alt_ctrl_c() {
	seq := ctrl_seq(.key_c, '\u0441', 0x0441, Mods.init(false, true, true, false, false, false, SideInfo{}))
	assert seq != none
	assert seq or { 0 } == u8(0x03)
}

fn test_ctrlseq_right_ctrl_c() {
	seq := ctrl_seq(.key_c, '\u0441', u32(`c`), Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .right, .left, .left)))
	assert seq != none
	assert seq or { 0 } == u8(0x03)
}

// Original Utf8View.init rejects these strings in every Kitty path.
fn test_invalid_utf8_is_absent_in_kitty_text_and_alternates() {
	for text in ['\xff', '\xc0\x80', '\xed\xa0\x80', '\xf4\x90\x80\x80', '\xe2\x82'] {
		for flags in [u8(1), 9, 13, 25] {
			assert encode(KeyEvent{key: .key_a, unshifted_codepoint: 97, utf8: text},
				Options{kitty_flags: KittyFlags.from_int(flags)}) == '\x1b[97u'
		}
	}
	// Invalid UTF-8 must not synthesize a base alternate for a different layout.
	opts := Options{kitty_flags: KittyFlags.from_int(13)}
	assert encode(KeyEvent{key: .key_a, unshifted_codepoint: 1092, utf8: '\xff'}, opts) == '\x1b[1092u'
	assert encode(KeyEvent{key: .key_a, unshifted_codepoint: 1092, utf8: ''}, opts) == '\x1b[1092::97u'
}

fn test_strict_source_utf8_validation_boundaries() {
	for text in ['', 'ascii', 'Ж', '☺', '\xf4\x8f\xbf\xbf'] { assert source_utf8_validate(text) }
	for text in ['\xc0', '\x80', '\xc0\x80', '\xed\xa0\x80', '\xed\xbf\xbf', '\xf4\x90\x80\x80', '\xf7\xbf\xbf\xbf'] {
		assert !source_utf8_validate(text)
	}
}
