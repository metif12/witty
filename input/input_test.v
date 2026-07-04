module input

// Tests for KeyEvent.

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
	assert s.shift == .none_
	assert s.ctrl == .none_
	assert s.alt == .none_
	assert s.super == .none_
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
	assert KeyboardLayout.unknown.detect_option_as_alt() == .false_
}

// Tests for ScrollMods.

fn test_scroll_mods_default() {
	s := ScrollMods{}
	assert s.precision == false
	assert s.momentum == .none_
}

// Tests for MouseButton.

fn test_mouse_button_values() {
	assert MouseButton.unknown != MouseButton.left
	assert MouseButton.left != MouseButton.right
}
