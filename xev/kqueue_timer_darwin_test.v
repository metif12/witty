module xev

// TimerTests from libxev src/watcher/timer.zig (pinned 34fa508), for the
// kqueue Timer.

fn kqueue_timer_test_set(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn test_kqueue_timer_watcher_timer() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := KqueueTimer.init()!
	defer {
		timer.deinit()
	}

	// Add the timer
	mut called := false
	c1 := &KqueueCompletion{}
	timer.run(mut loop, c1, 1, &called, kqueue_timer_test_set)

	// Wait
	loop.run(.until_done)!
	assert called
}

fn test_kqueue_timer_watcher_timer_reset() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := KqueueTimer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &KqueueCompletion{}
	c_cancel := &KqueueCompletion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 100_000, &canceled, kqueue_timer_test_set)

	// Wait
	loop.run(.no_wait)!
	assert !canceled

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, kqueue_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_kqueue_timer_watcher_timer_reset_before_tick() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := KqueueTimer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &KqueueCompletion{}
	c_cancel := &KqueueCompletion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 100_000, &canceled, kqueue_timer_test_set)

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, kqueue_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_kqueue_timer_watcher_timer_reset_after_trigger() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := KqueueTimer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &KqueueCompletion{}
	c_cancel := &KqueueCompletion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 1, &canceled, kqueue_timer_test_set)
	loop.run(.until_done)!
	assert canceled
	canceled = false

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, kqueue_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn kqueue_timer_test_canceled(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r ?ErrorKind) CallbackAction {
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = if err := r { err == .canceled } else { false }
	}
	return .disarm
}

fn test_kqueue_timer_watcher_timer_cancel() ! {
	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := KqueueTimer.init()!
	defer {
		timer.deinit()
	}

	// Add the timer
	mut canceled := false
	c1 := &KqueueCompletion{}
	timer.run(mut loop, c1, 100_000, &canceled, kqueue_timer_test_canceled)

	// Cancel
	mut cancel_confirm := false
	c2 := &KqueueCompletion{}
	timer.cancel(mut loop, c1, c2, &cancel_confirm, kqueue_timer_test_set)

	// Wait
	loop.run(.until_done)!
	assert canceled
	assert cancel_confirm
}
