module main

import zigimg

struct ValueFormatter {
	value int
	stop  bool
}

pub fn (value ValueFormatter) format(mut stream zigimg.WriteStream) ! {
	stream.write_all('custom:'.bytes())!
	if value.stop { return error_with_code('FormatterStopped', 47) }
	stream.print_value('d', zigimg.FormatOptions{}, value.value, 0)!
}

type ValueFormatterAlias = ValueFormatter
type ValueFormatterUnion = ValueFormatter | bool

pub fn (value ValueFormatterUnion) format(mut stream zigimg.WriteStream) ! {
	stream.write_all('union'.bytes())!
}

enum ValueFormatterEnum {
	alpha
	beta
}

pub fn (value ValueFormatterEnum) format(mut stream zigimg.WriteStream) ! {
	stream.write_all('enum'.bytes())!
}

fn test_value_custom_formats_ignore_options_and_depth() ! {
	options := zigimg.FormatOptions{ width: ~usize(0), precision: ~usize(0), fill: 255 }
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_value('f', options, ValueFormatter{-7, false}, 0)!
	writer.print_value('f', options, ValueFormatterAlias(ValueFormatter{8, false}), ~usize(0))!
	writer.print_value('f', options, ValueFormatterUnion(true), 0)!
	writer.print_value('f', options, ValueFormatterEnum.beta, 0)!
	writer.print_value('?f', options, ?ValueFormatter(ValueFormatter{9, false}), 0)!
	assert writer.buffered().bytestr() == 'custom:-7custom:8unionenumcustom:9'
}

fn test_value_custom_format_preserves_partial_writes_and_errors() ! {
	expected := 'custom:-127'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('f', zigimg.FormatOptions{}, ValueFormatter{-127, false}, 0) or {
			status = err.msg()
		}
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_value('f', zigimg.FormatOptions{}, ValueFormatter{9, true}, 0) or {
		assert err.msg() == 'FormatterStopped' && err.code() == 47
		assert writer.buffered().bytestr() == 'custom:'
		return
	}
	assert false
}

fn test_value_custom_format_bypass_and_absent_optional() ! {
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_value('any', zigimg.FormatOptions{}, ValueFormatter{7, true}, 1)!
	writer.print_value('any', zigimg.FormatOptions{}, ValueFormatterUnion(true), 0)!
	writer.print_value('t', zigimg.FormatOptions{}, ValueFormatterEnum.beta, 0)!
	writer.print_value('?f', zigimg.FormatOptions{ width: usize(6), fill: `_` }, ?ValueFormatter(none),
		0)!
	assert writer.buffered().bytestr() == '.{ .value = 7, .stop = true }.{ ... }beta__null'
	// Keep fixed arrays beside custom specializations to catch compiler heap-lifting regressions.
	writer.print_value('any', zigimg.FormatOptions{}, [u8(1), 255]!, 1)!
	assert writer.buffered().bytestr().ends_with('{ 1, 255 }')
}

fn test_value_custom_empty_format_remains_ambiguous() ! {
	mut buffer := []u8{len: 32, init: 0xa5}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.write_byte(`!`)!
	before := buffer.clone()
	writer.print_value('', zigimg.FormatOptions{}, ValueFormatter{}, 0) or {
		assert err.msg() == 'ambiguous print_value struct format'
		assert buffer == before && writer.buffered() == [u8(`!`)]
		return
	}
	assert false
}

fn main() {
	test_value_custom_formats_ignore_options_and_depth() or { panic(err) }
	test_value_custom_format_preserves_partial_writes_and_errors() or { panic(err) }
	test_value_custom_format_bypass_and_absent_optional() or { panic(err) }
	test_value_custom_empty_format_remains_ambiguous() or { panic(err) }
}
