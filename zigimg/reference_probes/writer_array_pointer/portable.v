module main

import zigimg as p

type Bytes = [3]u8

struct Args {
	value &Bytes
}

fn test_byte_array_pointers_keep_encodings_and_alignment() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	value := [u8(0), 255, 65]!
	alias_value := Bytes(value)
	writer.print_value('s', p.FormatOptions{ width: usize(5), precision: ~usize(0), alignment: .center, fill: `_` }, &value, 0)!
	writer.write_byte(`|`)!
	writer.print_value('x', p.FormatOptions{}, &alias_value, 0)!
	writer.write_byte(`|`)!
	writer.print_value('b64', p.FormatOptions{}, &value, 0)!
	assert writer.buffered().hex() == '5f00ff415f7c3030666634317c41503942'
}

fn test_array_pointer_depth_and_element_types_survive_mixed_specializations() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	bytes := [u8(255)]!
	integers := [i16(-32768), 32767]!
	flags := [false, true]!
	optionals := [?u8(7), ?u8(none)]!
	nested := [[u8(1)]!, [u8(2)]!]!
	writer.print_value('any', p.FormatOptions{}, &bytes, 1)!
	writer.print_value('any', p.FormatOptions{}, &integers, 1)!
	writer.print_value('any', p.FormatOptions{}, &flags, 1)!
	writer.print_value('any', p.FormatOptions{}, &optionals, 1)!
	writer.print_value('any', p.FormatOptions{}, &nested, 1)!
	writer.print_value('any', p.FormatOptions{}, &nested, 2)!
	assert writer.buffered().bytestr() == '{ 255 }{ -32768, 32767 }{ false, true }{ 7, null }{ { ... }, { ... } }{ { 1 }, { 2 } }'
}

fn test_array_pointers_compose_in_print_and_absent_optionals_bypass_encoding_options() ! {
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	bytes := [u8(0), 255, 65]!
	writer.print('a{x}b', Args{unsafe { &bytes }})!
	writer.print_value('?x', p.FormatOptions{ width: usize(6), precision: usize(0), fill: `_` }, ?&[3]u8(none), 0)!
	assert writer.buffered().bytestr() == 'a00ff41b__null'
}

fn test_array_pointer_partial_writes_keep_slice_boundaries() ! {
	bytes := [u8(0), 255, 65]!
	for format in ['s', 'x', 'X', 'b64', 'any'] {
		expected := match format {
			's' { [u8(0), 255, 65].bytestr() }
			'x' { '00ff41' }
			'X' { '00FF41' }
			'b64' { 'AP9B' }
			else { '{ 0, 255, 65 }' }
		}
		for capacity in 0 .. expected.len + 2 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			writer.print_value(format, p.FormatOptions{}, &bytes, 1) or { status = err.msg() }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
				capacity
			} else {
				expected.len
			}]
		}
	}
}

fn test_array_pointer_invalid_default_formats_leave_writer_untouched() ! {
	bytes := [u8(0), 255, 65]!
	for format in ['', 't', 'd'] {
		mut buffer := []u8{len: 128, init: 0xa5}
		before := buffer.clone()
		mut writer := p.WriteStream.init_memory(mut buffer)
		mut rejected := false
		writer.print_value(format, p.FormatOptions{}, &bytes, 0) or { rejected = true }
		assert rejected && writer.buffered().len == 0 && buffer == before
	}
}

fn main() {
	test_byte_array_pointers_keep_encodings_and_alignment() or { panic(err) }
	test_array_pointer_depth_and_element_types_survive_mixed_specializations() or { panic(err) }
	test_array_pointers_compose_in_print_and_absent_optionals_bypass_encoding_options() or { panic(err) }
	test_array_pointer_partial_writes_keep_slice_boundaries() or { panic(err) }
	test_array_pointer_invalid_default_formats_leave_writer_untouched() or { panic(err) }
}
