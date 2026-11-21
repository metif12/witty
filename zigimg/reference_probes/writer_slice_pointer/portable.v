module main

import zigimg as p

type SliceDescriptor = []u8
type SliceDescriptorPointer = &SliceDescriptor
type SliceDescriptorPointers = [2]SliceDescriptorPointer

fn test_slice_descriptor_pointer_formats_do_not_read_descriptor_or_elements() ! {
	value := unsafe { &[]u8(voidptr(uint(0x1234))) }
	alias := unsafe { SliceDescriptorPointer(voidptr(uint(0x1234))) }
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(value)!
	writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, alias, ~uint(0))!
	writer.print_value('any', p.FormatOptions{ width: 6, alignment: .left, fill: `_` }, value, 0)!
	writer.print_address(unsafe { &[]u8(nil) })!
	assert writer.buffered().bytestr() == '[]u8@1234[]u8@1234[]u8@1234__[]u8@0'
}

fn test_slice_descriptor_pointer_optionals_preserve_aliases_and_null_routes() ! {
	value := unsafe { &[]u8(voidptr(uint(0x1000))) }
	alias := unsafe { SliceDescriptorPointer(voidptr(uint(0x1000))) }
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(?&[]u8(value))!
	writer.print_value('?*', p.FormatOptions{}, ?&[]u8(value), 0)!
	writer.print_value('*', p.FormatOptions{}, ?SliceDescriptorPointer(none), 0)!
	writer.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?&[]u8(none), 0)!
	writer.print_address(?SliceDescriptorPointer(alias))!
	assert writer.buffered().bytestr() == '*[]u8@1000[]u8@1000*[]u8@0__null*[]u8@1000'
}

fn test_slice_descriptor_pointer_failures_keep_prefix_padding_digits_and_unused_bytes() ! {
	value := unsafe { &[]u8(voidptr(uint(0x1234))) }
	for direct in [true, false] {
		expected := if direct { '[]u8@1234' } else { '[]u8@__1234' }
		for capacity in 0 .. expected.len + 2 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if direct {
				writer.print_address(value) or { status = err.msg() }
			} else {
				writer.print_value('any', p.FormatOptions{ width: 6, fill: `_` }, value, 0) or { status = err.msg() }
			}
			end := if capacity < expected.len { capacity } else { expected.len }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..end]
			assert buffer[end..].all(it == 0xa5)
		}
	}
}

fn test_slice_descriptor_pointer_element_names_and_nested_descriptors() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(unsafe { &SliceDescriptorPointers(voidptr(uint(0x1234))) })!
	writer.print_value('any', p.FormatOptions{}, unsafe { &[][]u8(voidptr(uint(0x1234))) }, 0)!
	writer.print_value('*', p.FormatOptions{}, unsafe { &[]string(voidptr(uint(0x1234))) }, 0)!
	assert writer.buffered().bytestr() == '[2]*[]u8@1234[][]u8@1234[][]const u8@1234'
}

fn test_slice_descriptor_pointer_uses_owned_header_address_and_preserves_contents() ! {
	mut value := [u8(1), 2, 3]
	address := uint(voidptr(&value))
	before := unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))).clone() }
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(&value)!
	assert writer.buffered().bytestr() == '[]u8@${address:x}'
	assert unsafe { (&u8(voidptr(&value))).vbytes(int(sizeof(value))) } == before
	value = [u8(4), 5]
	writer.seek_to(0)!
	writer.print_value('any', p.FormatOptions{}, &value, 0)!
	assert writer.buffered().bytestr() == '[]u8@${address:x}'
	assert value == [u8(4), 5]
	writer.seek_to(0)!
	writer.print_value('any', p.FormatOptions{}, value, 1)!
	assert writer.buffered().bytestr() == '{ 4, 5 }'
}

fn main() {
	test_slice_descriptor_pointer_formats_do_not_read_descriptor_or_elements() or { panic(err) }
	test_slice_descriptor_pointer_optionals_preserve_aliases_and_null_routes() or { panic(err) }
	test_slice_descriptor_pointer_failures_keep_prefix_padding_digits_and_unused_bytes() or { panic(err) }
	test_slice_descriptor_pointer_element_names_and_nested_descriptors() or { panic(err) }
	test_slice_descriptor_pointer_uses_owned_header_address_and_preserves_contents() or { panic(err) }
}
