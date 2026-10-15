module main

import zigimg

fn main() {
	mut bytes := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_address(unsafe { &u8(voidptr(0x1234)) }) or { panic(err) }
	writer.write_byte(`|`) or { panic(err) }
	optional := ?&int(none)
	writer.print_address(optional) or { panic(err) }
	assert writer.buffered().bytestr() == 'u8@1234|*i32@0'
}
