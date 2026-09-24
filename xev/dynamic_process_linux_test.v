module xev

import os

// ProcessTests from libxev src/watcher/process.zig (pinned 34fa508), for the
// dynamic Process (ProcessDynamic). The suite runs with the backend in use, so
// it is run twice: with the backend chosen by detect() (io_uring when
// available) and with epoll selected by prefer(.epoll).

struct DynamicProcessTestCode {
mut:
	value ?u32
}

// Zig's `.?`: `?` propagation needs an option-returning function.
fn dynamic_process_test_unwrap(v ?u32) u32 {
	return v or { panic('attempt to use null value') }
}

fn dynamic_process_test_code(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind, exit_code u32) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut code := unsafe { &DynamicProcessTestCode(ud) }
	code.value = exit_code
	return .disarm
}

fn dynamic_process_test_code_or_zero(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind, exit_code u32) CallbackAction {
	mut code := unsafe { &DynamicProcessTestCode(ud) }
	code.value = if _ := r { u32(0) } else { exit_code }
	return .disarm
}

fn dynamic_process_test_spawn(script string) &os.Process {
	mut child := os.new_process('/bin/sh')
	child.set_args(['-c', script])
	child.run()
	return child
}

fn dynamic_process_test_process_wait() ! {
	child := dynamic_process_test_spawn('exit 0')

	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := Process.init(child.pid)!
	defer {
		p.deinit()
	}

	// Wait
	mut code := DynamicProcessTestCode{}
	c_wait := &Completion{}
	p.wait(mut loop, c_wait, &code, dynamic_process_test_code)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(0) == dynamic_process_test_unwrap(code.value)
}

fn dynamic_process_test_process_wait_with_non_zero_exit_code() ! {
	child := dynamic_process_test_spawn('exit 42')

	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := Process.init(child.pid)!
	defer {
		p.deinit()
	}

	// Wait
	mut code := DynamicProcessTestCode{}
	c_wait := &Completion{}
	p.wait(mut loop, c_wait, &code, dynamic_process_test_code)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(42) == dynamic_process_test_unwrap(code.value)
}

fn dynamic_process_test_process_wait_on_a_process_that_already_exited() ! {
	mut child := dynamic_process_test_spawn('exit 0')

	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}

	mut p := Process.init(child.pid)!
	defer {
		p.deinit()
	}

	child.wait()

	// Wait
	mut code := DynamicProcessTestCode{}
	c_wait := &Completion{}
	p.wait(mut loop, c_wait, &code, dynamic_process_test_code_or_zero)

	// Wait for wake
	loop.run(.until_done)!
	assert u32(0) == dynamic_process_test_unwrap(code.value)
}

fn dynamic_process_tests() ! {
	dynamic_process_test_process_wait()!
	dynamic_process_test_process_wait_with_non_zero_exit_code()!
	dynamic_process_test_process_wait_on_a_process_that_already_exited()!
}

fn test_dynamic_process_detect() ! {
	detect()!
	dynamic_process_tests()!
}

fn test_dynamic_process_prefer_epoll() ! {
	assert prefer(.epoll)
	dynamic_process_tests()!
}
