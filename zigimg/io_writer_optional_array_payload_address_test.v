module zigimg

type AddressPayloadPair = [2]int
type AddressPayloadNested = [2][3]bool
type AddressPayloadOptionalItems = [3]?u8
type AddressPayloadValues = []?AddressPayloadPair

struct ArrayPayloadAddressArgs {
	value []?AddressPayloadPair
}

fn array_payload_address_view[E](_ E, address uint, length int) []?E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(?E)) } }
}

fn test_optional_array_payload_address_names_do_not_read_elements() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	zero := AddressPayloadPair{}
	view := array_payload_address_view(zero, uint(0x1234), 0)
	writer.print_address(view)!
	writer.print_value('*', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, view, ~uint(0))!
	nested := AddressPayloadNested{}
	writer.print_address(array_payload_address_view(nested, ~uint(0), 3))!
	items := AddressPayloadOptionalItems{}
	writer.print_address(array_payload_address_view(items, uint(0), 0))!
	assert writer.buffered().bytestr() == '?[2]i32@1234?[2]i32@1234?[2][3]bool@ffffffffffffffff?[3]?u8@0'
}

fn test_optional_array_payload_addresses_keep_caller_storage_and_contents() ! {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	payload := AddressPayloadPair([int(7), 8]!)
	present := ?AddressPayloadPair(payload)
	mut values := [present, ?AddressPayloadPair(none)]
	address := uint(values.data)
	before := unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?AddressPayloadPair))).clone() }
	writer.print_address(values)!
	assert writer.buffered().bytestr() == '?[2]i32@${address:x}'
	assert unsafe { (&u8(values.data)).vbytes(values.len * int(sizeof(?AddressPayloadPair))) } == before
	writer.seek_to(0)!
	values.reverse_in_place()
	writer.print_value('*', FormatOptions{}, values, 0)!
	assert writer.buffered().bytestr() == '?[2]i32@${address:x}'
	assert uint(values.data) == address
	writer.seek_to(0)!
	writer.print_value('any', FormatOptions{}, values, 2)!
	assert writer.buffered().bytestr() == '{ null, { 7, 8 } }'
}

fn test_optional_array_payload_address_failures_preserve_write_boundaries() ! {
	expected := '?[2]i32@1234'
	zero := AddressPayloadPair{}
	view := array_payload_address_view(zero, uint(0x1234), 3)
	for capacity in 0 .. expected.len + 2 {
		for api in 0 .. 3 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if api == 0 { writer.print_address(view) or { status = err.msg() } }
			if api == 1 {
				writer.print_value('*', FormatOptions{ width: ~uint(0) }, view, 0) or { status = err.msg() }
			}
			if api == 2 {
				writer.print_value('?*', FormatOptions{ width: ~uint(0) }, ?AddressPayloadValues(view), 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_optional_array_payload_addresses_compose_with_print_and_outer_optionals() ! {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	zero := AddressPayloadPair{}
	view := array_payload_address_view(zero, uint(0x1234), 0)
	writer.print('a{[value]*}b', ArrayPayloadAddressArgs{view})!
	writer.print_value('?*', FormatOptions{ width: ~uint(0) }, ?AddressPayloadValues(view), 0)!
	writer.print_value('?*', FormatOptions{ width: 6, fill: `_` }, ?AddressPayloadValues(none), 0)!
	assert writer.buffered().bytestr() == 'a?[2]i32@1234b?[2]i32@1234__null'
}
