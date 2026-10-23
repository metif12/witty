module zigimg

import strconv

type ValueAddressWord = int
type ValueAddressPointer = &ValueAddressWord

fn test_value_address_dispatch_preserves_aliases_and_ignores_options() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	options := FormatOptions{
		width:     ~usize(0)
		precision: ~usize(0)
		alignment: .center
		fill:      `_`
	}
	writer.print_value('*', options,
		ValueAddressPointer(unsafe { &ValueAddressWord(usize(0x100)) }), 0)!
	writer.write_byte(`|`)!
	writer.print_value('*', options, ?&u32(none), ~usize(0))!
	writer.write_byte(`|`)!
	writer.print_value('*', options, unsafe { nil }, 0)!
	writer.write_byte(`|`)!
	writer.print_value('*', options, ?&f32(none), 0)!
	writer.write_byte(`|`)!
	writer.print_value('*', options, ?&bool(none), 0)!
	assert writer.buffered().bytestr() == 'i32@100|*u32@0|anyopaque@0|*f32@0|*bool@0'
}

fn test_value_address_byte_slice_bypasses_encoded_format_options() {
	mut payload := [u8(1), 2, 3]
	mut bytes := []u8{len: 64}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('*', FormatOptions{ precision: ~usize(0), width: ~usize(0) }, payload, 0)!
	text := writer.buffered().bytestr()
	assert text.starts_with('u8@')
	assert strconv.parse_uint(text[3..], 16, 64)! == u64(usize(payload.data))
	assert payload == [u8(1), 2, 3]
}

fn test_value_address_retains_type_prefix_and_partial_digits() {
	mut bytes := []u8{len: 5}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('*', FormatOptions{}, unsafe { &u8(usize(0x1234)) }, 0) or {
		assert err.msg() == 'WriteFailed'
		assert writer.buffered().bytestr() == 'u8@12'
		return
	}
	assert false
}
