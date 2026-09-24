module internal_os

import xev

// Ghostty's os/flatpak.zig has no tests. These cover the host command state
// machine and waitXev's delivery through the xev loop, which need no portal.

struct FlatpakWaitProbe {
mut:
	called bool
	err    string
	status u8
}

fn flatpak_test_wait_cb(ud voidptr, _ &xev.Loop, _ &FlatpakCompletion, r ?IError, status u8) {
	mut probe := unsafe { &FlatpakWaitProbe(ud) }
	probe.called = true
	if err := r {
		probe.err = err.msg()
	}
	probe.status = status
}

fn test_flatpak_host_command_wait_requires_start() {
	mut command := FlatpakHostCommand{
		argv: ['/bin/true']
	}
	command.wait() or {
		assert err.msg() == 'FlatpakMustBeStarted'
		return
	}
	assert false, 'wait succeeded before spawn'
}

fn test_flatpak_host_command_wait_xev_reports_through_loop() ! {
	mut command := FlatpakHostCommand{
		argv: ['/bin/true']
	}
	mut loop := xev.Loop.init(xev.Options{})!
	defer {
		loop.deinit()
	}
	mut probe := FlatpakWaitProbe{}
	c := &FlatpakCompletion{}
	command.wait_xev(mut loop, c, &probe, flatpak_test_wait_cb)

	// The result is delivered by a zero-delay timer on the loop.
	assert !probe.called
	loop.run(.until_done)!
	assert probe.called
	assert probe.err == 'FlatpakMustBeStarted'
}

fn test_flatpak_host_command_wait_xev_delivers_exit_status() ! {
	mut command := FlatpakHostCommand{
		argv: ['/bin/true']
	}
	command.update_state(FlatpakState{
		tag:    .exited
		pid:    42
		status: 3
	})
	mut loop := xev.Loop.init(xev.Options{})!
	defer {
		loop.deinit()
	}
	mut probe := FlatpakWaitProbe{}
	c := &FlatpakCompletion{}
	command.wait_xev(mut loop, c, &probe, flatpak_test_wait_cb)
	loop.run(.until_done)!
	assert probe.called
	assert probe.err == ''
	assert probe.status == 3
}
