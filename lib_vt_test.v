module main

import osc
import terminal
import terminal_c

fn test_lib_vt_input_paste_api() ! {
	assert input_is_safe_paste('echo hello')
	assert !input_is_safe_paste('echo hello\n')
	encoded := input_encode_paste('hello', InputPasteOptions{
		bracketed: true
	})!
	assert encoded == ['\x1b[200~', 'hello', '\x1b[201~']!
	input_encode_paste('hello\nworld', InputPasteOptions{}) or {
		assert err.msg() == 'MutableRequired'
		return
	}
	assert false, 'expected MutableRequired'
}

fn test_lib_vt_exports_complete_mouse_shapes() {
	assert VtMouseShape.context_menu != VtMouseShape.default_
	assert VtMouseShape.zoom_out != VtMouseShape.zoom_in
}

fn test_lib_vt_native_key_event_and_encoder_exports() {
	mut event := voidptr(unsafe { nil })
	assert ghostty_key_event_new_export(unsafe { nil }, &event) == .success
	assert !isnil(event)
	defer { ghostty_key_event_free_export(event) }

	ghostty_key_event_set_action_export(event, .press)
	ghostty_key_event_set_key_export(event, .key_a)
	ghostty_key_event_set_mods_export(event, 0x0205)
	ghostty_key_event_set_consumed_mods_export(event, 0x0001)
	ghostty_key_event_set_composing_export(event, true)
	text := 'a'
	ghostty_key_event_set_utf8_export(event, text.str, usize(text.len))
	ghostty_key_event_set_unshifted_codepoint_export(event, u32(`a`))

	assert ghostty_key_event_get_action_export(event) == .press
	assert ghostty_key_event_get_key_export(event) == .key_a
	assert ghostty_key_event_get_mods_export(event) == 0x0205
	assert ghostty_key_event_get_consumed_mods_export(event) == 1
	assert ghostty_key_event_get_composing_export(event)
	mut text_len := usize(0)
	text_ptr := ghostty_key_event_get_utf8_export(event, &text_len)
	assert text_len == 1
	assert unsafe { tos(&u8(text_ptr), int(text_len)) } == 'a'
	assert ghostty_key_event_get_unshifted_codepoint_export(event) == u32(`a`)
	ghostty_key_event_set_mods_export(event, 0)
	ghostty_key_event_set_consumed_mods_export(event, 0)
	ghostty_key_event_set_composing_export(event, false)

	mut encoder := voidptr(unsafe { nil })
	assert ghostty_key_encoder_new_export(unsafe { nil }, &encoder) == .success
	assert !isnil(encoder)
	defer { ghostty_key_encoder_free_export(encoder) }
	mut out := []u8{len: 8}
	mut written := usize(0)
	out_ptr := unsafe { &out[0] }
	assert ghostty_key_encoder_encode_export(encoder, event, out_ptr, usize(out.len), &written) == .success
	assert out[..int(written)].bytestr() == 'a'

	mut application_cursor := true
	ghostty_key_encoder_setopt_export(encoder, .cursor_key_application, voidptr(&application_cursor))
	assert unsafe { &terminal_c.KeyEncoder(encoder) }.opts.cursor_key_application
}

fn test_lib_vt_native_osc_paste_and_color_exports() {
	mut parser := voidptr(unsafe { nil })
	assert ghostty_osc_new_export(unsafe { nil }, &parser) == .success
	assert !isnil(parser)
	defer { ghostty_osc_free_export(parser) }
	for byte in '0;title'.bytes() {
		ghostty_osc_next_export(parser, byte)
	}
	command := ghostty_osc_end_export(parser, 0)
	assert !isnil(command)
	assert ghostty_osc_command_type_export(command) == osc.CommandType.change_window_title
	mut title_ptr := voidptr(unsafe { nil })
	assert ghostty_osc_command_data_export(command, .change_window_title_str, &title_ptr)
	assert unsafe { cstring_to_vstring(&char(title_ptr)) } == 'title'

	safe := 'echo hello'
	unsafe_text := 'echo hello\n'
	assert ghostty_paste_is_safe_export(safe.str, usize(safe.len))
	assert !ghostty_paste_is_safe_export(unsafe_text.str, usize(unsafe_text.len))

	mut red := u8(0)
	mut green := u8(0)
	mut blue := u8(0)
	ghostty_color_rgb_get_export(terminal_c.RGB{ r: 1, g: 2, b: 3 }, &red, &green, &blue)
	assert [red, green, blue] == [u8(1), 2, 3]
}

fn test_lib_vt_native_sgr_exports_and_c_projection() {
	mut parser := voidptr(unsafe { nil })
	assert ghostty_sgr_new_export(unsafe { nil }, &parser) == .success
	assert !isnil(parser)
	defer { ghostty_sgr_free_export(parser) }

	params := [u16(1), 38, 2, 0x12, 0x34, 0x56]
	assert ghostty_sgr_set_params_export(parser, &params[0], unsafe { nil }, usize(params.len)) == .success
	mut attr := terminal_c.SgrAttributeC{}
	assert ghostty_sgr_next_export(parser, &attr)
	assert ghostty_sgr_attribute_tag_export(attr) == terminal.SgrAttributeTag.bold
	assert !isnil(ghostty_sgr_attribute_value_export(&attr))
	assert ghostty_sgr_next_export(parser, &attr)
	assert attr.tag == .direct_color_fg
	unsafe {
		value := &u8(&attr.value)
		assert [value[0], value[1], value[2]] == [u8(0x12), 0x34, 0x56]
	}
	assert !ghostty_sgr_next_export(parser, &attr)
	ghostty_sgr_reset_export(parser)
	assert ghostty_sgr_next_export(parser, &attr)

	unknown_params := [u16(38), 7, 1]
	assert ghostty_sgr_set_params_export(parser, &unknown_params[0], unsafe { nil }, usize(unknown_params.len)) == .success
	assert ghostty_sgr_next_export(parser, &attr)
	assert attr.tag == .unknown
	unknown := unsafe { *(&terminal_c.SgrUnknownC(&attr.value)) }
	mut full_ptr := voidptr(unsafe { nil })
	mut partial_ptr := voidptr(unsafe { nil })
	assert ghostty_sgr_unknown_full_export(unknown, &full_ptr) == 3
	assert ghostty_sgr_unknown_partial_export(unknown, &partial_ptr) == 3
	assert unsafe { (&u16(full_ptr))[0] } == 38
	assert unsafe { (&u16(partial_ptr))[0] } == 38
}
