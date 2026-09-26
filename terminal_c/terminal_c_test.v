module terminal_c

import input
import lib_allocator
import terminal

// Tests for terminal_c.v
// Translated from ghostty/src/terminal/c/ test cases.

struct CApiAllocatorState {
mut:
	allocs int
	frees  int
}

fn c_api_test_alloc(ctx voidptr, len usize, _ u8, _ usize) voidptr {
	mut state := unsafe { &CApiAllocatorState(ctx) }
	state.allocs++
	return unsafe { malloc(if len == 0 { usize(1) } else { len }) }
}

fn c_api_test_resize(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) bool {
	return false
}

fn c_api_test_remap(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) voidptr {
	return unsafe { nil }
}

fn c_api_test_free(ctx voidptr, memory voidptr, _ usize, _ u8, _ usize) {
	mut state := unsafe { &CApiAllocatorState(ctx) }
	state.frees++
	unsafe { free(memory) }
}

fn test_c_api_objects_use_supplied_allocator() {
	mut state := CApiAllocatorState{}
	vtable := lib_allocator.VTable{
		alloc: c_api_test_alloc
		resize: c_api_test_resize
		remap: c_api_test_remap
		free_fn: c_api_test_free
	}
	allocator := lib_allocator.Allocator{
		ctx: &state
		vtable: &vtable
	}

	event_status, mut event := key_event_new_alloc(&allocator)
	assert event_status == .success
	assert !isnil(event)
	key_event_free(mut event)

	encoder_status, mut encoder := key_encoder_new_alloc(&allocator)
	assert encoder_status == .success
	assert !isnil(encoder)
	key_encoder_free(mut encoder)

	osc_status, mut osc_parser := osc_new_alloc(&allocator)
	assert osc_status == .success
	assert !isnil(osc_parser)
	osc_free_alloc(mut osc_parser)

	sgr_status, mut sgr_parser := sgr_new_alloc(&allocator)
	assert sgr_status == .success
	assert !isnil(sgr_parser)
	assert sgr_parser.set_params([u16(1)], none) == .success
	assert sgr_parser.set_params([u16(38), 7, 1], none) == .success
	unknown := sgr_parser.next() or { panic('expected unknown SGR attribute') }
	assert (unknown as terminal.SgrUnknown).full == [u16(38), 7, 1]
	sgr_free(mut sgr_parser)

	// Four wrapper objects plus both SGR parameter copies. Replacing the first
	// parameter list frees it immediately; destruction frees the second.
	assert state.allocs == 6
	assert state.frees == 6
}

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

fn test_sgr_c_projection_layout_and_payloads() {
	assert sizeof(SgrUnknownC) == sizeof(voidptr) * 4
	assert sizeof(SgrAttributeValueC) == 64
	assert sizeof(SgrAttributeC) == 72

	underline := sgr_attribute_cval(terminal.SgrUnderline{ style: .curly })
	assert underline.tag == .underline
	unsafe {
		assert *(&i32(&underline.value)) == i32(terminal.UnderlineStyle.curly)
	}

	color := sgr_attribute_cval(terminal.SgrDirectColorFg{ rgb: terminal.RGB{ r: 0x12, g: 0x34, b: 0x56 } })
	unsafe {
		bytes := &u8(&color.value)
		assert bytes[0] == 0x12
		assert bytes[1] == 0x34
		assert bytes[2] == 0x56
	}

	// Bright 8-color attributes carry the bright palette name.
	assert sgr_parser_bright_fg_cval() == 9

	params := [u16(38), 7, 1]
	unknown_attr := sgr_attribute_cval(terminal.SgrUnknown{ full: params, partial: params[1..] })
	unsafe {
		unknown := &SgrUnknownC(&unknown_attr.value)
		full, full_len := sgr_unknown_full(*unknown)
		partial, partial_len := sgr_unknown_partial(*unknown)
		assert full_len == 3
		assert partial_len == 2
		assert full[0] == 38
		assert partial[0] == 7
	}
}

fn sgr_parser_bright_fg_cval() u8 {
	mut parser := sgr_new()
	defer { sgr_free(mut parser) }
	assert parser.set_params([u16(91)], none) == .success
	attr := parser.next() or { panic('expected bright foreground attribute') }
	c := sgr_attribute_cval(attr)
	assert c.tag == .bright_fg_8
	return unsafe { *(&u8(&c.value)) }
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
	assert attribute_value(attr) is terminal.SgrBold
	assert parser.next() == none

	parser.reset()
	assert (parser.next() or { return }) is terminal.SgrBold
}

fn test_sgr_parser_colons_and_unknown_payload() {
	mut parser := sgr_new()
	defer { sgr_free(mut parser) }
	assert parser.set_params([u16(38), 2, 0, 1, 2, 3], [u8(`:`), `:`, `:`, `:`, `:`, `;`]) == .success
	attr := parser.next() or { return }
	assert attr.tag() == .direct_color_fg
	assert (attr as terminal.SgrDirectColorFg).rgb.r == 1
	assert (attr as terminal.SgrDirectColorFg).rgb.g == 2
	assert (attr as terminal.SgrDirectColorFg).rgb.b == 3

	assert parser.set_params([u16(38), 7, 1], none) == .success
	unknown := parser.next() or { return }
	assert unknown_full(unknown as terminal.SgrUnknown) == [u16(38), 7, 1]
	assert unknown_partial(unknown as terminal.SgrUnknown) == [u16(38), 7, 1]
}

fn test_sgr_parser_rejects_invalid_separator_length() {
	mut parser := sgr_new()
	defer { sgr_free(mut parser) }
	assert parser.set_params([u16(1), 2], [u8(`;`)]) == .invalid_value
}

fn test_sgr_wasm_attribute_allocation_helpers() {
	attr := wasm_alloc_attribute()
	assert attr != unsafe { nil }
	assert attr.tag == .unset
	wasm_free_attribute(attr)
}
