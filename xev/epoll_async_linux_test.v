module xev

// AsyncTests from libxev src/watcher/async.zig (pinned 34fa508), for the
// epoll Async (AsyncEventFd).

fn epoll_async_test_wake_rearm(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .rearm
}

fn epoll_async_test_wake_disarm(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

fn epoll_async_test_count(ud voidptr, _ &EpollLoop, _ &EpollCompletion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut count := unsafe { &u32(ud) }
	unsafe {
		*count += 1
	}
	return .rearm
}

fn test_epoll_async() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut notifier := EpollAsync.init()!
	defer {
		notifier.deinit()
	}

	// Wait
	mut wake := false
	c_wait := &EpollCompletion{}
	notifier.wait(mut loop, c_wait, &wake, epoll_async_test_wake_rearm)

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

fn test_epoll_async_notify_first() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut notifier := EpollAsync.init()!
	defer {
		notifier.deinit()
	}

	// Send a notification
	notifier.notify()!

	// Wait
	mut wake := false
	c_wait := &EpollCompletion{}
	notifier.wait(mut loop, c_wait, &wake, epoll_async_test_wake_disarm)

	// Wait for wake
	loop.run(.until_done)!
	assert wake
}

fn test_epoll_async_batches_multiple_notifications() ! {
	mut loop := EpollLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut notifier := EpollAsync.init()!
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
	c_wait := &EpollCompletion{}
	notifier.wait(mut loop, c_wait, &count, epoll_async_test_count)

	// Send a notification
	notifier.notify()!

	// Wait for wake
	loop.run(.once)!
	for _ in 0 .. 10 {
		loop.run(.no_wait)!
	}
	assert u32(1) == count
}
