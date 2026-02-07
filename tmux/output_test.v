module tmux

// Tests for tmux output variable parsing.
//
// Source: terminal/tmux/output.zig (tests)

fn test_parse_alternate_on() {
	v := Variable.alternate_on.parse('1') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as bool == true

	v2 := Variable.alternate_on.parse('0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as bool == false

	v3 := Variable.alternate_on.parse('') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v3 as bool == false

	v4 := Variable.alternate_on.parse('true') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v4 as bool == false
}

fn test_parse_cursor_x() {
	v := Variable.cursor_x.parse('0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 0

	v2 := Variable.cursor_x.parse('79') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 79
}

fn test_parse_session_id() {
	v := Variable.session_id.parse('\$42') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 42

	v2 := Variable.session_id.parse('\$0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 0

	// Should fail without $ prefix
	Variable.session_id.parse('0') or {
		// Expected
		return
	}
	assert false, 'expected error for session_id without \$'
}

fn test_parse_window_id() {
	v := Variable.window_id.parse('@42') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 42

	v2 := Variable.window_id.parse('@0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 0

	// Should fail without @ prefix
	Variable.window_id.parse('0') or {
		// Expected
		return
	}
	assert false, 'expected error for window_id without @'
}

fn test_parse_pane_id() {
	v := Variable.pane_id.parse('%42') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 42

	v2 := Variable.pane_id.parse('%0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 0

	// Should fail without % prefix
	Variable.pane_id.parse('0') or {
		// Expected
		return
	}
	assert false, 'expected error for pane_id without %'
}

fn test_parse_window_layout() {
	v := Variable.window_layout.parse('abc123') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as string == 'abc123'

	v2 := Variable.window_layout.parse('') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as string == ''
}

fn test_parse_cursor_colour() {
	v := Variable.cursor_colour.parse('red') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as string == 'red'

	v2 := Variable.cursor_colour.parse('#ff0000') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as string == '#ff0000'
}

fn test_parse_cursor_shape() {
	v := Variable.cursor_shape.parse('block') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as string == 'block'
}

fn test_parse_version() {
	v := Variable.version.parse('3.5a') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as string == '3.5a'
}

fn test_parse_window_width() {
	v := Variable.window_width.parse('80') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 80
}

fn test_parse_window_height() {
	v := Variable.window_height.parse('24') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 24
}

fn test_parse_bool_flags() {
	// Test all boolean flags
	flags := [
		Variable.bracketed_paste,
		Variable.cursor_blinking,
		Variable.cursor_flag,
		Variable.focus_flag,
		Variable.insert_flag,
		Variable.keypad_cursor_flag,
		Variable.keypad_flag,
		Variable.mouse_all_flag,
		Variable.mouse_any_flag,
		Variable.mouse_button_flag,
		Variable.mouse_sgr_flag,
		Variable.mouse_standard_flag,
		Variable.mouse_utf8_flag,
		Variable.origin_flag,
		Variable.wrap_flag,
	]
	for f in flags {
		v1 := f.parse('1') or {
			assert false, 'parse failed for ${f}: ${err}'
			continue
		}
		assert v1 as bool == true

		v0 := f.parse('0') or {
			assert false, 'parse failed for ${f}: ${err}'
			continue
		}
		assert v0 as bool == false
	}
}

fn test_format_single_variable() {
	result := format_variables([Variable.session_id], ` `)
	assert result == '#\{session_id\}'
}

fn test_format_multiple_variables() {
	result := format_variables([Variable.session_id, Variable.window_id, Variable.window_width, Variable.window_height], ` `)
	assert result == '#\{session_id\} #\{window_id\} #\{window_width\} #\{window_height\}'
}

fn test_format_with_comma_delimiter() {
	result := format_variables([Variable.window_id, Variable.window_layout], `,`)
	assert result == '#\{window_id\},#\{window_layout\}'
}

fn test_format_empty_variables() {
	result := format_variables([], ` `)
	assert result == ''
}

fn test_parse_format_struct_single_field() {
	result := parse_format_struct([Variable.session_id], '\$42', ` `) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert result.get_int(.session_id) or { -1 } == 42
}

fn test_parse_format_struct_multiple_fields() {
	result := parse_format_struct(
		[Variable.session_id, Variable.window_id, Variable.window_width, Variable.window_height],
		'\$1 @2 80 24',
		` `
	) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert result.get_int(.session_id) or { -1 } == 1
	assert result.get_int(.window_id) or { -1 } == 2
	assert result.get_int(.window_width) or { -1 } == 80
	assert result.get_int(.window_height) or { -1 } == 24
}

fn test_parse_format_struct_missing_entry() {
	parse_format_struct([Variable.session_id, Variable.window_id], '\$1', ` `) or {
		assert err.msg().contains('Missing')
		return
	}
	assert false, 'expected MissingEntry error'
}

fn test_parse_format_struct_extra_entry() {
	parse_format_struct([Variable.session_id], '\$1 @2', ` `) or {
		assert err.msg().contains('Extra')
		return
	}
	assert false, 'expected ExtraEntry error'
}
