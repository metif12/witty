module main

import zigimg

fn main() {
	mut bytes := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_value('d', zigimg.FormatOptions{}, f32(1.5), 0) or { panic(err) }
	writer.print_value('E', zigimg.FormatOptions{}, f64(1.5), ~uint(0)) or { panic(err) }
	writer.print_value('X', zigimg.FormatOptions{}, f64(1.625), 1) or { panic(err) }
	assert writer.buffered().bytestr() == '1.51.5e00x1.Ap0'
}
