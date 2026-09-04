module internal_os

// FlatpakHostCommand executes a process on the Flatpak host through
// org.freedesktop.Flatpak.Development. The command owns the native state
// created by spawn; callers must keep its address stable until wait returns.
pub struct FlatpakHostCommand {
pub:
	argv   []string
	cwd    ?string
	env    ?map[string]string
	stdin  int
	stdout int
	stderr int
mut:
	handle voidptr
}

// spawn starts the host command and blocks only until the host PID or a setup
// error is available. Process completion is handled by the bridge's dedicated
// GLib event-loop thread.
pub fn (mut self FlatpakHostCommand) spawn() !u32 {
	$if linux {
		return flatpak_host_command_spawn_linux(mut self)
	} $else {
		return error('Flatpak host commands are only supported on Linux')
	}
}

// wait blocks until the host command exits and returns its exit status.
pub fn (mut self FlatpakHostCommand) wait() !u8 {
	$if linux {
		return flatpak_host_command_wait_linux(mut self)
	} $else {
		return error('Flatpak host commands are only supported on Linux')
	}
}

// signal sends sig to the host PID or its process group. It is a no-op after
// the process has left the started state, matching the pinned implementation.
pub fn (mut self FlatpakHostCommand) signal(sig u8, process_group bool) ! {
	$if linux {
		flatpak_host_command_signal_linux(mut self, sig, process_group)!
	} $else {
		return error('Flatpak host commands are only supported on Linux')
	}
}

pub fn (mut self FlatpakHostCommand) deinit() {
	$if linux {
		flatpak_host_command_deinit_linux(mut self)
	}
}
