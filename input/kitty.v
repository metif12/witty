module input

// Entry represents a mapping from a physical key to its Kitty protocol encoding.
// This is used during Kitty keyboard protocol encoding to find the appropriate
// key code and final byte for a given key.
// Based on the Kitty keyboard protocol specification and Foot's kitty-keymap.h.
pub struct KittyEntry {
pub:
	// The physical key this entry maps.
	key Key
	// The Kitty protocol key code.
	code u32
	// The final byte of the CSI sequence ('u', '~', or a letter for special keys).
	final_byte u8
	// True if this key is a modifier key (shift, ctrl, alt, etc).
	modifier bool
}

// kitty_entries maps physical keys to their Kitty protocol codes.
const kitty_entries = [
	// Standard keys
	KittyEntry{ key: .escape, code: 27, final_byte: `u`, modifier: false },
	KittyEntry{ key: .enter, code: 13, final_byte: `u`, modifier: false },
	KittyEntry{ key: .tab, code: 9, final_byte: `u`, modifier: false },
	KittyEntry{ key: .backspace, code: 127, final_byte: `u`, modifier: false },
	// Control pad
	KittyEntry{ key: .insert, code: 2, final_byte: `~`, modifier: false },
	KittyEntry{ key: .delete, code: 3, final_byte: `~`, modifier: false },
	// Arrow keys
	KittyEntry{ key: .arrow_left, code: 1, final_byte: `D`, modifier: false },
	KittyEntry{ key: .arrow_right, code: 1, final_byte: `C`, modifier: false },
	KittyEntry{ key: .arrow_up, code: 1, final_byte: `A`, modifier: false },
	KittyEntry{ key: .arrow_down, code: 1, final_byte: `B`, modifier: false },
	// Page keys
	KittyEntry{ key: .page_up, code: 5, final_byte: `~`, modifier: false },
	KittyEntry{ key: .page_down, code: 6, final_byte: `~`, modifier: false },
	KittyEntry{ key: .home, code: 1, final_byte: `H`, modifier: false },
	KittyEntry{ key: .end, code: 1, final_byte: `F`, modifier: false },
	// Lock/special keys
	KittyEntry{ key: .caps_lock, code: 57358, final_byte: `u`, modifier: true },
	KittyEntry{ key: .scroll_lock, code: 57359, final_byte: `u`, modifier: false },
	KittyEntry{ key: .num_lock, code: 57360, final_byte: `u`, modifier: true },
	KittyEntry{ key: .print_screen, code: 57361, final_byte: `u`, modifier: false },
	KittyEntry{ key: .pause, code: 57362, final_byte: `u`, modifier: false },
	// Function keys F1-F12
	KittyEntry{ key: .f1, code: 1, final_byte: `P`, modifier: false },
	KittyEntry{ key: .f2, code: 1, final_byte: `Q`, modifier: false },
	KittyEntry{ key: .f3, code: 13, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f4, code: 1, final_byte: `S`, modifier: false },
	KittyEntry{ key: .f5, code: 15, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f6, code: 17, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f7, code: 18, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f8, code: 19, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f9, code: 20, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f10, code: 21, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f11, code: 23, final_byte: `~`, modifier: false },
	KittyEntry{ key: .f12, code: 24, final_byte: `~`, modifier: false },
	// Function keys F13-F25
	KittyEntry{ key: .f13, code: 57376, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f14, code: 57377, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f15, code: 57378, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f16, code: 57379, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f17, code: 57380, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f18, code: 57381, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f19, code: 57382, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f20, code: 57383, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f21, code: 57384, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f22, code: 57385, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f23, code: 57386, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f24, code: 57387, final_byte: `u`, modifier: false },
	KittyEntry{ key: .f25, code: 57388, final_byte: `u`, modifier: false },
	// Numpad keys
	KittyEntry{ key: .numpad_0, code: 57399, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_1, code: 57400, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_2, code: 57401, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_3, code: 57402, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_4, code: 57403, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_5, code: 57404, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_6, code: 57405, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_7, code: 57406, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_8, code: 57407, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_9, code: 57408, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_decimal, code: 57409, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_divide, code: 57410, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_multiply, code: 57411, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_subtract, code: 57412, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_add, code: 57413, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_enter, code: 57414, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_equal, code: 57415, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_separator, code: 57416, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_left, code: 57417, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_right, code: 57418, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_up, code: 57419, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_down, code: 57420, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_page_up, code: 57421, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_page_down, code: 57422, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_home, code: 57423, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_end, code: 57424, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_insert, code: 57425, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_delete, code: 57426, final_byte: `u`, modifier: false },
	KittyEntry{ key: .numpad_begin, code: 57427, final_byte: `u`, modifier: false },
	// Modifier keys
	KittyEntry{ key: .shift_left, code: 57441, final_byte: `u`, modifier: true },
	KittyEntry{ key: .shift_right, code: 57447, final_byte: `u`, modifier: true },
	KittyEntry{ key: .control_left, code: 57442, final_byte: `u`, modifier: true },
	KittyEntry{ key: .control_right, code: 57448, final_byte: `u`, modifier: true },
	KittyEntry{ key: .meta_left, code: 57444, final_byte: `u`, modifier: true },
	KittyEntry{ key: .meta_right, code: 57450, final_byte: `u`, modifier: true },
	KittyEntry{ key: .alt_left, code: 57443, final_byte: `u`, modifier: true },
	KittyEntry{ key: .alt_right, code: 57449, final_byte: `u`, modifier: true },
]
