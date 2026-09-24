module xev

import os

// ProcessTests from libxev src/watcher/process.zig (pinned 34fa508), for the
// kqueue Process.

struct KqueueProcessTestCode {
mut:
	value ?u32
}

fn kqueue_process_test_code(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r ?ErrorKind, exit_code u32) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut code := unsafe { &KqueueProcessTestCode(ud) }
	code.value = exit_code
	return .disarm
}

fn kqueue_process_test_code_or_zero(ud voidptr, _ &KqueueLoop, _ &KqueueCompletion, r ?ErrorKind, exit_code u32) CallbackAction {
	mut code := unsafe { &KqueueProcessTestCode(ud) }
	code.value = if _ := r { u32(0) } else { exit_code }
	return .disarm
}

fn kqueue_process_test_spawn(script string) &os.Process {
	mut child := os.new_process('/bin/sh')
	child.set_args(['-c', script])
	child.run()
	return child
}

fn test_kqueue_process_wait() ! {
	child := kqueue_process_test_spawn('exit 0')

	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := KqueueProcess.init(child.pid)!
	defer {
		p.deinit()
	}

	// Wait
	mut code := KqueueProcessTestCode{}
	c_wait := &KqueueCompletion{}
	p.wait(mut loop, c_wait, &code, kqueue_process_test_code)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(0) == code.value?
}

fn test_kqueue_process_wait_with_non_zero_exit_code() ! {
	child := kqueue_process_test_spawn('exit 42')

	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := KqueueProcess.init(child.pid)!
	defer {
		p.deinit()
	}

	// Wait
	mut code := KqueueProcessTestCode{}
	c_wait := &KqueueCompletion{}
	p.wait(mut loop, c_wait, &code, kqueue_process_test_code)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(42) == code.value?
}

fn test_kqueue_process_wait_on_a_process_that_already_exited() ! {
	mut child := kqueue_process_test_spawn('exit 0')

	mut loop := KqueueLoop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := KqueueProcess.init(child.pid)!
	defer {
		p.deinit()
	}

	child.wait()

	// Wait
	mut code := KqueueProcessTestCode{}
	c_wait := &KqueueCompletion{}
	p.wait(mut loop, c_wait, &code, kqueue_process_test_code_or_zero)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(0) == code.value?
}
