module zigimg

type ValueSliceElement = i16
type ValueSlice = []ValueSliceElement
type ValueNestedSlice = []ValueSlice

fn test_value_slices_recurse_with_element_options_and_aliases() {
	mut bytes := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut bytes)
	values := ValueNestedSlice([ValueSlice([ValueSliceElement(-12), 3]),
		ValueSlice([]ValueSliceElement{})])
	writer.print_value('any', FormatOptions{ width: uint(4), fill: `_` }, values, 2)!
	assert writer.buffered().bytestr() == '{ { _-12, __+3 }, {  } }'
}

fn test_value_slice_depth_bypasses_element_options() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	options := FormatOptions{
		width:     ~uint(0)
		precision: ~uint(0)
		alignment: .center
	}
	writer.print_value('any', options, [][]bool{len: 2}, 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', options, []f64{}, 0)!
	assert writer.buffered().bytestr() == '{ { ... }, { ... } }|{ ... }'
}

fn test_value_slice_failure_retains_recursive_write_order() {
	for capacity in 0 .. 25 {
		mut bytes := []u8{len: capacity}
		mut writer := WriteStream.init_memory(mut bytes)
		mut status := 'ok'
		writer.print_value('any', FormatOptions{}, [[int(-12), 34],
			[]int{}], 2) or { status = err.msg() }
		expected := '{ { -12, 34 }, {  } }'
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

fn test_value_slice_boolean_float_and_invalid_format() {
	mut bytes := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.print_value('any', FormatOptions{ width: uint(6), fill: `_` }, [true, false], 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', FormatOptions{ precision: uint(1) }, [f32(1.25), -2.5], 1)!
	assert writer.buffered().bytestr() == '{ __true, _false }|{ 1.3, -2.5 }'
	before := writer.buffered().clone()
	mut status := 'ok'
	writer.print_value('d', FormatOptions{}, [int(1)], 1) or { status = err.msg() }
	assert status == 'unsupported print_value slice format'
	assert writer.buffered() == before
}
