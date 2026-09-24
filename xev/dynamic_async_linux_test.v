module xev

// AsyncTests from libxev src/watcher/async.zig (pinned 34fa508), for the
// dynamic Async (AsyncDynamic). The suite runs with the backend in use, so it
// is run twice: with the backend chosen by detect() (io_uring when available)
// and with epoll selected by prefer(.epoll).

fn dynamic_async_test_wake_rearm(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .rearm
}

fn dynamic_async_test_wake_disarm(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn dynamic_async_test_count(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut count := unsafe { &u32(ud) }
	unsafe {
		*count += 1
	}
	return .rearm
}

fn dynamic_async_test_async() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut notifier := Async.init()!
	defer {
		notifier.deinit()
	}

	// Wait
	mut wake := false
	c_wait := &Completion{}
	notifier.wait(mut loop, c_wait, &wake, dynamic_async_test_wake_rearm)

	// Send a notification
	notifier.notify()!

	// Wait for wake
	loop.run(.once)!
	assert wake

	// Make sure it only triggers once
	wake = false
	loop.run(.no_wait)!
	assert !wake
}

fn dynamic_async_test_async_notify_first() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut notifier := Async.init()!
	defer {
		notifier.deinit()
	}

	// Send a notification
	notifier.notify()!

	// Wait
	mut wake := false
	c_wait := &Completion{}
	notifier.wait(mut loop, c_wait, &wake, dynamic_async_test_wake_disarm)

	// Wait for wake
	loop.run(.until_done)!
	assert wake
}

fn dynamic_async_test_async_batches_multiple_notifications() ! {
	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut notifier := Async.init()!
	defer {
		notifier.deinit()
	}

	// Send a notification many times
	notifier.notify()!
	notifier.notify()!
	notifier.notify()!
	notifier.notify()!
	notifier.notify()!

	// Wait
	mut count := u32(0)
	c_wait := &Completion{}
	notifier.wait(mut loop, c_wait, &count, dynamic_async_test_count)

	// Send a notification
	notifier.notify()!

	// Wait for wake
	loop.run(.once)!
	for _ in 0 .. 10 {
		loop.run(.no_wait)!
	}
	assert u32(1) == count
}

fn dynamic_async_tests() ! {
	dynamic_async_test_async()!
	dynamic_async_test_async_notify_first()!
	dynamic_async_test_async_batches_multiple_notifications()!
}

fn test_dynamic_async_detect() ! {
	detect()!
	dynamic_async_tests()!
}

fn test_dynamic_async_prefer_epoll() ! {
	assert prefer(.epoll)
	dynamic_async_tests()!
}
