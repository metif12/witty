module xev

import os

// ProcessTests from libxev src/watcher/process.zig (pinned 34fa508), for the
// io_uring Process (ProcessPidFd).

struct IoUringProcessTestCode {
mut:
	value ?u32
}

fn io_uring_process_test_code(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r ?ErrorKind, exit_code u32) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut code := unsafe { &IoUringProcessTestCode(ud) }
	code.value = exit_code
	return .disarm
}

fn io_uring_process_test_code_or_zero(ud voidptr, _ &IoUringLoop, _ &IoUringCompletion, r ?ErrorKind, exit_code u32) CallbackAction {
	mut code := unsafe { &IoUringProcessTestCode(ud) }
	code.value = if _ := r { u32(0) } else { exit_code }
	return .disarm
}

fn io_uring_process_test_spawn(script string) &os.Process {
	mut child := os.new_process('/bin/sh')
	child.set_args(['-c', script])
	child.run()
	return child
}

fn test_io_uring_process_wait() ! {
	child := io_uring_process_test_spawn('exit 0')

	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := IoUringProcess.init(child.pid)!
	defer {
		p.deinit()
	}

	// Wait
	mut code := IoUringProcessTestCode{}
	c_wait := &IoUringCompletion{}
	p.wait(mut loop, c_wait, &code, io_uring_process_test_code)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(0) == code.value?
}

fn test_io_uring_process_wait_with_non_zero_exit_code() ! {
	child := io_uring_process_test_spawn('exit 42')

	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := IoUringProcess.init(child.pid)!
	defer {
		p.deinit()
	}

	// Wait
	mut code := IoUringProcessTestCode{}
	c_wait := &IoUringCompletion{}
	p.wait(mut loop, c_wait, &code, io_uring_process_test_code)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(42) == code.value?
}

fn test_io_uring_process_wait_on_a_process_that_already_exited() ! {
	mut child := io_uring_process_test_spawn('exit 0')

	mut loop := IoUringLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := IoUringProcess.init(child.pid)!
	defer {
		p.deinit()
	}

	child.wait()

	// Wait
	mut code := IoUringProcessTestCode{}
	c_wait := &IoUringCompletion{}
	p.wait(mut loop, c_wait, &code, io_uring_process_test_code_or_zero)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(0) == code.value?
}
