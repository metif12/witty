module termio

import apprt
import configpkg
import datastruct
import os
import pty
import renderer
import sync
import terminal
import term.termios
import xev

fn mailbox_send_forever_for_test(mailbox_ptr voidptr, done chan bool) {
	mut mailbox := unsafe { &Mailbox(mailbox_ptr) }
	mailbox.send(MessageWriteStable{ data: 'overflow' }, unsafe { nil })
	done <- true
}

struct TermioWakeupProbe {
mut:
	count int
}

fn termio_wakeup_probe(ud voidptr, _ &xev.Loop, _ &xev.Completion, r ?xev.ErrorKind) xev.CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut probe := unsafe { &TermioWakeupProbe(ud) }
	probe.count++
	return .rearm
}

fn make_termio_opts() TermioOpts {
	return TermioOpts{
		size: renderer.Size{
			screen: renderer.ScreenSize{ width: 640, height: 384 }
			cell: renderer.CellSize{ width: 8, height: 16 }
		}
		full_config: &configpkg.Config{}
		backend: Exec.init(ExecConfig{}) or { panic(err) }
		mailbox: Mailbox.init_spsc() or { panic(err) }
		renderer_state: &renderer.State{
			mutex: sync.new_mutex()
		}
		renderer_wakeup: xev.Async.init() or { panic(err) }
		renderer_mailbox: renderer.Mailbox.create() or { panic(err) }
	}
}

fn test_mailbox_push_pop_fifo() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}

	assert mailbox.queue.push(MessageWriteStable{ data: 'one' }, datastruct.blocking_queue_instant) > 0
	assert mailbox.queue.push(MessageWriteStable{ data: 'two' }, datastruct.blocking_queue_instant) > 0
	assert mailbox.queue.len() == 2

	first := mailbox.queue.pop() or {
		assert false, 'expected first message'
		return
	}
	second := mailbox.queue.pop() or {
		assert false, 'expected second message'
		return
	}
	assert (first as MessageWriteStable).data == 'one'
	assert (second as MessageWriteStable).data == 'two'
	assert mailbox.queue.pop() == none
}

fn test_derived_config_converts_only_explicit_cursor_color() {
	mut config := configpkg.Config.default_config()
	config.cursor_color = configpkg.TerminalColorColor{
		color: configpkg.ColorRGB{ r: 0x12, g: 0x34, b: 0x56 }
	}
	derived := DerivedConfig.init(&config)!
	cursor_color := derived.cursor_color or { panic('explicit cursor color was discarded') }
	assert cursor_color == terminal.RGB{ r: 0x12, g: 0x34, b: 0x56 }

	config.cursor_color = configpkg.TerminalColorCellForeground{}
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
	assert inline_msg.kind() == .write_small
	assert (inline_msg as WriteSmall).slice().bytestr() == inline_data

	allocated_data := 'x'.repeat(39)
	allocated_msg := Message.write_req(allocated_data)
	assert allocated_msg.kind() == .write_alloc
	assert (allocated_msg as MessageWriteAlloc).data == allocated_data
}

fn test_write_req_preserves_storage_kind_and_full_payload() {
	inline_data := 'x'.repeat(38)
	inline_req := WriteReq.init(inline_data.bytes())
	inline_msg := inline_req.message()
	assert inline_msg.kind() == .write_small
	assert inline_msg.write_slice().bytestr() == inline_data

	allocated_data := 'y'.repeat(39)
	allocated_req := WriteReq.init(allocated_data.bytes())
	allocated_msg := allocated_req.message()
	assert allocated_msg.kind() == .write_alloc
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
	msg := Message(MessageScrollViewport{ scroll: terminal.ScrollViewport.from_delta(wide_delta) })
	assert msg.kind() == .scroll_viewport
	scroll := (msg as MessageScrollViewport).scroll
	assert scroll is terminal.ScrollViewportDelta
	assert (scroll as terminal.ScrollViewportDelta).delta == wide_delta
}

fn test_termio_queue_message_uses_mailbox() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer {
		tio.deinit()
	}

	tio.queue_message(MessageFocused{ value: true }, .unlocked)

	assert tio.mailbox.queue.len() == 1
	msg := tio.mailbox.queue.pop() or {
		assert false, 'expected queued message'
		return
	}
	assert msg.kind() == .focused
	assert (msg as MessageFocused).value
}

fn test_color_scheme_report_locked_honors_disabled_mode() {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer {
		tio.deinit()
	}

	assert !tio.terminal.modes.get(.report_color_scheme)
	mut td := ThreadData{}
	tio.color_scheme_report_locked(mut td, false)!
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

	mut td := ThreadData{}
	tio.clear_screen(mut td, false)!

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
		...make_termio_opts()
		full_config: &config
	})!
	defer {
		tio.deinit()
	}

	assert tio.thread_enter_input == [configpkg.ReadableIO(configpkg.ReadableIORaw{
		value: 'hello\nworld'
	}), configpkg.ReadableIO(configpkg.ReadableIOPath{
		value: 'startup.txt'
	})]
}

fn test_prepare_input_opens_all_sources_before_start() {
	path := os.join_path(os.temp_dir(), 'witty-termio-input-${os.getpid()}')
	os.write_file(path, 'from file')!
	defer {
		os.rm(path) or {}
	}

	tio := Termio{
		thread_enter_input: [configpkg.ReadableIO(configpkg.ReadableIORaw{ value: 'raw bytes' }),
			configpkg.ReadableIO(configpkg.ReadableIOPath{ value: path })]
	}
	mut prepared := tio.prepare_input()!
	defer {
		close_prepared_inputs(mut prepared)
	}
	assert prepared.len == 2
	assert prepared[0] is PreparedInputString
	assert (prepared[0] as PreparedInputString).data.bytestr() == 'raw bytes'
	assert prepared[1] is PreparedInputFile
	mut file_input := prepared[1] as PreparedInputFile
	assert read_initial_input_file(mut file_input.file)!.bytestr() == 'from file'

	missing := Termio{
		thread_enter_input: [configpkg.ReadableIO(configpkg.ReadableIORaw{ value: 'not sent' }),
			configpkg.ReadableIO(configpkg.ReadableIOPath{ value: path + '.missing' })]
	}
	missing.prepare_input() or {
		assert err.msg() == 'input not found'
		return
	}
	assert false, 'expected a missing startup input error'
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
	assert mailbox.queue.pop() == none
	assert mailbox.queue.len() == 0

	// Push until we're full. Each push succeeds (returns 1) until capacity.
	for i in 0 .. mailbox_capacity {
		assert mailbox.queue.push(MessageWriteStable{ data: 'm${i}' }, datastruct.blocking_queue_instant) > 0
	}
	assert mailbox.queue.len() == mailbox_capacity

	// The next push fails because the queue is full.
	assert mailbox.queue.push(MessageWriteStable{ data: 'overflow' }, datastruct.blocking_queue_instant) == 0

	// Pop everything back out in FIFO order.
	for i in 0 .. mailbox_capacity {
		msg := mailbox.queue.pop() or {
			assert false, 'expected message ${i}'
			return
		}
		assert (msg as MessageWriteStable).data == 'm${i}'
	}
	assert mailbox.queue.pop() == none
	assert mailbox.queue.len() == 0

	// Verify we can still push after fully draining (ring buffer wraps).
	assert mailbox.queue.push(MessageWriteStable{ data: 'again' }, datastruct.blocking_queue_instant) > 0
	assert mailbox.queue.len() == 1
}

// send() enqueues into the same underlying queue as push(). When no mutex is
// supplied (unlocked), it simply pushes without unlocking anything.
fn test_mailbox_send_enqueues() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}

	mailbox.send(MessageFocused{ value: true }, unsafe { nil })
	assert mailbox.queue.len() == 1

	msg := mailbox.queue.pop() or {
		assert false, 'expected sent message'
		return
	}
	assert msg.kind() == .focused
	assert (msg as MessageFocused).value
}

// notify() wakes the consuming thread's loop through the wakeup async.
fn test_mailbox_notify_wakes_writer_loop() ! {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}
	mut probe := TermioWakeupProbe{}
	mut loop := xev.Loop.init(xev.Options{})!
	defer {
		loop.deinit()
	}
	c := &xev.Completion{}
	mailbox.wakeup.wait(mut loop, c, &probe, termio_wakeup_probe)

	loop.run(.no_wait)!
	assert probe.count == 0
	mailbox.notify()
	loop.run(.no_wait)!
	assert probe.count == 1
}

fn test_mailbox_send_waits_for_space_without_dropping_message() {
	mut mailbox := Mailbox.init_spsc()!
	defer {
		mailbox.deinit()
	}
	for i in 0 .. mailbox_capacity {
		assert mailbox.queue.push(MessageWriteStable{ data: 'm${i}' }, datastruct.blocking_queue_instant) > 0
	}

	done := chan bool{ cap: 1 }
	worker := spawn mailbox_send_forever_for_test(voidptr(&mailbox), done)
	first := mailbox.queue.pop() or { panic('full mailbox unexpectedly empty') }
	assert (first as MessageWriteStable).data == 'm0'
	worker.wait()
	assert <-done
	assert mailbox.queue.len() == mailbox_capacity

	for i in 1 .. mailbox_capacity {
		msg := mailbox.queue.pop() or { panic('missing queued message ${i}') }
		assert (msg as MessageWriteStable).data == 'm${i}'
	}
	last := mailbox.queue.pop() or { panic('blocked message was dropped') }
	assert (last as MessageWriteStable).data == 'overflow'
}

// termio_test_callback_data mirrors threadMain_'s stack CallbackData for a
// thread whose loop is driven by the test.
fn termio_test_callback_data(mut writer Thread, mut tio Termio) &CallbackData {
	mut cb := &CallbackData{
		self_: writer
		io:    tio
	}
	cb.data.loop = &writer.loop
	cb.data.renderer_state = tio.renderer_state
	cb.data.surface_mailbox = tio.surface_mailbox
	cb.data.mailbox = &tio.mailbox
	return cb
}

fn test_thread_drain_mailbox_updates_writer_state() ! {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }
	mut cb := termio_test_callback_data(mut writer, mut tio)

	resize := renderer.Size{
		screen: renderer.ScreenSize{ width: 800, height: 600 }
		cell: renderer.CellSize{ width: 10, height: 20 }
	}
	tio.mailbox.queue.push(MessageInspector{ value: true }, datastruct.blocking_queue_instant)
	tio.mailbox.queue.push(MessageLinefeedMode{ value: true }, datastruct.blocking_queue_instant)
	tio.mailbox.queue.push(MessageSelectionScroll{ value: true }, datastruct.blocking_queue_instant)
	tio.mailbox.queue.push(MessageStartSynchronizedOutput{}, datastruct.blocking_queue_instant)
	tio.mailbox.queue.push(Message(resize), datastruct.blocking_queue_instant)

	writer.drain_mailbox(mut cb)!
	assert writer.flags.has_inspector()
	assert writer.flags.linefeed_mode()
	assert sizeof(ThreadFlags) == 1
	assert writer.scroll_active
	assert writer.scroll_c.state() == .active
	assert writer.sync_reset_c.state() == .active
	assert writer.coalesce_data.resize or { panic('missing coalesced resize') } == resize
	assert writer.coalesce_c.state() == .active
	assert tio.mailbox.queue.len() == 0
}

fn test_thread_drain_mailbox_discards_messages_while_draining() ! {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }
	mut cb := termio_test_callback_data(mut writer, mut tio)

	writer.flags.set_drain(true)
	tio.mailbox.queue.push(MessageInspector{ value: true }, datastruct.blocking_queue_instant)
	writer.drain_mailbox(mut cb)!
	assert !writer.flags.has_inspector()
	assert tio.mailbox.queue.len() == 0
}

struct SelectionScrollProbe {
mut:
	values   []bool
	timeouts []datastruct.BlockingQueueTimeoutKind
}

fn selection_scroll_probe_push(_ voidptr, surface voidptr, msg apprt.SurfaceMessage, timeout datastruct.BlockingQueueTimeout) u32 {
	if msg.kind() == .selection_scroll_tick {
		mut probe := unsafe { &SelectionScrollProbe(surface) }
		probe.values << (msg as apprt.SurfaceMessageSelectionScrollTick).value
		probe.timeouts << timeout.kind()
	}
	return 1
}

fn test_thread_selection_scroll_timer_reports_final_stop() ! {
	mut probe := SelectionScrollProbe{}
	mut tio := Termio{}
	tio.init(TermioOpts{
		...make_termio_opts()
		surface_mailbox: apprt.SurfaceMailbox{
			surface: &probe
			push_fn: selection_scroll_probe_push
		}
	})!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }
	mut cb := termio_test_callback_data(mut writer, mut tio)

	tio.mailbox.queue.push(MessageSelectionScroll{ value: true }, datastruct.blocking_queue_instant)
	writer.drain_mailbox(mut cb)!
	assert writer.scroll_c.state() == .active

	// Repeated starts leave the currently armed completion untouched.
	tio.mailbox.queue.push(MessageSelectionScroll{ value: true }, datastruct.blocking_queue_instant)
	writer.drain_mailbox(mut cb)!
	assert writer.scroll_c.state() == .active

	// Stopping does not cancel the completion. It fires once with false and
	// then disarms, matching selectionScrollCallback.
	tio.mailbox.queue.push(MessageSelectionScroll{ value: false }, datastruct.blocking_queue_instant)
	writer.drain_mailbox(mut cb)!
	assert !writer.scroll_active
	assert writer.scroll_c.state() == .active
	writer.loop.run(.until_done)!
	assert probe.values == [false]
	assert probe.timeouts == [.instant]
	assert writer.scroll_c.state() == .dead
}

struct PasswordInputProbe {
mut:
	values   []bool
	timeouts []datastruct.BlockingQueueTimeoutKind
}

fn password_input_probe_push(_ voidptr, surface voidptr, msg apprt.SurfaceMessage, timeout datastruct.BlockingQueueTimeout) u32 {
	if msg.kind() == .password_input {
		mut probe := unsafe { &PasswordInputProbe(surface) }
		probe.values << (msg as apprt.SurfaceMessagePasswordInput).value
		probe.timeouts << timeout.kind()
	}
	return 1
}

// termio_test_exec_thread_data is the exec backend state threadEnter builds,
// reading termios state from the given pty.
fn termio_test_exec_thread_data(mut writer Thread, tio &Termio, p pty.Pty) !ThreadData {
	return ThreadData{
		loop:            &writer.loop
		renderer_state:  tio.renderer_state
		surface_mailbox: tio.surface_mailbox
		backend:         ExecThreadData{
			read_thread_fd: p.master
			termios_timer:  xev.Timer.init()!
		}
	}
}

fn test_exec_termios_timer_reports_password_input_transitions() ! {
	mut probe := PasswordInputProbe{}
	mut tio := Termio{}
	tio.init(TermioOpts{
		...make_termio_opts()
		surface_mailbox: apprt.SurfaceMailbox{
			surface: &probe
			push_fn: password_input_probe_push
		}
	})!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }
	mut p := pty.Pty.open(pty.Winsize{ ws_row: 24, ws_col: 80 })!
	defer { p.deinit() }
	mut td := termio_test_exec_thread_data(mut writer, &tio, p)!
	td.backend.termios_timer_running = false

	// Canonical input with echo disabled is the password-entry heuristic.
	mut attrs := termios.Termios{}
	assert termios.tcgetattr(p.slave, mut attrs) == 0
	attrs.disable_echo()
	assert termios.tcsetattr(p.slave, C.TCSANOW, mut attrs) == 0
	_ = exec_termios_timer(&td, unsafe { nil }, unsafe { nil }, none)
	assert probe.values == [true]

	// The surface owns the shared password-input flag after consuming the
	// notification. Moving back to normal canonical+echo mode reports false.
	tio.terminal.flags.set_password_input(true)
	attrs.c_lflag |= termios.flag(int(C.ECHO))
	assert termios.tcsetattr(p.slave, C.TCSANOW, mut attrs) == 0
	_ = exec_termios_timer(&td, unsafe { nil }, unsafe { nil }, none)
	assert probe.values == [true, false]
	assert probe.timeouts == [.forever, .forever]

	// A stopped timer is not rearmed.
	assert td.backend.termios_timer_c.state() == .dead
}

fn test_exec_termios_timer_stops_unfocused_and_restarts_on_focus() ! {
	mut tio := Termio{}
	tio.init(make_termio_opts())!
	defer { tio.deinit() }
	mut writer := Thread.init()!
	defer { writer.deinit() }
	mut p := pty.Pty.open(pty.Winsize{ ws_row: 24, ws_col: 80 })!
	defer { p.deinit() }
	mut td := termio_test_exec_thread_data(mut writer, &tio, p)!

	// Focusing with no armed timer checks the mode immediately and arms it.
	tio.backend.focus_gained(mut td, true)!
	assert td.backend.termios_timer_running
	assert td.backend.termios_timer_c.state() == .active

	// Losing focus only flags the armed timer to end on its next tick.
	tio.backend.focus_gained(mut td, false)!
	assert !td.backend.termios_timer_running
	assert td.backend.termios_timer_c.state() == .active
	writer.loop.run(.until_done)!
	assert td.backend.termios_timer_c.state() == .dead

	// Regaining focus restarts it.
	tio.backend.focus_gained(mut td, true)!
	assert td.backend.termios_timer_c.state() == .active
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

fn test_process_output_notifies_renderer_wakeup() ! {
	mut probe := TermioWakeupProbe{}
	mut loop := xev.Loop.init(xev.Options{})!
	defer {
		loop.deinit()
	}
	mut wakeup := xev.Async.init()!
	defer {
		wakeup.deinit()
	}
	c := &xev.Completion{}
	wakeup.wait(mut loop, c, &probe, termio_wakeup_probe)

	mut tio := Termio{}
	tio.init(TermioOpts{
		...make_termio_opts()
		renderer_wakeup: wakeup
	})!
	defer { tio.deinit() }

	tio.process_output('hello'.bytes())
	loop.run(.no_wait)!
	assert probe.count == 1
}
