module zigimg

type ArrayPointee = [3]u8
type ArrayPointeePointer = &ArrayPointee
type ArrayPointeeElements = [2]ArrayPointeePointer
type ArrayPointeeNested = [2][3]u16
type ArrayPointeeNestedElements = [2]&ArrayPointeeNested

fn test_array_pointee_element_names_do_not_read_elements_or_targets() ! {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	value := unsafe { &ArrayPointeeElements(voidptr(usize(0x1234))) }
	writer.print_address(value)!
	writer.print_value('*', FormatOptions{ width: ~usize(0), precision: ~usize(0) }, value, ~usize(0))!
	writer.print_address(unsafe { &ArrayPointeeNestedElements(voidptr(usize(0))) })!
	assert writer.buffered().bytestr() == '[2]*[3]u8@1234[2]*[3]u8@1234[2]*[2][3]u16@0'
}

fn array_pointee_borrowed[E](_ E, raw usize, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_array_pointee_slice_names_preserve_storage_bits_and_optional_nulls() ! {
	zero := unsafe { ArrayPointeeElements{} }
	view := array_pointee_borrowed(zero, ~usize(0), 3)
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(view)!
	writer.print_value('?*', FormatOptions{}, ?[]ArrayPointeeElements(view), 0)!
	writer.print_value('?*', FormatOptions{ width: 6, fill: `_` }, ?[]ArrayPointeeElements(none), 0)!
	assert writer.buffered().bytestr() == '[2]*[3]u8@ffffffffffffffff[2]*[3]u8@ffffffffffffffff__null'
	assert usize(view.data) == ~usize(0) && view.len == 3
}

fn test_array_pointee_failures_keep_prefix_digits_and_unused_capacity() ! {
	expected := '[2]*[3]u8@1234'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_address(unsafe { &ArrayPointeeElements(voidptr(usize(0x1234))) }) or { status = err.msg() }
		end := if capacity < expected.len { capacity } else { expected.len }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..end]
		assert buffer[end..].all(it == 0xa5)
	}
}

fn test_array_pointee_owned_pointer_addresses_ignore_target_and_element_mutation() ! {
	mut first := [u8(1), 2, 3]!
	mut second := [u8(4), 5, 6]!
	mut values := [unsafe { ArrayPointeePointer(voidptr(&first)) },
		unsafe { ArrayPointeePointer(voidptr(&second)) }]!
	address := unsafe { usize(voidptr(&values)) }
	before := unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(&values)!
	assert writer.buffered().bytestr() == '[2]*[3]u8@${address:x}'
	assert unsafe { (&u8(voidptr(&values))).vbytes(int(sizeof(values))) } == before
	first[0] = 9
	second[1] = 10
	values.reverse_in_place()
	writer.seek_to(0)!
	writer.print_value('*', FormatOptions{}, &values, 0)!
	assert writer.buffered().bytestr() == '[2]*[3]u8@${address:x}'
	assert first == [u8(9), 2, 3]! && second == [u8(4), 10, 6]!
}
