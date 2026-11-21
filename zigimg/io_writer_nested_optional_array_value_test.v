module zigimg

type NestedOptionalBoolItems = [3]?bool
type NestedOptionalBoolValues = []?NestedOptionalBoolItems
type NestedOptionalIntItems = [2][3]?int
type NestedOptionalByteItems = [3]?u8

struct NestedOptionalValueArgs {
	value []?NestedOptionalBoolItems
}

fn nested_optional_value_view[E](_ E, address uint, length int) []?E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(?E)) } }
}

fn test_nested_optional_array_addresses_compile_without_reading_elements() ! {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	zero := NestedOptionalBoolItems{}
	view := nested_optional_value_view(zero, uint(0x1234), 3)
	writer.print_value('*', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, view, 0)!
	writer.print_value('?*', FormatOptions{ width: ~uint(0) }, ?NestedOptionalBoolValues(view), ~uint(0))!
	writer.print_value('?*', FormatOptions{ width: 6, fill: `_` }, ?NestedOptionalBoolValues(none), 0)!
	assert writer.buffered().bytestr() == '?[3]?bool@1234?[3]?bool@1234__null'
}

fn test_nested_optional_array_values_preserve_depth_and_leaf_options() ! {
	payload := NestedOptionalBoolItems([?bool(true), ?bool(none), ?bool(false)]!)
	present := ?NestedOptionalBoolItems(payload)
	values := [present, ?NestedOptionalBoolItems(none)]
	for depth, expected in ['{ ... }', '{ { ... }, null }', '{ { true, null, false }, null }'] {
		mut buffer := []u8{len: 128}
		mut writer := WriteStream.init_memory(mut buffer)
		writer.print_value('any', FormatOptions{}, values, uint(depth))!
		assert writer.buffered().bytestr() == expected
	}
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{ width: 6, precision: ~uint(0), fill: `_` }, values, 2)!
	assert writer.buffered().bytestr() == '{ { __true, __null, _false }, __null }'
}

fn test_nested_optional_array_values_keep_numeric_bytes_and_nested_arrays() ! {
	row0 := [?int(-7), ?int(none), ?int(8)]!
	row1 := [?int(1), ?int(2), ?int(none)]!
	payload := NestedOptionalIntItems([row0, row1]!)
	present := ?NestedOptionalIntItems(payload)
	values := [present, ?NestedOptionalIntItems(none)]
	bytes := NestedOptionalByteItems([?u8(7), ?u8(none), ?u8(255)]!)
	byte_payload := ?NestedOptionalByteItems(bytes)
	byte_values := [byte_payload, ?NestedOptionalByteItems(none)]
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{}, values, 3)!
	writer.print_value('any', FormatOptions{}, byte_values, 2)!
	assert writer.buffered().bytestr() == '{ { { -7, null, 8 }, { 1, 2, null } }, null }{ { 7, null, 255 }, null }'
}

fn test_nested_optional_array_partial_writes_and_print_keep_caller_values() ! {
	payload := NestedOptionalBoolItems([?bool(true), ?bool(none), ?bool(false)]!)
	present := ?NestedOptionalBoolItems(payload)
	mut values := [present, ?NestedOptionalBoolItems(none)]
	address := uint(values.data)
	before := unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?NestedOptionalBoolItems))).clone() }
	expected := '{ { true, null, false }, null }'
	for capacity in 0 .. expected.len + 2 {
		for api in 0 .. 3 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 {
				writer.print_value('any', FormatOptions{}, values, 2) or { status = err.msg() }
			}
			if api == 1 {
				writer.print_value('?any', FormatOptions{}, ?NestedOptionalBoolValues(values), 2) or { status = err.msg() }
			}
			if api == 2 {
				writer.print('{[value]any}', NestedOptionalValueArgs{values}) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
			assert uint(values.data) == address
			assert unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?NestedOptionalBoolItems))) } == before
		}
	}
	values.reverse_in_place()
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{}, values, 2)!
	assert writer.buffered().bytestr() == '{ null, { true, null, false } }'
	assert uint(values.data) == address
}
