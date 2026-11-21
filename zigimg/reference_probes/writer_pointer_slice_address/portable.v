module main

import zigimg as p

type PointerSliceByte = &u8
type PointerSliceInt = &int
type PointerSliceValues = []PointerSliceByte

struct PointerSliceAddressArgs {
	value []&u8
}

fn pointer_slice_address_view[E](_ E, address uint, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_pointer_slice_addresses_do_not_read_elements_or_targets() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	byte_zero := unsafe { &u8(voidptr(0)) }
	int_zero := unsafe { PointerSliceInt(voidptr(0)) }
	view := pointer_slice_address_view(byte_zero, uint(0x1234), 3)
	writer.print_address(view)!
	writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, view, ~uint(0))!
	writer.print_value('*', p.FormatOptions{}, pointer_slice_address_view(int_zero, ~uint(0), 0), 0)!
	writer.print_value('*', p.FormatOptions{}, pointer_slice_address_view(unsafe { voidptr(0) }, uint(0), 3), 0)!
	assert writer.buffered().bytestr() == '*u8@1234*u8@1234*i32@ffffffffffffffff*anyopaque@0'
}

fn test_pointer_slice_addresses_keep_storage_and_ignore_contents() ! {
	mut first := u8(7)
	mut second := u8(8)
	mut values := [&first, &second, &second]
	address := uint(values.data)
	before := unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(&u8))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(values)!
	assert writer.buffered().bytestr() == '*u8@${address:x}'
	assert unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(&u8))) } == before
	first = 9
	second = 10
	values.reverse_in_place()
	assert unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(&u8))) } != before
	writer.seek_to(0)!
	writer.print_value('*', p.FormatOptions{}, values, 0)!
	assert writer.buffered().bytestr() == '*u8@${address:x}'
	assert uint(values.data) == address
}

fn test_pointer_slice_address_partial_writes_preserve_prefix_and_digits() ! {
	expected := '*u8@1234'
	zero := unsafe { &u8(voidptr(0)) }
	view := pointer_slice_address_view(zero, uint(0x1234), 0)
	alias_view := PointerSliceValues(view)
	for capacity in 0 .. expected.len + 2 {
		for api in 0 .. 3 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 { writer.print_address(view) or { status = err.msg() } }
			if api == 1 {
				writer.print_value('*', p.FormatOptions{ width: ~uint(0) }, view, 0) or { status = err.msg() }
			}
			if api == 2 {
				writer.print_value('?*', p.FormatOptions{ width: ~uint(0) }, ?PointerSliceValues(alias_view), 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_pointer_slice_addresses_compose_with_print_aliases_and_optionals() ! {
	zero := unsafe { &u8(voidptr(0)) }
	view := pointer_slice_address_view(zero, uint(0x1234), 0)
	alias_view := PointerSliceValues(view)
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print('L{[value]*}R', PointerSliceAddressArgs{view})!
	writer.print_value('*', p.FormatOptions{}, alias_view, 0)!
	writer.print_value('?*', p.FormatOptions{ width: ~uint(0) }, ?PointerSliceValues(alias_view), 0)!
	writer.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?PointerSliceValues(none), 0)!
	assert writer.buffered().bytestr() == 'L*u8@1234R*u8@1234*u8@1234__null'
}

fn main() {
	test_pointer_slice_addresses_do_not_read_elements_or_targets() or { panic(err) }
	test_pointer_slice_addresses_keep_storage_and_ignore_contents() or { panic(err) }
	test_pointer_slice_address_partial_writes_preserve_prefix_and_digits() or { panic(err) }
	test_pointer_slice_addresses_compose_with_print_aliases_and_optionals() or { panic(err) }
}
