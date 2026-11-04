module zigimg

type PointeeByte = u8
type PointeeNumber = int
type PointeeFlag = bool
type PointeeElementPointer = &PointeeByte
type PointeePointerItems = [3]&PointeeByte
type PointeePointerAliases = [3]PointeeElementPointer
type PointeePointerNested = [2][3]&PointeeNumber
type PointeeOpaqueItems = [1]voidptr
type PointeePointerValues = []PointeePointerItems

struct PointeeAddressArgs {
	value []PointeePointerItems
}

fn pointee_address_view[E](_ E, address usize, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_pointee_address_names_do_not_read_arrays_or_targets() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(unsafe { &PointeePointerItems(voidptr(usize(0x1234))) })!
	writer.print_value('*', FormatOptions{ width: ~usize(0), precision: ~usize(0) }, unsafe { &PointeePointerAliases(voidptr(usize(0))) }, ~usize(0))!
	zero := unsafe { PointeePointerNested{} }
	writer.print_value('*', FormatOptions{}, pointee_address_view(zero, ~usize(0), 3), 0)!
	writer.print_address(unsafe { &PointeeOpaqueItems(voidptr(usize(1))) })!
	assert writer.buffered().bytestr() == '[3]*u8@1234[3]*u8@0[2][3]*i32@ffffffffffffffff[1]*anyopaque@1'
}

fn test_pointee_addresses_keep_storage_and_ignore_target_values() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	mut first := PointeeByte(7)
	mut second := PointeeByte(8)
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

fn test_pointee_address_failures_keep_prefix_and_digit_writes() ! {
	expected := '[3]*u8@1234'
	zero := unsafe { PointeePointerItems{} }
	for capacity in 0 .. expected.len + 2 {
		for api in 0 .. 4 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 {
				writer.print_address(unsafe { &PointeePointerItems(voidptr(usize(0x1234))) }) or { status = err.msg() }
			}
			if api == 1 {
				writer.print_value('*', FormatOptions{ width: ~usize(0) }, unsafe { &PointeePointerItems(voidptr(usize(0x1234))) }, 0) or { status = err.msg() }
			}
			if api == 2 {
				writer.print_address(pointee_address_view(zero, usize(0x1234), 0)) or { status = err.msg() }
			}
			if api == 3 {
				writer.print_value('*', FormatOptions{ width: ~usize(0) }, pointee_address_view(zero, usize(0x1234), 3), 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_pointee_addresses_compose_with_print_and_outer_optionals() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	zero := unsafe { PointeePointerItems{} }
	view := pointee_address_view(zero, usize(0x1234), 0)
	writer.print('L{[value]*}R', PointeeAddressArgs{view})!
	writer.print_value('?*', FormatOptions{ width: ~usize(0) }, ?PointeePointerValues(view), 0)!
	writer.print_value('?*', FormatOptions{ width: 6, fill: `_` }, ?PointeePointerValues(none), 0)!
	assert writer.buffered().bytestr() == 'L[3]*u8@1234R[3]*u8@1234__null'
}

fn test_pointee_address_slice_and_optional_names_preserve_original_addresses() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	zero := unsafe { &PointeeNumber(voidptr(0)) }
	view := pointee_address_view(zero, usize(0x1234), 3)
	writer.print_address(view)!
	writer.print_value('*', FormatOptions{ width: ~usize(0), precision: ~usize(0) }, view, ~usize(0))!
	optional_view := pointee_address_view(?&PointeeNumber(none), usize(0), 0)
	writer.print_address(optional_view)!
	writer.print_value('*', FormatOptions{}, optional_view, 0)!
	flag_view := pointee_address_view(unsafe { &PointeeFlag(voidptr(0)) }, ~usize(0), 0)
	writer.print_value('*', FormatOptions{}, flag_view, 0)!
	assert writer.buffered().bytestr() == '*i32@1234*i32@1234?*i32@0?*i32@0*bool@ffffffffffffffff'
}
