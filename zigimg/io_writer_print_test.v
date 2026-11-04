module zigimg

struct PrintArgs {
	value     int
	text      []u8
	width     usize
	precision ?usize
}

struct PrintEmpty {}

struct PrintPair {
	value int
	text  []u8
}

fn test_print_literals_named_sizes_and_argument_reuse() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	args := PrintArgs{-17, 'hello'.bytes(), 7, ?usize(3)}
	writer.print('a{{b}}{[value]d:0>[width]}:{[text]s:.<8}:{[value]d:.[precision]}!', args)!
	assert writer.buffered().bytestr() == 'a{b}0000-17:hello...:-17!'
}

fn test_print_implicit_and_explicit_argument_selection() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print('{1s}:{d}:{1s}:{s}', PrintPair{7, 'ok'.bytes()})!
	assert writer.buffered().bytestr() == 'ok:7:ok:ok'
	writer = WriteStream.init_memory(mut buffer)
	writer.print('{1s}:{d}:{2d}:{1s}', PrintArgs{7, 'ok'.bytes(), 4, none}) or {
		assert err.msg() == 'unused arguments'
		assert writer.buffered().len == 0
		return
	}
	assert false
}

fn test_print_absent_named_sizes_and_non_record_arguments() {
	mut buffer := []u8{len: 64}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print('{[text]s:>[width].[precision]}:{[value]d}', PrintArgs{7, 'ok'.bytes(), 4, none})!
	assert writer.buffered().bytestr() == '  ok:7'
	writer.print('literal', 7) or {
		assert err.msg() == 'expected struct argument'
		assert writer.buffered().bytestr() == '  ok:7'
		return
	}
	assert false
}

fn test_print_invalid_templates_leave_writer_untouched() {
	for format in ['literal}', 'literal{', 'literal{[missing]d}', 'literal{}', 'literal{d:bad}'] {
		mut buffer := []u8{len: 64, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		before := buffer.clone()
		mut failed := false
		writer.print(format, PrintEmpty{}) or { failed = true }
		assert failed
		assert buffer == before && writer.buffered().len == 0
	}
}

fn test_print_escaped_literal_and_partial_writes() {
	expected := 'a{b}c{d}'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print('a{{b}}c{{d}}', PrintEmpty{}) or { status = err.msg() }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
}

struct PrintError {}

fn (value PrintError) msg() string { return 'PrintError' }

fn (value PrintError) code() int { return 47 }

fn (value PrintError) format(mut writer WriteStream) ! {
	writer.write_all('custom-error'.bytes())!
	return error_with_code('FormatterStopped', 47)
}

struct PrintErrorArgs {
	value PrintError
}

struct PrintMixedArgs {
	bytes    [2]u8
	value    IError
	optional ?int
	nested   [][][][]int
}

fn test_print_reflected_errors_fixed_arrays_optionals_and_default_depth() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	args := PrintMixedArgs{[u8(1), 255]!, PrintError{}, ?int(-7), [[[[1]]]]}
	writer.print('{any}|{}|{?d}|{any}', args)!
	assert writer.buffered().bytestr() == '{ 1, 255 }|error.PrintError|-7|{ { { { ... } } } }'
}

fn test_print_custom_error_failure_preserves_literal_and_error_code() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print('before{f}after', PrintErrorArgs{}) or {
		assert err.msg() == 'FormatterStopped' && err.code() == 47
		assert writer.buffered().bytestr() == 'beforecustom-error'
		return
	}
	assert false
}

type PrintWidth = u16

struct PrintAliasSizes {
	value     int
	width     PrintWidth
	precision ?usize
}

type PrintArgsAlias = PrintAliasSizes

fn test_print_record_alias_and_unsigned_size_fields() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print('{d:_>[width].[precision]}', PrintArgsAlias(PrintAliasSizes{7, PrintWidth(5), ?usize(2)}))!
	assert writer.buffered().bytestr() == '___+7'
}

struct PrintSignedSize {
	value int
	width int
}

struct PrintOptionalSignedSize {
	value int
	width ?int
}

fn test_print_rejects_absent_signed_size_before_writer_effects() {
	mut buffer := []u8{len: 64, init: 0xa5}
	mut writer := WriteStream.init_memory(mut buffer)
	before := buffer.clone()
	writer.print('before{d:[width]}', PrintOptionalSignedSize{7, none}) or {
		assert err.msg() == 'named format size requires an unsigned integer or usize-sized optional unsigned integer'
		assert writer.buffered().len == 0 && buffer == before
		return
	}
	assert false
}

fn test_print_rejects_signed_size_before_writer_effects() {
	mut buffer := []u8{len: 64, init: 0xa5}
	mut writer := WriteStream.init_memory(mut buffer)
	before := buffer.clone()
	writer.print('before{d:[width]}', PrintSignedSize{7, 5}) or {
		assert err.msg() == 'named format size requires an unsigned integer or usize-sized optional unsigned integer'
		assert writer.buffered().len == 0 && buffer == before
		return
	}
	assert false
}

struct PrintOne {
	value int
}

fn test_print_runtime_value_rejection_follows_literal_write() {
	mut buffer := []u8{len: 64}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print('before{z}after', PrintOne{7}) or {
		assert err.msg() == 'unsupported print_value integer format'
		assert writer.buffered().bytestr() == 'before'
		return
	}
	assert false
}
