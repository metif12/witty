module zigimg

type AddressText = string
type AddressTextArray = [3]AddressText
type AddressTextNested = [2][3]string
type AddressTextRows = []AddressText
type AddressOptionalTextRows = []?string
type AddressTextPair = [2]string
type AddressOptionalTextPairs = []?AddressTextPair

struct StringElementAddressArgs {
	value AddressTextRows
}

fn string_element_address_view[E](_ E, address uint, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_string_element_address_names_preserve_const_byte_slice_spelling() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	fixed := unsafe { &AddressTextArray(voidptr(uint(0x1234))) }
	writer.print_address(fixed)!
	writer.print_value('*', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, fixed, ~uint(0))!
	view := AddressTextRows(string_element_address_view(AddressText(''), uint(0), 0))
	writer.print_address(view)!
	writer.print_value('*', FormatOptions{}, view, 0)!
	assert writer.buffered().bytestr() == '[3][]const u8@1234[3][]const u8@1234[]const u8@0[]const u8@0'
}

fn test_string_element_address_names_compose_with_options_and_arrays() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	optional := ?string(none)
	view := AddressOptionalTextRows(string_element_address_view(optional, ~uint(0), 0))
	writer.print_address(view)!
	pair := ?AddressTextPair(none)
	pairs := AddressOptionalTextPairs(string_element_address_view(pair, uint(0x1234), 0))
	writer.print_value('*', FormatOptions{}, pairs, 0)!
	nested := unsafe { &AddressTextNested(voidptr(uint(0))) }
	writer.print_address(nested)!
	assert writer.buffered().bytestr() == '?[]const u8@ffffffffffffffff?[2][]const u8@1234[2][3][]const u8@0'
}

fn test_string_element_address_failures_keep_exact_prefix_and_digits() ! {
	fixed := unsafe { &AddressTextArray(voidptr(uint(0x1234))) }
	expected := '[3][]const u8@1234'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('*', FormatOptions{}, fixed, 0) or { status = err.msg() }
		end := if capacity < expected.len { capacity } else { expected.len }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..end]
		assert buffer[end..].all(it == 0xa5)
	}
}

fn test_string_element_addresses_preserve_owned_headers_and_ignore_text() ! {
	mut value := ['a', 'longer', 'é']!
	address := unsafe { uint(voidptr(&value)) }
	before := unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(&value)!
	assert writer.buffered().bytestr() == '[3][]const u8@${address:x}'
	assert unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))) } == before
	value[0] = 'changed'
	value.reverse_in_place()
	writer.seek_to(0)!
	writer.print_value('*', FormatOptions{}, &value, 0)!
	assert writer.buffered().bytestr() == '[3][]const u8@${address:x}'
	assert value == ['é', 'longer', 'changed']!
}

fn test_string_element_addresses_compose_with_print_and_outer_optionals() ! {
	view := AddressTextRows(['a', 'b', 'c'].map(AddressText(it)))
	address := uint(view.data)
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print('L{[value]*}R', StringElementAddressArgs{view})!
	writer.print_value('?*', FormatOptions{ width: ~uint(0) }, ?AddressTextRows(view), 0)!
	writer.print_value('?*', FormatOptions{ width: 6, fill: `_` }, ?AddressTextRows(none), 0)!
	assert writer.buffered().bytestr() == 'L[]const u8@${address:x}R[]const u8@${address:x}__null'
}
