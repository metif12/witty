module main

import zigimg as p

type DirectAddressText = string

fn direct_address_text(address usize, length int) string {
	return unsafe { (&u8(voidptr(address))).vstring_with_len(length) }
}

fn test_direct_string_addresses_use_original_bytes_without_reading() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	value := direct_address_text(usize(0x1234), 3)
	writer.print_address(value)!
	writer.print_address(DirectAddressText(value))!
	writer.print_address(direct_address_text(usize(0), 0))!
	writer.print_address(direct_address_text(~usize(0), 0))!
	assert writer.buffered().bytestr() == 'u8@1234u8@1234u8@0u8@ffffffffffffffff'
}

fn test_direct_string_addresses_match_value_routes_and_ignore_length() ! {
	value := direct_address_text(usize(0x1234), 3)
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	writer.print_value('*', p.FormatOptions{ width: ~usize(0), precision: ~usize(0) }, value, ~usize(0))!
	writer.print_value('?*', p.FormatOptions{}, ?DirectAddressText(DirectAddressText(value)), 0)!
	writer.print_address(direct_address_text(usize(0x1234), 0))!
	assert writer.buffered().bytestr() == 'u8@1234u8@1234u8@1234u8@1234'
}

fn test_direct_string_address_partial_failures_keep_prefix_and_digits() ! {
	value := direct_address_text(usize(0x1234), 0)
	expected := 'u8@1234'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_address(value) or { status = err.msg() }
		end := if capacity < expected.len { capacity } else { expected.len }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..end]
		assert buffer[end..].all(it == 0xa5)
	}
}

fn test_direct_string_addresses_preserve_owned_storage_and_ignore_text() ! {
	mut bytes := [u8(65), 0, 255, 66]
	value := unsafe { (&u8(bytes.data)).vstring_with_len(bytes.len) }
	address := usize(value.str)
	before := bytes.clone()
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	assert writer.buffered().bytestr() == 'u8@${address:x}'
	assert bytes == before
	bytes[0] = 90
	writer.seek_to(0)!
	writer.print_address(value)!
	assert writer.buffered().bytestr() == 'u8@${address:x}'
	assert usize(value.str) == address && value.len == bytes.len
}

fn test_direct_string_addresses_keep_optionals_and_empty_literals_distinct() ! {
	value := ''
	address := usize(value.str)
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	writer.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?string(none), 0)!
	assert writer.buffered().bytestr() == 'u8@${address:x}__null'
}

fn main() {
	test_direct_string_addresses_use_original_bytes_without_reading() or { panic(err) }
	test_direct_string_addresses_match_value_routes_and_ignore_length() or { panic(err) }
	test_direct_string_address_partial_failures_keep_prefix_and_digits() or { panic(err) }
	test_direct_string_addresses_preserve_owned_storage_and_ignore_text() or { panic(err) }
	test_direct_string_addresses_keep_optionals_and_empty_literals_distinct() or { panic(err) }
}
