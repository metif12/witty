module zigimg

type ValueArrayByte = u8
type ValueByteArray = [3]ValueArrayByte
type ValueArrayElement = i16
type ValueArrayRow = [2]ValueArrayElement
type ValueArrayGrid = [2]ValueArrayRow

fn test_value_fixed_arrays_recurse_with_aliases_and_leaf_options() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	mut values := ValueArrayGrid{}
	values[0] = ValueArrayRow([ValueArrayElement(-12), 3]!)
	values[1] = ValueArrayRow([ValueArrayElement(0), -4]!)
	writer.print_value('any', FormatOptions{ width: usize(4), fill: `_` }, values, 2)!
	assert writer.buffered().bytestr() == '{ { _-12, __+3 }, { __+0, __-4 } }'
}

fn test_value_byte_arrays_use_byte_formats_even_at_depth_zero() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	value := ValueByteArray([ValueArrayByte(0), 127, 255]!)
	writer.print_value('s', FormatOptions{ width: usize(5), fill: `_`, precision: usize(0) },
		value, 0)!
	for format in ['x', 'X', 'b64'] {
		writer.write_byte(`|`)!
		writer.print_value(format, FormatOptions{}, value, 0)!
	}
	assert writer.buffered() == [u8(`_`), `_`, 0, 127, 255, `|`, `0`, `0`, `7`, `f`, `f`, `f`,
		`|`, `0`, `0`, `7`, `F`, `F`, `F`, `|`, `A`, `H`, `/`, `/`]
}

fn test_value_fixed_array_depth_and_mixed_dynamic_arrays() {
	mut bytes := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut bytes)
	options := FormatOptions{
		width:     ~usize(0)
		precision: ~usize(0)
		alignment: .center
	}
	writer.print_value('any', options, [[true, false]!, [false, true]!]!, 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', options, [f64(1.25), -2.5]!, 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', options, [2][]bool{}, 3)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{ precision: usize(1) }, [
		[f32(1.25), -2.5]!,
		[f32(3), 4]!,
	], 2)!
	assert writer.buffered().bytestr() == '{ { ... }, { ... } }|{ ... }|{ {  }, {  } }|{ { 1.3, -2.5 }, { 3.0, 4.0 } }'
}

fn test_value_fixed_array_failures_retain_prefix_and_reject_invalid_formats() {
	expected := '{ { -12, 34 }, { 56, -78 } }'
	for capacity in 0 .. expected.len + 2 {
		mut bytes := []u8{len: capacity}
		mut writer := WriteStream.init_memory(mut bytes)
		mut status := 'ok'
		writer.print_value('any', FormatOptions{}, [[int(-12), 34]!,
			[int(56), -78]!]!, 2) or { status = err.msg() }
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
		before := writer.buffered().clone()
		for format in ['*', '', 'd', 's', 'x'] {
			writer.print_value(format, FormatOptions{}, [int(1), 2]!, 3) or {
				assert err.msg() == 'unsupported print_value array format'
				continue
			}
			assert false
		}
		mut rejected := false
		writer.print_value('*', FormatOptions{}, [u8(1), 2]!, 3) or {
			assert err.msg() == 'unsupported print_value byte-slice format'
			rejected = true
		}
		assert rejected
		assert writer.buffered() == before
	}
}
