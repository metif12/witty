module terminal

// Terminal modes mapping table and lookup functions.
// Translated from Ghostty's terminal/modes.zig.
//
// This file contains the mode entry table that maps terminal protocol
// mode values (ANSI and DEC) to our internal Mode enum, and the
// mode_from_int lookup function.
//
// V represents Ghostty's generated packed mode struct as a u64. The bit order
// follows mode_entries while Mode itself retains its packed protocol tag.

pub struct ModePacked {
pub mut:
	data u64
}

pub struct ModeState {
pub mut:
	values  ModePacked
	saved   ModePacked
	default ModePacked
}

pub enum Mode as u16 {
	disable_keyboard                   = 32770
	insert                             = 32772
	send_receive_mode                  = 32780
	linefeed                           = 32788
	cursor_keys                        = 1
	column_132                         = 3
	slow_scroll                        = 4
	reverse_colors                     = 5
	origin                             = 6
	wraparound                         = 7
	autorepeat                         = 8
	mouse_event_x10                    = 9
	cursor_blinking                    = 12
	cursor_visible                     = 25
	enable_mode_3                      = 40
	reverse_wrap                       = 45
	alt_screen_legacy                  = 47
	keypad_keys                        = 66
	enable_left_and_right_margin       = 69
	mouse_event_normal                 = 1000
	mouse_event_button                 = 1002
	mouse_event_any                    = 1003
	focus_event                        = 1004
	mouse_format_utf8                  = 1005
	mouse_format_sgr                   = 1006
	mouse_alternate_scroll             = 1007
	mouse_format_urxvt                 = 1015
	mouse_format_sgr_pixels            = 1016
	ignore_keypad_with_numlock         = 1035
	alt_esc_prefix                     = 1036
	alt_sends_escape                   = 1039
	reverse_wrap_extended              = 1045
	alt_screen                         = 1047
	save_cursor                        = 1048
	alt_screen_save_cursor_clear_enter = 1049
	bracketed_paste                    = 2004
	synchronized_output                = 2026
	grapheme_cluster                   = 2027
	report_color_scheme                = 2031
	in_band_size_reports               = 2048
}

// The packed protocol tag underlying Mode. Bits 0-14 retain the numeric mode
// value and bit 15 distinguishes ANSI modes from DEC private modes.
pub struct ModeTag {
mut:
	data u16
}

pub fn ModeTag.init(value u16, ansi bool) ModeTag {
	assert value <= 0x7fff
	return ModeTag{
		data: value | (u16(ansi) << 15)
	}
}

pub fn ModeTag.from_u16(value u16) ModeTag {
	return ModeTag{
		data: value
	}
}

pub fn (self ModeTag) value() u16 {
	return self.data & 0x7fff
}

pub fn (self ModeTag) ansi() bool {
	return self.data & 0x8000 != 0
}

pub fn (self ModeTag) int() u16 {
	return self.data
}

pub fn (self Mode) tag() ModeTag {
	return ModeTag.from_u16(u16(self))
}

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
const mode_entries = [
	// ANSI modes
	ModeEntry{ mode: .disable_keyboard, value: 2, ansi: true, default_val: false },
	ModeEntry{ mode: .insert, value: 4, ansi: true, default_val: false },
	ModeEntry{ mode: .send_receive_mode, value: 12, ansi: true, default_val: true },
	ModeEntry{ mode: .linefeed, value: 20, ansi: true, default_val: false },

	// DEC modes
	ModeEntry{ mode: .cursor_keys, value: 1, ansi: false, default_val: false },
	ModeEntry{ mode: .column_132, value: 3, ansi: false, default_val: false },
	ModeEntry{ mode: .slow_scroll, value: 4, ansi: false, default_val: false },
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
	ModeEntry{ mode: .keypad_keys, value: 66, ansi: false, default_val: false },
	ModeEntry{ mode: .enable_left_and_right_margin, value: 69, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_event_normal, value: 1000, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_event_button, value: 1002, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_event_any, value: 1003, ansi: false, default_val: false },
	ModeEntry{ mode: .focus_event, value: 1004, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_format_utf8, value: 1005, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_format_sgr, value: 1006, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_alternate_scroll, value: 1007, ansi: false, default_val: true },
	ModeEntry{ mode: .mouse_format_urxvt, value: 1015, ansi: false, default_val: false },
	ModeEntry{ mode: .mouse_format_sgr_pixels, value: 1016, ansi: false, default_val: false },
	ModeEntry{ mode: .ignore_keypad_with_numlock, value: 1035, ansi: false, default_val: true },
	ModeEntry{ mode: .alt_esc_prefix, value: 1036, ansi: false, default_val: true },
	ModeEntry{ mode: .alt_sends_escape, value: 1039, ansi: false, default_val: false },
	ModeEntry{ mode: .reverse_wrap_extended, value: 1045, ansi: false, default_val: false },
	ModeEntry{ mode: .alt_screen, value: 1047, ansi: false, default_val: false },
	ModeEntry{ mode: .save_cursor, value: 1048, ansi: false, default_val: false },
	ModeEntry{ mode: .alt_screen_save_cursor_clear_enter, value: 1049, ansi: false, default_val: false },
	ModeEntry{ mode: .bracketed_paste, value: 2004, ansi: false, default_val: false },
	ModeEntry{ mode: .synchronized_output, value: 2026, ansi: false, default_val: false },
	ModeEntry{ mode: .grapheme_cluster, value: 2027, ansi: false, default_val: false },
	ModeEntry{ mode: .report_color_scheme, value: 2031, ansi: false, default_val: false },
	ModeEntry{ mode: .in_band_size_reports, value: 2048, ansi: false, default_val: false },
]

// Build the default ModePacked from the mode table's default flags. This
// mirrors ghostty's ModeState.default, which is derived from each entry's
// `.default`. Modes default to false unless their table entry says otherwise.
pub fn build_default_modes() ModePacked {
	mut data := u64(0)
	for i, entry in mode_entries {
		if entry.default_val {
			data |= u64(1) << i
		}
	}
	return ModePacked{
		data: data
	}
}

fn mode_mask(mode Mode) u64 {
	for i, entry in mode_entries {
		if entry.mode == mode {
			return u64(1) << i
		}
	}
	panic('unreachable: mode has no entry')
}

pub fn (self ModeState) get(mode Mode) bool {
	return (self.values.data & mode_mask(mode)) != 0
}

pub fn (mut self ModeState) set(mode Mode, val bool) {
	mask := mode_mask(mode)
	if val {
		self.values.data |= mask
	} else {
		self.values.data &= ~mask
	}
}

pub fn (mut self ModeState) reset() {
	self.values = self.default
	self.saved = ModePacked{}
}

pub fn (mut self ModeState) save(mode Mode) {
	mask := mode_mask(mode)
	if (self.values.data & mask) != 0 {
		self.saved.data |= mask
	} else {
		self.saved.data &= ~mask
	}
}

pub fn (mut self ModeState) restore(mode Mode) bool {
	mask := mode_mask(mode)
	val := (self.saved.data & mask) != 0
	if val {
		self.values.data |= mask
	} else {
		self.values.data &= ~mask
	}
	return val
}

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
	return u16(mode) & 0x7fff
}

// ============================================================
// mode_is_ansi - check if a Mode is an ANSI mode
// ============================================================

// Returns true if the given mode is an ANSI mode (as opposed to
// a DEC private mode).
pub fn mode_is_ansi(mode Mode) bool {
	return (u16(mode) & (u16(1) << 15)) != 0
}
