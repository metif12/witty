module main

import zigimg

type UnionCount = i64
type UnionChoice = UnionCount | []u8 | bool
type UnionAlias = UnionChoice
type UnionNested = UnionChoice | int

struct UnionRecord {
	choice UnionChoice
}

struct UnionProblem {
	name string
}

pub fn (e UnionProblem) msg() string {
	return e.name
}

pub fn (e UnionProblem) code() int {
	panic('code must not be called')
}

type UnionFailure = UnionProblem | int
type UnionCustom = bool | int

fn (value UnionCustom) format() string {
	return 'custom'
}

fn test_union_tags_payloads_and_aliases() ! {
	mut buffer := []u8{len: 512}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_value('', zigimg.FormatOptions{}, UnionChoice(UnionCount(-7)), 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', zigimg.FormatOptions{}, UnionAlias(UnionChoice(true)), 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', zigimg.FormatOptions{}, UnionChoice([u8(1), 255]), 2)!
	writer.write_byte(`|`)!
	writer.print_value('t', zigimg.FormatOptions{
		width:     usize(12)
		precision: ~usize(0)
		fill:      `_`
		alignment: .center
	}, UnionChoice(UnionCount(5)), 0)!
	assert writer.buffered().bytestr() == '.{ .UnionCount = -7 }|.{ .bool = true }|.{ .[]u8 = { 1, 255 } }|_UnionCount_'
}

fn test_union_depth_optional_and_recursive_containers() ! {
	value := UnionChoice([u8(1), 255])
	for depth, expected in ['.{ ... }', '.{ .[]u8 = { ... } }', '.{ .[]u8 = { 1, 255 } }'] {
		mut buffer := []u8{len: 512}
		mut writer := zigimg.WriteStream.init_memory(mut buffer)
		writer.print_value('any', zigimg.FormatOptions{}, value, usize(depth))!
		assert writer.buffered().bytestr() == expected
	}
	mut buffer := []u8{len: 512}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_value('any', zigimg.FormatOptions{}, UnionNested(value), 2)!
	writer.write_byte(`|`)!
	writer.print_value('any', zigimg.FormatOptions{}, [UnionChoice(true), value], 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', zigimg.FormatOptions{}, UnionRecord{value}, 1)!
	writer.write_byte(`|`)!
	optional := ?UnionChoice(UnionChoice(UnionCount(9)))
	writer.print_value('?any', zigimg.FormatOptions{}, optional, 1)!
	assert writer.buffered().bytestr() == '.{ .UnionChoice = .{ .[]u8 = { ... } } }|{ .{ ... }, .{ ... } }|.{ .choice = .{ ... } }|.{ .UnionCount = 9 }'
}

fn test_union_partial_writes_and_error_payloads() ! {
	expected := '.{ .UnionProblem = error.Alpha }'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('any', zigimg.FormatOptions{}, UnionFailure(UnionProblem{'Alpha'}), 1) or {
			status = err.msg()
		}
		assert status == if capacity < expected.len {
			'WriteFailed'
		} else {
			'ok'
		}
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
	// Keep fixed-array calls beside reflected error payloads to detect V's heap-lifting regression.
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_value('any', zigimg.FormatOptions{}, [u8(1), 255]!, 1)!
	writer.print_value('any', zigimg.FormatOptions{ width: usize(0), precision: usize(0) },
		UnionFailure(UnionProblem{'Alpha'}), 0)!
	assert writer.buffered().bytestr() == '{ 1, 255 }.{ ... }'
}

fn test_union_invalid_and_ambiguous_formats_preserve_writer_state() ! {
	for format in ['', '*', 'f', 's', 'd', 'x', '?', 'b64', 'bogus'] {
		mut buffer := []u8{len: 32, init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut buffer)
		writer.write_byte(`!`)!
		before := buffer.clone()
		mut status := 'ok'
		writer.print_value(format, zigimg.FormatOptions{ width: usize(0), precision: usize(0) },
			UnionCustom(true), 0) or { status = err.msg() }
		assert status == if format == '' {
			'ambiguous print_value union format'
		} else {
			'unsupported print_value union format'
		}
		assert buffer == before && writer.buffered() == [u8(`!`)]
	}
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_value('any', zigimg.FormatOptions{}, UnionCustom(true), 1)!
	writer.write_byte(`|`)!
	writer.print_value('t', zigimg.FormatOptions{}, UnionCustom(true), 0)!
	assert writer.buffered().bytestr() == '.{ .bool = true }|bool'
}

fn main() {
	test_union_tags_payloads_and_aliases()!
	test_union_depth_optional_and_recursive_containers()!
	test_union_partial_writes_and_error_payloads()!
	test_union_invalid_and_ambiguous_formats_preserve_writer_state()!
}
