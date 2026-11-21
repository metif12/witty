module zigimg

struct ValueEmptyRecord {}

struct ValueRecord {
	number int
	active bool
	bytes  [2]u8
}

struct ValueNestedRecord {
	child ValueRecord
	items []ValueEmptyRecord
}

type ValueRecordAlias = ValueRecord

struct ValueCustomRecord {
	number int
}

fn (value ValueCustomRecord) format() string {
	return '${value.number}'
}

fn test_value_records_preserve_field_order_aliases_and_recursive_depth() {
	value := ValueRecord{-3, true, [u8(1), 255]!}
	for depth, expected in ['.{ ... }', '.{ .number = -3, .active = true, .bytes = { ... } }',
		'.{ .number = -3, .active = true, .bytes = { 1, 255 } }'] {
		mut buffer := []u8{len: 256}
		mut writer := WriteStream.init_memory(mut buffer)
		writer.print_value('', FormatOptions{}, ValueRecordAlias(value), uint(depth))!
		assert writer.buffered().bytestr() == expected
	}
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{}, ValueNestedRecord{value, [
		ValueEmptyRecord{},
	]}, 2)!
	assert writer.buffered().bytestr() == '.{ .child = .{ .number = -3, .active = true, .bytes = { ... } }, .items = { .{ ... } } }'
}

fn test_value_records_retain_partial_prefix_at_every_capacity() {
	expected := '.{ .number = -3, .active = true, .bytes = { 1, 255 } }'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('any', FormatOptions{}, ValueRecord{-3, true, [u8(1), 255]!}, 2) or {
			status = err.msg()
		}
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
		assert status == if capacity < expected.len {
			'WriteFailed'
		} else {
			'ok'
		}
	}
}

fn test_value_records_empty_cutoff_and_custom_format_bypass() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, ValueEmptyRecord{},
		1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, ValueRecord{},
		0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ValueCustomRecord{7}, 1)!
	assert writer.buffered().bytestr() == '.{ }|.{ ... }|.{ .number = 7 }'
}

fn test_value_record_invalid_and_ambiguous_formats_preserve_state() {
	mut buffer := []u8{len: 32, init: 0xa5}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.write_byte(`!`)!
	before := buffer.clone()
	for format in ['', '*', 'f', 'd', 's', 'D', 'B', 'Bi', 't'] {
		writer.print_value(format, FormatOptions{}, ValueCustomRecord{7}, 0) or {
			assert err.msg() == if format == '' {
				'ambiguous print_value struct format'
			} else {
				'unsupported print_value struct format'
			}
			assert buffer == before && writer.buffered() == [u8(`!`)]
			continue
		}
		assert false
	}
}
