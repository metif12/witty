module cimgui

const test_font = $embed_file('@VMODROOT/font/res/JetBrainsMono-Regular.ttf').to_bytes()

fn test_pinned_version_and_context_setup() {
	if !available() {
		return
	}
	ctx := Context.create(test_font) or { panic(err) }
	defer {
		ctx.destroy()
	}

	assert version() == '1.92.5'
	assert ctx.config_flags() & (1 << 7) != 0
	assert ctx.config_flags() & (1 << 20) != 0

	ctx.set_size(752, 528)
	width, height := ctx.display_size()
	assert width == 752
	assert height == 528

	ctx.add_key(.key_a, true)
}

fn test_named_key_abi_values() {
	assert sizeof(Key) == sizeof(int)
	assert int(Key.tab) == 512
	assert int(Key.left_arrow) == 513
	assert int(Key.key_0) == 536
	assert int(Key.key_a) == 546
	assert int(Key.f1) == 572
	assert int(Key.apostrophe) == 596
	assert int(Key.keypad_0) == 612
	assert int(Key.keypad_equal) == 628
	assert sizeof(MouseButton) == sizeof(int)
	assert int(MouseButton.left) == 0
	assert int(MouseButton.right) == 1
	assert int(MouseButton.middle) == 2
}
