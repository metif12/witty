module zigimg

fn test_format_parser_preserves_borrowed_names_and_delimiter_position() {
	mut bytes := '[name]:42!'.bytes()
	mut parser := FormatParser{
		bytes: unsafe { bytes }
		i:     0
	}
	mut spec := parser.specifier()!
	assert parser.i == 6
	if mut spec is FormatNamed {
		assert spec.bytes.bytestr() == 'name'
		bytes[1] = `N`
		assert spec.bytes.bytestr() == 'Name'
		spec.bytes[2] = `M`
		assert bytes.bytestr() == '[NaMe]:42!'
	} else {
		assert false
	}
	assert parser.maybe(`:`)
	assert parser.number()? == 42
	assert parser.char()? == `!`
	assert parser.char() == none
}

fn test_format_parser_error_retains_consumed_name_and_empty_number_does_not_advance() {
	mut parser := FormatParser{
		bytes: '[missing'.bytes()
		i:     0
	}
	parser.specifier() or {
		assert err.msg() == 'Expected closing ]'
		assert parser.i == 8
		assert parser.number() == none
		return
	}
	assert false
}

fn test_format_argument_tracker_explicit_indices_leave_automatic_cursor() {
	mut state := FormatArgState{
		args_len: 3
	}
	assert state.next_arg(usize(2))? == 2
	assert state.next_arg == 0
	assert state.next_arg(none)? == 0
	assert state.has_unused_args()
	assert state.next_arg(none)? == 1
	assert !state.has_unused_args()
	assert state.next_arg(none)? == 2
	assert state.next_arg(none) == none
	assert state.next_arg == 4
	assert state.used_args == 7
}
