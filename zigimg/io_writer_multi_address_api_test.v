module zigimg

type MultiAddressWord = int
type MultiAddressAlias = &&MultiAddressWord
type MultiAddressArray = [2][3]u16
type MultiAddressArrayAlias = &&MultiAddressArray
type MultiAddressSlice = []u8
type MultiAddressSliceAlias = &&MultiAddressSlice

fn test_direct_multi_addresses_do_not_read_pointer_chains_or_descriptors() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(unsafe { MultiAddressAlias(voidptr(usize(0x1234))) })!
	writer.print_address(unsafe { MultiAddressArrayAlias(nil) })!
	writer.print_address(unsafe { MultiAddressSliceAlias(voidptr(~usize(0))) })!
	writer.print_address(unsafe { &&&&&&bool(voidptr(usize(1))) })!
	assert writer.buffered().bytestr() == '*i32@1234*[2][3]u16@0*[]u8@ffffffffffffffff*****bool@1'
}

fn test_direct_multi_addresses_match_explicit_and_default_pointer_formatting() ! {
	value := unsafe { &&u8(voidptr(usize(0x1234))) }
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	writer.print_value('*', FormatOptions{ width: ~usize(0), precision: ~usize(0) }, value, ~usize(0))!
	writer.print_value('any', FormatOptions{ width: 6, alignment: .left, fill: `_` }, value, 0)!
	assert writer.buffered().bytestr() == '*u8@1234*u8@1234*u8@1234__'
}

fn test_direct_multi_address_failures_keep_exact_prefix_digits_and_unused_bytes() ! {
	expected := '*i32@1234'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_address(unsafe { MultiAddressAlias(voidptr(usize(0x1234))) }) or { status = err.msg() }
		end := if capacity < expected.len { capacity } else { expected.len }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..end]
		assert buffer[end..].all(it == 0xa5)
	}
}

fn test_direct_multi_address_owned_intermediate_pointer_and_target_mutation() ! {
	mut first := 1
	mut second := 2
	mut intermediate := &first
	value := &intermediate
	address := usize(voidptr(value))
	before := unsafe { (&u8(voidptr(value))).vbytes(int(sizeof(intermediate))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	assert writer.buffered().bytestr() == '*i32@${address:x}'
	assert unsafe { (&u8(voidptr(value))).vbytes(int(sizeof(intermediate))) } == before
	first = 3
	second = 4
	intermediate = &second
	writer.seek_to(0)!
	writer.print_address(value)!
	assert writer.buffered().bytestr() == '*i32@${address:x}'
	assert first == 3 && second == 4 && intermediate == &second
}
