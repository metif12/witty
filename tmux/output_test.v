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

// ============================================================
// Additional integer-variable parse tests (translated from
// ghostty output.zig).
// ============================================================

fn test_parse_alternate_saved_x() {
	v := Variable.alternate_saved_x.parse('0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 0

	v2 := Variable.alternate_saved_x.parse('42') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 42

	// Non-numeric input must fail.
	Variable.alternate_saved_x.parse('abc') or { return }
	assert false, 'expected error for alternate_saved_x "abc"'
}

fn test_parse_alternate_saved_y() {
	v := Variable.alternate_saved_y.parse('0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 0

	v2 := Variable.alternate_saved_y.parse('42') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 42

	Variable.alternate_saved_y.parse('abc') or { return }
	assert false, 'expected error for alternate_saved_y "abc"'
}

fn test_parse_cursor_y() {
	v := Variable.cursor_y.parse('0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 0

	v2 := Variable.cursor_y.parse('23') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 23

	Variable.cursor_y.parse('abc') or { return }
	assert false, 'expected error for cursor_y "abc"'
}

fn test_parse_scroll_region_upper() {
	v := Variable.scroll_region_upper.parse('0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 0

	v2 := Variable.scroll_region_upper.parse('5') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 5

	Variable.scroll_region_upper.parse('abc') or { return }
	assert false, 'expected error for scroll_region_upper "abc"'
}

fn test_parse_scroll_region_lower() {
	v := Variable.scroll_region_lower.parse('0') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v as int == 0

	v2 := Variable.scroll_region_lower.parse('23') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert v2 as int == 23

	Variable.scroll_region_lower.parse('abc') or { return }
	assert false, 'expected error for scroll_region_lower "abc"'
}

fn test_parse_cursor_x_invalid() {
	Variable.cursor_x.parse('abc') or { return }
	assert false, 'expected error for cursor_x "abc"'
}

// ============================================================
// Full integer-error tests for window width/height, session,
// window and pane IDs.
// ============================================================

fn test_parse_window_width_full() {
	assert (Variable.window_width.parse('80') or { VariableValue(-1) }) as int == 80
	assert (Variable.window_width.parse('0') or { VariableValue(-1) }) as int == 0
	assert (Variable.window_width.parse('12345') or { VariableValue(-1) }) as int == 12345

	Variable.window_width.parse('abc') or {
		Variable.window_width.parse('80px') or {
			Variable.window_width.parse('-1') or { return }
			assert false, 'expected error for window_width "-1"'
			return
		}
		assert false, 'expected error for window_width "80px"'
		return
	}
	assert false, 'expected error for window_width "abc"'
}

fn test_parse_window_height_full() {
	assert (Variable.window_height.parse('24') or { VariableValue(-1) }) as int == 24
	assert (Variable.window_height.parse('0') or { VariableValue(-1) }) as int == 0
	assert (Variable.window_height.parse('12345') or { VariableValue(-1) }) as int == 12345

	Variable.window_height.parse('abc') or {
		Variable.window_height.parse('24px') or {
			Variable.window_height.parse('-1') or { return }
			assert false, 'expected error for window_height "-1"'
			return
		}
		assert false, 'expected error for window_height "24px"'
		return
	}
	assert false, 'expected error for window_height "abc"'
}

fn test_parse_session_id_full() {
	assert (Variable.session_id.parse('\$42') or { VariableValue(-1) }) as int == 42
	assert (Variable.session_id.parse('\$0') or { VariableValue(-1) }) as int == 0
	// Wrong / missing prefixes and non-numeric bodies must all fail.
	Variable.session_id.parse('0') or {
		Variable.session_id.parse('@0') or {
			Variable.session_id.parse('\$') or {
				Variable.session_id.parse('') or {
					Variable.session_id.parse('\$abc') or { return }
					assert false, 'expected error for session_id "\$abc"'
					return
				}
				assert false, 'expected error for session_id ""'
				return
			}
			assert false, 'expected error for session_id "\$"'
			return
		}
		assert false, 'expected error for session_id "@0"'
		return
	}
	assert false, 'expected error for session_id "0"'
}

fn test_parse_window_id_full() {
	assert (Variable.window_id.parse('@42') or { VariableValue(-1) }) as int == 42
	assert (Variable.window_id.parse('@0') or { VariableValue(-1) }) as int == 0
	assert (Variable.window_id.parse('@12345') or { VariableValue(-1) }) as int == 12345
	Variable.window_id.parse('0') or {
		Variable.window_id.parse('\$0') or {
			Variable.window_id.parse('@') or {
				Variable.window_id.parse('') or {
					Variable.window_id.parse('@abc') or { return }
					assert false, 'expected error for window_id "@abc"'
					return
				}
				assert false, 'expected error for window_id ""'
				return
			}
			assert false, 'expected error for window_id "@"'
			return
		}
		assert false, 'expected error for window_id "\$0"'
		return
	}
	assert false, 'expected error for window_id "0"'
}

fn test_parse_pane_id_full() {
	assert (Variable.pane_id.parse('%42') or { VariableValue(-1) }) as int == 42
	assert (Variable.pane_id.parse('%0') or { VariableValue(-1) }) as int == 0
	Variable.pane_id.parse('0') or {
		Variable.pane_id.parse('@0') or {
			Variable.pane_id.parse('%') or {
				Variable.pane_id.parse('') or {
					Variable.pane_id.parse('%abc') or { return }
					assert false, 'expected error for pane_id "%abc"'
					return
				}
				assert false, 'expected error for pane_id ""'
				return
			}
			assert false, 'expected error for pane_id "%"'
			return
		}
		assert false, 'expected error for pane_id "@0"'
		return
	}
	assert false, 'expected error for pane_id "0"'
}

// ============================================================
// Bool flag edge cases: empty and non-"1" strings are false.
// ============================================================

fn test_parse_bool_flags_edge_values() {
	flags := [
		Variable.alternate_on,
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
		// Only the exact string "1" is true.
		assert (f.parse('1') or {
			assert false, 'parse failed for ${f}: ${err}'
			VariableValue(false)
		}) as bool == true
		for s in ['0', '', 'true', 'yes'] {
			assert (f.parse(s) or {
				assert false, 'parse failed for ${f} ${s}: ${err}'
				VariableValue(false)
			}) as bool == false
		}
	}
}

// ============================================================
// String variable: pane_tabs.
// ============================================================

fn test_parse_pane_tabs() {
	assert (Variable.pane_tabs.parse('0,8,16,24') or {
		assert false, 'parse failed: ${err}'
		VariableValue('')
	}) as string == '0,8,16,24'
	assert (Variable.pane_tabs.parse('') or {
		assert false, 'parse failed: ${err}'
		VariableValue('')
	}) as string == ''
	assert (Variable.pane_tabs.parse('0') or {
		assert false, 'parse failed: ${err}'
		VariableValue('')
	}) as string == '0'
}

// ============================================================
// Additional format tests.
// ============================================================

fn test_format_with_tab_delimiter() {
	result := format_variables([Variable.window_width, Variable.window_height], `\t`)
	assert result == '#\{window_width\}\t#\{window_height\}'
}

fn test_format_all_variables() {
	result := format_variables([Variable.session_id, Variable.window_id, Variable.window_width,
		Variable.window_height, Variable.window_layout], ` `)
	assert result == '#\{session_id\} #\{window_id\} #\{window_width\} #\{window_height\} #\{window_layout\}'
}

// ============================================================
// Additional parse_format_struct tests.
// ============================================================

fn test_parse_format_struct_with_string_field() {
	result := parse_format_struct([Variable.window_id, Variable.window_layout], '@5,abc123',
		`,`) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert result.get_int(.window_id) or { -1 } == 5
	assert result.get_string(.window_layout) or { 'X' } == 'abc123'
}

fn test_parse_format_struct_different_delimiter() {
	result := parse_format_struct([Variable.window_width, Variable.window_height], '120\t40',
		`\t`) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert result.get_int(.window_width) or { -1 } == 120
	assert result.get_int(.window_height) or { -1 } == 40
}

fn test_parse_format_struct_format_error() {
	parse_format_struct([Variable.session_id], '42', ` `) or {
		assert err.msg().contains('Format')
		parse_format_struct([Variable.session_id], '@42', ` `) or {
			assert err.msg().contains('Format')
			parse_format_struct([Variable.session_id], '\$abc', ` `) or {
				assert err.msg().contains('Format')
				return
			}
			assert false, 'expected FormatError for "\$abc"'
			return
		}
		assert false, 'expected FormatError for "@42"'
		return
	}
	assert false, 'expected FormatError for "42"'
}

fn test_parse_format_struct_empty_string() {
	parse_format_struct([Variable.session_id], '', ` `) or {
		assert err.msg().contains('Format')
		return
	}
	assert false, 'expected FormatError for empty string'
}

fn test_parse_format_struct_with_empty_layout_field() {
	result := parse_format_struct([Variable.session_id, Variable.window_layout], '\$1,', `,`) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert result.get_int(.session_id) or { -1 } == 1
	assert result.get_string(.window_layout) or { 'X' } == ''
}
