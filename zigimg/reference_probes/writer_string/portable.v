module main

import zigimg as p

type WriterText = string

struct WriterTextRecord {
	text string
}

fn test_string_bytes_preserve_binary_encoding_and_alignment() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	text := [u8(0), 255, 65].bytestr()
	writer.print_value('s', p.FormatOptions{ width: uint(5), precision: ~uint(0), alignment: .center, fill: `_` }, WriterText(text), 0)!
	writer.write_byte(`|`)!
	writer.print_value('x', p.FormatOptions{}, text, 0)!
	writer.write_byte(`|`)!
	writer.print_value('X', p.FormatOptions{}, text, ~uint(0))!
	writer.write_byte(`|`)!
	writer.print_value('b64', p.FormatOptions{}, text, 1)!
	assert writer.buffered().hex() == '5f00ff415f7c3030666634317c3030464634317c41503942'
}

fn test_string_any_uses_byte_lanes_and_recursive_depth() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_value('any', p.FormatOptions{ width: uint(3), fill: `_` }, 'A\x00', 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', p.FormatOptions{}, WriterTextRecord{'A'}, 2)!
	writer.write_byte(`|`)!
	writer.print_value('any', p.FormatOptions{}, ['A', 'B'], 1)!
	assert writer.buffered().bytestr() == '{ _65, __0 }|.{ .text = { 65 } }|{ { ... }, { ... } }'
}

fn test_string_optionals_and_print_use_the_same_dispatch() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_value('?s', p.FormatOptions{}, ?WriterText(WriterText('A')), 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', p.FormatOptions{ width: uint(6), fill: `_` }, ?string(none), 0)!
	writer.write_byte(`|`)!
	writer.print('{[text]s}/{[text]x}', WriterTextRecord{'AB'})!
	assert writer.buffered().bytestr() == 'A|__null|AB/4142'
}

fn test_string_partial_writes_keep_padding_and_encoded_chunks() ! {
	text := [u8(0), 255, 65].bytestr()
	for format in ['s', 'x', 'X', 'b64', 'any'] {
		expected := match format {
			's' { text }
			'x' { '00ff41' }
			'X' { '00FF41' }
			'b64' { 'AP9B' }
			else { '{ 0, 255, 65 }' }
		}
		for capacity in 0 .. expected.len + 2 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			writer.print_value(format, p.FormatOptions{}, text, 1) or { status = err.msg() }
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
				capacity
			} else {
				expected.len
			}]
		}
	}
}

fn test_string_address_uses_original_storage_and_ignores_options() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	for text in ['', 'address'] {
		writer.print_value('*', p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, WriterText(text), 0)!
		assert writer.buffered().bytestr() == 'u8@${uint(text.str):x}'
		writer.seek_to(0)!
	}
	writer.print_value('', p.FormatOptions{}, 'invalid', 0) or {
		assert err.msg() == 'unsupported print_value byte-slice format'
		assert writer.buffered().len == 0
		return
	}
	assert false
}

fn run() ! {
	test_string_bytes_preserve_binary_encoding_and_alignment()!
	test_string_any_uses_byte_lanes_and_recursive_depth()!
	test_string_optionals_and_print_use_the_same_dispatch()!
	test_string_partial_writes_keep_padding_and_encoded_chunks()!
	test_string_address_uses_original_storage_and_ignores_options()!
}

fn main() { run() or { panic(err) } }
