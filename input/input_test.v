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

// Tests for Mods.translation (macos-option-as-alt).

fn test_mods_translation_unset() {
	m := Mods{}
	result := m.translation(.true_)
	assert result.equal(m)
}

fn test_mods_translation_set() {
	m := Mods{ alt: true }
	result := m.translation(.true_)
	assert result.alt == true // true_ means alt stays
}

fn test_mods_translation_disabled() {
	m := Mods{ alt: true }
	result := m.translation(.false_)
	assert result.alt == false
}

// Tests for Side enum.

fn test_side_defaults() {
	s := SideInfo{}
	assert s.shift == .none_
	assert s.ctrl == .none_
	assert s.alt == .none_
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
