module xev

// TimerTests from libxev src/watcher/timer.zig (pinned 34fa508), for the
// io_uring Timer.

fn io_uring_timer_test_set(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn test_io_uring_timer_watcher_timer() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := IoUringTimer.init()!
	defer {
		timer.deinit()
	}

	// Add the timer
	mut called := false
	c1 := &IoUringCompletion{}
	timer.run(mut loop, c1, 1, &called, io_uring_timer_test_set)

	// Wait
	loop.run(.until_done)!
	assert called
}

fn test_io_uring_timer_watcher_timer_reset() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := IoUringTimer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &IoUringCompletion{}
	c_cancel := &IoUringCompletion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 100_000, &canceled, io_uring_timer_test_set)

	// Wait
	loop.run(.no_wait)!
	assert !canceled

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, io_uring_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_io_uring_timer_watcher_timer_reset_before_tick() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := IoUringTimer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &IoUringCompletion{}
	c_cancel := &IoUringCompletion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 100_000, &canceled, io_uring_timer_test_set)

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, io_uring_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn test_io_uring_timer_watcher_timer_reset_after_trigger() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := IoUringTimer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &IoUringCompletion{}
	c_cancel := &IoUringCompletion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 1, &canceled, io_uring_timer_test_set)
	loop.run(.until_done)!
	assert canceled
	canceled = false

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, io_uring_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn io_uring_timer_test_canceled(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r ?ErrorKind) CallbackAction {
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = if err := r { err == .canceled } else { false }
	}
	return .disarm
}

fn test_io_uring_timer_watcher_timer_cancel() ! {
	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := IoUringTimer.init()!
	defer {
		timer.deinit()
	}

	// Add the timer
	mut canceled := false
	c1 := &IoUringCompletion{}
	timer.run(mut loop, c1, 100_000, &canceled, io_uring_timer_test_canceled)

	// Cancel
	mut cancel_confirm := false
	c2 := &IoUringCompletion{}
	timer.cancel(mut loop, c1, c2, &cancel_confirm, io_uring_timer_test_set)

	// Wait
	loop.run(.until_done)!
	assert canceled
	assert cancel_confirm
}
