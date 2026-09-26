module termio

import renderer
import terminal
import apprt
import build_meta
import datastruct
import osc
import sync
import tmux

// ============================================================
// StreamHandler tests
// ============================================================

// TestContext holds all test allocations so pointers stay valid.
struct TestContext {
mut:
	t              terminal.Terminal
	mailbox        Mailbox
	rstate         renderer.State
	rmailbox       &renderer.Mailbox = unsafe { nil }
	rsize          renderer.Size
	messages       []apprt.SurfaceMessage
	timeouts       []datastruct.BlockingQueueTimeoutKind
	reject_instant bool
}

fn collect_surface_message(app voidptr, surface voidptr, msg apprt.SurfaceMessage, timeout datastruct.BlockingQueueTimeout) u32 {
	_ = app
	mut ctx := unsafe { &TestContext(surface) }
	ctx.timeouts << timeout.kind
	if ctx.reject_instant && timeout.kind == .instant {
		return 0
	}
	ctx.messages << msg
	return 1
}

// Helper to create a StreamHandler with a test terminal.
fn make_test_handler() (&StreamHandler, &TestContext) {
	mut ctx := &TestContext{
		t: terminal.Terminal.init(terminal.Options{
			cols: 80
			rows: 24
		}) or { panic('failed to init terminal') }
		mailbox: Mailbox.init_spsc() or { panic(err) }
		rmailbox: renderer.Mailbox.create() or { panic(err) }
	}

	mut handler := &StreamHandler{
		terminal: &ctx.t
		termio_mailbox: &ctx.mailbox
		renderer_state: &ctx.rstate
		renderer_mailbox: ctx.rmailbox
		surface_mailbox: apprt.SurfaceMailbox{
			surface: ctx
			push_fn: collect_surface_message
		}
		size: &ctx.rsize
		default_cursor_style: .block
	}
	return handler, ctx
}

fn test_surface_message_writer_retries_without_renderer_lock_after_full_queue() ! {
	mut handler, mut ctx := make_test_handler()
	defer {
		ctx.t.deinit()
	}
	ctx.reject_instant = true
	ctx.rstate.mutex = sync.new_mutex()
	ctx.rstate.mutex.lock()
	handler.surface_message_writer(apprt.SurfaceMessage{ kind: .ring_bell })
	ctx.rstate.mutex.unlock()
	ctx.rstate.mutex.destroy()
	ctx.rstate.mutex = unsafe { nil }
	assert ctx.messages.len == 1
	assert ctx.messages[0].kind == .ring_bell
	assert ctx.timeouts == [.instant, .forever]
}

fn test_progress_report_forwards_payload() ! {
	mut handler, mut ctx := make_test_handler()
	defer {
		ctx.t.deinit()
	}
	handler.progress_report(osc.ProgressReport{
		state: .set
		progress: 42
	})
	assert ctx.messages.len == 1
	assert ctx.messages[0].kind == .progress_report
	assert ctx.messages[0].progress_report.state == osc.ProgressState.set
	assert ctx.messages[0].progress_report.progress or { 0 } == 42

	handler.progress_report(osc.ProgressReport{
		state: .indeterminate
	})
	assert ctx.messages.len == 2
	assert ctx.messages[1].progress_report.state == .indeterminate
	assert ctx.messages[1].progress_report.progress == none
}

fn test_desktop_notification_forwards_typed_payload() ! {
	mut handler, mut ctx := make_test_handler()
	defer {
		ctx.t.deinit()
	}
	handler.show_desktop_notification(osc.DesktopNotification{
		title: 'Compiler'
		body: 'Build failed'
	})!
	assert ctx.messages.len == 1
	assert ctx.messages[0].kind == .desktop_notification
	assert ctx.messages[0].notification_title[..8].bytestr() == 'Compiler'
	assert ctx.messages[0].notification_body[..12].bytestr() == 'Build failed'
}

fn test_desktop_notification_preserves_full_sentinel_array_payloads() ! {
	mut handler, mut ctx := make_test_handler()
	defer {
		ctx.t.deinit()
	}
	title := 't'.repeat(63)
	body := 'b'.repeat(255)
	handler.show_desktop_notification(osc.DesktopNotification{
		title: title
		body: body
	})!

	assert ctx.messages.len == 1
	assert ctx.messages[0].notification_title[..63].bytestr() == title
	assert ctx.messages[0].notification_title[63] == 0
	assert ctx.messages[0].notification_body[..255].bytestr() == body
	assert ctx.messages[0].notification_body[255] == 0
}

// Test that the StreamHandler can be created and deinitialized.
fn test_stream_handler_init_deinit() ! {
	mut handler, mut ctx := make_test_handler()
	handler.deinit()
	ctx.t.deinit()
}

fn test_stream_handler_tmux_viewer_lifecycle_and_commands() ! {
	if !terminal.tmux_control_mode {
		return
	}
	mut handler, mut ctx := make_test_handler()
	defer {
		handler.deinit()
		ctx.t.deinit()
	}

	mut enter := terminal.DcsCommand(terminal.DcsCommandTmux{
		notification: tmux.Notification(tmux.NotifEnter{})
	})
	handler.dcs_command(mut enter)!
	assert handler.tmux_viewer != none

	mut startup_done := terminal.DcsCommand(terminal.DcsCommandTmux{
		notification: tmux.Notification(tmux.NotifBlockEnd{})
	})
	handler.dcs_command(mut startup_done)!
	assert ctx.mailbox.queue.len() == 0

	mut session := terminal.DcsCommand(terminal.DcsCommandTmux{
		notification: tmux.Notification(tmux.NotifSessionChanged{
			id: 7
			name: 'main'
		})
	})
	handler.dcs_command(mut session)!
	assert handler.termio_messaged
	msg := ctx.mailbox.queue.pop() or { panic('expected tmux command') }
	assert msg.kind == .write_small
	assert msg.write_small_data.slice().bytestr().starts_with('display-message')

	mut exit := terminal.DcsCommand(terminal.DcsCommandTmux{
		notification: tmux.Notification(tmux.NotifExit{})
	})
	handler.dcs_command(mut exit)!
	assert handler.tmux_viewer == none
}

fn test_xtgettcap_uses_complete_ghostty_capability_encoding() ! {
	// Keys are the hex-encoded capability names exactly as they arrive on the
	// wire, and each value is the full DCS response.
	assert xtgettcap_map['616D'] or { 'missing' } == '\x1bP1+r616D\x1b\\'
	assert xtgettcap_map['636F6C6F7273'] or { '' } == '\x1bP1+r636F6C6F7273=323536\x1b\\'
	assert xtgettcap_map['524742'] or { '' } == '\x1bP1+r524742=38\x1b\\'
	assert xtgettcap_map['536D756C78'] or { '' } == '\x1bP1+r536D756C78=5C455B343A25703125646D\x1b\\'
	assert xtgettcap_map['6B6273'] or { '' } == '\x1bP1+r6B6273=7F\x1b\\'
	assert xtgettcap_map['6B6631'] or { '' } == '\x1bP1+r6B6631=1B4F50\x1b\\'
	assert xtgettcap_map['6B663633'] or { '' } == '\x1bP1+r6B663633=1B5B313B3452\x1b\\'
	assert '6E6F742D612D6361706162696C697479' !in xtgettcap_map

	// Lower-case requests go unanswered, as in the source.
	assert '616d' !in xtgettcap_map
}

fn test_stream_handler_xtgettcap_omits_unknown_and_formats_boolean() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	mut query := terminal.DcsXtgettcap{
		data: '616D;756E6B6E6F776E;636F6C6F7273'.bytes()
	}
	handler.dcs_xtgettcap(mut query)
	assert ctx.mailbox.queue.len() == 2

	boolean_msg := ctx.mailbox.queue.pop() or {
		assert false
		return
	}
	assert boolean_msg.kind == .write_small
	assert boolean_msg.write_small_data.slice().bytestr() == '\x1bP1+r616D\x1b\\'

	numeric_msg := ctx.mailbox.queue.pop() or {
		assert false
		return
	}
	assert numeric_msg.kind == .write_small
	assert numeric_msg.write_small_data.slice().bytestr() == '\x1bP1+r636F6C6F7273=323536\x1b\\'
}

fn test_stream_handler_xtversion_uses_build_version() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.report_xtversion()!

	assert ctx.mailbox.queue.len() == 1
	msg := ctx.mailbox.queue.pop() or { panic('expected XTVERSION response') }
	assert msg.kind == .write_small
	assert msg.write_small_data.slice().bytestr() == '\x1bP>|ghostty ${build_meta.version_string}\x1b\\'
}

fn test_stream_handler_request_mode_uses_dec_protocol_value() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.request_mode(.cursor_visible)!

	msg := ctx.mailbox.queue.pop() or { panic('expected DECRQM response') }
	assert msg.kind == .write_small
	assert msg.write_small_data.slice().bytestr() == '\x1b[?25;1\$y'
}

fn test_stream_handler_request_mode_uses_ansi_protocol_value() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.request_mode(.insert)!

	msg := ctx.mailbox.queue.pop() or { panic('expected DECRQM response') }
	assert msg.kind == .write_small
	assert msg.write_small_data.slice().bytestr() == '\x1b[4;2\$y'
}

fn test_stream_handler_decrqss_requires_declrmm_for_horizontal_margins() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.dcs_decrqss(.decslrm)
	disabled := ctx.mailbox.queue.pop() or { panic('expected invalid DECRPSS response') }
	assert disabled.write_small_data.slice().bytestr() == '\x1bP0\$r\x1b\\'

	handler.terminal.modes.set(.enable_left_and_right_margin, true)
	handler.dcs_decrqss(.decslrm)
	enabled := ctx.mailbox.queue.pop() or { panic('expected valid DECRPSS response') }
	assert enabled.write_small_data.slice().bytestr() == '\x1bP1\$r1;80s\x1b\\'
}

fn test_stream_handler_decrqss_hollow_cursor_uses_blink_mode() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.terminal.screens.active.cursor.cursor_style = .block_hollow

	handler.terminal.modes.set(.cursor_blinking, true)
	handler.dcs_decrqss(.decscusr)
	blinking := ctx.mailbox.queue.pop() or { panic('expected blinking cursor DECRPSS response') }
	assert blinking.write_small_data.slice().bytestr() == '\x1bP1\$r1 q\x1b\\'

	handler.terminal.modes.set(.cursor_blinking, false)
	handler.dcs_decrqss(.decscusr)
	steady := ctx.mailbox.queue.pop() or { panic('expected steady cursor DECRPSS response') }
	assert steady.write_small_data.slice().bytestr() == '\x1bP1\$r2 q\x1b\\'
}

fn test_stream_handler_decrqss_uses_terminal_sgr_serialization() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.terminal.set_attribute(terminal.SgrAttribute{
		kind: .underline_set
		underline: .double
	})!
	handler.terminal.set_attribute(terminal.SgrAttribute{ kind: .overline })!

	handler.dcs_decrqss(.sgr)
	msg := ctx.mailbox.queue.pop() or { panic('expected SGR DECRPSS response') }
	assert msg.write_small_data.slice().bytestr() == '\x1bP1\$r0;4m\x1b\\'
}

// Test bell dispatches without crashing.
fn test_stream_handler_bell() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .bell
	})!
}

// Test horizontal tab.
fn test_stream_handler_horizontal_tab() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .horizontal_tab
		payload: terminal.ActionPayload{ num: 1 }
	})!
	// The cursor should have moved to the first tabstop
	assert handler.terminal.screens.active.cursor.x == 8
}

// Test carriage return.
fn test_stream_handler_carriage_return() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	// Move cursor right first
	handler.terminal.cursor_right(5)
	assert handler.terminal.screens.active.cursor.x == 5
	// Carriage return
	handler.vt(terminal.StreamEvent{
		key: .carriage_return
	})!
	assert handler.terminal.screens.active.cursor.x == 0
}

// Test cursor movement dispatching.
fn test_stream_handler_cursor_movement() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// cursor_right
	handler.vt(terminal.StreamEvent{
		key: .cursor_right
		payload: terminal.ActionPayload{ num: 3 }
	})!
	assert handler.terminal.screens.active.cursor.x == 3

	// cursor_down
	handler.vt(terminal.StreamEvent{
		key: .cursor_down
		payload: terminal.ActionPayload{ num: 2 }
	})!
	assert handler.terminal.screens.active.cursor.y == 2

	// cursor_left
	handler.vt(terminal.StreamEvent{
		key: .cursor_left
		payload: terminal.ActionPayload{ num: 1 }
	})!
	assert handler.terminal.screens.active.cursor.x == 2

	// cursor_up
	handler.vt(terminal.StreamEvent{
		key: .cursor_up
		payload: terminal.ActionPayload{ num: 1 }
	})!
	assert handler.terminal.screens.active.cursor.y == 1
}

// Test cursor_pos dispatching (row, col in 1-based).
fn test_stream_handler_cursor_pos() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .cursor_pos
		payload: terminal.ActionPayload{ num: 5, num2: 10 }
	})!
	assert handler.terminal.screens.active.cursor.y == 4 // 0-based
	assert handler.terminal.screens.active.cursor.x == 9 // 0-based
}

// Test set_cursor_style dispatching.
fn test_stream_handler_cursor_style() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// Set to steady underline
	handler.vt(terminal.StreamEvent{
		key: .cursor_style
		payload: terminal.ActionPayload{ cursor_style: .steady_underline }
	})!
	assert handler.terminal.screens.active.cursor.cursor_style == .underline
	assert !handler.default_cursor

	// Set to default
	handler.vt(terminal.StreamEvent{
		key: .cursor_style
		payload: terminal.ActionPayload{ cursor_style: .default_ }
	})!
	assert handler.default_cursor
	assert handler.terminal.screens.active.cursor.cursor_style == .block
}

// Test set_mode dispatching.
fn test_stream_handler_set_mode_origin() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// Move cursor somewhere
	handler.terminal.set_cursor_pos(5, 10)
	assert handler.terminal.screens.active.cursor.y == 4

	// Setting origin mode resets cursor to (1,1)
	handler.vt(terminal.StreamEvent{
		key: .set_mode
		payload: terminal.ActionPayload{ mode: .origin }
	})!
	assert handler.terminal.screens.active.cursor.y == 0
	assert handler.terminal.screens.active.cursor.x == 0
}

// Test print dispatching.
fn test_stream_handler_print() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .print
		payload: terminal.ActionPayload{ cp: u32(`A`) }
	})!
	assert handler.terminal.screens.active.cursor.x == 1
}

// Test full_reset dispatching.
fn test_stream_handler_full_reset() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// Move cursor, change mode
	handler.terminal.set_cursor_pos(10, 20)
	handler.terminal.modes.set(.origin, true)

	// Full reset
	handler.vt(terminal.StreamEvent{
		key: .full_reset
	})!

	assert !handler.terminal.modes.get(.origin)
	assert handler.terminal.screens.active.cursor.x == 0
	assert handler.terminal.screens.active.cursor.y == 0
}

// Test save/restore cursor dispatching.
fn test_stream_handler_save_restore_cursor() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// Move cursor
	handler.terminal.set_cursor_pos(5, 10)
	assert handler.terminal.screens.active.cursor.y == 4
	assert handler.terminal.screens.active.cursor.x == 9

	// Save cursor
	handler.vt(terminal.StreamEvent{
		key: .save_cursor
	})!

	// Move cursor elsewhere
	handler.terminal.set_cursor_pos(1, 1)
	assert handler.terminal.screens.active.cursor.y == 0

	// Restore cursor
	handler.vt(terminal.StreamEvent{
		key: .restore_cursor
	})!
	assert handler.terminal.screens.active.cursor.y == 4
	assert handler.terminal.screens.active.cursor.x == 9
}

// Test modify_key_format dispatching.
fn test_stream_handler_modify_key_format() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	assert !handler.terminal.flags.modify_other_keys_2()

	handler.vt(terminal.StreamEvent{
		key: .modify_key_format
		payload: terminal.ActionPayload{ modify_key_format: .other_keys_numeric }
	})!
	assert handler.terminal.flags.modify_other_keys_2()

	handler.vt(terminal.StreamEvent{
		key: .modify_key_format
		payload: terminal.ActionPayload{ modify_key_format: .legacy }
	})!
	assert !handler.terminal.flags.modify_other_keys_2()
}

// Test linefeed dispatching (calls index).
fn test_stream_handler_linefeed() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .linefeed
	})!
	assert handler.terminal.screens.active.cursor.y == 1
}

// Test protected mode dispatching.
fn test_stream_handler_protected_mode() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.vt(terminal.StreamEvent{
		key: .protected_mode_dec
	})!
	assert handler.terminal.screens.active.cursor.is_protected

	handler.vt(terminal.StreamEvent{
		key: .protected_mode_off
	})!
	assert !handler.terminal.screens.active.cursor.is_protected
}

// Test backspace dispatching.
fn test_stream_handler_backspace() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.terminal.cursor_right(3)
	assert handler.terminal.screens.active.cursor.x == 3
	handler.vt(terminal.StreamEvent{
		key: .backspace
	})!
	assert handler.terminal.screens.active.cursor.x == 2
}

// Test erase_display_complete dispatching.
fn test_stream_handler_erase_display() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	// Print something
	handler.terminal.print(u32(`X`)) or {}
	// Erase complete
	handler.vt(terminal.StreamEvent{
		key: .erase_display_complete
		payload: terminal.ActionPayload{ flag: false }
	})!
	// Verify cursor x didn't change (erase doesn't move cursor)
}

// Test scroll_up dispatching.
fn test_stream_handler_scroll_up() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .scroll_up
		payload: terminal.ActionPayload{ count: 1 }
	})!
	// Should not crash
}

// Test erase_chars dispatching.
fn test_stream_handler_erase_chars() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .erase_chars
		payload: terminal.ActionPayload{ count: 5 }
	})!
}

// Test insert_lines dispatching.
fn test_stream_handler_insert_lines() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .insert_lines
		payload: terminal.ActionPayload{ count: 2 }
	})!
}

// Test delete_lines dispatching.
fn test_stream_handler_delete_lines() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .delete_lines
		payload: terminal.ActionPayload{ count: 1 }
	})!
}

// Test insert_blanks dispatching.
fn test_stream_handler_insert_blanks() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .insert_blanks
		payload: terminal.ActionPayload{ count: 3 }
	})!
}

// Test delete_chars dispatching.
fn test_stream_handler_delete_chars() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .delete_chars
		payload: terminal.ActionPayload{ count: 2 }
	})!
}

// Test tab_set and tab_clear_current dispatching.
fn test_stream_handler_tab_operations() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.vt(terminal.StreamEvent{
		key: .tab_set
	})!
	handler.vt(terminal.StreamEvent{
		key: .tab_clear_current
	})!
	handler.vt(terminal.StreamEvent{
		key: .tab_clear_all
	})!
	handler.vt(terminal.StreamEvent{
		key: .tab_reset
	})!
}

// Test kitty keyboard push/pop dispatching.
fn test_stream_handler_kitty_keyboard() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// Push
	handler.vt(terminal.StreamEvent{
		key: .kitty_keyboard_push
		payload: terminal.ActionPayload{ kitty_flags: 5 }
	})!
	assert handler.terminal.screens.active.kitty_keyboard.current().int() == 5

	// Pop
	handler.vt(terminal.StreamEvent{
		key: .kitty_keyboard_pop
		payload: terminal.ActionPayload{ num: 1 }
	})!
	assert handler.terminal.screens.active.kitty_keyboard.current() == terminal.key_flags_disabled

	// The full u16 count must reach FlagStack.pop; narrowing to u8 would
	// turn 256 into zero instead of resetting the stack.
	handler.terminal.screens.active.kitty_keyboard.set(.set_, terminal.KeyFlags.from_int(3))
	handler.terminal.screens.active.kitty_keyboard.push(terminal.KeyFlags.from_int(5))
	handler.vt(terminal.StreamEvent{
		key: .kitty_keyboard_pop
		payload: terminal.ActionPayload{ num: 256 }
	})!
	assert handler.terminal.screens.active.kitty_keyboard.current() == terminal.key_flags_disabled
}

// Test set_mode for mouse events.
fn test_stream_handler_mouse_modes() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// Enable mouse normal tracking
	handler.set_mode(.mouse_event_normal, true)!
	assert handler.terminal.flags.mouse_event() == .normal
	assert handler.terminal.mouse_shape == .default_

	// Disable
	handler.set_mode(.mouse_event_normal, false)!
	assert handler.terminal.flags.mouse_event() == .none
	assert handler.terminal.mouse_shape == .text
}

// Test set_mode for mouse format.
fn test_stream_handler_mouse_format() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.set_mode(.mouse_format_sgr, true)!
	assert handler.terminal.flags.mouse_format() == .sgr

	handler.set_mode(.mouse_format_sgr, false)!
	assert handler.terminal.flags.mouse_format() == .x10
}

// Test DCS/APC handlers don't crash.
fn test_stream_handler_dcs_apc() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// APC start/put/end
	handler.vt(terminal.StreamEvent{
		key: .apc_start
	})!
	handler.vt(terminal.StreamEvent{
		key: .apc_put
		payload: terminal.ActionPayload{ byte_val: u8(`G`) }
	})!
	handler.vt(terminal.StreamEvent{
		key: .apc_end
	})!

	// DCS hook/put/unhook
	handler.vt(terminal.StreamEvent{
		key: .dcs_hook
	})!
	handler.vt(terminal.StreamEvent{
		key: .dcs_put
		payload: terminal.ActionPayload{ byte_val: u8(`x`) }
	})!
	handler.vt(terminal.StreamEvent{
		key: .dcs_unhook
	})!
}

fn test_apc_handler_rejects_unknown_and_invalid_commands() ! {
	for input in ['Xabcdef1234', 'Gabcdef1234', 'Ga=p,i=10000000000', 'Ga=p,i=1,z=-9999999999'] {
		mut handler := ApcHandler{}
		handler.start()
		for byte_val in input.bytes() {
			handler.feed(byte_val)
		}
		assert handler.end() == none
	}
}

fn test_apc_handler_state_values_match_source_order() ! {
	assert sizeof(ApcHandlerState) == 1
	assert int(ApcHandlerState.inactive) == 0
	assert int(ApcHandlerState.ignore) == 1
	assert int(ApcHandlerState.identify) == 2
	assert int(ApcHandlerState.kitty) == 3
}

fn test_apc_handler_parses_valid_kitty_command() ! {
	if !terminal.kitty_graphics {
		return
	}
	mut handler := ApcHandler{}
	handler.start()
	for byte_val in 'Gf=24,s=10,v=20,hello=world'.bytes() {
		handler.feed(byte_val)
	}
	cmd := handler.end() or {
		assert false
		return
	}
	transmission := cmd.transmission() or {
		assert false
		return
	}
	assert transmission.format_ == .rgb
	assert transmission.width == 10
	assert transmission.height == 20
}

fn test_apc_handler_obeys_synthesized_kitty_graphics_option() ! {
	mut handler := ApcHandler{}
	handler.start()
	for byte_val in 'Gf=24,s=10,v=20,hello=world'.bytes() {
		handler.feed(byte_val)
	}
	cmd := handler.end()
	assert (cmd != none) == terminal.kitty_graphics
}

// Test change_config.
fn test_stream_handler_change_config() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	config := DerivedConfig{
		osc_color_report_format: .format_8_bit
		clipboard_write: .deny
		enquiry_response: 'test'
		cursor_style: .underline
		cursor_blink: true
	}
	handler.change_config(&config)

	assert handler.osc_color_report_format == .format_8_bit
	assert handler.clipboard_write == .deny
	assert handler.enquiry_response == 'test'
	assert handler.default_cursor_style == .underline
}

fn test_color_query_response_mirrors_osc_terminator() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.osc_color_report_format = .format_8_bit

	handler.vt(terminal.StreamEvent{
		key: .color_operation
		payload: terminal.ActionPayload{
			color_operation: osc.ColorOperationCommand{
				op:         .osc_4
				requests:   [osc.ColorRequest(osc.ColorRequestQuery{
					target: osc.ColorTarget(osc.ColorTargetPalette{
						index: 1
					})
				})]
				terminator: .bel
			}
		}
	})!
	bel := ctx.mailbox.queue.pop() or { panic('expected BEL-terminated color response') }
	assert bel.kind == .write_small
	assert bel.write_small_data.slice().bytestr().ends_with('\a')

	handler.vt(terminal.StreamEvent{
		key: .color_operation
		payload: terminal.ActionPayload{
			color_operation: osc.ColorOperationCommand{
				op:         .osc_4
				requests:   [osc.ColorRequest(osc.ColorRequestQuery{
					target: osc.ColorTarget(osc.ColorTargetPalette{
						index: 1
					})
				})]
				terminator: .st
			}
		}
	})!
	st := ctx.mailbox.queue.pop() or { panic('expected ST-terminated color response') }
	assert st.kind == .write_small
	assert st.write_small_data.slice().bytestr().ends_with('\x1b\\')
}

fn test_kitty_color_query_response_mirrors_osc_terminator() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.vt(terminal.StreamEvent{
		key: .kitty_color_report
		payload: terminal.ActionPayload{
			kitty_color: osc.KittyColorOSC{
				list:       [osc.KittyColorRequest(osc.KittyColorQuery{
					key: u8(1)
				})]
				terminator: .bel
			}
		}
	})!
	msg := ctx.mailbox.queue.pop() or { panic('expected Kitty color response') }
	assert msg.kind == .write_small
	response := msg.write_small_data.slice().bytestr()
	assert response.starts_with('\x1b]21;1=rgb:')
	assert response.ends_with('\a')
}

// Test cursor_blinking mode is ignored when default_cursor_blink is set.
fn test_stream_handler_cursor_blinking_override() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	// Set a default blink preference
	handler.default_cursor_blink = true

	// Try to set cursor_blinking mode - should be ignored
	handler.set_mode(.cursor_blinking, false)!
	// The mode should still be whatever it was (it's ignored)
	// This tests the early return in set_mode for cursor_blinking
}

// Test report_pwd with empty URL.
fn test_stream_handler_report_pwd_empty() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.report_pwd('')!
	assert ctx.messages.len == 2
	assert ctx.messages[0].kind == .set_title
	assert ctx.messages[1].kind == .pwd_change
	assert ctx.messages[1].pwd_change.slice().bytestr() == ''
}

fn test_stream_handler_clipboard_read_forwards_clipboard_type() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.clipboard_contents(`p`, '?')!

	assert ctx.messages.len == 1
	assert ctx.messages[0].kind == .clipboard_read
	assert ctx.messages[0].clipboard_type == .primary
}

fn test_stream_handler_clipboard_write_forwards_contents_and_type() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.clipboard_contents(`s`, 'translated clipboard data')!

	assert ctx.messages.len == 1
	assert ctx.messages[0].kind == .clipboard_write
	assert ctx.messages[0].clipboard_write_type == .selection
	assert ctx.messages[0].clipboard_write_req.slice().bytestr() == 'translated clipboard data'
}

fn test_stream_handler_clipboard_write_owns_contents() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	mut data := 'owned clipboard data'.bytes()
	handler.clipboard_contents(`c`, data.bytestr())!
	data[0] = `X`

	assert ctx.messages[0].clipboard_write_req.slice().bytestr() == 'owned clipboard data'
}

fn test_stream_handler_report_pwd_forwards_decoded_path() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.report_pwd('file://localhost/tmp/translated%20path')!

	assert ctx.messages.len == 2
	assert ctx.messages[0].kind == .pwd_change
	assert ctx.messages[0].pwd_change.slice().bytestr() == '/tmp/translated path'
	assert ctx.messages[1].kind == .set_title
}

fn test_stream_handler_report_pwd_preserves_kitty_raw_path() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }

	handler.report_pwd('kitty-shell-cwd://localhost/tmp/raw%20path??#fragment')!

	assert ctx.messages.len == 2
	assert ctx.messages[0].kind == .pwd_change
	assert ctx.messages[0].pwd_change.slice().bytestr() == '/tmp/raw%20path??#fragment'
	assert ctx.messages[1].kind == .set_title
}

// Test window_title with empty title.
fn test_stream_handler_window_title_empty() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.window_title('')!
	assert !handler.seen_title
}

// Test window_title with non-empty title.
fn test_stream_handler_window_title() ! {
	mut handler, mut ctx := make_test_handler()
	defer { ctx.t.deinit() }
	handler.window_title('My Terminal')!
	assert handler.seen_title
}
