module zigimg

type ValueDuration = i64
type ValueByteSize = u64

fn test_value_units_dispatch_preserves_signed_duration_and_byte_size_thresholds() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('D', FormatOptions{ width: usize(8), fill: `_` }, ValueDuration(-1000), 0)!
	writer.write_byte(`|`)!
	writer.print_value('B', FormatOptions{ precision: usize(2) }, ValueByteSize(512), ~usize(0))!
	writer.write_byte(`|`)!
	writer.print_value('Bi', FormatOptions{ precision: usize(2) }, u16(1024), 1)!
	assert writer.buffered().bytestr() == '____-1us|0.51kB|1.00KiB'
}

fn test_value_units_zero_ignores_maximum_precision_before_alignment() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('B', FormatOptions{ precision: ~usize(0), width: usize(4), fill: `_` },
		u8(0), 0)!
	assert writer.buffered().bytestr() == '__0B'
}

fn test_value_units_signed_byte_size_is_unsupported_before_output() {
	mut bytes := []u8{len: 16}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.write_all('prefix'.bytes())!
	writer.print_value('B', FormatOptions{}, i64(1), 0) or {
		assert err.msg() == 'unsupported print_value integer format'
		assert writer.buffered().bytestr() == 'prefix'
		return
	}
	assert false
}
