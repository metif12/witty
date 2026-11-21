module main

import zigimg as p

type Bytes = [3]u8
type Views = []Bytes

struct Args {
	value []Bytes
}

struct MaybeArgs {
	value ?Views
}

struct Record {
	value int
}

fn borrowed[E](_ E, address uint, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn native_optional() ?[][3]u8 {
	zero := [3]u8{}
	return borrowed(zero, uint(0x1234), 0)
}

fn test_slice_array_addresses_ignore_options_and_keep_storage() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	values := [Bytes([u8(1), 2, 3]!), Bytes([u8(4), 5, 6]!)]
	address := uint(values.data)
	writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, values, 0)!
	assert writer.buffered().bytestr() == '[3]u8@${address:x}'
	writer.seek_to(0)!
	alias_values := Views(values)
	writer.print_value('*', p.FormatOptions{}, alias_values, ~uint(0))!
	assert writer.buffered().bytestr() == '[3]u8@${address:x}'
	assert uint(values.data) == address && values.len == 2 && values[1][2] == 6
}

fn test_slice_array_addresses_never_read_empty_or_synthetic_storage() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	zero := [u8(0), 0, 0]!
	nested := [[int(0), 0, 0]!, [int(0), 0, 0]!]!
	writer.print_value('*', p.FormatOptions{}, borrowed(zero, uint(0), 0), 0)!
	writer.print_value('*', p.FormatOptions{}, borrowed(nested, ~uint(0), 3), 0)!
	assert writer.buffered().bytestr() == '[3]u8@0[2][3]i32@ffffffffffffffff'
}

fn test_optional_slice_array_addresses_and_print_preserve_null_alignment() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	zero := Bytes{}
	view := borrowed(zero, uint(0x1234), 0)
	alias_view := Views(view)
	options := p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }
	writer.print_value('?*', options, ?[]Bytes(view), 0)!
	writer.print_value('?*', options, ?Views(alias_view), 0)!
	writer.print_value('?*', options, native_optional(), 0)!
	writer.print_value('?*', p.FormatOptions{ width: uint(8), alignment: .center, fill: `_` }, ?Views(none), 0)!
	writer.print('a{[value]*}b', Args{view})!
	writer.print('{[value]?*:_^8}', MaybeArgs{?Views(none)})!
	assert writer.buffered().bytestr() == '[3]u8@1234[3]u8@1234[3]u8@1234__null__a[3]u8@1234b__null__'
}

fn test_slice_array_address_partial_writes_preserve_prefix_and_digits() ! {
	expected := '[2][3]i32@1234'
	zero := [[int(0), 0, 0]!, [int(0), 0, 0]!]!
	view := borrowed(zero, uint(0x1234), 0)
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('*', p.FormatOptions{ width: ~uint(0) }, view, 0) or { status = err.msg() }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
}

fn test_slice_array_address_rejects_unsupported_elements_before_writes() ! {
	mut buffer := []u8{len: 128, init: 0xa5}
	before := buffer.clone()
	mut writer := p.WriteStream.init_memory(mut buffer)
	values := [[Record{7}]!]
	mut rejected := false
	writer.print_value('*', p.FormatOptions{}, values, 0) or {
		assert err.msg() == 'unsupported print_value array-pointer address element'
		rejected = true
	}
	assert rejected && writer.buffered().len == 0 && buffer == before
}

fn main() {
	test_slice_array_addresses_ignore_options_and_keep_storage() or { panic(err) }
	test_slice_array_addresses_never_read_empty_or_synthetic_storage() or { panic(err) }
	test_optional_slice_array_addresses_and_print_preserve_null_alignment() or { panic(err) }
	test_slice_array_address_partial_writes_preserve_prefix_and_digits() or { panic(err) }
	test_slice_array_address_rejects_unsupported_elements_before_writes() or { panic(err) }
}
