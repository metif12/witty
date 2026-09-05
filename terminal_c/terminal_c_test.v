module terminal_c

// Tests for terminal_c.v
// Translated from ghostty/src/terminal/c/ test cases.

// ============================================================
// Result tests (from c/result.zig)
// ============================================================

fn test_result_values() {
	assert Result.success != Result.out_of_memory
	assert Result.success != Result.invalid_value
	assert Result.out_of_memory != Result.invalid_value
	assert i32(Result.success) == 0
	assert i32(Result.out_of_memory) == -1
	assert i32(Result.invalid_value) == -2
}

// ============================================================
// Color tests (from c/color.zig)
// ============================================================

fn test_rgb_get() {
	c := RGB{ r: 0xAA, g: 0xBB, b: 0xCC }
	r, g, b := rgb_get(c)
	assert r == 0xAA
	assert g == 0xBB
	assert b == 0xCC
}

fn test_rgb_get_zero() {
	c := RGB{ r: 0, g: 0, b: 0 }
	r, g, b := rgb_get(c)
	assert r == 0
	assert g == 0
	assert b == 0
}

fn test_rgb_get_max() {
	c := RGB{ r: 255, g: 255, b: 255 }
	r, g, b := rgb_get(c)
	assert r == 255
	assert g == 255
	assert b == 255
}

// ============================================================
// Paste tests (from c/paste.zig)
// ============================================================

fn test_paste_is_safe_with_safe_data() {
	assert paste_is_safe('hello world') == true
}

fn test_paste_is_safe_with_newline() {
	assert paste_is_safe('hello\nworld') == false
}

fn test_paste_is_safe_with_bracketed_paste_end() {
	assert paste_is_safe('hello\x1b[201~world') == false
}

fn test_paste_is_safe_with_empty_data() {
	assert paste_is_safe('') == true
}

// ============================================================
// OSC parser tests (from c/osc.zig)
// ============================================================

fn test_osc_new() {
	p := osc_new()
	// Just verify it can be created without panicking.
	_ = p
}

fn test_command_data_invalid() {
	// Null command should return none.
	result := command_data(none, .invalid)
	assert result == none
}

fn test_command_data_no_command() {
	result := command_data(none, .change_window_title_str)
	assert result == none
}

// ============================================================
// SGR parser tests (from c/sgr.zig)
// ============================================================

fn test_sgr_parser_lifecycle_and_params() {
	mut parser := sgr_new()
	defer { sgr_free(mut parser) }
	assert parser.set_params([u16(1)], none) == .success
	attr := parser.next() or {
		assert false, 'expected bold attribute'
		return
	}
	assert sgr_attribute_tag(attr) == .bold
	assert sgr_attribute_value(attr).kind == .bold
	assert parser.next() == none

	parser.reset()
	assert (parser.next() or { return }).kind == .bold
}

fn test_sgr_parser_colons_and_unknown_payload() {
	mut parser := sgr_new()
	defer { sgr_free(mut parser) }
	assert parser.set_params([u16(38), 2, 0, 1, 2, 3], [u8(`:`), `:`, `:`, `:`, `:`, `;`]) == .success
	attr := parser.next() or { return }
	assert attr.kind == .direct_color_fg
	assert attr.r == 1
	assert attr.g == 2
	assert attr.b == 3

	assert parser.set_params([u16(38), 7, 1], none) == .success
	unknown := parser.next() or { return }
	assert sgr_unknown_full(unknown) == [u16(38), 7, 1]
	assert sgr_unknown_partial(unknown) == [u16(38), 7, 1]
}

fn test_sgr_parser_rejects_invalid_separator_length() {
	mut parser := sgr_new()
	defer { sgr_free(mut parser) }
	assert parser.set_params([u16(1), 2], [u8(`;`)]) == .invalid_value
}
