module main

import zigimg as p

type OptionalAddressValues = []?int

struct OptionalSliceAddressArgs {
	value []?int
}

fn optional_slice_address_view[E](_ E, address uint, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_optional_scalar_slice_addresses_never_read_elements() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	view := optional_slice_address_view(?int(none), uint(0x1234), 0)
	writer.print_address(view)!
	writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, view, ~uint(0))!
	writer.print_address(optional_slice_address_view(?bool(none), ~uint(0), 3))!
	writer.print_address(optional_slice_address_view(?u8(none), uint(0), 0))!
	assert writer.buffered().bytestr() == '?i32@1234?i32@1234?bool@ffffffffffffffff?u8@0'
}

fn test_optional_scalar_slice_addresses_keep_storage_and_ignore_presence() ! {
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	mut values := [?int(7), ?int(none), ?int(-1)]
	address := uint(values.data)
	before := unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?int))).clone() }
	writer.print_address(values)!
	assert writer.buffered().bytestr() == '?i32@${address:x}'
	assert unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?int))) } == before
	writer.seek_to(0)!
	values[0] = none
	values[1] = 8
	writer.print_value('*', p.FormatOptions{}, values, 0)!
	assert writer.buffered().bytestr() == '?i32@${address:x}'
	assert uint(values.data) == address
	writer.seek_to(0)!
	writer.print_value('any', p.FormatOptions{}, values, 1)!
	assert writer.buffered().bytestr() == '{ null, 8, -1 }'
}

fn test_optional_scalar_slice_address_failures_preserve_write_boundaries() ! {
	expected := '?i32@1234'
	view := optional_slice_address_view(?int(none), uint(0x1234), 3)
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
				writer.print_value('?*', p.FormatOptions{ width: ~uint(0) }, ?OptionalAddressValues(view), 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_optional_scalar_slice_addresses_compose_with_print_and_outer_optionals() ! {
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	view := optional_slice_address_view(?int(none), uint(0x1234), 0)
	writer.print('a{[value]*}b', OptionalSliceAddressArgs{view})!
	writer.print_value('?*', p.FormatOptions{ width: ~uint(0) }, ?OptionalAddressValues(view), 0)!
	writer.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?OptionalAddressValues(none), 0)!
	assert writer.buffered().bytestr() == 'a?i32@1234b?i32@1234__null'
}

fn main() {
	test_optional_scalar_slice_addresses_never_read_elements() or { panic(err) }
	test_optional_scalar_slice_addresses_keep_storage_and_ignore_presence() or { panic(err) }
	test_optional_scalar_slice_address_failures_preserve_write_boundaries() or { panic(err) }
	test_optional_scalar_slice_addresses_compose_with_print_and_outer_optionals() or { panic(err) }
}
