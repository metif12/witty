module zigimg

type AddressWord = int
type AddressPointer = &AddressWord

fn test_address_formats_native_pointers_aliases_and_zero_without_dereferencing() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_address(unsafe { &u8(usize(0x12ab)) })!
	writer.write_byte(`|`)!
	writer.print_address(AddressPointer(unsafe { &AddressWord(usize(0x100)) }))!
	writer.write_byte(`|`)!
	writer.print_address(unsafe { nil })!
	assert writer.buffered().bytestr() == 'u8@12ab|i32@100|anyopaque@0'
}

fn test_address_formats_optional_pointers() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	absent := ?&u32(none)
	present := ?&u32(unsafe { &u32(usize(0x100)) })
	writer.print_address(absent)!
	writer.write_byte(`|`)!
	writer.print_address(present)!
	assert writer.buffered().bytestr() == '*u32@0|*u32@100'
}

fn test_address_retains_prefix_and_short_hex_write() {
	mut bytes := []u8{len: 5}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.print_address(unsafe { &u8(usize(0x1234)) }) or { status = err.msg() }
	assert status == 'WriteFailed'
	assert writer.buffered().bytestr() == 'u8@12'
}
