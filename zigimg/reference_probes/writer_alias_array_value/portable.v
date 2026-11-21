module main

import zigimg as p

type ValueAliasByte = u8
type ValueAliasPointer = &ValueAliasByte
type ValueAliasArray = [2]&ValueAliasByte

struct AliasArrayValueArgs {
	value ValueAliasArray
}

fn alias_array_value_sample() ValueAliasArray {
	return [unsafe { &ValueAliasByte(voidptr(uint(0x1234))) },
		unsafe { &ValueAliasByte(voidptr(uint(0x5678))) }]!
}

fn test_alias_pointer_array_values_preserve_pointer_names_and_depth() ! {
	value := alias_array_value_sample()
	aliases := [ValueAliasPointer(value[0]), ValueAliasPointer(value[1])]!
	nested := [value, value]!
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_value('any', p.FormatOptions{}, value, 1)!
	writer.print_value('any', p.FormatOptions{}, aliases, 1)!
	writer.print_value('any', p.FormatOptions{}, &value, 1)!
	writer.print_value('any', p.FormatOptions{}, nested, 1)!
	writer.print_value('any', p.FormatOptions{}, value, 0)!
	assert writer.buffered().bytestr() == '{ u8@1234, u8@5678 }{ u8@1234, u8@5678 }{ u8@1234, u8@5678 }{ { ... }, { ... } }{ ... }'
}

fn test_alias_pointer_array_value_failures_keep_exact_prefix() ! {
	value := alias_array_value_sample()
	expected := '{ u8@1234__, u8@5678__ }'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('any', p.FormatOptions{ width: 6, alignment: .left, fill: `_`, precision: ~uint(0) }, value, 1) or { status = err.msg() }
		end := if capacity < expected.len { capacity } else { expected.len }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..end]
		assert buffer[end..].all(it == 0xa5)
	}
}

fn test_alias_pointer_arrays_reject_byte_formats_before_writing() {
	value := alias_array_value_sample()
	for format in ['', 's', 'x', 'X', 'b64'] {
		mut buffer := []u8{len: 64, init: 0xa5}
		before := buffer.clone()
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value(format, p.FormatOptions{}, value, 0) or { status = err.msg() }
		assert status == 'unsupported print_value array format'
		assert writer.buffered().len == 0 && buffer == before
	}
}

fn test_alias_scalar_bytes_keep_the_existing_formats() ! {
	bytes := [ValueAliasByte(0), ValueAliasByte(255), ValueAliasByte(65)]!
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_value('x', p.FormatOptions{}, bytes, 0)!
	writer.print_value('b64', p.FormatOptions{}, bytes, 0)!
	writer.print_value('any', p.FormatOptions{}, bytes, 1)!
	assert writer.buffered().bytestr() == '00ff41AP9B{ 0, 255, 65 }'
}

fn test_alias_pointer_array_values_compose_with_print_and_preserve_storage() ! {
	mut first := ValueAliasByte(7)
	mut second := ValueAliasByte(8)
	mut value := [&first, &second]!
	before := unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print('L{[value]any}R', AliasArrayValueArgs{value})!
	assert writer.buffered().bytestr() == 'L{ u8@${uint(voidptr(&first)):x}, u8@${uint(voidptr(&second)):x} }R'
	assert unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))) } == before
	first = 9
	second = 10
	value.reverse_in_place()
	writer.seek_to(0)!
	writer.print_value('any', p.FormatOptions{}, value, 1)!
	assert writer.buffered().bytestr() == '{ u8@${uint(voidptr(&second)):x}, u8@${uint(voidptr(&first)):x} }'
}

fn main() {
	test_alias_pointer_array_values_preserve_pointer_names_and_depth() or { panic(err) }
	test_alias_pointer_array_value_failures_keep_exact_prefix() or { panic(err) }
	test_alias_pointer_arrays_reject_byte_formats_before_writing()
	test_alias_scalar_bytes_keep_the_existing_formats() or { panic(err) }
	test_alias_pointer_array_values_compose_with_print_and_preserve_storage() or { panic(err) }
}
