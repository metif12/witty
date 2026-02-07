module terminal

// Terminal modes mapping table and lookup functions.
// Translated from Ghostty's terminal/modes.zig.
//
// This file contains the mode entry table that maps terminal protocol
// mode values (ANSI and DEC) to our internal Mode enum, and the
// mode_from_int lookup function.
//
// The Mode enum, ModeState, and ModePacked are defined in terminal.v.
// This file provides the protocol-level mapping layer on top of those.

// ============================================================
// ModeEntry - a single entry in the mode table
// ============================================================

// A single entry of a possible mode we support. This is used to
// map protocol-level mode values (e.g., DEC mode 25 for cursor visible)
// to our internal Mode enum values.
struct ModeEntry {
	// The internal Mode enum value.
	mode Mode
	// The protocol-level value (e.g., 25 for cursor_visible).
	value u16
	// True if this is an ANSI mode, false if it is a DEC mode (?-prefixed).
	ansi bool
	// The default value for this mode (true = enabled by default).
	default_val bool
	// If true, this mode is disabled and will not be settable or queryable.
	disabled bool
}

// The full list of mode entries. For documentation see how
// they are used within Ghostty or search for their values.
// It is not valuable to redocument them all here.
//
// The order matches the Zig source for easy cross-reference.
// Modes not yet present in the Mode enum are commented out with XTODO.
const mode_entries = [
	// ANSI modes
	// XTODO: disable_keyboard (KAM, ANSI mode 2) not yet in Mode enum
	ModeEntry{ mode: .insert, value: 4, ansi: true, default_val: false },
	// XTODO: send_receive_mode (SRM, ANSI mode 12) not yet in Mode enum
	ModeEntry{ mode: .linefeed, value: 20, ansi: true, default_val: false },

	// DEC modes
	// XTODO: cursor_keys (DECCKM, DEC mode 1) not yet in Mode enum
	ModeEntry{ mode: .column_132, value: 3, ansi: false, default_val: false },
	// XTODO: slow_scroll (DEC mode 4) not yet in Mode enum
	ModeEntry{ mode: .reverse_colors, value: 5, ansi: false, default_val: false },
	ModeEntry{ mode: .origin, value: 6, ansi: false, default_val: false },
	ModeEntry{ mode: .wraparound, value: 7, ansi: false, default_val: true },
	ModeEntry{ mode: .autorepeat, value: 8, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_event_x10, value: 9, ansi: false, default_val: false },
	ModeEntry{ mode: .cursor_blinking, value: 12, ansi: false, default_val: false },
	ModeEntry{ mode: .cursor_visible, value: 25, ansi: false, default_val: true },
	ModeEntry{ mode: .enable_mode_3, value: 40, ansi: false, default_val: false },
	ModeEntry{ mode: .reverse_wrap, value: 45, ansi: false, default_val: false },
	ModeEntry{ mode: .alt_screen_legacy, value: 47, ansi: false, default_val: false },
	// XTODO: keypad_keys (DEC mode 66) not yet in Mode enum
	ModeEntry{ mode: .enable_left_and_right_margin, value: 69, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_event_normal, value: 1000, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_event_button, value: 1002, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_event_any, value: 1003, ansi: false, default_val: false },
	ModeEntry{ mode: .focus_event, value: 1004, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_format_utf8, value: 1005, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_format_sgr, value: 1006, ansi: false, default_val: false },
	// XTODO: mouse_alternate_scroll (DEC mode 1007) not yet in Mode enum
	ModeEntry{ mode: .mouse_format_urxvt, value: 1015, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_format_sgr_pixels, value: 1016, ansi: false, default_val: false },
	// XTODO: ignore_keypad_with_numlock (DEC mode 1035) not yet in Mode enum
	// XTODO: alt_esc_prefix (DEC mode 1036) not yet in Mode enum
	// XTODO: alt_sends_escape (DEC mode 1039) not yet in Mode enum
	ModeEntry{ mode: .reverse_wrap_extended, value: 1045, ansi: false, default_val: false },
	ModeEntry{ mode: .alt_screen, value: 1047, ansi: false, default_val: false },
	ModeEntry{ mode: .save_cursor, value: 1048, ansi: false, default_val: false },
	ModeEntry{ mode: .alt_screen_save_cursor_clear_enter, value: 1049, ansi: false, default_val: false },
	ModeEntry{ mode: .bracketed_paste, value: 2004, ansi: false, default_val: false },
	ModeEntry{ mode: .synchronized_output, value: 2026, ansi: false, default_val: false },
	ModeEntry{ mode: .grapheme_cluster, value: 2027, ansi: false, default_val: false },
	// XTODO: report_color_scheme (DEC mode 2031) not yet in Mode enum
	ModeEntry{ mode: .in_band_size_reports, value: 2048, ansi: false, default_val: false },
]

// ============================================================
// mode_from_int - look up a Mode from a protocol value
// ============================================================

// Look up a Mode from its protocol-level integer value and whether
// it is an ANSI mode or a DEC mode. Returns none if the value does
// not correspond to any known (and enabled) mode.
//
// For example:
//   mode_from_int(25, false) returns ?Mode(.cursor_visible)  -- DEC mode 25
//   mode_from_int(4, true)  returns ?Mode(.insert)           -- ANSI mode 4
//   mode_from_int(9, true)  returns none                     -- 9 is DEC, not ANSI
pub fn mode_from_int(v u16, ansi bool) ?Mode {
	for entry in mode_entries {
		if !entry.disabled && entry.value == v && entry.ansi == ansi {
			return entry.mode
		}
	}
	return none
}

// ============================================================
// mode_entry_for - look up the ModeEntry for a given Mode
// ============================================================

// Returns the ModeEntry for the given Mode. This provides access
// to the protocol-level value, whether it is ANSI or DEC, and
// the default value.
pub fn mode_entry_for(mode Mode) ?ModeEntry {
	for entry in mode_entries {
		if entry.mode == mode {
			return entry
		}
	}
	return none
}

// ============================================================
// mode_value - get the protocol integer value for a Mode
// ============================================================

// Returns the protocol-level integer value for the given mode.
// For example, mode_value(.cursor_visible) returns 25.
pub fn mode_value(mode Mode) u16 {
	if entry := mode_entry_for(mode) {
		return entry.value
	}
	return 0
}

// ============================================================
// mode_is_ansi - check if a Mode is an ANSI mode
// ============================================================

// Returns true if the given mode is an ANSI mode (as opposed to
// a DEC private mode).
pub fn mode_is_ansi(mode Mode) bool {
	if entry := mode_entry_for(mode) {
		return entry.ansi
	}
	return false
}
