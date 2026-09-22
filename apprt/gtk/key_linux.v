module gtk

// key_linux.v - GTK/GDK key translation.
//
// Translated faithfully from ghostty/src/apprt/gtk/key.zig.
//
// Covers:
//   - the GDK keyval <-> input.Key keymap (`keymap`)
//   - keyFromKeyval / keyvalFromKey
//   - accelFromTrigger / xdgShortcutFromTrigger / writeTriggerKey
//   - labelFromTrigger (human-readable)
//   - translateMods
//   - keyvalUnicode helpers
//
// The GDK keyval numeric constants below are the standard X11 keysym values
// (GDK keysyms are identical to X11 keysyms). They are stable ABI constants
// defined by <X11/keysymdef.h> / <gdk/gdkkeysyms.h>.

import input

// --- GDK / X11 keysym constants -------------------------------------------

const gdk_key_a = u32(0x061)
const gdk_key_b = u32(0x062)
const gdk_key_c = u32(0x063)
const gdk_key_d = u32(0x064)
const gdk_key_e = u32(0x065)
const gdk_key_f = u32(0x066)
const gdk_key_g = u32(0x067)
const gdk_key_h = u32(0x068)
const gdk_key_i = u32(0x069)
const gdk_key_j = u32(0x06a)
const gdk_key_k = u32(0x06b)
const gdk_key_l = u32(0x06c)
const gdk_key_m = u32(0x06d)
const gdk_key_n = u32(0x06e)
const gdk_key_o = u32(0x06f)
const gdk_key_p = u32(0x070)
const gdk_key_q = u32(0x071)
const gdk_key_r = u32(0x072)
const gdk_key_s = u32(0x073)
const gdk_key_t = u32(0x074)
const gdk_key_u = u32(0x075)
const gdk_key_v = u32(0x076)
const gdk_key_w = u32(0x077)
const gdk_key_x = u32(0x078)
const gdk_key_y = u32(0x079)
const gdk_key_z = u32(0x07a)

const gdk_key_0 = u32(0x030)
const gdk_key_1 = u32(0x031)
const gdk_key_2 = u32(0x032)
const gdk_key_3 = u32(0x033)
const gdk_key_4 = u32(0x034)
const gdk_key_5 = u32(0x035)
const gdk_key_6 = u32(0x036)
const gdk_key_7 = u32(0x037)
const gdk_key_8 = u32(0x038)
const gdk_key_9 = u32(0x039)

const gdk_key_semicolon = u32(0x03b)
const gdk_key_space = u32(0x020)
const gdk_key_apostrophe = u32(0x027)
const gdk_key_comma = u32(0x02c)
const gdk_key_grave = u32(0x060)
const gdk_key_period = u32(0x02e)
const gdk_key_slash = u32(0x02f)
const gdk_key_minus = u32(0x02d)
const gdk_key_equal = u32(0x03d)
const gdk_key_bracketleft = u32(0x05b)
const gdk_key_bracketright = u32(0x05d)
const gdk_key_backslash = u32(0x05c)

const gdk_key_up = u32(0xff52)
const gdk_key_down = u32(0xff54)
const gdk_key_right = u32(0xff53)
const gdk_key_left = u32(0xff51)
const gdk_key_home = u32(0xff50)
const gdk_key_end = u32(0xff57)
const gdk_key_insert = u32(0xff63)
const gdk_key_delete = u32(0xffff)
const gdk_key_caps_lock = u32(0xffe5)
const gdk_key_scroll_lock = u32(0xff14)
const gdk_key_num_lock = u32(0xff7f)
const gdk_key_page_up = u32(0xff55)
const gdk_key_page_down = u32(0xff56)
const gdk_key_escape = u32(0xff1b)
const gdk_key_return = u32(0xff0d)
const gdk_key_tab = u32(0xff09)
const gdk_key_backspace = u32(0xff08)
const gdk_key_print = u32(0xff61)
const gdk_key_pause = u32(0xff13)

const gdk_key_f1 = u32(0xffbe)
const gdk_key_f2 = u32(0xffbf)
const gdk_key_f3 = u32(0xffc0)
const gdk_key_f4 = u32(0xffc1)
const gdk_key_f5 = u32(0xffc2)
const gdk_key_f6 = u32(0xffc3)
const gdk_key_f7 = u32(0xffc4)
const gdk_key_f8 = u32(0xffc5)
const gdk_key_f9 = u32(0xffc6)
const gdk_key_f10 = u32(0xffc7)
const gdk_key_f11 = u32(0xffc8)
const gdk_key_f12 = u32(0xffc9)
const gdk_key_f13 = u32(0xffca)
const gdk_key_f14 = u32(0xffcb)
const gdk_key_f15 = u32(0xffcc)
const gdk_key_f16 = u32(0xffcd)
const gdk_key_f17 = u32(0xffce)
const gdk_key_f18 = u32(0xffcf)
const gdk_key_f19 = u32(0xffd0)
const gdk_key_f20 = u32(0xffd1)
const gdk_key_f21 = u32(0xffd2)
const gdk_key_f22 = u32(0xffd3)
const gdk_key_f23 = u32(0xffd4)
const gdk_key_f24 = u32(0xffd5)
const gdk_key_f25 = u32(0xffd6)

const gdk_key_kp_0 = u32(0xffb0)
const gdk_key_kp_1 = u32(0xffb1)
const gdk_key_kp_2 = u32(0xffb2)
const gdk_key_kp_3 = u32(0xffb3)
const gdk_key_kp_4 = u32(0xffb4)
const gdk_key_kp_5 = u32(0xffb5)
const gdk_key_kp_6 = u32(0xffb6)
const gdk_key_kp_7 = u32(0xffb7)
const gdk_key_kp_8 = u32(0xffb8)
const gdk_key_kp_9 = u32(0xffb9)
const gdk_key_kp_decimal = u32(0xffae)
const gdk_key_kp_divide = u32(0xffaf)
const gdk_key_kp_multiply = u32(0xffaa)
const gdk_key_kp_subtract = u32(0xffad)
const gdk_key_kp_add = u32(0xffab)
const gdk_key_kp_enter = u32(0xff8d)
const gdk_key_kp_equal = u32(0xffbd)

const gdk_key_kp_separator = u32(0xffac)
const gdk_key_kp_left = u32(0xff96)
const gdk_key_kp_right = u32(0xff98)
const gdk_key_kp_up = u32(0xff97)
const gdk_key_kp_down = u32(0xff99)
const gdk_key_kp_page_up = u32(0xff9a)
const gdk_key_kp_page_down = u32(0xff9b)
const gdk_key_kp_home = u32(0xff95)
const gdk_key_kp_end = u32(0xff9c)
const gdk_key_kp_insert = u32(0xff9e)
const gdk_key_kp_delete = u32(0xff9f)
const gdk_key_kp_begin = u32(0xff9d)

const gdk_key_copy = u32(0x1008ff57)
const gdk_key_cut = u32(0x1008ff58)
const gdk_key_paste = u32(0x1008ff6d)

const gdk_key_shift_l = u32(0xffe1)
const gdk_key_control_l = u32(0xffe3)
const gdk_key_alt_l = u32(0xffe9)
const gdk_key_super_l = u32(0xffeb)
const gdk_key_shift_r = u32(0xffe2)
const gdk_key_control_r = u32(0xffe4)
const gdk_key_alt_r = u32(0xffea)
const gdk_key_super_r = u32(0xffec)

// --- Keymap ---------------------------------------------------------------

// KeymapEntry is a single (GDK keyval, input.Key) mapping.
// Mirrors the Zig `RawEntry` tuple.
struct KeymapEntry {
	keyval u32
	key    input.Key
}

// keymap contains the mappings between GDK keyvals and our own key enum.
// Faithful port of the `keymap` table in key.zig.
const keymap = [
	KeymapEntry{gdk_key_a, .key_a},
	KeymapEntry{gdk_key_b, .key_b},
	KeymapEntry{gdk_key_c, .key_c},
	KeymapEntry{gdk_key_d, .key_d},
	KeymapEntry{gdk_key_e, .key_e},
	KeymapEntry{gdk_key_f, .key_f},
	KeymapEntry{gdk_key_g, .key_g},
	KeymapEntry{gdk_key_h, .key_h},
	KeymapEntry{gdk_key_i, .key_i},
	KeymapEntry{gdk_key_j, .key_j},
	KeymapEntry{gdk_key_k, .key_k},
	KeymapEntry{gdk_key_l, .key_l},
	KeymapEntry{gdk_key_m, .key_m},
	KeymapEntry{gdk_key_n, .key_n},
	KeymapEntry{gdk_key_o, .key_o},
	KeymapEntry{gdk_key_p, .key_p},
	KeymapEntry{gdk_key_q, .key_q},
	KeymapEntry{gdk_key_r, .key_r},
	KeymapEntry{gdk_key_s, .key_s},
	KeymapEntry{gdk_key_t, .key_t},
	KeymapEntry{gdk_key_u, .key_u},
	KeymapEntry{gdk_key_v, .key_v},
	KeymapEntry{gdk_key_w, .key_w},
	KeymapEntry{gdk_key_x, .key_x},
	KeymapEntry{gdk_key_y, .key_y},
	KeymapEntry{gdk_key_z, .key_z},
	KeymapEntry{gdk_key_0, .digit_0},
	KeymapEntry{gdk_key_1, .digit_1},
	KeymapEntry{gdk_key_2, .digit_2},
	KeymapEntry{gdk_key_3, .digit_3},
	KeymapEntry{gdk_key_4, .digit_4},
	KeymapEntry{gdk_key_5, .digit_5},
	KeymapEntry{gdk_key_6, .digit_6},
	KeymapEntry{gdk_key_7, .digit_7},
	KeymapEntry{gdk_key_8, .digit_8},
	KeymapEntry{gdk_key_9, .digit_9},
	KeymapEntry{gdk_key_semicolon, .semicolon},
	KeymapEntry{gdk_key_space, .space},
	KeymapEntry{gdk_key_apostrophe, .quote},
	KeymapEntry{gdk_key_comma, .comma},
	KeymapEntry{gdk_key_grave, .backquote},
	KeymapEntry{gdk_key_period, .period},
	KeymapEntry{gdk_key_slash, .slash},
	KeymapEntry{gdk_key_minus, .minus},
	KeymapEntry{gdk_key_equal, .equal},
	KeymapEntry{gdk_key_bracketleft, .bracket_left},
	KeymapEntry{gdk_key_bracketright, .bracket_right},
	KeymapEntry{gdk_key_backslash, .backslash},
	KeymapEntry{gdk_key_up, .arrow_up},
	KeymapEntry{gdk_key_down, .arrow_down},
	KeymapEntry{gdk_key_right, .arrow_right},
	KeymapEntry{gdk_key_left, .arrow_left},
	KeymapEntry{gdk_key_home, .home},
	KeymapEntry{gdk_key_end, .end},
	KeymapEntry{gdk_key_insert, .insert},
	KeymapEntry{gdk_key_delete, .delete},
	KeymapEntry{gdk_key_caps_lock, .caps_lock},
	KeymapEntry{gdk_key_scroll_lock, .scroll_lock},
	KeymapEntry{gdk_key_num_lock, .num_lock},
	KeymapEntry{gdk_key_page_up, .page_up},
	KeymapEntry{gdk_key_page_down, .page_down},
	KeymapEntry{gdk_key_escape, .escape},
	KeymapEntry{gdk_key_return, .enter},
	KeymapEntry{gdk_key_tab, .tab},
	KeymapEntry{gdk_key_backspace, .backspace},
	KeymapEntry{gdk_key_print, .print_screen},
	KeymapEntry{gdk_key_pause, .pause},
	KeymapEntry{gdk_key_f1, .f1},
	KeymapEntry{gdk_key_f2, .f2},
	KeymapEntry{gdk_key_f3, .f3},
	KeymapEntry{gdk_key_f4, .f4},
	KeymapEntry{gdk_key_f5, .f5},
	KeymapEntry{gdk_key_f6, .f6},
	KeymapEntry{gdk_key_f7, .f7},
	KeymapEntry{gdk_key_f8, .f8},
	KeymapEntry{gdk_key_f9, .f9},
	KeymapEntry{gdk_key_f10, .f10},
	KeymapEntry{gdk_key_f11, .f11},
	KeymapEntry{gdk_key_f12, .f12},
	KeymapEntry{gdk_key_f13, .f13},
	KeymapEntry{gdk_key_f14, .f14},
	KeymapEntry{gdk_key_f15, .f15},
	KeymapEntry{gdk_key_f16, .f16},
	KeymapEntry{gdk_key_f17, .f17},
	KeymapEntry{gdk_key_f18, .f18},
	KeymapEntry{gdk_key_f19, .f19},
	KeymapEntry{gdk_key_f20, .f20},
	KeymapEntry{gdk_key_f21, .f21},
	KeymapEntry{gdk_key_f22, .f22},
	KeymapEntry{gdk_key_f23, .f23},
	KeymapEntry{gdk_key_f24, .f24},
	KeymapEntry{gdk_key_f25, .f25},
	KeymapEntry{gdk_key_kp_0, .numpad_0},
	KeymapEntry{gdk_key_kp_1, .numpad_1},
	KeymapEntry{gdk_key_kp_2, .numpad_2},
	KeymapEntry{gdk_key_kp_3, .numpad_3},
	KeymapEntry{gdk_key_kp_4, .numpad_4},
	KeymapEntry{gdk_key_kp_5, .numpad_5},
	KeymapEntry{gdk_key_kp_6, .numpad_6},
	KeymapEntry{gdk_key_kp_7, .numpad_7},
	KeymapEntry{gdk_key_kp_8, .numpad_8},
	KeymapEntry{gdk_key_kp_9, .numpad_9},
	KeymapEntry{gdk_key_kp_decimal, .numpad_decimal},
	KeymapEntry{gdk_key_kp_divide, .numpad_divide},
	KeymapEntry{gdk_key_kp_multiply, .numpad_multiply},
	KeymapEntry{gdk_key_kp_subtract, .numpad_subtract},
	KeymapEntry{gdk_key_kp_add, .numpad_add},
	KeymapEntry{gdk_key_kp_enter, .numpad_enter},
	KeymapEntry{gdk_key_kp_equal, .numpad_equal},
	KeymapEntry{gdk_key_kp_separator, .numpad_separator},
	KeymapEntry{gdk_key_kp_left, .numpad_left},
	KeymapEntry{gdk_key_kp_right, .numpad_right},
	KeymapEntry{gdk_key_kp_up, .numpad_up},
	KeymapEntry{gdk_key_kp_down, .numpad_down},
	KeymapEntry{gdk_key_kp_page_up, .numpad_page_up},
	KeymapEntry{gdk_key_kp_page_down, .numpad_page_down},
	KeymapEntry{gdk_key_kp_home, .numpad_home},
	KeymapEntry{gdk_key_kp_end, .numpad_end},
	KeymapEntry{gdk_key_kp_insert, .numpad_insert},
	KeymapEntry{gdk_key_kp_delete, .numpad_delete},
	KeymapEntry{gdk_key_kp_begin, .numpad_begin},
	KeymapEntry{gdk_key_copy, .copy},
	KeymapEntry{gdk_key_cut, .cut},
	KeymapEntry{gdk_key_paste, .paste},
	KeymapEntry{gdk_key_shift_l, .shift_left},
	KeymapEntry{gdk_key_control_l, .control_left},
	KeymapEntry{gdk_key_alt_l, .alt_left},
	KeymapEntry{gdk_key_super_l, .meta_left},
	KeymapEntry{gdk_key_shift_r, .shift_right},
	KeymapEntry{gdk_key_control_r, .control_right},
	KeymapEntry{gdk_key_alt_r, .alt_right},
	KeymapEntry{gdk_key_super_r, .meta_right},
	// TODO: media keys
]

// --- keyval <-> input.Key -------------------------------------------------

// key_from_keyval returns an input.Key from a GDK keyval, or none if we have
// no mapping. Mirrors `keyFromKeyval`.
pub fn key_from_keyval(keyval u32) ?input.Key {
	for entry in keymap {
		if entry.keyval == keyval {
			return entry.key
		}
	}
	return none
}

// keyval_from_key returns a GDK keyval from an input.Key, or none if we have
// no mapping. Mirrors `keyvalFromKey`.
pub fn keyval_from_key(key input.Key) ?u32 {
	for entry in keymap {
		if entry.key == key {
			return entry.keyval
		}
	}
	return none
}

// --- Trigger -> string ----------------------------------------------------

// accel_from_trigger returns a GTK accelerator string from a trigger (e.g.
// "<Shift><Ctrl>a"), or none if the trigger can't be represented.
// Mirrors `accelFromTrigger`.
pub fn accel_from_trigger(trigger input.Trigger) ?string {
	mut sb := ''

	// Modifiers
	if trigger.mods.shift() {
		sb += '<Shift>'
	}
	if trigger.mods.ctrl() {
		sb += '<Ctrl>'
	}
	if trigger.mods.alt() {
		sb += '<Alt>'
	}
	if trigger.mods.super_() {
		sb += '<Super>'
	}

	// Write our key
	keypart := write_trigger_key(trigger) or { return none }
	sb += keypart
	return sb
}

// xdg_shortcut_from_trigger returns an XDG-compliant shortcuts string from a
// trigger (e.g. "SHIFT+CTRL+a"), or none. Mirrors `xdgShortcutFromTrigger`.
//
// Spec: https://specifications.freedesktop.org/shortcuts-spec/latest/
pub fn xdg_shortcut_from_trigger(trigger input.Trigger) ?string {
	mut sb := ''

	// Modifiers
	if trigger.mods.shift() {
		sb += 'SHIFT+'
	}
	if trigger.mods.ctrl() {
		sb += 'CTRL+'
	}
	if trigger.mods.alt() {
		sb += 'ALT+'
	}
	if trigger.mods.super_() {
		sb += 'LOGO+'
	}

	// Write our key. While the spec expects libxkbcommon keysyms, GTK's
	// keysyms are identical to X11's keysyms which work here.
	keypart := write_trigger_key(trigger) or { return none }
	sb += keypart
	return sb
}

// write_trigger_key returns the key portion of a trigger as a GDK keyval name
// (or unicode char), or none if the trigger cannot be represented.
// Mirrors `writeTriggerKey`.
fn write_trigger_key(trigger input.Trigger) ?string {
	match trigger.key.typ {
		.physical {
			keyval := keyval_from_key(trigger.key.physical) or { return none }
			return keyval_name_string(keyval) or { return none }
		}
		.unicode {
			cp := trigger.key.unicode
			if name := keyval_name_string(cp) {
				return name
			}
			return utf32_to_string(cp)
		}
		.catch_all {
			return none
		}
	}
}

// --- Trigger -> human-readable label --------------------------------------

// label_from_trigger converts a trigger to a human-readable label for display
// in the UI (e.g. "Ctrl+Shift+A"), or none if it can't be formatted (e.g.
// catch_all). Mirrors `labelFromTrigger`.
pub fn label_from_trigger(trigger input.Trigger) ?string {
	mut sb := ''

	// Modifiers first, using human-readable format
	if trigger.mods.super_() {
		sb += 'Super+'
	}
	if trigger.mods.ctrl() {
		sb += 'Ctrl+'
	}
	if trigger.mods.alt() {
		sb += 'Alt+'
	}
	if trigger.mods.shift() {
		sb += 'Shift+'
	}

	keypart := write_trigger_key_label(trigger) or { return none }
	sb += keypart
	return sb
}

// write_trigger_key_label writes the key portion of a trigger in
// human-readable format (capitalizing the first letter). Mirrors
// `writeTriggerKeyLabel`.
fn write_trigger_key_label(trigger input.Trigger) ?string {
	match trigger.key.typ {
		.physical {
			keyval := keyval_from_key(trigger.key.physical) or { return none }
			name := keyval_name_string(keyval) or { return none }
			return capitalize_first(name)
		}
		.unicode {
			cp := trigger.key.unicode
			if name := keyval_name_string(cp) {
				return capitalize_first(name)
			}
			return utf32_to_string(cp)
		}
		.catch_all {
			return none
		}
	}
}

// capitalize_first capitalizes the first ASCII letter of a name, as done by
// the label formatting in key.zig.
fn capitalize_first(s string) string {
	if s.len == 0 {
		return s
	}
	c := s[0]
	if c >= `a` && c <= `z` {
		upper := u8(c - u8(`a`) + u8(`A`))
		return upper.ascii_str() + s[1..]
	}
	return s
}

// --- Modifiers ------------------------------------------------------------

// GDK ModifierType bit flags (from gdk/gdkenums.h). Only the bits used by
// `translate_mods` are declared.
const gdk_shift_mask = u32(1) << 0
const gdk_lock_mask = u32(1) << 1
const gdk_control_mask = u32(1) << 2
const gdk_alt_mask = u32(1) << 3
const gdk_super_mask = u32(1) << 26

// translate_mods converts a GDK ModifierType bitmask into input.Mods.
// Mirrors `translateMods`.
pub fn translate_mods(state u32) input.Mods {
	// Lock is dependent on X settings but we assume caps lock.
	return input.Mods.init((state & gdk_shift_mask) != 0, (state & gdk_control_mask) != 0, (state & gdk_alt_mask) != 0, (state & gdk_super_mask) != 0, (state & gdk_lock_mask) != 0, false, input.SideInfo{})
}

fn C.gdk_key_event_get_layout(event GdkEvent) u32

pub struct C.GdkKeymapKey {
pub mut:
	keycode u32
	group   int
	level   int
}

fn C.gdk_display_map_keycode(display GdkDisplay, keycode u32, keys &&C.GdkKeymapKey, keyvals &&u32, n_entries &int) bool

// keyval_unicode_unshifted finds the level-zero keyval for the event's active
// keyboard layout. This is used by the Kitty keyboard protocol.
pub fn keyval_unicode_unshifted(widget GtkWidget, event GdkEvent, keycode u32) u32 {
	display := widget_get_display(widget)
	if isnil(display) {
		return 0
	}
	layout := C.gdk_key_event_get_layout(event)
	mut keys := unsafe { &C.GdkKeymapKey(nil) }
	mut keyvals := unsafe { &u32(nil) }
	mut n_entries := 0
	if !C.gdk_display_map_keycode(display, keycode, &keys, &keyvals, &n_entries) {
		return 0
	}
	defer {
		g_free_mem(keys)
		g_free_mem(keyvals)
	}
	for i in 0 .. n_entries {
		key := unsafe { keys[i] }
		if key.group == int(layout) && key.level == 0 {
			return keyval_unicode(unsafe { keyvals[i] })
		}
	}
	return 0
}

// --- GDK keyval helpers (string wrappers) ---------------------------------

// keyval_name_string returns the GDK name for a keyval as a V string, or none
// if GDK has no name for it. Wraps `gdk_keyval_name`.
pub fn keyval_name_string(keyval u32) ?string {
	name := keyval_name(keyval)
	if isnil(name) {
		return none
	}
	return unsafe { cstring_to_vstring(name) }
}

// keyval_unicode returns the Unicode codepoint for a GDK keyval, or 0.
// Wraps `gdk_keyval_to_unicode`.
pub fn keyval_unicode(keyval u32) u32 {
	return keyval_to_unicode(keyval)
}

// utf32_to_string encodes a single codepoint as a UTF-8 V string, mirroring
// Zig's `{u}` format used as a fallback in the key.zig writers.
fn utf32_to_string(cp u32) string {
	return utf32_to_str(cp)
}
