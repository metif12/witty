module zigimg

type ValueOptionalInteger = i64
type ValueOptionalItems = []?int

struct ValueOptionalRecord {
	n     ?int
	bytes ?[]u8
}

fn test_value_optional_payloads_and_null_alignment() ! {
	mut buffer := []u8{len: 512}
	mut writer := WriteStream.init_memory(mut buffer)
	options := FormatOptions{
		width:     usize(6)
		fill:      `_`
		alignment: .center
	}
	writer.print_value('?X', options, ?ValueOptionalInteger(ValueOptionalInteger(42)), 0)!
	writer.write_byte(`|`)!
	writer.print_value('?X', options, ?ValueOptionalInteger(none), ~usize(0))!
	writer.write_byte(`|`)!
	writer.print_value('?s', FormatOptions{}, ?[]u8([u8(0), 255]), 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ?bool(true), 0)!
	writer.write_byte(`|`)!
	writer.print_value('?e', FormatOptions{ precision: usize(1) }, ?f32(1.25), 0)!
	assert writer.buffered() == [u8(95), `+`, `2`, `A`, 95, 95, `|`, 95, `n`, `u`, `l`, `l`, 95,
		`|`, 0, 255, `|`, `t`, `r`, `u`, `e`, `|`, `1`, `.`, `3`, `e`, `0`]
}

fn test_value_optional_recursive_depth_and_fields() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('?any', FormatOptions{}, ?ValueOptionalItems(ValueOptionalItems([
		?int(7),
		?int(none),
	])), 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ValueOptionalRecord{?int(-3), ?[]u8([
		u8(1),
		2,
	])}, 2)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ?ValueOptionalRecord(ValueOptionalRecord{}), 0)!
	assert writer.buffered().bytestr() == '{ 7, null }|.{ .n = -3, .bytes = { 1, 2 } }|.{ ... }'
}

fn test_value_optional_each_capacity_retains_prefix() ! {
	expected := '{ 7, null, -2 }'.bytes()
	for cap in 0 .. expected.len + 2 {
		mut buffer := []u8{len: cap, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('?any', FormatOptions{}, ?ValueOptionalItems(ValueOptionalItems([
			?int(7),
			?int(none),
			?int(-2),
		])), 1) or { status = err.msg() }
		assert status == if cap < expected.len {
			'WriteFailed'
		} else {
			'ok'
		}
		assert writer.buffered() == expected[..if cap < expected.len {
			cap
		} else {
			expected.len
		}]
	}
}

fn test_value_optional_invalid_format_has_no_effect() ! {
	for format in ['', 'd', 'bogus', '*'] {
		mut buffer := []u8{len: 16, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value(format, FormatOptions{}, ?int(none), 0) or { status = err.msg() }
		assert status == if format == '*' {
			'unsupported print_value pointer carrier'
		} else {
			'unsupported print_value optional format'
		}
		assert writer.buffered().len == 0
		assert buffer == []u8{len: 16, init: 0xa5}
	}
}

fn test_value_optional_distinct_array_specializations_and_pointer() ! {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{}, [?i64(-7), ?i64(none)], 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, [?u64(~u64(0)), ?u64(none)], 1)!
	writer.write_byte(`|`)!
	address := unsafe { &u32(usize(40)) }
	writer.print_value('?*', FormatOptions{}, ?&u32(address), 0)!
	writer.write_byte(`|`)!
	writer.print_value('*', FormatOptions{}, ?&u32(address), 0)!
	assert writer.buffered().bytestr() == '{ -7, null }|{ 18446744073709551615, null }|u32@28|*u32@28'
}

fn test_value_optional_byte_elements_use_recursive_array_format() ! {
	values := [?u8(7), ?u8(none), ?u8(255)]!
	expected := '{ 7, null, 255 }'.bytes()
	for cap in 0 .. expected.len + 2 {
		mut buffer := []u8{len: cap, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('any', FormatOptions{}, values, 1) or { status = err.msg() }
		assert status == if cap < expected.len {
			'WriteFailed'
		} else {
			'ok'
		}
		assert writer.buffered() == expected[..if cap < expected.len {
			cap
		} else {
			expected.len
		}]
	}
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{}, values[..], 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, values, 0)!
	assert writer.buffered().bytestr() == '{ 7, null, 255 }|{ ... }'
	writer.print_value('s', FormatOptions{}, values, 1) or {
		assert err.msg() == 'unsupported print_value array format'
		assert writer.buffered().bytestr() == '{ 7, null, 255 }|{ ... }'
		return
	}
	assert false
}
