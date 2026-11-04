module main

import zigimg as p

struct PointerFormatter {
	value int
	stop  bool
}

pub fn (value PointerFormatter) format(mut writer p.WriteStream) ! {
	writer.write_all('custom:'.bytes())!
	if value.stop { return error_with_code('Stopped', 47) }
	writer.print_value('d', p.FormatOptions{}, value.value, 0)!
}

type PointerFormatterAlias = PointerFormatter
type FormatterPointer = &PointerFormatterAlias

enum PointerFormatterEnum {
	zero
	high
}

pub fn (value PointerFormatterEnum) format(mut writer p.WriteStream) ! {
	writer.write_all(value.str().bytes())!
}

type PointerFormatterSum = PointerFormatter | bool

pub fn (value PointerFormatterSum) format(mut writer p.WriteStream) ! {
	match value {
		PointerFormatter { writer.print_value('d', p.FormatOptions{}, value.value, 0)! }
		bool { writer.write_all(if value { 'true'.bytes() } else { 'false'.bytes() })! }
	}
}

struct PointerFormatArgs {
	value ?&PointerFormatter
}

fn test_optional_pointer_custom_calls_ignore_options_and_depth() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	options := p.FormatOptions{ width: ~usize(0), precision: ~usize(0), fill: 255 }
	value := PointerFormatter{7, false}
	aliasvalue := PointerFormatterAlias(value)
	ptr := FormatterPointer(&aliasvalue)
	writer.print_value('?f', options, ?&PointerFormatter(&value), 0)!
	writer.print_value('?f', options, ?&PointerFormatterAlias(&aliasvalue), 0)!
	writer.print_value('?f', options, ?FormatterPointer(ptr), 0)!
	choice := PointerFormatterEnum.high
	writer.print_value('?f', options, ?&PointerFormatterEnum(&choice), 0)!
	sum := PointerFormatterSum(true)
	writer.print_value('?f', options, ?&PointerFormatterSum(&sum), 0)!
	record_sum := PointerFormatterSum(PointerFormatter{8, false})
	writer.print_value('?f', options, ?&PointerFormatterSum(&record_sum), 0)!
	assert writer.buffered().bytestr() == 'custom:7custom:7custom:7hightrue8'
}

fn test_optional_pointer_custom_partial_writes_keep_method_failures() ! {
	value := PointerFormatter{-127, false}
	expected := 'custom:-127'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('?f', p.FormatOptions{}, ?&PointerFormatter(&value), 0) or { status = err.msg() }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
	mut buffer := []u8{len: 64}
	mut writer := p.WriteStream.init_memory(mut buffer)
	stopped := PointerFormatter{9, true}
	writer.print_value('?f', p.FormatOptions{}, ?&PointerFormatter(&stopped), 0) or {
		assert err.msg() == 'Stopped' && err.code() == 47
		assert writer.buffered().bytestr() == 'custom:'
		return
	}
	assert false
}

fn test_optional_pointer_custom_absence_and_print_composition() ! {
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_value('?f', p.FormatOptions{ width: usize(6), fill: `_` }, ?&PointerFormatter(none), 0)!
	value := PointerFormatter{3, false}
	writer.print('|{?f}', PointerFormatArgs{?&PointerFormatter(&value)})!
	writer.print_value('any', p.FormatOptions{}, [u8(1), 255]!, 1)!
	assert writer.buffered().bytestr() == '__null|custom:3{ 1, 255 }'
}

fn run() ! {
	test_optional_pointer_custom_calls_ignore_options_and_depth()!
	test_optional_pointer_custom_partial_writes_keep_method_failures()!
	test_optional_pointer_custom_absence_and_print_composition()!
}

fn main() { run() or { panic(err) } }
