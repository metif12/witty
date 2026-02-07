module command

// Tests for Command and Exit types.

fn test_exit_normal() {
	exit_val := Exit(ExitNormal{ status: 42 })
	match exit_val {
		ExitNormal {
			assert exit_val.status == 42
		}
		else {
			assert false, 'expected ExitNormal'
		}
	}
}

fn test_exit_signal() {
	exit_val := Exit(ExitSignal{ signal: 9 })
	match exit_val {
		ExitSignal {
			assert exit_val.signal == 9
		}
		else {
			assert false, 'expected ExitSignal'
		}
	}
}

fn test_exit_stopped() {
	exit_val := Exit(ExitStopped{ signal: 19 })
	match exit_val {
		ExitStopped {
			assert exit_val.signal == 19
		}
		else {
			assert false, 'expected ExitStopped'
		}
	}
}

fn test_exit_unknown() {
	exit_val := Exit(ExitUnknown{ status: 0xDEAD })
	match exit_val {
		ExitUnknown {
			assert exit_val.status == 0xDEAD
		}
		else {
			assert false, 'expected ExitUnknown'
		}
	}
}

fn test_exit_from_status_exited() {
	// On POSIX, normal exit status is (exit_code << 8) with low byte 0.
	status := int(42) << 8
	exit_val := exit_from_status(status)
	match exit_val {
		ExitNormal {
			assert exit_val.status == 42
		}
		else {
			assert false, 'expected ExitNormal from status'
		}
	}
}

fn test_exit_from_status_zero() {
	// Exit status 0 (success).
	status := int(0) << 8
	exit_val := exit_from_status(status)
	match exit_val {
		ExitNormal {
			assert exit_val.status == 0
		}
		else {
			assert false, 'expected ExitNormal with status 0'
		}
	}
}

fn test_command_defaults() {
	cmd := Command{}
	assert cmd.path == ''
	assert cmd.args.len == 0
	assert cmd.env.len == 0
	assert cmd.cwd == ''
	assert cmd.stdin_fd == -1
	assert cmd.stdout_fd == -1
	assert cmd.stderr_fd == -1
	assert cmd.pid == -1
	assert cmd.data == unsafe { nil }
}

fn test_command_set_data() {
	mut cmd := Command{
		path: '/bin/sh'
	}
	mut value := 42
	cmd.set_data(voidptr(&value))
	assert cmd.get_data() != unsafe { nil }
}

fn test_command_with_args() {
	cmd := Command{
		path: '/bin/sh'
		args: ['/bin/sh', '-c', 'echo hello']
	}
	assert cmd.path == '/bin/sh'
	assert cmd.args.len == 3
	assert cmd.args[0] == '/bin/sh'
	assert cmd.args[1] == '-c'
	assert cmd.args[2] == 'echo hello'
}

fn test_command_with_env() {
	cmd := Command{
		path: '/bin/sh'
		env: {
			'HOME':  '/home/test'
			'VALUE': 'hello'
		}
	}
	assert cmd.env.len == 2
	assert cmd.env['HOME'] == '/home/test'
	assert cmd.env['VALUE'] == 'hello'
}

fn test_command_with_cwd() {
	cmd := Command{
		path: '/bin/sh'
		args: ['/bin/sh', '-c', 'pwd']
		cwd: '/tmp'
	}
	assert cmd.cwd == '/tmp'
}

fn test_command_wait_not_started() {
	cmd := Command{
		path: '/bin/sh'
	}
	// Waiting on a command that hasn't been started should error.
	cmd.wait(true) or {
		assert err.msg() == 'process not started'
		return
	}
	assert false, 'expected error from wait on unstarted command'
}

fn test_wifexited() {
	// Normal exit: low 7 bits are 0.
	assert wifexited(0) == true
	assert wifexited(256) == true // exit(1) -> status = 256
	// Signal termination: low 7 bits are non-zero.
	assert wifexited(9) == false // killed by signal 9
}

fn test_wexitstatus() {
	assert wexitstatus(0) == 0
	assert wexitstatus(256) == 1 // exit(1)
	assert wexitstatus(int(42) << 8) == 42
}

fn test_wifsignaled() {
	// Signal 9 (SIGKILL): low 7 bits = 9, (9+1)>>1 = 5 > 0.
	assert wifsignaled(9) == true
	// Normal exit: low 7 bits = 0, (0+1)>>1 = 0, not > 0.
	assert wifsignaled(0) == false
}

fn test_wtermsig() {
	assert wtermsig(9) == 9
	assert wtermsig(15) == 15 // SIGTERM
}
