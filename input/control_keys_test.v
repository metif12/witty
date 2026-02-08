module input

fn test_ctrl_v_encoding() {
	// Simulate Ctrl-v
	mut event := KeyEvent{
		action:              .press
		key:                 .key_v
		mods:                Mods{
			ctrl: true
		}
		utf8:                'v'
		unshifted_codepoint: u32(`v`)
	}

	opts := Options{
		// Defaults, ensure legacy mode
		kitty_flags: KittyFlags{}
	}

	println('Testing Ctrl-v encoding...')

	// Case 1: utf8 is 'v'
	res1 := encode(event, opts)
	println('Case 1: Ctrl-v (utf8="v") encoded as: "${res1}" (bytes: ${res1.bytes()})')
	// We expect standard control character \x16 (0x16)
	assert res1.bytes() == [u8(0x16)]

	// Case 2: utf8 is '\x16' (already control char)
	event.utf8 = '\x16'
	res2 := encode(event, opts)
	println('Case 2: Ctrl-v (utf8="\\x16") encoded as: "${res2}" (bytes: ${res2.bytes()})')
	assert res2.bytes() == [u8(0x16)]

	// Case 3: utf8 is empty (relying on key)
	event.utf8 = ''
	res3 := encode(event, opts)
	println('Case 3: Ctrl-v (utf8="") encoded as: "${res3}" (bytes: ${res3.bytes()})')
	assert res3.bytes() == [u8(0x16)]
}
