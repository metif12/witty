module termio

import renderer

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
