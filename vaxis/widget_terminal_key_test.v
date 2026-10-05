module vaxis

import zigimg

fn test_terminal_key_encoding_preserves_legacy_decimal_and_release_rules() {
	mut bytes := []u8{len: 32}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	terminal_key_encode(mut writer, Key{ codepoint: u32(`j`), mods: Modifiers.from_int(6) }, true, KittyFlags.from_int(0))!
	assert writer.buffered() == [u8(0x1b), `1`, `0`]
	terminal_key_encode(mut writer, Key{ codepoint: f3, mods: Modifiers.from_int(0x80) }, true, KittyFlags.from_int(0))!
	assert writer.buffered() == [u8(0x1b), `1`, `0`, 0x1b, `O`, `R`]
	terminal_key_encode(mut writer, Key{ codepoint: u32(`a`), text: 'release' }, false, KittyFlags{})!
	assert writer.get_pos() == 6
	terminal_key_encode(mut writer, Key{ codepoint: left, mods: Modifiers.from_int(5) }, true, KittyFlags.from_int(0))!
	assert writer.buffered()[6..].bytestr() == '\x1b[1;6D'
}

fn test_terminal_key_generated_text_wins_and_write_failure_preserves_prefix() {
	mut bytes := []u8{len: 3}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	mut failed := false
	terminal_key_encode(mut writer, Key{ codepoint: u32(`a`), text: 'ab\x00cd', mods: Modifiers.from_int(7) }, true, KittyFlags.from_int(0)) or {
		failed = true
		assert err.msg() == 'WriteFailed'
	}
	assert failed && writer.buffered() == [u8(`a`), `b`, 0]
	mut empty := []u8{}
	mut empty_writer := zigimg.WriteStream.init_memory(mut empty)
	terminal_key_encode(mut empty_writer, Key{ codepoint: u32(`a`), text: '', mods: Modifiers.from_int(4) }, true, KittyFlags.from_int(0))!
	assert empty_writer.get_pos() == 0
}
