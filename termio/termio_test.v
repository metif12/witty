module termio

import configpkg
import os
import renderer

fn mailbox_send_forever_for_test(mailbox_ptr voidptr, done chan bool) {
	mut mailbox := unsafe { &Mailbox(mailbox_ptr) }
	mailbox.send(Message.write_stable_msg('overflow'), unsafe { nil })
	done <- true
}

fn test_mailbox_push_pop_fifo() {
	mut mailbox := Mailbox.init()!
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

fn test_termio_queue_message_uses_mailbox() {
	mut tio := Termio{}
	tio.init(TermioOpts{})!
	defer {
		tio.deinit()
	}

	tio.queue_message(Message.visible_msg(true), .unlocked)

	assert tio.mailbox.len() == 1
	msg := tio.mailbox.pop() or {
		assert false, 'expected queued message'
		return
	}
	assert msg.kind == .visible
	assert msg.flag_val
}

fn test_termio_clones_and_decodes_startup_input() {
	mut config := configpkg.Config.default_config()
	config.load_string('input = raw:hello\\nworld\ninput = path:startup\\x2etxt\n')
	assert config.diagnostics.len == 0

	mut tio := Termio{}
	tio.init(TermioOpts{
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
	mut mailbox := Mailbox.init()!
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
	mut mailbox := Mailbox.init()!
	defer {
		mailbox.deinit()
	}

	mailbox.send(Message.visible_msg(true), unsafe { nil })
	assert mailbox.len() == 1

	msg := mailbox.pop() or {
		assert false, 'expected sent message'
		return
	}
	assert msg.kind == .visible
	assert msg.flag_val
}

// notify() records that a wakeup signal was raised for the consuming thread.
fn test_mailbox_notify_sets_flag() {
	mut mailbox := Mailbox.init()!
	defer {
		mailbox.deinit()
	}

	assert !mailbox.notified
	mailbox.notify()
	assert mailbox.notified
}

fn test_mailbox_send_waits_for_space_without_dropping_message() {
	mut mailbox := Mailbox.init()!
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
	tio.init(TermioOpts{})!
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
	assert writer.has_inspector
	assert writer.linefeed_mode
	assert writer.scroll_active
	assert writer.scroll_deadline > 0
	assert writer.sync_deadline > 0
	assert writer.pending_resize or { panic('missing coalesced resize') } == resize
	assert writer.resize_deadline > 0
	assert tio.mailbox.len() == 0
}
