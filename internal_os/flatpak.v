module internal_os

// V translation of Ghostty's src/os/flatpak.zig FlatpakHostCommand. The GIO
// calls are in flatpak_linux.c.v; on other systems spawning and signalling
// report an error, since Ghostty only builds this type with Flatpak support.
import datastruct
import sync
import xev

// A struct to help execute commands on the host via the
// org.freedesktop.Flatpak.Development DBus module. This uses GIO/GLib
// under the hood.
//
// This always spawns its own thread and maintains its own GLib event loop.
// This makes it easy for the command to behave synchronously similar to
// std.process.Child.
//
// There are lots of chances for low-hanging improvements here (automatic
// pipes, /dev/null, etc.) but this was purpose built for my needs so
// it doesn't have all of those.
//
// Requires GIO, GLib to be available and linked.
pub struct FlatpakHostCommand {
pub:
	// Argv are the arguments to call on the host with argv[0] being
	// the command to execute.
	argv []string

	// The cwd for the new process. If this is not set then it will use
	// the current cwd of the calling process.
	cwd ?string

	// Environment variables for the child process. If this is null, this
	// does not send any environment variables.
	env ?map[string]string

	// File descriptors to send to the child process. It is up to the
	// caller to create the file descriptors and set them up.
	stdin  int
	stdout int
	stderr int
mut:
	// State of the process. This is updated by the dedicated thread it
	// runs in and is protected by the given lock and condition variable.
	state       FlatpakState
	state_mutex &sync.Mutex          = sync.new_mutex()
	state_cv    datastruct.Condition = datastruct.Condition.init()
}

// State the process is in. This can't be inspected directly, you
// must use getters on the struct to get access.
enum FlatpakStateTag {
	// Initial state
	init
	// Error starting. The error message is only available via logs.
	// (This isn't a fundamental limitation, just didn't need the
	// error message yet)
	err
	// Process started with the given pid on the host.
	started
	// Process exited
	exited
}

// Ghostty's tagged State union, flattened: `pid` belongs to started and
// exited, `status` to exited, and the remaining fields to started.
struct FlatpakState {
mut:
	tag          FlatpakStateTag
	pid          u32
	loop_xev     &xev.Loop          = unsafe { nil }
	completion   &FlatpakCompletion = unsafe { nil }
	subscription u32
	loop         voidptr
	status       u8
}

// The callback of waitXev. Zig's `WaitError!u8` result is split into the
// error (none on success) and the exit status.
pub type FlatpakWaitCallback = fn (ud voidptr, l &xev.Loop, c &FlatpakCompletion, r ?IError, status u8)

// The WaitError!u8 value stored for a completion.
pub struct FlatpakWaitResult {
pub:
	err    ?IError
	status u8
}

pub struct FlatpakCompletion {
pub mut:
	callback FlatpakWaitCallback = flatpak_noop_callback
	c_xev    xev.Completion
	userdata voidptr
	timer    ?xev.Timer
	result   ?FlatpakWaitResult
}

// Errors that are possible from us: FlatpakMustBeStarted, FlatpakSpawnFail,
// FlatpakSetupFail, and FlatpakRPCFail. WaitError adds the xev.Timer.RunError
// kinds.

// Spawn the command. This will start the host command. On return,
// the pid will be available. This must only be called with the
// state in "init".
//
// Precondition: The self pointer MUST be stable.
pub fn (mut self FlatpakHostCommand) spawn() !u32 {
	$if linux {
		// We don't track this thread, it will terminate on its own on command exit
		_ = spawn flatpak_host_command_thread_main(self)
	} $else {
		return error('Flatpak host commands are only supported on Linux')
	}

	// Wait for the process to start or error.
	self.state_mutex.lock()
	defer {
		self.state_mutex.unlock()
	}
	for self.state.tag == .init {
		self.state_cv.wait(mut self.state_mutex)
	}

	return match self.state.tag {
		.init { panic('unreachable') }
		.err { error('FlatpakSpawnFail') }
		.started, .exited { self.state.pid }
	}
}

// Wait for the process to end and return the exit status. This
// can only be called ONCE. Once this returns, the state is reset.
pub fn (mut self FlatpakHostCommand) wait() !u8 {
	self.state_mutex.lock()
	defer {
		self.state_mutex.unlock()
	}

	for {
		match self.state.tag {
			.init {
				return error('FlatpakMustBeStarted')
			}
			.err {
				return error('FlatpakSpawnFail')
			}
			.started {}
			.exited {
				status := self.state.status
				self.state = FlatpakState{
					tag: .init
				}
				self.state_cv.broadcast()
				return status
			}
		}

		self.state_cv.wait(mut self.state_mutex)
	}
	return 0
}

// Wait for the process to end asynchronously via libxev. This
// can only be called ONCE.
pub fn (mut self FlatpakHostCommand) wait_xev(mut loop xev.Loop, completion &FlatpakCompletion, userdata voidptr, cb FlatpakWaitCallback) {
	self.state_mutex.lock()
	defer {
		self.state_mutex.unlock()
	}

	mut c := unsafe { completion }
	unsafe {
		*c = FlatpakCompletion{
			callback: cb
			userdata: userdata
			timer:    xev.Timer.init() or { panic('unreachable') } // not great, but xev timer can't fail atm
		}
	}

	match self.state.tag {
		.init {
			c.result = FlatpakWaitResult{
				err: error('FlatpakMustBeStarted')
			}
		}
		.err {
			c.result = FlatpakWaitResult{
				err: error('FlatpakSpawnFail')
			}
		}
		.started {
			self.state.loop_xev = unsafe { &loop }
			self.state.completion = c
			return
		}
		.exited {
			c.result = FlatpakWaitResult{
				status: self.state.status
			}
		}
	}

	flatpak_completion_run(mut loop, c)
}

// Runs the zero-delay timer that delivers a completion's result on its xev
// loop. Ghostty inlines this identical timer call in waitXev and onExit.
fn flatpak_completion_run(mut loop xev.Loop, c &FlatpakCompletion) {
	timer := c.timer or { panic('unreachable') }
	timer.run(mut loop, &c.c_xev, 0, c.userdata, flatpak_completion_timer_callback)
}

fn flatpak_completion_timer_callback(ud voidptr, l_inner &xev.Loop, c_inner &xev.Completion, r ?xev.ErrorKind) xev.CallbackAction {
	mut c_outer := unsafe { &FlatpakCompletion(voidptr(usize(c_inner) - __offsetof(FlatpakCompletion, c_xev))) }
	defer {
		if mut t := c_outer.timer {
			t.deinit()
		}
	}

	result := if err := r {
		FlatpakWaitResult{
			err: xev.new_error(err)
		}
	} else {
		c_outer.result or { panic('unreachable') }
	}
	c_outer.callback(ud, l_inner, c_outer, result.err, result.status)
	return .disarm
}

// Send a signal to the started command. This does nothing if the
// command is not in the started state.
pub fn (mut self FlatpakHostCommand) signal(sig u8, pg bool) ! {
	pid := self.started_pid() or { return }
	$if linux {
		flatpak_host_command_signal_linux(pid, sig, pg)!
	} $else {
		return error('Flatpak host commands are only supported on Linux')
	}
}

fn (mut self FlatpakHostCommand) started_pid() ?u32 {
	self.state_mutex.lock()
	defer {
		self.state_mutex.unlock()
	}
	if self.state.tag == .started {
		return self.state.pid
	}
	return none
}

// Helper to update the state and notify waiters via the cv.
fn (mut self FlatpakHostCommand) update_state(state FlatpakState) {
	self.state_mutex.lock()
	defer {
		self.state_mutex.unlock()
	}
	defer {
		self.state_cv.broadcast()
	}
	self.state = state
}

fn flatpak_noop_callback(_ voidptr, _ &xev.Loop, _ &FlatpakCompletion, _ ?IError, _ u8) {}
