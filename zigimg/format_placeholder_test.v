module zigimg

fn test_format_placeholder_parses_named_fields_and_owns_input_storage() {
	mut bytes := '[value]x:0>[width].[precision]'.bytes()
	value := FormatPlaceholder.parse(bytes)!
	assert value.specifier_arg.bytestr() == 'x'
	assert value.fill == `0` && value.alignment == .right
	if value.arg is FormatNamed {
		assert value.arg.bytes.bytestr() == 'value'
	} else {
		assert false
	}
	if value.width is FormatNamed {
		assert value.width.bytes.bytestr() == 'width'
	} else {
		assert false
	}
	if value.precision is FormatNamed {
		assert value.precision.bytes.bytestr() == 'precision'
	} else {
		assert false
	}
	for i in 0 .. bytes.len {
		bytes[i] = `!`
	}
	assert value.specifier_arg.bytestr() == 'x'
	if value.arg is FormatNamed {
		assert value.arg.bytes.bytestr() == 'value'
	} else {
		assert false
	}
}

fn test_format_placeholder_preserves_leading_zero_fill_and_empty_precision() {
	value := FormatPlaceholder.parse('12d:005.'.bytes())!
	if value.arg is FormatNumber {
		assert value.arg.value == 12
	} else {
		assert false
	}
	if value.width is FormatNumber {
		assert value.width.value == 5
	} else {
		assert false
	}
	assert value.precision is FormatNone
	assert value.fill == `0` && value.alignment == .right
	assert value.specifier_arg.bytestr() == 'd'
}

fn test_format_placeholder_rejects_malformed_width_before_precision() {
	FormatPlaceholder.parse('d:[width'.bytes()) or {
		assert err.msg() == 'Expected closing ]'
		return
	}
	assert false
}
