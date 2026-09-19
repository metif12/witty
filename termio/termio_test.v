module termio

import apprt
import configpkg
import datastruct
import os
import pty
import renderer
import terminal
import time

fn mailbox_send_forever_for_test(mailbox_ptr voidptr, done chan bool) {
	mut mailbox := unsafe { &Mailbox(mailbox_ptr) }
	mailbox.send(Message.write_stable_msg('overflow'), unsafe { nil })
	done <- true
}

struct TermioWakeupProbe {
mut:
	count int
}

fn termio_wakeup_probe(data voidptr) {
	mut probe := unsafe { &TermioWakeupProbe(data) }
	probe.count++
}

fn make_termio_opts() TermioOpts {
	return TermioOpts{
		size: renderer.Size{
			screen: renderer.ScreenSize{ width: 640, height: 384 }
			cell: renderer.CellSize{ width: 8, height: 16 }
		}
	}
}

fn test_mailbox_push_pop_fifo() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}

	assert mailbox.push(Message.write_stable_msg('one')) == 1
	assert mailbox.push(Message.write_stable_msg('two')) == 1
	assert mailbox.len() == 2

	first := mailbox.pop() or {
		assert false, 'expected first message'
		return
	}
	second := mailbox.pop() or {
		assert false, 'expected second message'
		return
	}
	assert first.write_stable_data == 'one'
	assert second.write_stable_data == 'two'
	assert mailbox.pop() == none
}

fn test_derived_config_converts_only_explicit_cursor_color() {
	mut config := configpkg.Config.default_config()
	config.cursor_color = configpkg.TerminalColor{
		color: configpkg.ColorRGB{ r: 0x12, g: 0x34, b: 0x56 }
	}
	derived := DerivedConfig.init(&config)!
	cursor_color := derived.cursor_color or { panic('explicit cursor color was discarded') }
	assert cursor_color == terminal.RGB{ r: 0x12, g: 0x34, b: 0x56 }

	config.cursor_color = configpkg.TerminalColor{ kind: .cell_foreground }
	cell_relative := DerivedConfig.init(&config)!
	assert cell_relative.cursor_color == none

	config.cursor_color = none
	unset := DerivedConfig.init(&config)!
	assert unset.cursor_color == none
}

fn test_derived_config_carries_raw_palette() {
	mut config := configpkg.Config.default_config()
	config.palette.value[42] = configpkg.ColorRGB{ r: 0x12, g: 0x34, b: 0x56 }

	derived := DerivedConfig.init(&config)!
	assert derived.palette[42] == terminal.RGB{ r: 0x12, g: 0x34, b: 0x56 }
}

fn test_message_write_req_uses_pinned_inline_capacity() {
	inline_data := 'x'.repeat(38)
	inline_msg := Message.write_req(inline_data)
	assert inline_msg.kind == .write_small
	assert inline_msg.write_small_data.slice().bytestr() == inline_data

	allocated_data := 'x'.repeat(39)
	allocated_msg := Message.write_req(allocated_data)
	assert allocated_msg.kind == .write_alloc
	assert allocated_msg.write_alloc_data == allocated_data
}

fn test_write_req_preserves_storage_kind_and_full_payload() {
	inline_data := 'x'.repeat(38)
	inline_req := WriteReq.init(inline_data.bytes())
	inline_msg := inline_req.message()
	assert inline_msg.kind == .write_small
	assert inline_msg.write_slice().bytestr() == inline_data

	allocated_data := 'y'.repeat(39)
	allocated_req := WriteReq.init(allocated_data.bytes())
	allocated_msg := allocated_req.message()
	assert allocated_msg.kind == .write_alloc
	assert allocated_msg.write_slice().bytestr() == allocated_data
}

fn test_message_discriminants_match_source_declaration_order() {
	assert sizeof(MessageKind) == 1
	assert u8(MessageKind.color_scheme_report) == 0
	assert u8(MessageKind.crash) == 1
	assert u8(MessageKind.change_config) == 2
	assert u8(MessageKind.inspector) == 3
	assert u8(MessageKind.resize) == 4
	assert u8(MessageKind.size_report) == 5
	assert u8(MessageKind.clear_screen) == 6
	assert u8(MessageKind.scroll_viewport) == 7
	assert u8(MessageKind.selection_scroll) == 8
	assert u8(MessageKind.jump_to_prompt) == 9
	assert u8(MessageKind.start_synchronized_output) == 10
	assert u8(MessageKind.linefeed_mode) == 11
	assert u8(MessageKind.focused) == 12
	assert u8(MessageKind.write_small) == 13
	assert u8(MessageKind.write_stable) == 14
	assert u8(MessageKind.write_alloc) == 15

	assert sizeof(SizeReportKind) == 1
	assert u8(SizeReportKind.mode_2048) == 0
	assert u8(SizeReportKind.csi_14_t) == 1
	assert u8(SizeReportKind.csi_16_t) == 2
	assert u8(SizeReportKind.csi_18_t) == 3

	assert sizeof(MutexState) == 1
	assert u8(MutexState.locked) == 0
	assert u8(MutexState.unlocked) == 1
}

fn test_scroll_viewport_message_preserves_source_payload() {
	wide_delta := isize(1_099_511_627_776)
	msg := Message.scroll_viewport_msg(terminal.ScrollViewport.from_delta(wide_delta))
	assert msg.kind == .scroll_viewport
	assert msg.scroll_viewport_val.tag == .delta
	assert msg.scroll_viewport_val.delta == wide_delta
}

fn test_termio_queue_message_uses_mailbox() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer {
		tio.deinit()
	}

	tio.queue_message(Message.focused_msg(true), .unlocked)

	assert tio.mailbox.len() == 1
	assert tio.mailbox.notified
	msg := tio.mailbox.pop() or {
		assert false, 'expected queued message'
		return
	}
	assert msg.kind == .focused
	assert msg.flag_val
}

fn test_termio_clear_screen_preserves_and_moves_cursor_row() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer {
		tio.deinit()
	}

	tio.terminal.print_string('first\nsecond\nkeep')!
	assert tio.terminal.screens.active.cursor.x == 4
	assert tio.terminal.screens.active.cursor.y == 2

	tio.clear_screen(false)!

	assert tio.terminal.plain_string()! == 'keep'
	assert tio.terminal.screens.active.cursor.x == 4
	assert tio.terminal.screens.active.cursor.y == 0
}

fn test_termio_clones_and_decodes_startup_input() {
	mut config := configpkg.Config.default_config()
	config.load_string('input = raw:hello\\nworld\ninput = path:startup\\x2etxt\n')
	assert config.diagnostics.len == 0

	mut tio := Termio{}
	tio.init(TermioOpts{
		size: make_termio_opts().size
		full_config: &config
	})!
	defer {
		tio.deinit()
	}

	assert tio.thread_enter_input == [configpkg.ReadableIO{
		kind: .raw
		value: 'hello\nworld'
	}, configpkg.ReadableIO{
		kind: .path
		value: 'startup.txt'
	}]
}

fn test_prepare_initial_input_opens_all_sources_before_start() {
	path := os.join_path(os.temp_dir(), 'witty-termio-input-${os.getpid()}')
	os.write_file(path, 'from file')!
	defer {
		os.rm(path) or {}
	}

	tio := Termio{
		thread_enter_input: [configpkg.ReadableIO{ kind: .raw, value: 'raw bytes' },
			configpkg.ReadableIO{ kind: .path, value: path }]
	}
	mut prepared := tio.prepare_initial_input()!
	defer {
		close_prepared_inputs(mut prepared)
	}
	assert prepared.len == 2
	assert sizeof(PreparedInputTag) == 1
	assert u8(PreparedInputTag.string) == 0
	assert u8(PreparedInputTag.file) == 1
	assert prepared[0].kind == .string
	assert prepared[1].kind == .file
	assert prepared[0].data.bytestr() == 'raw bytes'
	assert read_initial_input_file(mut prepared[1].file)!.bytestr() == 'from file'

	missing := Termio{
		thread_enter_input: [configpkg.ReadableIO{ kind: .raw, value: 'not sent' },
			configpkg.ReadableIO{ kind: .path, value: path + '.missing' }]
	}
	missing.prepare_initial_input() or {
		assert err.msg() == 'input not found'
		return
	}
	assert false, 'expected a missing startup input error'
}

fn test_stopwatch_notify_records_signal() {
	mut s := Stopwatch{}
	s.notify()!

	assert s.notified
}

// Translated from ghostty datastruct/blocking_queue.zig "basic push and pop".
// The Mailbox wraps a bounded ring buffer (BlockingQueue(Message, 64)); this
// exercises filling to capacity, the full-queue drop, FIFO drain, and reuse.
fn test_mailbox_fill_drain_reuse() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}

	// Should have no values.
	assert mailbox.pop() == none
	assert mailbox.len() == 0

	// Push until we're full. Each push succeeds (returns 1) until capacity.
	for i in 0 .. mailbox_capacity {
		assert mailbox.push(Message.write_stable_msg('m${i}')) == 1
	}
	assert mailbox.len() == mailbox_capacity

	// The next push fails because the queue is full.
	assert mailbox.push(Message.write_stable_msg('overflow')) == 0

	// Pop everything back out in FIFO order.
	for i in 0 .. mailbox_capacity {
		msg := mailbox.pop() or {
			assert false, 'expected message ${i}'
			return
		}
		assert msg.write_stable_data == 'm${i}'
	}
	assert mailbox.pop() == none
	assert mailbox.len() == 0

	// Verify we can still push after fully draining (ring buffer wraps).
	assert mailbox.push(Message.write_stable_msg('again')) == 1
	assert mailbox.len() == 1
}

// send() enqueues into the same underlying queue as push(). When no mutex is
// supplied (unlocked), it simply pushes without unlocking anything.
fn test_mailbox_send_enqueues() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}

	mailbox.send(Message.focused_msg(true), unsafe { nil })
	assert mailbox.len() == 1

	msg := mailbox.pop() or {
		assert false, 'expected sent message'
		return
	}
	assert msg.kind == .focused
	assert msg.flag_val
}

// notify() records that a wakeup signal was raised for the consuming thread.
fn test_mailbox_notify_sets_flag() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}

	assert !mailbox.notified
	mailbox.notify()
	assert mailbox.notified
}

fn test_mailbox_send_waits_for_space_without_dropping_message() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}
	for i in 0 .. mailbox_capacity {
		assert mailbox.push(Message.write_stable_msg('m${i}')) == 1
	}

	done := chan bool{ cap: 1 }
	worker := spawn mailbox_send_forever_for_test(voidptr(&mailbox), done)
	first := mailbox.pop() or { panic('full mailbox unexpectedly empty') }
	assert first.write_stable_data == 'm0'
	worker.wait()
	assert <-done
	assert mailbox.len() == mailbox_capacity

	for i in 1 .. mailbox_capacity {
		msg := mailbox.pop() or { panic('missing queued message ${i}') }
		assert msg.write_stable_data == 'm${i}'
	}
	last := mailbox.pop() or { panic('blocked message was dropped') }
	assert last.write_stable_data == 'overflow'
}

// stopwatch reset clears the notification state.
fn test_stopwatch_reset_clears() {
	mut s := Stopwatch{}
	s.notify()!
	assert s.notified
	s.reset()
	assert !s.notified
}

fn test_thread_drain_mailbox_updates_writer_state() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }

	resize := renderer.Size{
		screen: renderer.ScreenSize{ width: 800, height: 600 }
		cell: renderer.CellSize{ width: 10, height: 20 }
	}
	tio.mailbox.push(Message.inspector_msg(true))
	tio.mailbox.push(Message{ kind: .linefeed_mode, flag_val: true })
	tio.mailbox.push(Message.selection_scroll_msg(true))
	tio.mailbox.push(Message{ kind: .start_synchronized_output })
	tio.mailbox.push(Message.resize_msg(resize))

	assert writer.drain_mailbox(mut tio)
	assert writer.flags.has_inspector()
	assert writer.flags.linefeed_mode()
	assert sizeof(ThreadFlags) == 1
	assert writer.scroll_active
	assert writer.scroll_deadline > 0
	assert writer.sync_deadline > 0
	assert writer.pending_resize or { panic('missing coalesced resize') } == resize
	assert writer.resize_deadline > 0
	assert tio.mailbox.len() == 0
}

struct SelectionScrollProbe {
mut:
	values   []bool
	timeouts []datastruct.BlockingQueueTimeoutKind
}

fn selection_scroll_probe_push(_ voidptr, surface voidptr, msg apprt.SurfaceMessage, timeout datastruct.BlockingQueueTimeout) u32 {
	if msg.kind == .selection_scroll_tick {
		mut probe := unsafe { &SelectionScrollProbe(surface) }
		probe.values << msg.selection_scroll_tick
		probe.timeouts << timeout.kind
	}
	return 1
}

fn test_thread_selection_scroll_timer_reports_final_stop() {
	mut probe := SelectionScrollProbe{}
	mut tio := Termio{}
	tio.init(TermioOpts{
		size: make_termio_opts().size
		surface_mailbox: apprt.SurfaceMailbox{
			surface: &probe
			push_fn: selection_scroll_probe_push
		}
	})!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }

	tio.mailbox.push(Message.selection_scroll_msg(true))
	assert writer.drain_mailbox(mut tio)
	deadline := writer.scroll_deadline
	assert deadline > 0

	// Repeated starts leave the currently armed completion untouched.
	tio.mailbox.push(Message.selection_scroll_msg(true))
	assert writer.drain_mailbox(mut tio)
	assert writer.scroll_deadline == deadline

	// Stopping does not cancel the completion. It fires once with false and
	// then disarms, matching selectionScrollCallback.
	tio.mailbox.push(Message.selection_scroll_msg(false))
	assert writer.drain_mailbox(mut tio)
	assert !writer.scroll_active
	assert writer.scroll_deadline == deadline
	assert writer.run_timers(mut tio, deadline)
	assert probe.values == [false]
	assert probe.timeouts == [.instant]
	assert writer.scroll_deadline == 0
}

struct PasswordInputProbe {
mut:
	values   []bool
	timeouts []datastruct.BlockingQueueTimeoutKind
}

fn password_input_probe_push(_ voidptr, surface voidptr, msg apprt.SurfaceMessage, timeout datastruct.BlockingQueueTimeout) u32 {
	if msg.kind == .password_input {
		mut probe := unsafe { &PasswordInputProbe(surface) }
		probe.values << msg.password_input
		probe.timeouts << timeout.kind
	}
	return 1
}

fn test_thread_termios_mode_reports_password_input_transitions() {
	mut probe := PasswordInputProbe{}
	mut tio := Termio{}
	tio.init(TermioOpts{
		size: make_termio_opts().size
		surface_mailbox: apprt.SurfaceMailbox{
			surface: &probe
			push_fn: password_input_probe_push
		}
	})!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }

	writer.apply_termios_mode(mut tio, pty.Mode.init(true, false))
	assert probe.values == [true]

	// The surface owns the shared password-input flag after consuming the
	// notification. Moving back to normal canonical+echo mode reports false.
	tio.terminal.flags.set_password_input(true)
	writer.apply_termios_mode(mut tio, pty.Mode{})
	assert probe.values == [true, false]
	assert probe.timeouts == [.forever, .forever]
}

fn test_thread_termios_timer_stops_unfocused_and_restarts_on_focus() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }

	tio.backend.thread_data.termios_deadline = 1
	tio.backend.focus_gained(false)!
	assert writer.run_termios_timer(mut tio, 1)
	assert tio.backend.thread_data.termios_deadline == 0

	tio.backend.focus_gained(true)!
	assert tio.backend.thread_data.termios_deadline == 1
	assert writer.run_termios_timer(mut tio, 1)
	assert tio.backend.thread_data.termios_deadline == 1 + termios_poll_ms * i64(time.millisecond)
}

fn test_thread_start_error_explains_pty_exhaustion() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }

	writer.show_start_error(mut tio, 'openpty failed')
	text := tio.terminal.plain_string()!
	assert text.starts_with('Your system cannot allocate any more pty devices.')
	assert text.contains('Please free up some pty devices and try again.')
	assert !tio.terminal.modes.get(.cursor_visible)
}

fn test_thread_start_error_explains_invalid_input() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }

	writer.show_start_error(mut tio, 'input not found')
	text := tio.terminal.plain_string()!
	assert text.starts_with('A configured `input` path was not found')
	assert text.contains('ensure that all the path values exist and are readable.')
}

fn test_process_output_notifies_callback_renderer_wakeup() {
	mut probe := TermioWakeupProbe{}
	mut tio := Termio{}
	tio.init(TermioOpts{
		size: make_termio_opts().size
		renderer_wakeup: renderer.Wakeup{
			user_data: &probe
			notify_fn: termio_wakeup_probe
		}
	})!
	defer { tio.deinit() }

	tio.process_output('hello'.bytes())
	assert probe.count == 1
}
