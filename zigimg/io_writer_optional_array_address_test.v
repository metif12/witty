module zigimg

type OptionalAddressNumbers = [3]?int
type OptionalAddressNested = [2][3]?bool

struct OptionalAddressArgs {
	value []OptionalAddressNumbers
}

fn optional_address_borrowed[E](_ E, address uint, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_optional_array_elements_name_payload_without_reading_it() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('*', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, unsafe { &OptionalAddressNumbers(voidptr(uint(0x1234))) }, 0)!
	writer.print_address(unsafe { &OptionalAddressNested(voidptr(uint(0))) })!
	zero := OptionalAddressNumbers{}
	writer.print_value('*', FormatOptions{}, optional_address_borrowed(zero, ~uint(0), 0), ~uint(0))!
	writer.print_address(optional_address_borrowed(zero, uint(1), 3))!
	assert writer.buffered().bytestr() == '[3]?i32@1234[2][3]?bool@0[3]?i32@ffffffffffffffff[3]?i32@1'
}

fn test_optional_array_addresses_ignore_element_presence_and_keep_storage() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	mut values := [?int(7), ?int(none), ?int(-1)]!
	address := unsafe { uint(voidptr(&values)) }
	before := unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))).clone() }
	writer.print_address(&values)!
	assert writer.buffered().bytestr() == '[3]?i32@${address:x}'
	assert unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))) } == before
	writer.seek_to(0)!
	values[0] = none
	values[1] = 8
	writer.print_value('*', FormatOptions{}, &values, 0)!
	assert writer.buffered().bytestr() == '[3]?i32@${address:x}'
	writer.seek_to(0)!
	arrays := [[?int(7), ?int(none), ?int(-1)]!]
	writer.print_address(arrays)!
	assert writer.buffered().bytestr() == '[3]?i32@${uint(arrays.data):x}'
}

fn test_optional_array_addresses_preserve_prefix_and_digit_failures() ! {
	expected := '[3]?i32@1234'
	zero := OptionalAddressNumbers{}
	for capacity in 0 .. expected.len + 2 {
		for api in 0 .. 4 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 {
				writer.print_address(unsafe { &OptionalAddressNumbers(voidptr(uint(0x1234))) }) or { status = err.msg() }
			}
			if api == 1 {
				writer.print_value('*', FormatOptions{}, unsafe { &OptionalAddressNumbers(voidptr(uint(0x1234))) }, 0) or { status = err.msg() }
			}
			if api == 2 {
				writer.print_address(optional_address_borrowed(zero, uint(0x1234), 0)) or { status = err.msg() }
			}
			if api == 3 {
				writer.print_value('*', FormatOptions{}, optional_address_borrowed(zero, uint(0x1234), 0), 0) or { status = err.msg() }
			}
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
				capacity
			} else {
				expected.len
			}]
		}
	}
}

fn test_optional_array_slice_print_and_optional_outer_slice() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	zero := OptionalAddressNumbers{}
	view := optional_address_borrowed(zero, uint(0x1234), 0)
	writer.print('a{[value]*}b', OptionalAddressArgs{view})!
	writer.print_value('?*', FormatOptions{ width: ~uint(0) }, ?[]OptionalAddressNumbers(view), 0)!
	writer.print_value('?*', FormatOptions{ width: uint(6), fill: `_` }, ?[]OptionalAddressNumbers(none), 0)!
	assert writer.buffered().bytestr() == 'a[3]?i32@1234b[3]?i32@1234__null'
}
