module input

fn test_xkb_keycode_to_key() {
	assert xkb_keycode_to_key(0x0026) == .key_a
	assert xkb_keycode_to_key(0x0036) == .key_c
	assert xkb_keycode_to_key(0x006f) == .arrow_up
	assert xkb_keycode_to_key(0x0085) == .meta_left
	assert xkb_keycode_to_key(0x008f) == .paste
	// Codes absent from Ghostty's pinned code_to_key table remain unidentified.
	assert xkb_keycode_to_key(0x00a6) == .unidentified
	assert xkb_keycode_to_key(0) == .unidentified
}

fn test_mac_keycode_to_key() {
	assert mac_keycode_to_key(0x0000) == .key_a
	assert mac_keycode_to_key(0x0008) == .key_c
	assert mac_keycode_to_key(0x007e) == .arrow_up
	assert mac_keycode_to_key(0x0037) == .meta_left
	assert mac_keycode_to_key(0x000a) == .unidentified
	assert mac_keycode_to_key(0xffff) == .unidentified
}
