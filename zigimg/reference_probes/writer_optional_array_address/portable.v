module main

import zigimg as p

type Numbers = [3]?int
type Nested = [2][3]?bool

struct Args {
	value []Numbers
}

fn borrowed[E](_ E, address usize, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_optional_array_elements_name_payload_without_reading_it() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_value('*', p.FormatOptions{ width: ~usize(0), precision: ~usize(0) }, unsafe { &Numbers(voidptr(usize(0x1234))) }, 0)!
	writer.print_address(unsafe { &Nested(voidptr(usize(0))) })!
	zero := Numbers{}
	writer.print_value('*', p.FormatOptions{}, borrowed(zero, ~usize(0), 0), ~usize(0))!
	writer.print_address(borrowed(zero, usize(1), 3))!
	assert writer.buffered().bytestr() == '[3]?i32@1234[2][3]?bool@0[3]?i32@ffffffffffffffff[3]?i32@1'
}

fn test_optional_array_addresses_ignore_element_presence_and_keep_storage() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	mut values := [?int(7), ?int(none), ?int(-1)]!
	address := unsafe { usize(voidptr(&values)) }
	before := unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))).clone() }
	writer.print_address(&values)!
	assert writer.buffered().bytestr() == '[3]?i32@${address:x}'
	assert unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))) } == before
	writer.seek_to(0)!
	values[0] = none
	values[1] = 8
	writer.print_value('*', p.FormatOptions{}, &values, 0)!
	assert writer.buffered().bytestr() == '[3]?i32@${address:x}'
	writer.seek_to(0)!
	arrays := [[?int(7), ?int(none), ?int(-1)]!]
	writer.print_address(arrays)!
	assert writer.buffered().bytestr() == '[3]?i32@${usize(arrays.data):x}'
}

fn test_optional_array_addresses_preserve_prefix_and_digit_failures() ! {
	expected := '[3]?i32@1234'
	zero := Numbers{}
	for capacity in 0 .. expected.len + 2 {
		for api in 0 .. 4 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 {
				writer.print_address(unsafe { &Numbers(voidptr(usize(0x1234))) }) or { status = err.msg() }
			}
			if api == 1 {
				writer.print_value('*', p.FormatOptions{}, unsafe { &Numbers(voidptr(usize(0x1234))) }, 0) or { status = err.msg() }
			}
			if api == 2 {
				writer.print_address(borrowed(zero, usize(0x1234), 0)) or { status = err.msg() }
			}
			if api == 3 {
				writer.print_value('*', p.FormatOptions{}, borrowed(zero, usize(0x1234), 0), 0) or { status = err.msg() }
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
	mut writer := p.WriteStream.init_memory(mut buffer)
	zero := Numbers{}
	view := borrowed(zero, usize(0x1234), 0)
	writer.print('a{[value]*}b', Args{view})!
	writer.print_value('?*', p.FormatOptions{ width: ~usize(0) }, ?[]Numbers(view), 0)!
	writer.print_value('?*', p.FormatOptions{ width: usize(6), fill: `_` }, ?[]Numbers(none), 0)!
	assert writer.buffered().bytestr() == 'a[3]?i32@1234b[3]?i32@1234__null'
}

fn main() {
	test_optional_array_elements_name_payload_without_reading_it() or { panic(err) }
	test_optional_array_addresses_ignore_element_presence_and_keep_storage() or { panic(err) }
	test_optional_array_addresses_preserve_prefix_and_digit_failures() or { panic(err) }
	test_optional_array_slice_print_and_optional_outer_slice() or { panic(err) }
}
