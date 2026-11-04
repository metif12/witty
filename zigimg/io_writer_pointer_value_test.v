module zigimg

type DefaultPointerWord = int
type DefaultPointer = &DefaultPointerWord

fn test_default_pointer_options_apply_only_to_address_digits() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{ width: usize(6), precision: ~usize(0), alignment: .left, fill: `_` }, unsafe { &u8(usize(0x1234)) }, 0)!
	writer.write_byte(`|`)!
	writer.print_value('', FormatOptions{ width: usize(6), alignment: .center, fill: `0` }, unsafe { &bool(usize(0x12)) }, ~usize(0))!
	assert writer.buffered().bytestr() == 'u8@1234__|bool@001200'
}

fn test_default_pointer_aliases_and_optional_unwrapping_preserve_bits() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	pointer := DefaultPointer(unsafe { &DefaultPointerWord(usize(0x1234)) })
	writer.print_value('any', FormatOptions{}, pointer, 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ?DefaultPointer(pointer), 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, ?&u16(unsafe { &u16(usize(0x1234)) }), 0)!
	writer.write_byte(`|`)!
	writer.print_value('?', FormatOptions{}, ?&f64(unsafe { &f64(usize(0x5678)) }), 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{ width: usize(6), fill: `_` }, ?&u8(none), 0)!
	assert writer.buffered().bytestr() == 'i32@1234|i32@1234|u16@1234|f64@5678|__null'
}

fn test_default_opaque_and_zero_pointers_never_dereference() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{ width: usize(4), fill: `_` }, voidptr(usize(0x123)), 0)!
	writer.write_byte(`|`)!
	writer.print_value('', FormatOptions{}, unsafe { &int(usize(0)) }, 0)!
	assert writer.buffered().bytestr() == 'anyopaque@_123|i32@0'
}

fn test_default_pointer_failures_preserve_prefix_padding_and_digits() {
	expected := 'u32@__1234'
	for cap in 0 .. expected.len + 2 {
		mut buffer := []u8{len: cap, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('any', FormatOptions{ width: usize(6), fill: `_` }, unsafe { &u32(usize(0x1234)) }, 0) or { status = err.msg() }
		assert status == if cap < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if cap < expected.len {
			cap
		} else {
			expected.len
		}]
	}
}

fn test_explicit_address_format_still_ignores_options() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	options := FormatOptions{ width: ~usize(0), precision: ~usize(0) }
	writer.print_value('*', options, unsafe { &u8(usize(0x123)) }, 0)!
	writer.write_byte(`|`)!
	writer.print_value('*', options, ?&u8(none), 0)!
	writer.write_byte(`|`)!
	pointer := DefaultPointer(unsafe { &DefaultPointerWord(usize(0x1234)) })
	writer.print_value('*', options, ?DefaultPointer(pointer), 0)!
	writer.write_byte(`|`)!
	writer.print_value('*', options, ?DefaultPointer(none), 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, [u8(1), 255]!, 1)!
	assert writer.buffered().bytestr() == 'u8@123|*u8@0|*i32@1234|*i32@0|{ 1, 255 }'
}
