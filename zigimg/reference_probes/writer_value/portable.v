module main

import zigimg

fn main() {
	mut data := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut data)
	writer.print_value('X', zigimg.FormatOptions{ width: uint(6), fill: `0` }, i16(42), 0) or {
		panic(err)
	}
	writer.print_value('any', zigimg.FormatOptions{}, true, 0) or { panic(err) }
	writer.print_value('any', zigimg.FormatOptions{}, [u8(1), 2], 1) or { panic(err) }
	assert writer.buffered().bytestr() == '000+2Atrue{ 1, 2 }'
}
