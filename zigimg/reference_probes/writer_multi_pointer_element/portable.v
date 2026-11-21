module main

import zigimg as p

type MultiPointerWord = int
type MultiPointerAlias = &&MultiPointerWord
type MultiPointerElements = [2]MultiPointerAlias
type MultiPointerTarget = [2][3]u16
type MultiPointerArrayAlias = &&MultiPointerTarget
type MultiPointerArrayElements = [2]MultiPointerArrayAlias
type MultiPointerTripleElements = [2]&&&bool
type MultiPointerOptionalElements = [2]?&&u8

fn multi_pointer_view[E](_ E, raw uint, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_multi_pointer_element_names_do_not_read_chains_or_outer_storage() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	value := unsafe { &MultiPointerElements(voidptr(uint(0x1234))) }
	writer.print_address(value)!
	writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, value, ~uint(0))!
	writer.print_value('*', p.FormatOptions{}, unsafe { &MultiPointerTripleElements(nil) }, 0)!
	writer.print_address(unsafe { &MultiPointerArrayElements(voidptr(~uint(0))) })!
	assert writer.buffered().bytestr() == '[2]**i32@1234[2]**i32@1234[2]***bool@0[2]**[2][3]u16@ffffffffffffffff'
}

fn test_multi_pointer_slice_and_optional_element_names_preserve_original_storage() ! {
	zero := unsafe { MultiPointerElements{} }
	view := multi_pointer_view(zero, uint(0x1234), 3)
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(view)!
	writer.print_value('?*', p.FormatOptions{}, ?[]MultiPointerElements(view), 0)!
	writer.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?[]MultiPointerElements(none), 0)!
	writer.print_address(unsafe { &MultiPointerOptionalElements(voidptr(uint(1))) })!
	assert writer.buffered().bytestr() == '[2]**i32@1234[2]**i32@1234__null[2]?**u8@1'
	assert uint(view.data) == uint(0x1234) && view.len == 3
}

fn test_multi_pointer_name_failures_keep_prefix_digits_and_unused_bytes() ! {
	expected := '[2]**i32@1234'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_address(unsafe { &MultiPointerElements(voidptr(uint(0x1234))) }) or { status = err.msg() }
		end := if capacity < expected.len { capacity } else { expected.len }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..end]
		assert buffer[end..].all(it == 0xa5)
	}
}

fn test_multi_pointer_owned_elements_ignore_intermediate_and_target_mutation() ! {
	mut first := 1
	mut second := 2
	mut first_pointer := &first
	mut second_pointer := &second
	mut values := [unsafe { MultiPointerAlias(voidptr(&first_pointer)) },
		unsafe { MultiPointerAlias(voidptr(&second_pointer)) }]!
	address := unsafe { uint(voidptr(&values)) }
	before := unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(&values)!
	assert writer.buffered().bytestr() == '[2]**i32@${address:x}'
	assert unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))) } == before
	first = 9
	second = 10
	first_pointer = &second
	second_pointer = &first
	values.reverse_in_place()
	writer.seek_to(0)!
	writer.print_value('*', p.FormatOptions{}, &values, 0)!
	assert writer.buffered().bytestr() == '[2]**i32@${address:x}'
	assert first == 9 && second == 10 && first_pointer == &second && second_pointer == &first
}

fn main() {
	test_multi_pointer_element_names_do_not_read_chains_or_outer_storage() or { panic(err) }
	test_multi_pointer_slice_and_optional_element_names_preserve_original_storage() or { panic(err) }
	test_multi_pointer_name_failures_keep_prefix_digits_and_unused_bytes() or { panic(err) }
	test_multi_pointer_owned_elements_ignore_intermediate_and_target_mutation() or { panic(err) }
}
