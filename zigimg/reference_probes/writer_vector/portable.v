module main

import zigimg

type VectorByte = u8
type VectorWords = [3]VectorByte

fn test_vector_forwards_numeric_formats_and_leaf_options() ! {
	mut buffer := []u8{len: 256}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_vector('X', zigimg.FormatOptions{ width: uint(4), fill: `_` }, VectorWords([
		VectorByte(1),
		127,
		255,
	]!), 1)!
	writer.write_byte(`|`)!
	writer.print_vector('b', zigimg.FormatOptions{}, [i16(-7), 0, 9]!, 2)!
	assert writer.buffered().bytestr() == '{ ___1, __7F, __FF }|{ -111, 0, 1001 }'
}

fn test_vector_bytes_are_lanes_and_do_not_change_array_formatting() ! {
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_vector('x', zigimg.FormatOptions{}, [u8(1), 255]!, 1)!
	writer.write_byte(`|`)!
	writer.print_value('x', zigimg.FormatOptions{}, [u8(1), 255]!, 1)!
	assert writer.buffered().bytestr() == '{ 1, ff }|01ff'
}

fn test_vector_depth_cutoff_ignores_format_and_options_at_runtime() ! {
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_vector('unsupported', zigimg.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, [
		true,
		false,
	]!, 0)!
	assert writer.buffered().bytestr() == '{ ... }'
	// A visited invalid leaf rejects after the opening write.
	writer.print_vector('d', zigimg.FormatOptions{}, [true, false]!, 1) or {
		assert err.msg() == 'unsupported print_value boolean format'
		assert writer.buffered().bytestr() == '{ ... }{ '
		return
	}
	assert false
}

fn test_vector_boolean_float_and_direct_character_formats() ! {
	mut buffer := []u8{len: 256}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print_vector('any', zigimg.FormatOptions{ width: uint(6), fill: `_` }, [
		true,
		false,
	]!, 1)!
	writer.write_byte(`|`)!
	writer.print_vector('d', zigimg.FormatOptions{ precision: uint(1) }, [f32(1.25), -2.5]!, 1)!
	writer.write_byte(`|`)!
	writer.print_vector('X', zigimg.FormatOptions{}, [f64(1.5), -2.5]!, 1)!
	writer.write_byte(`|`)!
	writer.print_vector('c', zigimg.FormatOptions{}, [u8(`A`), `Z`]!, 1)!
	assert writer.buffered().bytestr() == '{ __true, _false }|{ 1.3, -2.5 }|{ 0x1.8p0, -0x1.4p1 }|{ A, Z }'
}

fn test_vector_partial_output_keeps_each_leaf_separator_and_closing_write() ! {
	expected := '{ -17, 0, 42 }'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_vector('d', zigimg.FormatOptions{}, [int(-17), 0, 42]!, 1) or { status = err.msg() }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
}

fn main() {
	test_vector_forwards_numeric_formats_and_leaf_options() or { panic(err) }
	test_vector_bytes_are_lanes_and_do_not_change_array_formatting() or { panic(err) }
	test_vector_depth_cutoff_ignores_format_and_options_at_runtime() or { panic(err) }
	test_vector_boolean_float_and_direct_character_formats() or { panic(err) }
	test_vector_partial_output_keeps_each_leaf_separator_and_closing_write() or { panic(err) }
}
