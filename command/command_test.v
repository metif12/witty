module command

import os

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

fn test_exit_from_status_stopped() {
	status := (int(19) << 8) | 0x7f
	exit_val := exit_from_status(status)
	match exit_val {
		ExitStopped {
			assert exit_val.signal == 19
		}
		else {
			assert false, 'expected ExitStopped from status'
		}
	}
}

fn test_command_defaults() {
	cmd := Command{}
	assert cmd.path == ''
	assert cmd.args.len == 0
	assert cmd.env == none
	assert cmd.cwd == none
	assert cmd.stdin_fd == -1
	assert cmd.stdout_fd == -1
	assert cmd.stderr_fd == -1
	assert cmd.pid == none
	assert cmd.data == unsafe { nil }
	assert cmd.process_handle == unsafe { nil }
	assert cmd.pseudo_console == unsafe { nil }
}

fn test_windows_create_env_block() {
	block := create_windows_env_block({
		'VALUE': 'hello'
	})
	assert block[..12] == [u16(`V`), u16(`A`), u16(`L`), u16(`U`), u16(`E`), u16(`=`), u16(`h`),
		u16(`e`), u16(`l`), u16(`l`), u16(`o`), u16(0)]
	assert block[block.len - 4..] == [u16(0), 0, 0, 0]
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
	if env := cmd.env {
		assert env.len == 2
		assert env['HOME'] == '/home/test'
		assert env['VALUE'] == 'hello'
	} else {
		assert false, 'expected an explicit environment'
	}
}

fn test_command_with_cwd() {
	cmd := Command{
		path: '/bin/sh'
		args: ['/bin/sh', '-c', 'pwd']
		cwd: '/tmp'
	}
	assert cmd.cwd or { '' } == '/tmp'
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
	// A stopped child has the low status byte 0x7f and is not signaled.
	assert wifsignaled((int(19) << 8) | 0x7f) == false
}

fn test_wtermsig() {
	assert wtermsig(9) == 9
	assert wtermsig(15) == 15 // SIGTERM
}

fn test_command_start_with_exact_environment_and_path_search() {
	$if windows {
		return
	}
	mut cmd := Command{
		path: 'sh'
		args: ['sh', '-c', 'test "\$WITTY_COMMAND_ENV" = translated && test -z "\$HOME"']
		env: {
			'PATH':              '/bin:/usr/bin'
			'WITTY_COMMAND_ENV': 'translated'
		}
	}
	testing_start(mut cmd) or { assert false, err.msg() }
	exit := cmd.wait(true) or { panic(err) }
	assert exit == Exit(ExitNormal{
		status: 0
	})
}

fn command_test_pre_exec(mut _ Command) {
	C._exit(42)
}

fn test_command_pre_exec() {
	$if windows {
		return
	}
	mut cmd := Command{
		path: '/bin/sh'
		args: ['/bin/sh', '-v']
		pre_exec: command_test_pre_exec
	}
	testing_start(mut cmd)!
	assert cmd.pid != none
	exit_state := cmd.wait(true)!
	assert exit_state == Exit(ExitNormal{
		status: 42
	})
}

fn test_command_redirect_stdout() {
	$if windows {
		return
	}
	path := os.join_path(os.temp_dir(), 'witty-command-stdout-${os.getpid()}')
	os.rm(path) or {}
	defer {
		os.rm(path) or {}
	}
	mut stdout := os.create(path)!
	defer {
		stdout.close()
	}
	mut cmd := Command{
		path: '/bin/sh'
		args: ['/bin/sh', '-c', 'echo hello']
		stdout_fd: stdout.fd
	}
	testing_start(mut cmd)!
	exit_state := cmd.wait(true)!
	assert exit_state == Exit(ExitNormal{
		status: 0
	})
	assert os.read_file(path)! == 'hello\n'
}

fn test_command_start_inherits_environment() {
	$if windows {
		return
	}
	name := 'WITTY_COMMAND_INHERIT_TEST'
	previous := os.getenv_opt(name)
	os.setenv(name, 'inherited', true)
	defer {
		if value := previous {
			os.setenv(name, value, true)
		} else {
			os.unsetenv(name)
		}
	}
	mut cmd := Command{
		path: '/bin/sh'
		args: ['/bin/sh', '-c', 'test "\$WITTY_COMMAND_INHERIT_TEST" = inherited']
	}
	testing_start(mut cmd) or { assert false, err.msg() }
	exit := cmd.wait(true) or { panic(err) }
	assert exit == Exit(ExitNormal{
		status: 0
	})
}

fn test_command_start_with_explicit_empty_environment() {
	$if windows {
		return
	}
	name := 'WITTY_COMMAND_EMPTY_ENV_TEST'
	previous := os.getenv_opt(name)
	os.setenv(name, 'must-not-be-inherited', true)
	defer {
		if value := previous {
			os.setenv(name, value, true)
		} else {
			os.unsetenv(name)
		}
	}
	mut cmd := Command{
		path: '/bin/sh'
		args: ['/bin/sh', '-c', 'test -z "\$WITTY_COMMAND_EMPTY_ENV_TEST"']
		env: map[string]string{}
	}
	testing_start(mut cmd) or { assert false, err.msg() }
	exit := cmd.wait(true) or { panic(err) }
	assert exit == Exit(ExitNormal{
		status: 0
	})
}

fn test_command_exec_failure_exits_child() {
	$if windows {
		return
	}
	mut cmd := Command{
		path: '/not/a/witty-binary'
		args: ['/not/a/witty-binary', '']
	}
	testing_start(mut cmd) or { assert false, err.msg() }
	exit := cmd.wait(true) or { panic(err) }
	assert exit == Exit(ExitNormal{
		status: 1
	})
}

fn testing_start(mut cmd Command) ! {
	cmd.start() or {
		if is_exec_failed_in_child(err) {
			C._exit(1)
		}
		return err
	}
}
