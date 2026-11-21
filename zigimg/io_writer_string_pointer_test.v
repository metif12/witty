module zigimg

type DescriptorText = string
type DescriptorPointer = &DescriptorText
type DescriptorPointers = [2]&string

fn test_string_descriptor_pointer_addresses_do_not_read_descriptor_or_text() ! {
	value := unsafe { &string(voidptr(uint(0x1234))) }
	alias := unsafe { DescriptorPointer(voidptr(uint(0x1234))) }
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	writer.print_value('*', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, alias, ~uint(0))!
	writer.print_value('any', FormatOptions{ width: 6, alignment: .left, fill: `_` }, value, 0)!
	writer.print_address(unsafe { &string(voidptr(uint(0))) })!
	assert writer.buffered().bytestr() == '[]const u8@1234[]const u8@1234[]const u8@1234__[]const u8@0'
}

fn test_string_descriptor_pointer_optionals_keep_address_and_null_routes() ! {
	value := unsafe { &string(voidptr(uint(0x1000))) }
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(?&string(value))!
	writer.print_value('?*', FormatOptions{}, ?&string(value), 0)!
	writer.print_value('*', FormatOptions{}, ?&string(none), 0)!
	writer.print_value('?*', FormatOptions{ width: 6, fill: `_` }, ?&string(none), 0)!
	assert writer.buffered().bytestr() == '*[]const u8@1000[]const u8@1000*[]const u8@0__null'
}

fn test_string_descriptor_optional_pointer_aliases_keep_raw_bits() ! {
	pointer := unsafe { DescriptorPointer(voidptr(uint(0x1000))) }
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(?DescriptorPointer(pointer))!
	writer.print_address(?DescriptorPointer(none))!
	writer.print_value('*', FormatOptions{}, ?DescriptorPointer(pointer), 0)!
	writer.print_value('?*', FormatOptions{}, ?DescriptorPointer(pointer), 0)!
	assert writer.buffered().bytestr() == '*[]const u8@1000*[]const u8@0*[]const u8@1000[]const u8@1000'
}

fn test_string_descriptor_pointer_failures_keep_exact_prefix_and_digits() ! {
	value := unsafe { &string(voidptr(uint(0x1234))) }
	expected := '[]const u8@1234'
	for capacity in 0 .. expected.len + 2 {
		for direct in [true, false] {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if direct {
				writer.print_address(value) or { status = err.msg() }
			} else {
				writer.print_value('any', FormatOptions{}, value, 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_string_descriptor_pointer_elements_name_the_pointer_type() ! {
	value := unsafe { &DescriptorPointers(voidptr(uint(0x1234))) }
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	writer.print_value('*', FormatOptions{}, value, 0)!
	assert writer.buffered().bytestr() == '[2]*[]const u8@1234[2]*[]const u8@1234'
}

fn test_string_descriptor_addresses_preserve_owned_headers_and_ignore_replacement() ! {
	mut value := 'first'
	address := unsafe { uint(voidptr(&value)) }
	before := unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_address(&value)!
	assert writer.buffered().bytestr() == '[]const u8@${address:x}'
	assert unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))) } == before
	value = 'replacement'
	writer.seek_to(0)!
	writer.print_value('any', FormatOptions{}, &value, 0)!
	assert writer.buffered().bytestr() == '[]const u8@${address:x}'
	assert value == 'replacement'
}
