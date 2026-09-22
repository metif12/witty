module terminal_c

import input

// Tests for terminal_c.v
// Translated from ghostty/src/terminal/c/ test cases.

// ============================================================
// Result tests (from c/result.zig)
// ============================================================

fn test_result_values() {
	assert sizeof(Result) == 4
	assert Result.success != Result.out_of_memory
	assert Result.success != Result.invalid_value
	assert Result.out_of_memory != Result.invalid_value
	assert i32(Result.success) == 0
	assert i32(Result.out_of_memory) == -1
	assert i32(Result.invalid_value) == -2
}

fn test_osc_command_data_c_layout_and_ordinals() {
	assert sizeof(CommandData) == 4
	assert [CommandData.invalid, .change_window_title_str].map(i32(it)) == [i32(0), 1]
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
// Key event tests (from c/key_event.zig)
// ============================================================

fn test_key_event_set_and_get() {
	mut event := key_event_new()
	defer { key_event_free(mut event) }

	event.set_action(.repeat)
	event.set_key(.key_z)
	event.set_mods(input.Mods.init(false, false, true, true, false, false, input.SideInfo{}))
	event.set_consumed_mods(input.Mods.init(false, false, true, false, false, false, input.SideInfo{}))
	event.set_composing(true)
	event.set_utf8('test')
	event.set_unshifted_codepoint(u32(`z`))

	assert event.get_action() == .repeat
	assert event.get_key() == .key_z
	assert event.get_mods().alt()
	assert event.get_mods().super_()
	assert event.get_consumed_mods().alt()
	assert !event.get_consumed_mods().super_()
	assert event.get_composing()
	assert event.get_utf8() == 'test'
	assert event.get_unshifted_codepoint() == u32(`z`)
}

fn test_key_event_utf8_can_be_cleared() {
	mut event := key_event_new()
	defer { key_event_free(mut event) }
	event.set_utf8('hello')
	assert event.get_utf8() == 'hello'
	event.set_utf8('')
	assert event.get_utf8() == ''
}

// ============================================================
// Key encoder tests (from c/key_encode.zig)
// ============================================================

fn test_key_encoder_options() {
	mut encoder := key_encoder_new()
	defer { key_encoder_free(mut encoder) }
	encoder.setopt(.cursor_key_application, KeyEncoderOptionValue(true))
	encoder.setopt(.keypad_key_application, KeyEncoderOptionValue(true))
	encoder.setopt(.kitty_flags, KeyEncoderOptionValue(u8(3)))
	encoder.setopt(.macos_option_as_alt, KeyEncoderOptionValue(input.OptionAsAlt.left))
	assert encoder.opts.cursor_key_application
	assert encoder.opts.keypad_key_application
	assert encoder.opts.kitty_flags.disambiguate()
	assert encoder.opts.kitty_flags.report_events()
	assert !encoder.opts.kitty_flags.report_alternates()
	assert encoder.opts.macos_option_as_alt == .left
}

fn test_key_encoder_fixed_buffer_and_required_size() {
	mut encoder := key_encoder_new()
	defer { key_encoder_free(mut encoder) }
	mut event := key_event_new()
	defer { key_event_free(mut event) }
	event.set_action(.press)
	event.set_key(.key_a)
	event.set_utf8('a')
	event.set_unshifted_codepoint(u32(`a`))

	mut too_small := []u8{}
	status_small, required := encoder.encode(event, mut too_small)
	assert status_small == .out_of_memory
	assert required == 1

	mut out := []u8{len: int(required)}
	status, written := encoder.encode(event, mut out)
	assert status == .success
	assert written == 1
	assert out[..int(written)].bytestr() == 'a'
}

// ============================================================
// OSC parser tests (from c/osc.zig)
// ============================================================

fn test_osc_new() {
	mut p := osc_new()
	osc_free(mut p)
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

fn test_osc_change_window_title() {
	mut parser := osc_new()
	defer { osc_free(mut parser) }
	parser.next(`0`)
	parser.next(`;`)
	parser.next(`a`)
	cmd := parser.end(0)
	assert command_type(cmd) == .change_window_title
	assert (command_data(cmd, .change_window_title_str) or { '' }) == 'a'
	assert command_type(none) == .invalid
}

fn test_osc_c_parser_is_allocation_enabled() {
	mut parser := osc_new()
	defer { osc_free(mut parser) }
	for ch in '21;foreground=?'.bytes() {
		parser.next(ch)
	}
	cmd := parser.end(0x1b)
	assert command_type(cmd) == .kitty_color_protocol
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
	assert attribute_tag(attr) == .bold
	assert attribute_value(attr).kind == .bold
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
	assert unknown_full(unknown) == [u16(38), 7, 1]
	assert unknown_partial(unknown) == [u16(38), 7, 1]
}

fn test_sgr_parser_rejects_invalid_separator_length() {
	mut parser := sgr_new()
	defer { sgr_free(mut parser) }
	assert parser.set_params([u16(1), 2], [u8(`;`)]) == .invalid_value
}

fn test_sgr_wasm_attribute_allocation_helpers() {
	attr := wasm_alloc_attribute()
	assert attr != unsafe { nil }
	assert attr.kind == .unset
	wasm_free_attribute(attr)
}
