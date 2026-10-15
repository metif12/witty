module main

import zigimg

fn main() {
	mut bytes := []u8{len: 32}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_value('c', zigimg.FormatOptions{ width: usize(3), fill: `_` }, u8(255), 0) or {
		panic(err)
	}
	writer.print_value('u', zigimg.FormatOptions{ width: ~usize(0) }, u32(0x1f642), ~usize(0)) or {
		panic(err)
	}
	writer.print_value('u', zigimg.FormatOptions{}, u16(0xd800), 1) or { panic(err) }
	assert writer.buffered().hex() == '5f5ffff09f9982efbfbd'
}
