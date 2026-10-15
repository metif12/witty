module main

import zigimg

fn main() {
	mut bytes := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_byte_size(~u64(0), .decimal, zigimg.FormatOptions{}) or { panic(err) }
	writer.write_byte(`|`) or { panic(err) }
	writer.print_byte_size(~u64(0), .binary, zigimg.FormatOptions{}) or { panic(err) }
	assert writer.buffered().bytestr() == '0.01844674407370955ZB|16EiB'
}
