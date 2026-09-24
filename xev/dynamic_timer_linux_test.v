module xev

// TimerTests from libxev src/watcher/timer.zig (pinned 34fa508), for the
// dynamic Timer (TimerDynamic). The suite runs with the backend in use, so it
// is run twice: with the backend chosen by detect() (io_uring when available)
// and with epoll selected by prefer(.epoll).

fn dynamic_timer_test_set(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn dynamic_timer_test_timer() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := Timer.init()!
	defer {
		timer.deinit()
	}

	// Add the timer
	mut called := false
	c1 := &Completion{}
	timer.run(mut loop, c1, 1, &called, dynamic_timer_test_set)

	// Wait
	loop.run(.until_done)!
	assert called
}

fn dynamic_timer_test_timer_reset() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := Timer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &Completion{}
	c_cancel := &Completion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 100_000, &canceled, dynamic_timer_test_set)

	// Wait
	loop.run(.no_wait)!
	assert !canceled

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, dynamic_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn dynamic_timer_test_timer_reset_before_tick() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := Timer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &Completion{}
	c_cancel := &Completion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 100_000, &canceled, dynamic_timer_test_set)

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, dynamic_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn dynamic_timer_test_timer_reset_after_trigger() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := Timer.init()!
	defer {
		timer.deinit()
	}

	c_timer := &Completion{}
	c_cancel := &Completion{}

	// Add the timer
	mut canceled := false
	timer.run(mut loop, c_timer, 1, &canceled, dynamic_timer_test_set)
	loop.run(.until_done)!
	assert canceled
	canceled = false

	// Reset it
	timer.reset(mut loop, c_timer, c_cancel, 1, &canceled, dynamic_timer_test_set)

	loop.run(.until_done)!
	assert canceled
	assert c_timer.state() == .dead
	assert c_cancel.state() == .dead
}

fn dynamic_timer_test_canceled(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind) CallbackAction {
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = if err := r { err == .canceled } else { false }
	}
	return .disarm
}

fn dynamic_timer_test_timer_cancel() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	timer := Timer.init()!
	defer {
		timer.deinit()
	}

	// Add the timer
	mut canceled := false
	c1 := &Completion{}
	timer.run(mut loop, c1, 100_000, &canceled, dynamic_timer_test_canceled)

	// Cancel
	mut cancel_confirm := false
	c2 := &Completion{}
	timer.cancel(mut loop, c1, c2, &cancel_confirm, dynamic_timer_test_set)

	// Wait
	loop.run(.until_done)!
	assert canceled
	assert cancel_confirm
}

fn dynamic_timer_tests() ! {
	dynamic_timer_test_timer()!
	dynamic_timer_test_timer_reset()!
	dynamic_timer_test_timer_reset_before_tick()!
	dynamic_timer_test_timer_reset_after_trigger()!
	dynamic_timer_test_timer_cancel()!
}

fn test_dynamic_timer_detect() ! {
	detect()!
	dynamic_timer_tests()!
}

fn test_dynamic_timer_prefer_epoll() ! {
	assert prefer(.epoll)
	dynamic_timer_tests()!
}
