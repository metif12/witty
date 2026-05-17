module termio

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
