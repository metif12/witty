module terminal

// Tests for modes.v.
// Translated from Ghostty's terminal/modes.zig tests.

// ============================================================
// mode_from_int tests
// ============================================================

// Test that mode_from_int correctly maps ANSI mode values.
fn test_mode_from_int_ansi() {
	// ANSI mode 4 = insert
	m := mode_from_int(4, true) or {
		assert false, 'expected insert mode'
		return
	}
	assert m == .insert
}

// Test that ANSI flag is respected - DEC mode 9 is not ANSI.
fn test_mode_from_int_ansi_not_dec() {
	// Mode 9 exists as DEC (mouse_event_x10), not as ANSI
	m := mode_from_int(9, true)
	assert m == none
}

// Test that mode_from_int correctly maps DEC mode values.
fn test_mode_from_int_dec() {
	// DEC mode 9 = mouse_event_x10
	m := mode_from_int(9, false) or {
		assert false, 'expected mouse_event_x10 mode'
		return
	}
	assert m == .mouse_event_x10
}

// Test that unknown mode values return none.
fn test_mode_from_int_unknown() {
	// Mode 14 does not exist as ANSI
	m := mode_from_int(14, true)
	assert m == none
}

// Test well-known DEC modes.
fn test_mode_from_int_well_known_dec() {
	// DEC mode 25 = cursor_visible
	if m := mode_from_int(25, false) {
		assert m == .cursor_visible
	} else {
		assert false, 'expected cursor_visible'
	}

	// DEC mode 7 = wraparound
	if m := mode_from_int(7, false) {
		assert m == .wraparound
	} else {
		assert false, 'expected wraparound'
	}

	// DEC mode 2004 = bracketed_paste
	if m := mode_from_int(2004, false) {
		assert m == .bracketed_paste
	} else {
		assert false, 'expected bracketed_paste'
	}

	// DEC mode 1049 = alt_screen_save_cursor_clear_enter
	if m := mode_from_int(1049, false) {
		assert m == .alt_screen_save_cursor_clear_enter
	} else {
		assert false, 'expected alt_screen_save_cursor_clear_enter'
	}
}

// ============================================================
// mode_value tests
// ============================================================

// Test that mode_value returns the correct protocol value.
fn test_mode_value() {
	assert mode_value(.cursor_visible) == u16(25)
	assert mode_value(.wraparound) == u16(7)
	assert mode_value(.bracketed_paste) == u16(2004)
	assert mode_value(.insert) == u16(4)
	assert mode_value(.mouse_event_x10) == u16(9)
}

// ============================================================
// mode_is_ansi tests
// ============================================================

// Test that mode_is_ansi correctly identifies ANSI vs DEC modes.
fn test_mode_is_ansi() {
	// insert is ANSI mode 4
	assert mode_is_ansi(.insert) == true
	// linefeed is ANSI mode 20
	assert mode_is_ansi(.linefeed) == true
	// cursor_visible is DEC mode 25
	assert mode_is_ansi(.cursor_visible) == false
	// wraparound is DEC mode 7
	assert mode_is_ansi(.wraparound) == false
}

// ============================================================
// ModeState tests (exercising the existing ModeState with mode_from_int)
// ============================================================

// Test ModeState set/get cycle using mode_from_int lookup.
fn test_mode_state_with_mode_from_int() {
	mut state := ModeState{}

	// Look up DEC mode 25 (cursor_visible)
	mode := mode_from_int(25, false) or {
		assert false, 'expected cursor_visible'
		return
	}
	assert mode == .cursor_visible

	// Set it via ModeState
	state.set(mode, true)
	assert state.get(mode) == true

	// Save and restore
	state.save(mode)
	state.set(mode, false)
	assert state.get(mode) == false
	restored := state.restore(mode)
	assert restored == true
	assert state.get(mode) == true
}

fn test_mode_state_reset_clears_saved_modes() {
	mut state := ModeState{
		default: build_default_modes()
	}
	state.set(.cursor_keys, true)
	state.save(.cursor_keys)
	assert state.saved.data != 0

	state.reset()
	assert state.values.data == state.default.data
	assert state.saved.data == 0
}

fn test_mode_uses_packed_protocol_tags() {
	assert u16(Mode.cursor_keys) == 1
	assert u16(Mode.insert) == (u16(1) << 15) | 4
	assert u16(Mode.send_receive_mode) == (u16(1) << 15) | 12
	assert u16(Mode.grapheme_cluster) == 2027
	assert sizeof(ModeTag) == 2
	dec := Mode.cursor_keys.tag()
	assert dec.value() == 1
	assert !dec.ansi()
	ansi := Mode.insert.tag()
	assert ansi.value() == 4
	assert ansi.ansi()
	assert ansi.int() == (u16(1) << 15) | 4
}

// ============================================================
// mode_entry_for tests
// ============================================================

// Test that mode_entry_for returns correct entries.
fn test_mode_entry_for() {
	if entry := mode_entry_for(.cursor_visible) {
		assert entry.value == u16(25)
		assert entry.ansi == false
		assert entry.default_val == true
	} else {
		assert false, 'expected entry for cursor_visible'
	}

	if entry := mode_entry_for(.insert) {
		assert entry.value == u16(4)
		assert entry.ansi == true
		assert entry.default_val == false
	} else {
		assert false, 'expected entry for insert'
	}
}

// Test round-trip: mode_from_int -> mode_value.
fn test_mode_roundtrip() {
	// DEC mode 1006 = mouse_format_sgr
	m := mode_from_int(1006, false) or {
		assert false, 'expected mouse_format_sgr'
		return
	}
	assert m == .mouse_format_sgr
	assert mode_value(m) == u16(1006)
}
