module zigimg

enum ValueClosedEnum as i8 {
	zero     = 0
	long_tag = 126
}

@[nonexhaustive]
enum ValueOpenEnum as u64 {
	zero = 0
	high = 0xffffffffffffffff
}

@[nonexhaustive]
enum ValueSignedEnum as i64 {
	low  = -9223372036854775808
	zero = 0
}

type ValueEnumAlias = ValueOpenEnum

fn test_value_enums_preserve_signedness_tag_names_and_aliases() {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('d', FormatOptions{ width: uint(5), fill: `_` }, ValueClosedEnum.long_tag,
		0)!
	writer.write_byte(`|`)!
	writer.print_value('X', FormatOptions{}, ValueEnumAlias(ValueOpenEnum.high), 0)!
	writer.write_byte(`|`)!
	writer.print_value('t', FormatOptions{
		width:     uint(12)
		alignment: .center
		fill:      `_`
		precision: uint(0)
	}, ValueClosedEnum.long_tag, 0)!
	writer.write_byte(`|`)!
	writer.print_value('', FormatOptions{}, ValueSignedEnum.low, 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, unsafe { ValueSignedEnum(i64(-3)) }, 0)!
	writer.write_byte(`|`)!
	writer.print_value('', FormatOptions{}, unsafe { ValueEnumAlias(u64(9223372036854775808)) }, 0)!
	assert writer.buffered().bytestr() == '_+126|FFFFFFFFFFFFFFFF|__long_tag__|.low|@enumFromInt(-3)|@enumFromInt(9223372036854775808)'
}

fn test_value_enum_arrays_recurse_and_depth_zero_bypasses_options() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('any', FormatOptions{}, [ValueClosedEnum.zero, .long_tag]!, 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{}, [[ValueEnumAlias(ValueOpenEnum.high)],
		[ValueEnumAlias(ValueOpenEnum.zero)]], 2)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{ width: ~uint(0), precision: ~uint(0) }, [
		ValueOpenEnum.high,
	], 0)!
	assert writer.buffered().bytestr() == '{ .zero, .long_tag }|{ { .high }, { .zero } }|{ ... }'
}

fn test_value_enum_vectored_and_unnamed_writes_retain_every_partial_prefix() {
	for unnamed in [false, true] {
		expected := if unnamed { '@enumFromInt(123)' } else { '.long_tag' }
		for capacity in 0 .. expected.len + 2 {
			mut buffer := []u8{len: capacity}
			mut writer := WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if unnamed {
				writer.print_value('any', FormatOptions{}, unsafe { ValueOpenEnum(u64(123)) }, 0) or {
					status = err.msg()
				}
			} else {
				writer.print_value('', FormatOptions{}, ValueClosedEnum.long_tag, 0) or {
					status = err.msg()
				}
			}
			assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
				capacity
			} else {
				expected.len
			}]
			assert status == if capacity < expected.len {
				'WriteFailed'
			} else {
				'ok'
			}
		}
	}
}

fn test_value_enum_invalid_format_preserves_writer_state() {
	mut buffer := []u8{len: 32, init: 0xa5}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.write_byte(`!`)!
	before := buffer.clone()
	for format in ['*', 's', 'c', 'u', 'D', 'B', 'Bi', 'e', 'b64'] {
		writer.print_value(format, FormatOptions{ width: uint(0), precision: uint(0) },
			ValueOpenEnum.high, 2) or {
			assert err.msg() == 'unsupported print_value enum format'
			assert buffer == before && writer.buffered() == [u8(`!`)]
			continue
		}
		assert false
	}
}
