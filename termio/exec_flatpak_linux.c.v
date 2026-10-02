module termio

import internal_os
import log
import os
import xev

// Kill the underlying process started via Flatpak host command.
// This sends a signal via the Flatpak API.
fn kill_command_flatpak(mut command internal_os.FlatpakHostCommand) ! {
	command.signal(u8(sig_hup), true)!
}

fn exec_flatpak_exit(td_ voidptr, _ &xev.Loop, _ &internal_os.FlatpakCompletion, r ?IError, exit_code u8) {
	if _ := r {
		panic('unreachable')
	}
	mut td := unsafe { &ThreadData(td_) }
	exec_process_exit_common(mut td, u32(exit_code))
}

// Flatpak sandboxing prevents access to certain reserved paths
// regardless of configured permissions. Perform a test spawn
// to get around this problem
//
// https://docs.flatpak.org/en/latest/sandbox-permissions.html#reserved-paths
fn flatpak_cwd_accessible(cwd string) !bool {
	mut dev_null := os.open_file('/dev/null', 'r+')!
	defer {
		dev_null.close()
	}
	mut command := internal_os.FlatpakHostCommand{
		argv:   ['/bin/sh', '-c', ':']
		cwd:    cwd
		stdin:  dev_null.fd
		stdout: dev_null.fd
		stderr: dev_null.fd
	}
	command.spawn() or {
		log.warn('cannot spawn command at cwd, ignoring: ${err}')
		return false
	}
	_ = command.wait()!

	return true
}
