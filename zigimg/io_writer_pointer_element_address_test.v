module zigimg

type AddressElementPointer = &u8
type AddressPointerItems = [3]&u8
type AddressPointerAliases = [3]AddressElementPointer
type AddressPointerNested = [2][3]&int
type AddressOpaqueItems = [1]voidptr
type AddressPointerValues = []AddressPointerItems

struct PointerElementAddressArgs {
	value []AddressPointerItems
}

fn pointer_element_address_view[E](_ E, address usize, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_pointer_element_address_names_do_not_read_arrays_or_targets() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(unsafe { &AddressPointerItems(voidptr(usize(0x1234))) })!
	writer.print_value('*', FormatOptions{ width: ~usize(0), precision: ~usize(0) }, unsafe { &AddressPointerAliases(voidptr(usize(0))) }, ~usize(0))!
	zero := unsafe { AddressPointerNested{} }
	writer.print_value('*', FormatOptions{}, pointer_element_address_view(zero, ~usize(0), 3), 0)!
	writer.print_address(unsafe { &AddressOpaqueItems(voidptr(usize(1))) })!
	assert writer.buffered().bytestr() == '[3]*u8@1234[3]*u8@0[2][3]*i32@ffffffffffffffff[1]*anyopaque@1'
}

fn test_pointer_element_addresses_keep_storage_and_ignore_target_values() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	mut first := u8(7)
	mut second := u8(8)
	mut values := [&first, &second, &second]!
	address := unsafe { usize(voidptr(&values)) }
	before := unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))).clone() }
	writer.print_address(&values)!
	assert writer.buffered().bytestr() == '[3]*u8@${address:x}'
	assert unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))) } == before
	first = 9
	second = 10
	values.reverse_in_place()
	assert unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))) } != before
	writer.seek_to(0)!
	writer.print_value('*', FormatOptions{}, &values, 0)!
	assert writer.buffered().bytestr() == '[3]*u8@${address:x}'
	arrays := [values]
	writer.seek_to(0)!
	writer.print_value('*', FormatOptions{}, arrays, 0)!
	assert writer.buffered().bytestr() == '[3]*u8@${usize(arrays.data):x}'
}

fn test_pointer_element_address_failures_keep_prefix_and_digit_writes() ! {
	expected := '[3]*u8@1234'
	zero := unsafe { AddressPointerItems{} }
	for capacity in 0 .. expected.len + 2 {
		for api in 0 .. 4 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 {
				writer.print_address(unsafe { &AddressPointerItems(voidptr(usize(0x1234))) }) or { status = err.msg() }
			}
			if api == 1 {
				writer.print_value('*', FormatOptions{ width: ~usize(0) }, unsafe { &AddressPointerItems(voidptr(usize(0x1234))) }, 0) or { status = err.msg() }
			}
			if api == 2 {
				writer.print_address(pointer_element_address_view(zero, usize(0x1234), 0)) or { status = err.msg() }
			}
			if api == 3 {
				writer.print_value('*', FormatOptions{ width: ~usize(0) }, pointer_element_address_view(zero, usize(0x1234), 3), 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_pointer_element_addresses_compose_with_print_and_outer_optionals() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	zero := unsafe { AddressPointerItems{} }
	view := pointer_element_address_view(zero, usize(0x1234), 0)
	writer.print('L{[value]*}R', PointerElementAddressArgs{view})!
	writer.print_value('?*', FormatOptions{ width: ~usize(0) }, ?AddressPointerValues(view), 0)!
	writer.print_value('?*', FormatOptions{ width: 6, fill: `_` }, ?AddressPointerValues(none), 0)!
	assert writer.buffered().bytestr() == 'L[3]*u8@1234R[3]*u8@1234__null'
}
