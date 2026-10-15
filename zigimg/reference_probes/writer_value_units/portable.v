module main

import zigimg

fn main() {
	mut bytes := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_value('D', zigimg.FormatOptions{}, i64(-1000), 0) or { panic(err) }
	writer.print_value('B', zigimg.FormatOptions{ precision: usize(2) }, u16(512), ~usize(0)) or {
		panic(err)
	}
	writer.print_value('Bi', zigimg.FormatOptions{ precision: usize(2) }, u64(1024), 1) or {
		panic(err)
	}
	assert writer.buffered().bytestr() == '-1us0.51kB1.00KiB'
}
