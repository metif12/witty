module main

import zigimg as p

type SliceAddressScalar = int
type SliceAddressRow = []SliceAddressScalar
type SliceAddressOuter = []SliceAddressRow
type SliceAddressFixed = [2]SliceAddressRow
type SliceAddressNestedRow = []SliceAddressRow
type SliceAddressNestedOuter = []SliceAddressNestedRow
type SliceAddressOptionalOuter = []?SliceAddressRow

struct SliceElementAddressArgs {
	value SliceAddressOuter
}

fn slice_element_address_view[E](_ E, address uint, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_slice_element_addresses_do_not_read_inner_headers() ! {
	row := SliceAddressRow{}
	view := SliceAddressOuter(slice_element_address_view(row, uint(0x1234), 3))
	fixed := unsafe { &SliceAddressFixed(voidptr(uint(0))) }
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(view)!
	writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, view, ~uint(0))!
	writer.print_address(fixed)!
	writer.print_value('*', p.FormatOptions{}, fixed, 0)!
	assert writer.buffered().bytestr() == '[]i32@1234[]i32@1234[2][]i32@0[2][]i32@0'
}

fn test_slice_element_names_compose_with_nesting_and_optionals() ! {
	nested := SliceAddressNestedRow{}
	view := SliceAddressNestedOuter(slice_element_address_view(nested, ~uint(0), 0))
	optional := ?SliceAddressRow(none)
	optional_view := SliceAddressOptionalOuter(slice_element_address_view(optional, uint(0), 3))
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(view)!
	writer.print_value('*', p.FormatOptions{}, optional_view, 0)!
	assert writer.buffered().bytestr() == '[][]i32@ffffffffffffffff?[]i32@0'
}

fn test_slice_element_address_failures_preserve_exact_prefixes() ! {
	row := SliceAddressRow{}
	view := SliceAddressOuter(slice_element_address_view(row, uint(0x1234), 0))
	fixed := unsafe { &SliceAddressFixed(voidptr(uint(0x1234))) }
	for api in 0 .. 4 {
		expected := if api < 2 { '[]i32@1234' } else { '[2][]i32@1234' }
		for capacity in 0 .. expected.len + 2 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 { writer.print_address(view) or { status = err.msg() } }
			if api == 1 {
				writer.print_value('*', p.FormatOptions{}, view, 0) or { status = err.msg() }
			}
			if api == 2 { writer.print_address(fixed) or { status = err.msg() } }
			if api == 3 {
				writer.print_value('*', p.FormatOptions{}, fixed, 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_slice_element_addresses_keep_owned_headers_and_targets() ! {
	mut first := [SliceAddressScalar(7), 8]
	mut second := [SliceAddressScalar(9)]
	mut value := [SliceAddressRow(first), SliceAddressRow(second)]!
	address := unsafe { uint(voidptr(&value)) }
	before := unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(&value)!
	assert writer.buffered().bytestr() == '[2][]i32@${address:x}'
	assert unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))) } == before
	first[0] = 10
	second[0] = 11
	value.reverse_in_place()
	writer.seek_to(0)!
	writer.print_value('*', p.FormatOptions{}, &value, 0)!
	assert writer.buffered().bytestr() == '[2][]i32@${address:x}'
	assert unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))) } != before
}

fn test_slice_element_addresses_compose_with_print_and_outer_optionals() ! {
	row := SliceAddressRow{}
	view := SliceAddressOuter(slice_element_address_view(row, uint(0x1234), 3))
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print('L{[value]*}R', SliceElementAddressArgs{view})!
	writer.print_value('?*', p.FormatOptions{ width: ~uint(0) }, ?SliceAddressOuter(view), 0)!
	writer.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?SliceAddressOuter(none), 0)!
	assert writer.buffered().bytestr() == 'L[]i32@1234R[]i32@1234__null'
}

fn main() {
	test_slice_element_addresses_do_not_read_inner_headers() or { panic(err) }
	test_slice_element_names_compose_with_nesting_and_optionals() or { panic(err) }
	test_slice_element_address_failures_preserve_exact_prefixes() or { panic(err) }
	test_slice_element_addresses_keep_owned_headers_and_targets() or { panic(err) }
	test_slice_element_addresses_compose_with_print_and_outer_optionals() or { panic(err) }
}
