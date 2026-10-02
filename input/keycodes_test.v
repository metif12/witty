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

fn test_windows_keycode_column_and_exported_entry_metadata() {
	assert windows_keycode_to_key(0x001e) == .key_a
	assert windows_keycode_to_key(0x002e) == .key_c
	assert windows_keycode_to_key(0xe048) == .arrow_up
	assert windows_keycode_to_key(0xe05b) == .meta_left
	assert windows_keycode_to_key(0) == .unidentified
	assert windows_keycode_to_key(0xffff) == .unidentified
	assert keycodes_entries.len == raw_keycodes_entries.len
	for i, entry in keycodes_entries {
		raw := raw_keycodes_entries[i]
		assert entry.key == raw.key
		assert entry.usb == raw.usb
		assert entry.code == raw.code
		$if windows { assert entry.native == raw.windows }
		$else $if linux || freebsd { assert entry.native == raw.xkb }
		$else { assert entry.native == raw.mac }
	}
}
