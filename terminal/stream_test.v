module terminal

import osc

// Tests for the Stream VT escape sequence processor.
// Translated from Ghostty's stream.zig test suite.

// ============================================================
// Test helpers
// ============================================================

// has_event checks if any event with the given key exists.
fn has_event(events []StreamEvent, key ActionKey) bool {
	for e in events {
		if e.key == key {
			return true
		}
	}
	return false
}

// get_last_event returns the last event with the given key.
// Caller should check has_event() first.
fn get_last_event(events []StreamEvent, key ActionKey) StreamEvent {
	mut result := StreamEvent{}
	for e in events {
		if e.key == key {
			result = e
		}
	}
	return result
}

// ============================================================
// Tests
// ============================================================

// Test that a simple ASCII character produces a print event.
fn test_stream_print() {
	mut s := Stream.init()
	s.next_slice('x'.bytes())
	assert s.events.len == 1
	assert s.events[0].key == .print
	assert s.events[0].payload.cp == u32(`x`)
	assert s.raw_events.len == 0
}

// The inspector slow path consumes every parser action alongside the semantic
// stream, including actions whose terminal handlers intentionally do nothing.
fn test_stream_collects_raw_parser_actions() {
	mut s := Stream.init()
	s.capture_raw = true
	defer {
		s.deinit()
	}

	s.next_slice('x\a\x1b[5C\x1b]0;title\a'.bytes())
	assert s.raw_events.len == 4
	assert s.raw_events[0].action_type == .print_action
	assert s.raw_events[0].char == u32(`x`)
	assert s.raw_events[1].action_type == .execute_action
	assert s.raw_events[1].byte_val == 0x07
	assert s.raw_events[2].action_type == .csi_dispatch_action
	assert s.raw_events[2].csi.params == [u16(5)]
	assert s.raw_events[2].csi.final_byte == u8(`C`)
	assert s.raw_events[3].action_type == .osc_dispatch_action
	assert s.raw_events[3].osc.cmd_type == .change_window_title
	assert s.raw_events[3].osc.str_value == 'title'
	s.clear_events()
	assert s.events.len == 0
	assert s.raw_events.len == 0
}

fn test_stream_preserves_osc_terminator_for_color_responses() {
	mut s := Stream.init()
	defer { s.deinit() }

	s.next_slice('\x1b]10;?\a'.bytes())
	color := get_last_event(s.events, .color_operation)
	assert color.payload.osc_terminator == .bel
	assert color.payload.color_op == .osc_10
	assert color.payload.color_requests.len == 1
	request := color.payload.color_requests[0]
	assert request is osc.ColorRequestQuery
	if request is osc.ColorRequestQuery {
		assert request.target is osc.ColorTargetDynamic
		if request.target is osc.ColorTargetDynamic {
			assert request.target.color == .foreground
		}
	}

	s.clear_events()
	s.next_slice('\x1b]21;foreground=?\x1b\\'.bytes())
	kitty := get_last_event(s.events, .kitty_color_report)
	assert kitty.payload.osc_terminator == .st
	assert kitty.payload.kitty_color_items.len == 1
	assert kitty.payload.kitty_color_items[0].item_type == .query
	assert kitty.payload.kitty_color_items[0].key.kind == .special
	assert kitty.payload.kitty_color_items[0].key.special == .foreground
}

fn test_stream_carries_typed_semantic_and_progress_actions() {
	mut s := Stream.init()
	defer { s.deinit() }

	s.next_slice('\x1b]133;D;err=23\a'.bytes())
	semantic := get_last_event(s.events, .semantic_prompt)
	assert semantic.payload.semantic_prompt_action == .end_command
	assert semantic.payload.semantic_prompt_opts == 'err=23'

	s.clear_events()
	s.next_slice('\x1b]9;4;1;900\a'.bytes())
	progress := get_last_event(s.events, .progress_report)
	assert progress.payload.progress_report.state == .set
	assert progress.payload.progress_report.progress? == 100
}

fn test_stream_carries_typed_desktop_notifications() {
	mut s := Stream.init()
	defer { s.deinit() }

	s.next_slice('\x1b]9;Build complete\a'.bytes())
	iterm := get_last_event(s.events, .show_desktop_notification)
	assert iterm.payload.desktop_notification.title == ''
	assert iterm.payload.desktop_notification.body == 'Build complete'

	s.clear_events()
	s.next_slice('\x1b]777;notify;Compiler;Build failed\x1b\\'.bytes())
	rxvt := get_last_event(s.events, .show_desktop_notification)
	assert rxvt.payload.desktop_notification.title == 'Compiler'
	assert rxvt.payload.desktop_notification.body == 'Build failed'
}

fn test_stream_carries_typed_clipboard_and_hyperlink_actions() {
	mut s := Stream.init()
	defer { s.deinit() }

	s.next_slice('\x1b]52;s;?\a'.bytes())
	clipboard := get_last_event(s.events, .clipboard_contents)
	assert clipboard.payload.clipboard.kind == `s`
	assert clipboard.payload.clipboard.data == '?'

	s.clear_events()
	s.next_slice('\x1b]8;id=build;https://example.com\x1b\\'.bytes())
	hyperlink := get_last_event(s.events, .start_hyperlink)
	assert hyperlink.payload.hyperlink.uri == 'https://example.com'
	assert hyperlink.payload.hyperlink.id? == 'build'

	s.clear_events()
	s.next_slice('\x1b]8;;https://example.com\x1b\\'.bytes())
	without_id := get_last_event(s.events, .start_hyperlink)
	assert without_id.payload.hyperlink.id == none
}

// Test that invalid UTF-8 byte 0xFF produces replacement character U+FFFD.
fn test_simd_print_invalid_utf8() {
	mut s := Stream.init()
	s.next_slice([u8(0xFF)])
	assert has_event(s.events, .print)
	ev := get_last_event(s.events, .print)
	assert ev.payload.cp == 0xFFFD
}

// Test that an incomplete multi-byte UTF-8 sequence completes
// when the remaining bytes arrive in subsequent calls.
fn test_simd_complete_incomplete_utf8() {
	mut s := Stream.init()
	// 3-byte sequence for U+0800: 0xE0 0xA0 0x80
	s.next_slice([u8(0xE0)])
	assert !has_event(s.events, .print)

	s.next_slice([u8(0xA0)])
	assert !has_event(s.events, .print)

	s.next_slice([u8(0x80)])
	assert has_event(s.events, .print)
	ev := get_last_event(s.events, .print)
	assert ev.payload.cp == 0x800
}

fn test_simd_next_slice_crosses_internal_chunk_boundary() {
	mut s := Stream.init()
	input := 'x'.repeat(5000).bytes()
	s.next_slice(input)
	assert s.events.len == 5000
	assert s.events[0].key == .print
	assert s.events.last().payload.cp == u32(`x`)
}

fn test_simd_escape_sequence_crosses_internal_chunk_boundary() {
	mut s := Stream.init()
	input := ('x'.repeat(4095) + '\x1b[5C').bytes()
	s.next_slice(input)
	assert s.events.len == 4096
	assert s.events.last().key == .cursor_right
	assert s.events.last().payload.num == 5
}

fn test_simd_utf8_sequence_crosses_internal_chunk_boundary() {
	mut s := Stream.init()
	input := ('x'.repeat(4095) + '€y').bytes()
	s.next_slice(input)
	assert s.events.len == 4097
	assert s.events[4095].payload.cp == 0x20ac
	assert s.events[4096].payload.cp == u32(`y`)
}

// Test CUF (Cursor Forward/Right) CSI sequence.
fn test_stream_cursor_right() {
	mut s := Stream.init()

	// Default parameter is 1
	s.next_slice('\x1b[C'.bytes())
	assert has_event(s.events, .cursor_right)
	ev1 := get_last_event(s.events, .cursor_right)
	assert ev1.payload.num == 1

	// Explicit parameter
	s.clear_events()
	s.next_slice('\x1b[5C'.bytes())
	assert has_event(s.events, .cursor_right)
	ev2 := get_last_event(s.events, .cursor_right)
	assert ev2.payload.num == 5

	// Two parameters - too many for cursor_right, should not dispatch
	s.clear_events()
	s.next_slice('\x1b[5;4C'.bytes())
	assert !has_event(s.events, .cursor_right)

	// Private marker ? - should not dispatch cursor_right
	s.clear_events()
	s.next_slice('\x1b[?3C'.bytes())
	assert !has_event(s.events, .cursor_right)
}

// Test DEC private set mode (SM) and reset mode (RM).
fn test_stream_dec_set_reset_mode() {
	mut s := Stream.init()

	// CSI ?6h → set_mode origin
	s.next_slice('\x1b[?6h'.bytes())
	assert has_event(s.events, .set_mode)
	ev1 := get_last_event(s.events, .set_mode)
	assert ev1.payload.mode == .origin

	// CSI ?6l → reset_mode
	s.clear_events()
	s.next_slice('\x1b[?6l'.bytes())
	assert has_event(s.events, .reset_mode)

	// CSI 6 SP h → has space intermediate, should not dispatch
	s.clear_events()
	s.next_slice('\x1b[6 h'.bytes())
	assert !has_event(s.events, .set_mode)
}

// Test ANSI set mode (SM) and reset mode (RM).
fn test_stream_ansi_set_reset_mode() {
	mut s := Stream.init()

	// CSI 4h → set_mode insert
	s.next_slice('\x1b[4h'.bytes())
	assert has_event(s.events, .set_mode)
	ev1 := get_last_event(s.events, .set_mode)
	assert ev1.payload.mode == .insert

	// CSI 4l → reset_mode
	s.clear_events()
	s.next_slice('\x1b[4l'.bytes())
	assert has_event(s.events, .reset_mode)

	// CSI >5h → has > intermediate, should not dispatch
	s.clear_events()
	s.next_slice('\x1b[>5h'.bytes())
	assert !has_event(s.events, .set_mode)
}

// Test that unknown ANSI mode values don't dispatch.
fn test_stream_ansi_set_mode_unknown() {
	mut s := Stream.init()

	// Mode 6 is not a valid ANSI mode (only valid as DEC private mode)
	s.next_slice('\x1b[6h'.bytes())
	assert !has_event(s.events, .set_mode)

	s.next_slice('\x1b[6l'.bytes())
	assert !has_event(s.events, .reset_mode)
}

// Test CSI ?42r does NOT trigger top_and_bottom_margin.
// It would be restore_mode but mode 42 is not recognized.
fn test_stream_restore_mode() {
	mut s := Stream.init()
	s.next_slice('\x1b[?42r'.bytes())
	assert !has_event(s.events, .top_and_bottom_margin)
}

// Test CSI <u (pop kitty keyboard) defaults to 1.
fn test_stream_pop_kitty_keyboard() {
	mut s := Stream.init()
	s.next_slice('\x1b[<u'.bytes())
	assert has_event(s.events, .kitty_keyboard_pop)
	ev := get_last_event(s.events, .kitty_keyboard_pop)
	assert ev.payload.num == 1
}

// Test DECSCA (Select Character Protection Attribute).
fn test_stream_decsca() {
	mut s := Stream.init()

	// CSI "q (no params) → protected_mode_off
	s.next_slice('\x1b["q'.bytes())
	assert has_event(s.events, .protected_mode_off)

	// CSI 0"q → protected_mode_off
	s.clear_events()
	s.next_slice('\x1b[0"q'.bytes())
	assert has_event(s.events, .protected_mode_off)

	// CSI 2"q → protected_mode_off
	s.clear_events()
	s.next_slice('\x1b[2"q'.bytes())
	assert has_event(s.events, .protected_mode_off)

	// CSI 1"q → protected_mode_dec
	s.clear_events()
	s.next_slice('\x1b[1"q'.bytes())
	assert has_event(s.events, .protected_mode_dec)
}

// Test DECED/DECSED (Erase Display) with and without protected mode.
fn test_stream_erase_display() {
	mut s := Stream.init()

	// Protected mode (? prefix)
	// CSI ?J → erase_display_below, protected=true
	s.next_slice('\x1b[?J'.bytes())
	assert has_event(s.events, .erase_display_below)
	ev1 := get_last_event(s.events, .erase_display_below)
	assert ev1.payload.flag == true

	// CSI ?0J → erase_display_below, protected=true
	s.clear_events()
	s.next_slice('\x1b[?0J'.bytes())
	assert has_event(s.events, .erase_display_below)
	ev2 := get_last_event(s.events, .erase_display_below)
	assert ev2.payload.flag == true

	// CSI ?1J → erase_display_above, protected=true
	s.clear_events()
	s.next_slice('\x1b[?1J'.bytes())
	assert has_event(s.events, .erase_display_above)
	ev3 := get_last_event(s.events, .erase_display_above)
	assert ev3.payload.flag == true

	// CSI ?2J → erase_display_complete, protected=true
	s.clear_events()
	s.next_slice('\x1b[?2J'.bytes())
	assert has_event(s.events, .erase_display_complete)
	ev4 := get_last_event(s.events, .erase_display_complete)
	assert ev4.payload.flag == true

	// CSI ?3J → erase_display_scrollback, protected=true
	s.clear_events()
	s.next_slice('\x1b[?3J'.bytes())
	assert has_event(s.events, .erase_display_scrollback)
	ev5 := get_last_event(s.events, .erase_display_scrollback)
	assert ev5.payload.flag == true

	// Normal mode (no ? prefix)
	// CSI J → erase_display_below, protected=false
	s.clear_events()
	s.next_slice('\x1b[J'.bytes())
	assert has_event(s.events, .erase_display_below)
	ev6 := get_last_event(s.events, .erase_display_below)
	assert ev6.payload.flag == false

	// CSI 0J → erase_display_below, protected=false
	s.clear_events()
	s.next_slice('\x1b[0J'.bytes())
	assert has_event(s.events, .erase_display_below)
	ev7 := get_last_event(s.events, .erase_display_below)
	assert ev7.payload.flag == false

	// CSI 1J → erase_display_above, protected=false
	s.clear_events()
	s.next_slice('\x1b[1J'.bytes())
	assert has_event(s.events, .erase_display_above)
	ev8 := get_last_event(s.events, .erase_display_above)
	assert ev8.payload.flag == false

	// CSI 2J → erase_display_complete, protected=false
	s.clear_events()
	s.next_slice('\x1b[2J'.bytes())
	assert has_event(s.events, .erase_display_complete)
	ev9 := get_last_event(s.events, .erase_display_complete)
	assert ev9.payload.flag == false

	// CSI 3J → erase_display_scrollback, protected=false
	s.clear_events()
	s.next_slice('\x1b[3J'.bytes())
	assert has_event(s.events, .erase_display_scrollback)
	ev10 := get_last_event(s.events, .erase_display_scrollback)
	assert ev10.payload.flag == false

	// CSI >0J → invalid intermediate, ignored
	s.clear_events()
	s.next_slice('\x1b[>0J'.bytes())
	assert !has_event(s.events, .erase_display_below)
	assert !has_event(s.events, .erase_display_above)
	assert !has_event(s.events, .erase_display_complete)
	assert !has_event(s.events, .erase_display_scrollback)
}

// Test DECEL/DECSEL (Erase Line) with and without protected mode.
fn test_stream_erase_line() {
	mut s := Stream.init()

	// Protected mode
	s.next_slice('\x1b[?K'.bytes())
	assert has_event(s.events, .erase_line_right)
	ev1 := get_last_event(s.events, .erase_line_right)
	assert ev1.payload.flag == true

	s.clear_events()
	s.next_slice('\x1b[?0K'.bytes())
	assert has_event(s.events, .erase_line_right)
	ev2 := get_last_event(s.events, .erase_line_right)
	assert ev2.payload.flag == true

	s.clear_events()
	s.next_slice('\x1b[?1K'.bytes())
	assert has_event(s.events, .erase_line_left)
	ev3 := get_last_event(s.events, .erase_line_left)
	assert ev3.payload.flag == true

	s.clear_events()
	s.next_slice('\x1b[?2K'.bytes())
	assert has_event(s.events, .erase_line_complete)
	ev4 := get_last_event(s.events, .erase_line_complete)
	assert ev4.payload.flag == true

	// Normal mode
	s.clear_events()
	s.next_slice('\x1b[K'.bytes())
	assert has_event(s.events, .erase_line_right)
	ev5 := get_last_event(s.events, .erase_line_right)
	assert ev5.payload.flag == false

	s.clear_events()
	s.next_slice('\x1b[0K'.bytes())
	assert has_event(s.events, .erase_line_right)
	ev6 := get_last_event(s.events, .erase_line_right)
	assert ev6.payload.flag == false

	s.clear_events()
	s.next_slice('\x1b[1K'.bytes())
	assert has_event(s.events, .erase_line_left)
	ev7 := get_last_event(s.events, .erase_line_left)
	assert ev7.payload.flag == false

	s.clear_events()
	s.next_slice('\x1b[2K'.bytes())
	assert has_event(s.events, .erase_line_complete)
	ev8 := get_last_event(s.events, .erase_line_complete)
	assert ev8.payload.flag == false

	// Invalid intermediate
	s.clear_events()
	s.next_slice('\x1b[<1K'.bytes())
	assert !has_event(s.events, .erase_line_right)
	assert !has_event(s.events, .erase_line_left)
	assert !has_event(s.events, .erase_line_complete)
}

// Test DECSCUSR (Set Cursor Style) with space intermediate.
fn test_stream_decscusr() {
	mut s := Stream.init()

	// CSI SP q → default cursor style
	s.next_slice('\x1b[ q'.bytes())
	assert has_event(s.events, .cursor_style)
	ev1 := get_last_event(s.events, .cursor_style)
	assert ev1.payload.cursor_style == .default_

	// CSI 1 SP q → blinking block
	s.clear_events()
	s.next_slice('\x1b[1 q'.bytes())
	assert has_event(s.events, .cursor_style)
	ev2 := get_last_event(s.events, .cursor_style)
	assert ev2.payload.cursor_style == .blinking_block

	// CSI ?0 SP q → has ? intermediate, should not dispatch
	s.clear_events()
	s.next_slice('\x1b[?0 q'.bytes())
	assert !has_event(s.events, .cursor_style)
}

// Test DECSCUSR without the space intermediate does NOT trigger cursor_style.
fn test_stream_decscusr_without_space() {
	mut s := Stream.init()

	// CSI q → no intermediate, csi_q returns early
	s.next_slice('\x1b[q'.bytes())
	assert !has_event(s.events, .cursor_style)

	// CSI 1q → no intermediate, csi_q returns early
	s.next_slice('\x1b[1q'.bytes())
	assert !has_event(s.events, .cursor_style)
}

// Test XTSHIFTESCAPE (CSI > Ps s).
fn test_stream_xtshiftescape() {
	mut s := Stream.init()

	// CSI >2s → invalid (param 2 not recognized), no dispatch
	s.next_slice('\x1b[>2s'.bytes())
	assert !has_event(s.events, .mouse_shift_capture)

	// CSI >s → mouse_shift_capture false (default)
	s.clear_events()
	s.next_slice('\x1b[>s'.bytes())
	assert has_event(s.events, .mouse_shift_capture)
	ev1 := get_last_event(s.events, .mouse_shift_capture)
	assert ev1.payload.flag == false

	// CSI >0s → mouse_shift_capture false
	s.clear_events()
	s.next_slice('\x1b[>0s'.bytes())
	assert has_event(s.events, .mouse_shift_capture)
	ev2 := get_last_event(s.events, .mouse_shift_capture)
	assert ev2.payload.flag == false

	// CSI >1s → mouse_shift_capture true
	s.clear_events()
	s.next_slice('\x1b[>1s'.bytes())
	assert has_event(s.events, .mouse_shift_capture)
	ev3 := get_last_event(s.events, .mouse_shift_capture)
	assert ev3.payload.flag == true

	// CSI 1 SP s → has space intermediate, not dispatched
	s.clear_events()
	s.next_slice('\x1b[1 s'.bytes())
	assert !has_event(s.events, .mouse_shift_capture)
}

// Test that window title with invalid UTF-8 is rejected.
fn test_stream_change_window_title_invalid_utf8() {
	// Valid UTF-8 title
	mut s1 := Stream.init()
	s1.next_slice('\x1b]2;abc\x1b\\'.bytes())
	assert has_event(s1.events, .window_title)

	// Invalid UTF-8 in title (0xC0 without continuation)
	mut s2 := Stream.init()
	mut invalid := '\x1b]2;abc'.bytes()
	invalid << u8(0xc0)
	invalid << '\x1b\\'.bytes()
	s2.next_slice(invalid)
	assert !has_event(s2.events, .window_title)
}

// Test ICH (Insert Character / Insert Blanks).
fn test_stream_insert_characters() {
	mut s := Stream.init()

	// CSI 42@ → insert_blanks
	s.next_slice('\x1b[42@'.bytes())
	assert has_event(s.events, .insert_blanks)

	// CSI ?42@ → has ? intermediate, should not dispatch
	s.clear_events()
	s.next_slice('\x1b[?42@'.bytes())
	assert !has_event(s.events, .insert_blanks)
}

// Test SCOSC (Save Cursor, no params CSI s).
fn test_stream_scosc() {
	mut s := Stream.init()
	s.next_slice('\x1b[s'.bytes())
	// CSI s with no params dispatches left_and_right_margin_ambiguous
	assert has_event(s.events, .left_and_right_margin_ambiguous)
	// It should NOT dispatch left_and_right_margin
	assert !has_event(s.events, .left_and_right_margin)
}

// Test SCORC (Restore Cursor, CSI u).
fn test_stream_scorc() {
	mut s := Stream.init()
	s.next_slice('\x1b[u'.bytes())
	assert has_event(s.events, .restore_cursor)
}

// Test that too many CSI params does not dispatch cursor_right.
fn test_stream_too_many_csi_params() {
	mut s := Stream.init()
	// 17 params separated by semicolons (exceeds single param requirement)
	s.next_slice('\x1b[1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1C'.bytes())
	assert !has_event(s.events, .cursor_right)
}

// Test that extremely long CSI param digits don't crash.
fn test_stream_csi_param_too_long() {
	mut s := Stream.init()
	// Very long parameter digit string (should saturate to 65535)
	mut seq := []u8{}
	seq << u8(0x1b)
	seq << u8(`[`)
	for _ in 0 .. 256 {
		seq << u8(`1`)
	}
	seq << u8(`C`)
	s.next_slice(seq)
	// Should not crash; cursor_right dispatches with saturated value
}

// Test CSI t size reports.
fn test_stream_csi_t_size_report() {
	mut s := Stream.init()

	// CSI 14t → csi_14_t
	s.next_slice('\x1b[14t'.bytes())
	assert has_event(s.events, .size_report)
	ev1 := get_last_event(s.events, .size_report)
	assert ev1.payload.size_report_style == .csi_14_t

	// CSI 16t → csi_16_t
	s.clear_events()
	s.next_slice('\x1b[16t'.bytes())
	assert has_event(s.events, .size_report)
	ev2 := get_last_event(s.events, .size_report)
	assert ev2.payload.size_report_style == .csi_16_t

	// CSI 18t → csi_18_t
	s.clear_events()
	s.next_slice('\x1b[18t'.bytes())
	assert has_event(s.events, .size_report)
	ev3 := get_last_event(s.events, .size_report)
	assert ev3.payload.size_report_style == .csi_18_t

	// CSI 21t → csi_21_t
	s.clear_events()
	s.next_slice('\x1b[21t'.bytes())
	assert has_event(s.events, .size_report)
	ev4 := get_last_event(s.events, .size_report)
	assert ev4.payload.size_report_style == .csi_21_t
}

// Test invalid CSI t value does not dispatch.
fn test_stream_invalid_csi_t() {
	mut s := Stream.init()
	s.next_slice('\x1b[19t'.bytes())
	assert !has_event(s.events, .size_report)
}

// Test CSI t push title.
fn test_stream_csi_t_push_title() {
	mut s := Stream.init()
	// CSI 22;0t → title_push with index 0
	s.next_slice('\x1b[22;0t'.bytes())
	assert has_event(s.events, .title_push)
	ev := get_last_event(s.events, .title_push)
	assert ev.payload.num == 0
}

// Test CSI t push title with explicit window param (22;2t).
fn test_stream_csi_t_push_title_explicit_window() {
	mut s := Stream.init()
	s.next_slice('\x1b[22;2t'.bytes())
	assert has_event(s.events, .title_push)
	ev := get_last_event(s.events, .title_push)
	assert ev.payload.num == 0
}

// Test CSI t push title with explicit icon param (22;1t) - not supported.
fn test_stream_csi_t_push_title_explicit_icon() {
	mut s := Stream.init()
	s.next_slice('\x1b[22;1t'.bytes())
	// Icon title (param 1) is not supported, should not dispatch
	assert !has_event(s.events, .title_push)
}

// Test CSI t push title with explicit index.
fn test_stream_csi_t_push_title_with_index() {
	mut s := Stream.init()
	s.next_slice('\x1b[22;0;5t'.bytes())
	assert has_event(s.events, .title_push)
	ev := get_last_event(s.events, .title_push)
	assert ev.payload.num == 5
}

// Test CSI t pop title.
fn test_stream_csi_t_pop_title() {
	mut s := Stream.init()
	s.next_slice('\x1b[23;0t'.bytes())
	assert has_event(s.events, .title_pop)
	ev := get_last_event(s.events, .title_pop)
	assert ev.payload.num == 0
}

// Test CSI t pop title with explicit window.
fn test_stream_csi_t_pop_title_explicit_window() {
	mut s := Stream.init()
	s.next_slice('\x1b[23;2t'.bytes())
	assert has_event(s.events, .title_pop)
	ev := get_last_event(s.events, .title_pop)
	assert ev.payload.num == 0
}

// Test CSI t pop title with explicit icon - not supported.
fn test_stream_csi_t_pop_title_explicit_icon() {
	mut s := Stream.init()
	s.next_slice('\x1b[23;1t'.bytes())
	assert !has_event(s.events, .title_pop)
}

// Test CSI t pop title with index.
fn test_stream_csi_t_pop_title_with_index() {
	mut s := Stream.init()
	s.next_slice('\x1b[23;0;5t'.bytes())
	assert has_event(s.events, .title_pop)
	ev := get_last_event(s.events, .title_pop)
	assert ev.payload.num == 5
}

// Test CSI W for tab clear.
fn test_stream_csi_w_clear_tab_stops() {
	mut s := Stream.init()

	// CSI 2W → tab_clear_current
	s.next_slice('\x1b[2W'.bytes())
	assert has_event(s.events, .tab_clear_current)

	// CSI 5W → tab_clear_all
	s.clear_events()
	s.next_slice('\x1b[5W'.bytes())
	assert has_event(s.events, .tab_clear_all)
}

// Test CSI W for tab set.
fn test_stream_csi_w_tab_set() {
	mut s := Stream.init()

	// CSI W → tab_set (no params)
	s.next_slice('\x1b[W'.bytes())
	assert has_event(s.events, .tab_set)

	// CSI 0W → tab_set
	s.clear_events()
	s.next_slice('\x1b[0W'.bytes())
	assert has_event(s.events, .tab_set)

	// CSI >W → has > intermediate, not dispatched
	s.clear_events()
	s.next_slice('\x1b[>W'.bytes())
	assert !has_event(s.events, .tab_set)

	// CSI 99W → unknown param, not dispatched
	s.clear_events()
	s.next_slice('\x1b[99W'.bytes())
	assert !has_event(s.events, .tab_set)
	assert !has_event(s.events, .tab_clear_current)
	assert !has_event(s.events, .tab_clear_all)
}

// Test CSI ?W for tab reset.
fn test_stream_csi_question_w_reset_tab_stops() {
	mut s := Stream.init()

	// CSI ?2W → not recognized, not dispatched
	s.next_slice('\x1b[?2W'.bytes())
	assert !has_event(s.events, .tab_reset)

	// CSI ?5W → tab_reset
	s.clear_events()
	s.next_slice('\x1b[?5W'.bytes())
	assert has_event(s.events, .tab_reset)

	// CSI ?1;2;3W → multiple params, not dispatched
	s.clear_events()
	s.next_slice('\x1b[?1;2;3W'.bytes())
	assert !has_event(s.events, .tab_reset)
}

// Test SGR with 17+ parameters for underline color.
// This tests that all parameters are correctly parsed even with many params.
fn test_stream_sgr_17_plus_params() {
	mut s := Stream.init()

	// Kakoune-style SGR with underline color as 17th+ parameter:
	// 4:3 → curly underline
	// 38;2;51;51;51 → direct fg color
	// 48;2;170;170;170 → direct bg color
	// 58;2;255;97;136 → underline color
	// 0 → reset
	s.next_slice('\x1b[4:3;38;2;51;51;51;48;2;170;170;170;58;2;255;97;136;0m'.bytes())
	assert has_event(s.events, .set_attribute)
}
