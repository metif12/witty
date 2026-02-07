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
