module input

import oniguruma

// Tests for KeyEvent.

fn test_link_clone_equal_and_regex() {
	original := Link{
		regex: 'https?://[^ ]+'
		action: .open
		highlight: .hover_mods
		mods: Mods{ ctrl: true, shift: true }
	}
	cloned := original.clone()
	assert original.equal(cloned)
	assert cloned.regex == original.regex
	assert cloned.mods.equal(original.mods)

	mut compiled := original.oni_regex()!
	defer { compiled.deinit() }
	mut region := compiled.search('open https://ghostty.org now', oniguruma.Options{})!
	defer { region.deinit() }
	assert region.starts()[0] == 5
	assert region.ends()[0] == 24

	different := Link{
		regex: original.regex
		action: .open_osc8
		highlight: original.highlight
		mods: original.mods
	}
	assert !original.equal(different)
	different_mods := Link{
		regex: original.regex
		action: original.action
		highlight: original.highlight
		mods: Mods{ ctrl: true }
	}
	assert !original.equal(different_mods)
}

fn test_link_non_mod_highlight_has_no_mod_payload() {
	with_stale_mods := Link{
		regex: 'https?://[^ ]+'
		action: .open
		highlight: .always
		mods: Mods{ ctrl: true }
	}
	canonical := Link{
		regex: with_stale_mods.regex
		action: .open
		highlight: .always
	}
	assert with_stale_mods.equal(canonical)
	cloned := with_stale_mods.clone()
	assert cloned.equal(canonical)
	assert cloned.mods.equal(Mods{})
}

fn test_command_cval_matches_command() {
	command := Command{
		action: Action.new_str(.text, 'hello')
		title: 'Title'
		description: 'Description'
	}
	cval := command.cval()
	unsafe {
		assert cstring_to_vstring(cval.action_key) == 'text'
		assert cstring_to_vstring(cval.action) == 'text:hello'
		assert cstring_to_vstring(cval.title) == 'Title'
		assert cstring_to_vstring(cval.description) == 'Description'
	}
	assert command.comptime_cval().action_key != unsafe { nil }
	assert command_defaults_c.len == command_defaults.len
}

fn test_key_event_effective_mods_no_utf8() {
	e := KeyEvent{
		mods: Mods{ shift: true, ctrl: true }
	}
	result := e.effective_mods()
	assert result.shift == true
	assert result.ctrl == true
}

fn test_key_event_effective_mods_with_utf8() {
	e := KeyEvent{
		utf8: 'a'
		mods: Mods{ shift: true, ctrl: true }
		consumed_mods: Mods{ shift: true }
	}
	result := e.effective_mods()
	assert result.shift == false
	assert result.ctrl == true
}

fn test_key_event_binding_hash_different_keys() {
	e1 := KeyEvent{ key: .key_a }
	e2 := KeyEvent{ key: .key_b }
	assert e1.binding_hash() != e2.binding_hash()
}

fn test_key_event_binding_hash_same_key() {
	e1 := KeyEvent{ key: .key_a }
	e2 := KeyEvent{ key: .key_a }
	assert e1.binding_hash() == e2.binding_hash()
}

fn test_key_event_binding_hash_matches_source() {
	e := KeyEvent{
		key: .key_a
		unshifted_codepoint: u32(`A`)
		mods: Mods{ ctrl: true }
	}
	// Reference value from KeyEvent.bindingHash under Zig 0.15.2.
	assert e.binding_hash() == u64(0x65a4726ba67fc9ce)
}

// test "translation macos-option-as-alt"
// Translated from ghostty src/input/key_mods.zig. The whole test is
// Darwin-only there (`if (!isDarwin) return SkipZigTest`) because the
// translation only unsets alt on Darwin.
fn test_mods_translation_macos_option_as_alt() {
	$if darwin {
		// Unset
		{
			mods := Mods{}
			result := mods.translation(.true_)
			assert result.equal(mods)
		}

		// Set
		{
			mods := Mods{ alt: true }
			result := mods.translation(.true_)
			assert result.equal(Mods{})
		}

		// Set but disabled
		{
			mods := Mods{ alt: true }
			result := mods.translation(.false_)
			assert result.equal(mods)
		}

		// Set wrong side
		{
			mods := Mods{ alt: true, sides: SideInfo{ alt: .right } }
			result := mods.translation(.left)
			assert result.equal(mods)
		}
		{
			mods := Mods{ alt: true, sides: SideInfo{ alt: .left } }
			result := mods.translation(.right)
			assert result.equal(mods)
		}

		// Set with other mods
		{
			mods := Mods{ alt: true, shift: true }
			result := mods.translation(.true_)
			assert result.equal(Mods{ shift: true })
		}
	}
}

// Tests for Side enum.

fn test_side_defaults() {
	s := SideInfo{}
	assert s.shift == .left
	assert s.ctrl == .left
	assert s.alt == .left
	assert s.super == .left
}

// Verifies that Mods.int() covers the full packed layout (standard keys,
// caps_lock, num_lock and the side bits) and that mods_from_int round-trips
// it. Faithful to ghostty's packed `Mods` bitcast, where int()/@bitCast are
// inverse operations over all fields.
fn test_mods_int_roundtrip() {
	// Locks occupy bits 4 and 5.
	assert Mods{ caps_lock: true }.int() == 16
	assert Mods{ num_lock: true }.int() == 32

	// Right sides occupy bits 6..9 (shift, ctrl, alt, super).
	assert Mods{ sides: SideInfo{ shift: .right } }.int() == 64
	assert Mods{ sides: SideInfo{ ctrl: .right } }.int() == 128
	assert Mods{ sides: SideInfo{ alt: .right } }.int() == 256
	assert Mods{ sides: SideInfo{ super: .right } }.int() == 512

	// Full round-trip preserves keys, locks and sides.
	m := Mods{
		shift: true
		ctrl: true
		alt: true
		super_: true
		caps_lock: true
		num_lock: true
		sides: SideInfo{ shift: .right, ctrl: .left, alt: .right, super: .right }
	}
	r := mods_from_int(m.int())
	assert r.shift == m.shift
	assert r.ctrl == m.ctrl
	assert r.alt == m.alt
	assert r.super_ == m.super_
	assert r.caps_lock == m.caps_lock
	assert r.num_lock == m.num_lock
	assert r.sides.shift == .right
	assert r.sides.ctrl == .left
	assert r.sides.alt == .right
	assert r.sides.super == .right
}

// Tests for KeyboardLayout.

fn test_keyboard_layout_detect_option_as_alt() {
	assert KeyboardLayout.us_standard.detect_option_as_alt() == .true_
	assert KeyboardLayout.us_international.detect_option_as_alt() == .true_
	assert KeyboardLayout.unknown.detect_option_as_alt() == .false_
}

fn test_keyboard_layout_map_apple_id() {
	assert KeyboardLayout.map_apple_id('com.apple.keylayout.US') or { panic('missing US') } == .us_standard
	assert KeyboardLayout.map_apple_id('com.apple.keylayout.USInternational') or {
		panic('missing US International')
	} == .us_international
	assert KeyboardLayout.map_apple_id('example.unknown') == none
}

fn test_keymap_current_source() {
	mut keymap := Keymap.init() or { panic(err) }
	defer { keymap.deinit() }
	$if macos {
		mut buf := []u8{len: 256}
		id := keymap.source_id(mut buf) or { panic(err) }
		assert id.len > 0
	} $else {
		mut state := KeymapState{}
		result := keymap.translate([]u8{}, mut state, 0xffff, Mods{
			shift: true
			ctrl: true
			alt: true
			super_: true
			caps_lock: true
			num_lock: true
		}) or { panic(err) }
		assert result.text == ''
		assert !result.composing
		assert result.mods == Mods{}
	}
	keymap.reload() or { panic(err) }
}

// Tests for ScrollMods.

fn test_scroll_mods_default() {
	s := ScrollMods{}
	assert s.precision() == false
	assert s.momentum() == .none_
}

fn test_compact_mouse_enum_storage() {
	assert sizeof(MouseButtonState) == 4
	assert sizeof(MouseButton) == 4
	assert sizeof(Momentum) == 1
	assert sizeof(PressureStage) == 1
	assert sizeof(ScrollMods) == 1
}

fn test_scroll_mods_packed_abi_roundtrip() {
	values := [Momentum.none_, .began, .stationary, .changed, .ended, .cancelled, .may_begin]
	for i, momentum in values {
		for precision in [false, true] {
			mods := ScrollMods.init(precision, momentum)
			expected := u8(precision) | (u8(i) << 1)
			assert mods.int() == expected
			assert scroll_mods_from_int(expected) == mods
			assert mods.precision() == precision
			assert mods.momentum() == momentum
		}
	}
}

fn test_scroll_mods_preserves_all_c_abi_bits() {
	assert scroll_mods_from_int(0xfe).int() == 0xfe
	assert scroll_mods_from_int(0xff).int() == 0xff
}

// Tests for MouseButton.

fn test_mouse_button_values() {
	assert MouseButton.unknown != MouseButton.left
	assert MouseButton.left != MouseButton.right
}
