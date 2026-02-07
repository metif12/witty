module input

// CursorMode represents the cursor key mode requirement for a function key entry.
pub enum CursorMode {
	any
	normal
	application
}

// KeypadMode represents the keypad application mode requirement for a function key entry.
pub enum KeypadMode {
	any
	normal
	application
}

// ModifyKeys represents the "modify other keys" setting requirement.
// A bit confusing so documenting: this is the "modify other keys"
// setting. We only change behavior for "set_other" which is ESC [ > 4; 2 m.
// So this can be "any" which means we don't care what's going on. Or it
// can be "set" which means modify keys must be set EXCEPT FOR "other keys"
// mode, and "set_other" which means modify keys must be set to "other keys"
// mode.
//
// See: https://invisible-island.net/xterm/modified-keys.html
pub enum ModifyKeys {
	any
	set
	set_other
}

// FunctionKeyEntry represents a single function key sequence mapping.
// The exact set of modifiers that must be active for this entry to match.
// If mods_empty_is_any is true then empty mods means any set of mods can
// match. Otherwise, empty mods means no mods must be active.
pub struct FunctionKeyEntry {
pub:
	mods              Mods
	mods_empty_is_any bool       = true
	cursor            CursorMode = .any
	keypad            KeypadMode = .any
	modify_other_keys ModifyKeys = .any
	sequence          string
}

// fk_modifiers is the set of modifier combinations used for PC-style function keys.
// The modifier code sent in the escape sequence is the array index + 2.
const fk_modifiers = [
	Mods{ shift: true },
	Mods{ alt: true },
	Mods{ shift: true, alt: true },
	Mods{ ctrl: true },
	Mods{ shift: true, ctrl: true },
	Mods{ alt: true, ctrl: true },
	Mods{ shift: true, alt: true, ctrl: true },
	Mods{ super_: true },
	Mods{ shift: true, super_: true },
	Mods{ alt: true, super_: true },
	Mods{ shift: true, alt: true, super_: true },
	Mods{ ctrl: true, super_: true },
	Mods{ shift: true, ctrl: true, super_: true },
	Mods{ alt: true, ctrl: true, super_: true },
	Mods{ shift: true, alt: true, ctrl: true, super_: true },
]

// make_pc_style generates PC-style function key entries for all modifier combinations.
// The fmt string should contain '{}' which gets replaced with the modifier code (2-16).
fn make_pc_style(fmt string) []FunctionKeyEntry {
	mut entries := []FunctionKeyEntry{cap: 15}
	for i, m in fk_modifiers {
		code := i + 2
		seq := fmt.replace('{}', code.str())
		entries << FunctionKeyEntry{
			mods: m
			mods_empty_is_any: false
			sequence: seq
		}
	}
	return entries
}

// make_cursor_key generates cursor key mode entries (normal vs application mode).
fn make_cursor_key(normal string, application string) []FunctionKeyEntry {
	return [
		FunctionKeyEntry{ cursor: .normal, sequence: normal },
		FunctionKeyEntry{ cursor: .application, sequence: application },
	]
}

// make_kp_keys generates keypad application mode entries.
fn make_kp_keys(letter string) []FunctionKeyEntry {
	return [
		FunctionKeyEntry{ keypad: .application, sequence: '\x1bO${letter}' },
	]
}

// get_function_key_entries returns the function key entries for a given key.
// Returns an empty array if the key has no function key encoding.
fn get_function_key_entries(k Key) []FunctionKeyEntry {
	match k {
		// Arrow keys
		.arrow_up {
			mut entries := make_pc_style('\x1b[1;{}A')
			entries << make_cursor_key('\x1b[A', '\x1bOA')
			return entries
		}
		.arrow_down {
			mut entries := make_pc_style('\x1b[1;{}B')
			entries << make_cursor_key('\x1b[B', '\x1bOB')
			return entries
		}
		.arrow_right {
			mut entries := make_pc_style('\x1b[1;{}C')
			entries << make_cursor_key('\x1b[C', '\x1bOC')
			return entries
		}
		.arrow_left {
			mut entries := make_pc_style('\x1b[1;{}D')
			entries << make_cursor_key('\x1b[D', '\x1bOD')
			return entries
		}
		// Navigation keys
		.home {
			mut entries := make_pc_style('\x1b[1;{}H')
			entries << make_cursor_key('\x1b[H', '\x1bOH')
			return entries
		}
		.end {
			mut entries := make_pc_style('\x1b[1;{}F')
			entries << make_cursor_key('\x1b[F', '\x1bOF')
			return entries
		}
		.insert {
			mut entries := make_pc_style('\x1b[2;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[2~' }
			return entries
		}
		.delete {
			mut entries := make_pc_style('\x1b[3;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[3~' }
			return entries
		}
		.page_up {
			mut entries := make_pc_style('\x1b[5;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[5~' }
			return entries
		}
		.page_down {
			mut entries := make_pc_style('\x1b[6;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[6~' }
			return entries
		}
		// Function keys
		.f1 {
			mut entries := make_pc_style('\x1b[1;{}P')
			entries << FunctionKeyEntry{ sequence: '\x1bOP' }
			return entries
		}
		.f2 {
			mut entries := make_pc_style('\x1b[1;{}Q')
			entries << FunctionKeyEntry{ sequence: '\x1bOQ' }
			return entries
		}
		.f3 {
			mut entries := make_pc_style('\x1b[13;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1bOR' }
			return entries
		}
		.f4 {
			mut entries := make_pc_style('\x1b[1;{}S')
			entries << FunctionKeyEntry{ sequence: '\x1bOS' }
			return entries
		}
		.f5 {
			mut entries := make_pc_style('\x1b[15;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[15~' }
			return entries
		}
		.f6 {
			mut entries := make_pc_style('\x1b[17;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[17~' }
			return entries
		}
		.f7 {
			mut entries := make_pc_style('\x1b[18;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[18~' }
			return entries
		}
		.f8 {
			mut entries := make_pc_style('\x1b[19;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[19~' }
			return entries
		}
		.f9 {
			mut entries := make_pc_style('\x1b[20;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[20~' }
			return entries
		}
		.f10 {
			mut entries := make_pc_style('\x1b[21;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[21~' }
			return entries
		}
		.f11 {
			mut entries := make_pc_style('\x1b[23;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[23~' }
			return entries
		}
		.f12 {
			mut entries := make_pc_style('\x1b[24;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[24~' }
			return entries
		}
		// Keypad keys
		.numpad_0 {
			return make_kp_keys('p')
		}
		.numpad_1 {
			return make_kp_keys('q')
		}
		.numpad_2 {
			return make_kp_keys('r')
		}
		.numpad_3 {
			return make_kp_keys('s')
		}
		.numpad_4 {
			return make_kp_keys('t')
		}
		.numpad_5 {
			return make_kp_keys('u')
		}
		.numpad_6 {
			return make_kp_keys('v')
		}
		.numpad_7 {
			return make_kp_keys('w')
		}
		.numpad_8 {
			return make_kp_keys('x')
		}
		.numpad_9 {
			return make_kp_keys('y')
		}
		.numpad_decimal {
			return make_kp_keys('n')
		}
		.numpad_divide {
			return make_kp_keys('o')
		}
		.numpad_multiply {
			return make_kp_keys('j')
		}
		.numpad_subtract {
			return make_kp_keys('m')
		}
		.numpad_add {
			return make_kp_keys('k')
		}
		.numpad_enter {
			mut entries := make_kp_keys('M')
			entries << FunctionKeyEntry{ sequence: '\r' }
			return entries
		}
		// Numpad navigation keys (same as regular nav keys)
		.numpad_up {
			mut entries := make_pc_style('\x1b[1;{}A')
			entries << make_cursor_key('\x1b[A', '\x1bOA')
			return entries
		}
		.numpad_down {
			mut entries := make_pc_style('\x1b[1;{}B')
			entries << make_cursor_key('\x1b[B', '\x1bOB')
			return entries
		}
		.numpad_right {
			mut entries := make_pc_style('\x1b[1;{}C')
			entries << make_cursor_key('\x1b[C', '\x1bOC')
			return entries
		}
		.numpad_left {
			mut entries := make_pc_style('\x1b[1;{}D')
			entries << make_cursor_key('\x1b[D', '\x1bOD')
			return entries
		}
		.numpad_begin {
			mut entries := make_pc_style('\x1b[1;{}E')
			entries << make_cursor_key('\x1b[E', '\x1bOE')
			return entries
		}
		.numpad_home {
			mut entries := make_pc_style('\x1b[1;{}H')
			entries << make_cursor_key('\x1b[H', '\x1bOH')
			return entries
		}
		.numpad_end {
			mut entries := make_pc_style('\x1b[1;{}F')
			entries << make_cursor_key('\x1b[F', '\x1bOF')
			return entries
		}
		.numpad_insert {
			mut entries := make_pc_style('\x1b[2;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[2~' }
			return entries
		}
		.numpad_delete {
			mut entries := make_pc_style('\x1b[3;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[3~' }
			return entries
		}
		.numpad_page_up {
			mut entries := make_pc_style('\x1b[5;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[5~' }
			return entries
		}
		.numpad_page_down {
			mut entries := make_pc_style('\x1b[6;{}~')
			entries << FunctionKeyEntry{ sequence: '\x1b[6~' }
			return entries
		}
		// Backspace has complex modifier handling
		.backspace {
			return [
				// Modify Keys Normal
				FunctionKeyEntry{ mods: Mods{ shift: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x7f' },
				FunctionKeyEntry{ mods: Mods{ alt: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\x7f' },
				FunctionKeyEntry{ mods: Mods{ shift: true, alt: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\x7f' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true, shift: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x08' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\x08' },
				FunctionKeyEntry{ mods: Mods{ super_: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x7f' },
				FunctionKeyEntry{ mods: Mods{ super_: true, shift: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x7f' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\x7f' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, shift: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\x7f' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x08' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true, shift: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x08' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\x08' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true, shift: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\x08' },
				// Modify Keys Other
				FunctionKeyEntry{ mods: Mods{ shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;2;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;3;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;4;127~' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true, shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;6;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;7;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, shift: true, ctrl: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;8;127~' },
				FunctionKeyEntry{ mods: Mods{ super_: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;9;127~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;10;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;11;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;12;127~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;13;127~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true, shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;14;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;15;127~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true, shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;16;127~' },
				// Default
				FunctionKeyEntry{ mods: Mods{ ctrl: true }, mods_empty_is_any: false, sequence: '\x08' },
				FunctionKeyEntry{ sequence: '\x7f' },
			]
		}
		// Tab has complex modifier handling
		.tab {
			return [
				// Modify Keys Normal
				FunctionKeyEntry{ mods: Mods{ shift: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b[Z' },
				FunctionKeyEntry{ mods: Mods{ alt: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\t' },
				// Modify Keys Other
				FunctionKeyEntry{ mods: Mods{ shift: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;2;9~' },
				FunctionKeyEntry{ mods: Mods{ alt: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;3;9~' },
				// Everything else
				FunctionKeyEntry{ mods: Mods{ alt: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;4;9~' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;5;9~' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;6;9~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;7;9~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;8;9~' },
				FunctionKeyEntry{ mods: Mods{ super_: true }, mods_empty_is_any: false, sequence: '\x1b[27;9;9~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;10;9~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true }, mods_empty_is_any: false, sequence: '\x1b[27;11;9~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;12;9~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;13;9~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;14;9~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;15;9~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;16;9~' },
				// Default
				FunctionKeyEntry{ sequence: '\t' },
			]
		}
		// Enter has complex modifier handling
		.enter {
			return [
				FunctionKeyEntry{ mods: Mods{ shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;2;13~' },
				// Modify Keys Normal
				FunctionKeyEntry{ mods: Mods{ alt: true }, modify_other_keys: .set, mods_empty_is_any: false, sequence: '\x1b\r' },
				// Modify Keys Other
				FunctionKeyEntry{ mods: Mods{ alt: true }, modify_other_keys: .set_other, mods_empty_is_any: false, sequence: '\x1b[27;3;13~' },
				// Everything else
				FunctionKeyEntry{ mods: Mods{ alt: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;4;13~' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;5;13~' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;6;13~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;7;13~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;8;13~' },
				FunctionKeyEntry{ mods: Mods{ super_: true }, mods_empty_is_any: false, sequence: '\x1b[27;9;13~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;10;13~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true }, mods_empty_is_any: false, sequence: '\x1b[27;11;13~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;12;13~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;13;13~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;14;13~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;15;13~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;16;13~' },
				// Default
				FunctionKeyEntry{ sequence: '\r' },
			]
		}
		// Escape has complex modifier handling
		.escape {
			return [
				FunctionKeyEntry{ mods: Mods{ shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;2;27~' },
				FunctionKeyEntry{ mods: Mods{ alt: true }, mods_empty_is_any: false, sequence: '\x1b\x1b' },
				FunctionKeyEntry{ mods: Mods{ alt: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;4;27~' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;5;27~' },
				FunctionKeyEntry{ mods: Mods{ ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;6;27~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;7;27~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;8;27~' },
				FunctionKeyEntry{ mods: Mods{ super_: true }, mods_empty_is_any: false, sequence: '\x1b[27;9;27~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;10;27~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true }, mods_empty_is_any: false, sequence: '\x1b[27;11;27~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;12;27~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;13;27~' },
				FunctionKeyEntry{ mods: Mods{ super_: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;14;27~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true }, mods_empty_is_any: false, sequence: '\x1b[27;15;27~' },
				FunctionKeyEntry{ mods: Mods{ alt: true, super_: true, ctrl: true, shift: true }, mods_empty_is_any: false, sequence: '\x1b[27;16;27~' },
				// Default
				FunctionKeyEntry{ sequence: '\x1b' },
			]
		}
		else {
			return []
		}
	}
}
