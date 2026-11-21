module main

import zigimg as p

type OptionalPointerByte = &u8
type OptionalPointerValues = []?OptionalPointerByte
type OptionalPointerArray = [2]?&u8

struct OptionalPointerAddressArgs {
	value []?&u8
}

fn optional_pointer_address_view[E](_ E, address uint, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_optional_pointer_addresses_do_not_read_elements_or_targets() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	zero := ?&u8(none)
	view := optional_pointer_address_view(zero, uint(0x1234), 3)
	writer.print_address(view)!
	writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, view, ~uint(0))!
	writer.print_value('*', p.FormatOptions{}, optional_pointer_address_view(?&int(none), ~uint(0), 0), 0)!
	writer.print_value('*', p.FormatOptions{}, optional_pointer_address_view(?voidptr(none), uint(0), 3), 0)!
	array_pointer := unsafe { &OptionalPointerArray(voidptr(uint(0x1234))) }
	writer.print_address(array_pointer)!
	writer.print_value('*', p.FormatOptions{}, array_pointer, 0)!
	assert writer.buffered().bytestr() == '?*u8@1234?*u8@1234?*i32@ffffffffffffffff?*anyopaque@0[2]?*u8@1234[2]?*u8@1234'
}

fn test_optional_pointer_addresses_preserve_owned_storage() ! {
	mut first := u8(7)
	mut second := u8(8)
	some := ?&u8(&first)
	absent := ?&u8(none)
	other := ?&u8(&second)
	mut values := [some, absent, other]
	address := uint(values.data)
	before := unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?&u8))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(values)!
	assert writer.buffered().bytestr() == '?*u8@${address:x}'
	assert unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?&u8))) } == before
	first = 9
	second = 10
	values.reverse_in_place()
	writer.seek_to(0)!
	writer.print_value('*', p.FormatOptions{}, values, 0)!
	assert writer.buffered().bytestr() == '?*u8@${address:x}'
	assert uint(values.data) == address
	last := values[0] or { panic('missing pointer') }
	assert last == &second
	assert values[1] == none
	initial := values[2] or { panic('missing pointer') }
	assert initial == &first
}

fn test_optional_pointer_address_partial_writes_preserve_prefix_and_digits() ! {
	view := optional_pointer_address_view(?&u8(none), uint(0x1234), 0)
	array_pointer := unsafe { &OptionalPointerArray(voidptr(uint(0x1234))) }
	for api in 0 .. 5 {
		expected := if api < 3 { '?*u8@1234' } else { '[2]?*u8@1234' }
		for capacity in 0 .. expected.len + 2 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 { writer.print_address(view) or { status = err.msg() } }
			if api == 1 {
				writer.print_value('*', p.FormatOptions{}, view, 0) or { status = err.msg() }
			}
			if api == 2 {
				alias_view := OptionalPointerValues(view)
				writer.print_value('?*', p.FormatOptions{ width: ~uint(0) }, ?OptionalPointerValues(alias_view), 0) or { status = err.msg() }
			}
			if api == 3 { writer.print_address(array_pointer) or { status = err.msg() } }
			if api == 4 {
				writer.print_value('*', p.FormatOptions{}, array_pointer, 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_optional_pointer_addresses_compose_with_print_aliases_and_optionals() ! {
	view := optional_pointer_address_view(?&u8(none), uint(0x1234), 0)
	alias_view := OptionalPointerValues(view)
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print('L{[value]*}R', OptionalPointerAddressArgs{view})!
	writer.print_value('*', p.FormatOptions{}, alias_view, 0)!
	writer.print_value('?*', p.FormatOptions{ width: ~uint(0) }, ?OptionalPointerValues(alias_view), 0)!
	writer.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?OptionalPointerValues(none), 0)!
	assert writer.buffered().bytestr() == 'L?*u8@1234R?*u8@1234?*u8@1234__null'
}

fn main() {
	test_optional_pointer_addresses_do_not_read_elements_or_targets() or { panic(err) }
	test_optional_pointer_addresses_preserve_owned_storage() or { panic(err) }
	test_optional_pointer_address_partial_writes_preserve_prefix_and_digits() or { panic(err) }
	test_optional_pointer_addresses_compose_with_print_aliases_and_optionals() or { panic(err) }
}
