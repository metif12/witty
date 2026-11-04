module main

import zigimg as p

struct PointedRecord {
	value int
}

type PointedRecordAlias = PointedRecord
type PointedRecordPointer = &PointedRecordAlias

enum PointedChoice {
	zero
	high
}

type PointedSum = PointedRecord | bool
type PointedOuter = PointedSum | u64

struct PointedNode {
	value int
mut:
	next ?&PointedNode
}

struct PointedCustom {
	value int
}

pub fn (value PointedCustom) format(mut stream p.WriteStream) ! {
	stream.print_value('d', p.FormatOptions{}, value.value, 0)!
}

fn test_aggregate_pointer_record_aliases_and_optionals_keep_pointee_depth() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	value := PointedRecord{7}
	alias_value := PointedRecordAlias(value)
	pointer := PointedRecordPointer(&alias_value)
	writer.print_value('any', p.FormatOptions{}, &value, 0)!
	writer.write_byte(`|`)!
	writer.print_value('', p.FormatOptions{}, pointer, 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', p.FormatOptions{}, ?PointedRecordPointer(pointer), 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', p.FormatOptions{ width: usize(6), fill: `_` }, ?&PointedRecord(none), 0)!
	assert writer.buffered().bytestr() == '.{ ... }|.{ .value = 7 }|.{ .value = 7 }|__null'
}

fn test_aggregate_pointer_enums_and_sums_preserve_active_tag() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	choice := PointedChoice.high
	writer.print_value('any', p.FormatOptions{}, &choice, 0)!
	writer.write_byte(`|`)!
	sum := PointedSum(true)
	writer.print_value('any', p.FormatOptions{}, &sum, 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', p.FormatOptions{}, ?&PointedSum(&sum), 1)!
	writer.write_byte(`|`)!
	outer := PointedOuter(sum)
	writer.print_value('any', p.FormatOptions{}, &outer, 2)!
	assert writer.buffered().bytestr() == '.high|.{ .bool = true }|.{ .bool = true }|.{ .PointedSum = .{ .bool = true } }'
}

fn test_aggregate_pointer_cycles_stop_at_record_depth() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	mut value := PointedNode{ value: 1 }
	value.next = &value
	writer.print_value('any', p.FormatOptions{}, &value, 2)!
	assert writer.buffered().bytestr() == '.{ .value = 1, .next = .{ .value = 1, .next = .{ ... } } }'
}

fn test_aggregate_pointer_partial_writes_keep_record_field_boundaries() ! {
	expected := '.{ .value = 7 }'
	value := PointedRecord{7}
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('any', p.FormatOptions{}, &value, 1) or { status = err.msg() }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
}

fn test_aggregate_pointer_custom_format_and_rejected_address_precede_depth() ! {
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	value := PointedCustom{9}
	writer.print_value('f', p.FormatOptions{ width: ~usize(0) }, &value, 0)!
	assert writer.buffered().bytestr() == '9'
	writer.seek_to(0)!
	writer.print_value('*', p.FormatOptions{}, ?&PointedCustom(&value), 0) or {
		assert err.msg() == 'unsupported print_value aggregate-pointer format'
		assert writer.buffered().len == 0
		return
	}
	assert false
}

fn run() ! {
	test_aggregate_pointer_record_aliases_and_optionals_keep_pointee_depth()!
	test_aggregate_pointer_enums_and_sums_preserve_active_tag()!
	test_aggregate_pointer_cycles_stop_at_record_depth()!
	test_aggregate_pointer_partial_writes_keep_record_field_boundaries()!
	test_aggregate_pointer_custom_format_and_rejected_address_precede_depth()!
}

fn main() { run() or { panic(err) } }
