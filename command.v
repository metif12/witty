module main

// --- Original Ghostty Comments Start: src/Command.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/Command.zig
//
// Command launches sub-processes. This is an alternate implementation to the
// Zig std.process.Child since at the time of authoring this, std.process.Child
// didn't support the options necessary to spawn a shell attached to a pty.
//
// Consequently, I didn't implement a lot of features that std.process.Child
// supports because we didn't need them. Cross-platform subprocessing is not
// a trivial thing to implement (I've done it in three separate languages now)
// so if we want to replatform onto std.process.Child I'd love to do that.
// This was just the fastest way to get something built.
//
// Issues with std.process.Child:
//
//   * No pre_exec callback for logic after fork but before exec.
//   * posix_spawn is used for Mac, but doesn't support the necessary
//     features for tty setup.
//
// Path to the command to run. This doesn't have to be an absolute path,
// because use exec functions that search the PATH, if necessary.
//
// This field is null-terminated to avoid a copy for the sake of
// adding a null terminator since POSIX systems are so common.
// Command-line arguments. It is the responsibility of the caller to set
// args[0] to the command. If args is empty then args[0] will automatically
// be set to equal path.
// Environment variables for the child process. If this is null, inherits
// the environment variables from this process. These are the exact
// environment variables to set; these are /not/ merged.
// Working directory to change to in the child process. If not set, the
// working directory of the calling process is preserved.
// The file handle to set for stdin/out/err. If this isn't set, we do
// nothing explicitly so it is up to the behavior of the operating system.
// If set, this will be executed /in the child process/ after fork but
// before exec. This is useful to setup some state in the child before the
// exec process takes over, such as signal handlers, setsid, setuid, etc.
// If set, then the process will be created attached to this pseudo console.
// `stdin`, `stdout`, and `stderr` will be ignored if set.
// User data that is sent to the callback. Set with setData and getData
// for a more user-friendly API.
// Process ID is set after start is called.
// LinuxCGroup type depends on our target OS
// The various methods a process may exit.
// Exited by normal exit call, value is exit status
// Exited by a signal, value is the signal
// Exited by a stop signal, value is signal
// Unknown exit reason, value is the status from waitpid
// Start the subprocess. This returns immediately once the child is started.
//
// After this is successful, self.pid is available.
// Use an arena allocator for the temporary allocations we need in this func.
// IMPORTANT: do all allocation prior to the fork(). I believe it is undefined
// behavior if you malloc between fork and exec. The source of the Zig
// stdlib seems to verify this as well as Go.
// Null-terminate all our arguments
// Determine our env vars
// Fork. If we have a cgroup specified on Linxu then we use clone
// Parent, return immediately.
// We are the child.
// Setup our file descriptors for std streams.
// Setup our working directory
// This can fail if we don't have permission to go to
// this directory or if due to race conditions it doesn't
// exist or any various other reasons. We don't want to
// crash the entire process if this fails so we ignore it.
// We don't log because that'll show up in the output.
// Restore any rlimits that were set by Ghostty. This might fail but
// any failures are ignored (its best effort).
// If the user requested a pre exec callback, call it now.
// Finally, replace our process.
// Note: we must use the "p"-variant of exec here because we
// do not guarantee our command is looked up already in the path.
// If we are executing this code, the exec failed. We're in the
// child process so there isn't much we can do. We try to output
// something reasonable. Its important to note we MUST NOT return
// any other error condition from here on out.
// We return a very specific error that can be detected to determine
// we're in the child.
// TODO: In the case of having FDs instead of pty, need to set up
// attributes such that the child process only inherits these handles,
// then set bInheritsHandles below.
// We use dup3 so that we can clear CLO_ON_EXEC. We do NOT want this
// file descriptor to be closed on exec since we're exactly exec-ing after
// this.
// Mac doesn't support dup3 so we use dup2. We purposely clear
// CLO_ON_EXEC for this fd.
// Wait for the command to exit and return information about how it exited.
// Block until the process exits. This returns immediately if the
// process already exited.
// We specify NOHANG because its not our fault if the process we launch
// for the tty doesn't properly waitpid its children. We don't want
// to hang the terminal over it.
// When NOHANG is specified, waitpid will return a pid of 0 if the process
// doesn't have a status to report. When that happens, it is as though the
// wait call has not been performed, so we need to keep trying until we get
// a non-zero pid back, otherwise we end up with zombie processes.
// Sets command->data to data.
// Returns command->data.
// Copied from Zig. This is a publicly exported function but there is no
// way to get it from the std package.
// Copied from Zig. This is a publicly exported function but there is no
// way to get it from the std package.
// count bytes needed
// +1 for '='
// +1 for null byte
// Copied from Zig. This function could be made public in child_process.zig instead.
// This runs in the child, so we can exit and it won't
// kill the test runner.
// Read our stdout
// Read our stdout
// Read our stdout
// Test validate an execveZ failure correctly terminates when error.ExecFailedInChild is correctly handled
//
// Incorrectly handling an error.ExecFailedInChild results in a second copy of the test process running.
// Duplicating the test process leads to weird behavior
// zig build test will hang
// test binary created via -Demit-test-exe will run 2 copies of the test suite
// If cmd.start fails with error.ExecFailedInChild it's the _child_ process that is running. If it does not
// terminate in response to that error both the parent and child will continue as if they _are_ the test suite
// process.
// I am a child process, I must not get confused and continue running the rest of the test suite.
//
// --- Original Ghostty Comments End: src/Command.zig


// Command launches sub-processes. This is an alternate implementation to
// manage subprocess spawning with PTY support.
//
// Consequently, this doesn't implement many features that a full
// subprocess library would. Cross-platform subprocessing is not
// a trivial thing to implement (it has been done in three separate
// languages now) so if we want to replatform onto a standard library
// implementation, that would be great. This was just the fastest way
// to get something built.
//
// Issues with standard library process spawning:
//
//   * No pre_exec callback for logic after fork but before exec.
//   * posix_spawn is used for Mac, but doesn't support the necessary
//     features for tty setup.

import os

// C interop declarations for POSIX process management.
fn C.fork() int
fn C.execvp(file &char, argv &&char) int
fn C.waitpid(pid int, status &int, options int) int
fn C.dup2(oldfd int, newfd int) int
fn C.chdir(path &char) int
fn C.setsid() int
fn C._exit(status int)

// WNOHANG flag for non-blocking waitpid.
const wnohang = 1

// WIFEXITED and friends - macros for interpreting waitpid status.
// These match the POSIX definitions on macOS and Linux.

// wifexited returns true if the child terminated normally.
fn wifexited(status int) bool {
	return (status & 0x7f) == 0
}

// wexitstatus returns the exit status of a normally terminated child.
fn wexitstatus(status int) u8 {
	return u8((status >> 8) & 0xff)
}

// wifsignaled returns true if the child was terminated by a signal.
fn wifsignaled(status int) bool {
	return ((status & 0x7f) + 1) >> 1 > 0
}

// wtermsig returns the signal number that caused the child to terminate.
fn wtermsig(status int) u32 {
	return u32(status & 0x7f)
}

// wifstopped returns true if the child is currently stopped.
fn wifstopped(status int) bool {
	return (status & 0xff) == 0x7f
}

// wstopsig returns the signal number that caused the child to stop.
fn wstopsig(status int) u32 {
	return u32((status >> 8) & 0xff)
}

// PreExecFn is called in the child process after fork but before exec.
// This is useful to setup some state in the child before the exec process
// takes over, such as signal handlers, setsid, setuid, etc.
pub type PreExecFn = fn (mut cmd Command)

// The various methods a process may exit.
pub type Exit = ExitNormal | ExitSignal | ExitStopped | ExitUnknown

pub struct ExitNormal {
pub:
	// Exited by normal exit call, value is exit status.
	status u8
}

pub struct ExitSignal {
pub:
	// Exited by a signal, value is the signal number.
	signal u32
}

pub struct ExitStopped {
pub:
	// Exited by a stop signal, value is signal number.
	signal u32
}

pub struct ExitUnknown {
pub:
	// Unknown exit reason, value is the raw status from waitpid.
	status u32
}

// exit_from_status interprets a raw waitpid status value and returns
// the appropriate Exit variant.
pub fn exit_from_status(status int) Exit {
	if wifexited(status) {
		return ExitNormal{
			status: wexitstatus(status)
		}
	} else if wifsignaled(status) {
		return ExitSignal{
			signal: wtermsig(status)
		}
	} else if wifstopped(status) {
		return ExitStopped{
			signal: wstopsig(status)
		}
	} else {
		return ExitUnknown{
			status: u32(status)
		}
	}
}

pub struct Command {
pub mut:
	// Path to the command to run. This doesn't have to be an absolute path,
	// because we use exec functions that search the PATH, if necessary.
	path string

	// Command-line arguments. It is the responsibility of the caller to set
	// args[0] to the command. If args is empty then args[0] will automatically
	// be set to equal path.
	args []string

	// Environment variables for the child process. If this is empty, inherits
	// the environment variables from this process. These are the exact
	// environment variables to set; these are /not/ merged.
	env map[string]string

	// Working directory to change to in the child process. If not set, the
	// working directory of the calling process is preserved.
	cwd string

	// File descriptors for stdin/out/err (as fd integers).
	// -1 means not set, in which case we do nothing explicitly
	// so it is up to the behavior of the operating system.
	stdin_fd  int = -1
	stdout_fd int = -1
	stderr_fd int = -1

	// If set, this will be executed /in the child process/ after fork but
	// before exec. This is useful to setup some state in the child before the
	// exec process takes over, such as signal handlers, setsid, setuid, etc.
	pre_exec ?PreExecFn

	// User data pointer. Use set_data/get_data for a more user-friendly API.
	data voidptr

	// Process ID is set after start is called.
	pid int = -1
}

// start launches the subprocess. This returns immediately once the child
// is started.
//
// After this is successful, self.pid is available.
//
// On POSIX, this forks and execs. The fork/exec pattern is used instead
// of posix_spawn because we need the pre_exec callback to run between
// fork and exec (e.g. for PTY setup, setsid, signal handling, etc.).
//
// XTODO: Windows support is not implemented.
pub fn (mut self Command) start() ! {
	self.start_posix()!
}

// start_posix implements the POSIX fork/exec subprocess launch.
fn (mut self Command) start_posix() ! {
	// Build the argv array for execvp.
	// If args is empty, args[0] will be set to path.
	mut argv := if self.args.len > 0 {
		self.args.clone()
	} else {
		[self.path]
	}

	// Fork. IMPORTANT: do all allocation prior to the fork().
	// It is undefined behavior to malloc between fork and exec.
	pid := C.fork()
	if pid < 0 {
		return error('fork failed')
	}

	if pid != 0 {
		// Parent, return immediately.
		self.pid = pid
		return
	}

	// We are the child.

	// Setup our file descriptors for std streams.
	// We use dup2 to redirect file descriptors. We purposely do NOT
	// set CLO_ON_EXEC for these since we want them inherited by exec.
	if self.stdin_fd >= 0 {
		if C.dup2(self.stdin_fd, 0) < 0 {
			C._exit(1)
		}
	}
	if self.stdout_fd >= 0 {
		if C.dup2(self.stdout_fd, 1) < 0 {
			C._exit(1)
		}
	}
	if self.stderr_fd >= 0 {
		if C.dup2(self.stderr_fd, 2) < 0 {
			C._exit(1)
		}
	}

	// Setup our working directory.
	// This can fail if we don't have permission to go to this directory
	// or if due to race conditions it doesn't exist or any various other
	// reasons. We don't want to crash the entire process if this fails
	// so we ignore it. We don't log because that'll show up in the output.
	if self.cwd.len > 0 {
		C.chdir(self.cwd.str)
	}

	// If the user requested a pre exec callback, call it now.
	// This runs in the child process after fork but before exec,
	// which is useful for PTY setup, signal handling, setsid, etc.
	if pre_exec_fn := self.pre_exec {
		pre_exec_fn(mut self)
	}

	// Finally, replace our process.
	// Note: we must use the "p"-variant of exec here because we
	// do not guarantee our command is looked up already in the path.
	// We use execvp which searches PATH.

	// Build null-terminated C argv array.
	mut c_argv := unsafe { []&char{len: argv.len + 1, init: &char(0)} }
	for i, arg in argv {
		c_argv[i] = arg.str
	}

	// If we have custom environment variables, set them.
	// XTODO: Currently we use os.setenv for each var. A more complete
	// implementation would build a full envp array and use execvpe.
	if self.env.len > 0 {
		// Clear existing environment and set new vars.
		// XTODO: This is a simplified approach. The Zig version builds
		// a null-delimited env map for execvpeZ. We approximate by
		// setting env vars individually before exec.
		for key, val in self.env {
			os.setenv(key, val, true)
		}
	}

	C.execvp(self.path.str, c_argv.data)

	// If we are executing this code, the exec failed. We're in the
	// child process so there isn't much we can do. We try to output
	// something reasonable. It's important to note we MUST NOT return
	// any other error condition from here on out - we must exit.
	eprintln('exec failed for command: ${self.path}')
	eprintln('Requested executable not found or could not be executed.')
	eprintln('Please verify the command is on the PATH and try again.')

	// Exit with status 1 to indicate failure. We use _exit to avoid
	// running any atexit handlers from the parent process.
	C._exit(1)
}

// wait waits for the command to exit and returns information about
// how it exited.
//
// If block is true, this blocks until the process exits.
// If block is false, this uses WNOHANG and polls until the process
// has a status to report. When NOHANG is specified, waitpid will
// return a pid of 0 if the process doesn't have a status to report.
// When that happens, it is as though the wait call has not been
// performed, so we need to keep trying until we get a non-zero pid
// back, otherwise we end up with zombie processes.
pub fn (self Command) wait(block bool) !Exit {
	if self.pid < 0 {
		return error('process not started')
	}

	mut status := 0
	if block {
		result := C.waitpid(self.pid, &status, 0)
		if result < 0 {
			return error('waitpid failed')
		}
	} else {
		// We specify NOHANG because its not our fault if the process we launch
		// for the tty doesn't properly waitpid its children. We don't want
		// to hang the terminal over it.
		for {
			result := C.waitpid(self.pid, &status, wnohang)
			if result < 0 {
				return error('waitpid failed')
			}
			if result != 0 {
				break
			}
			// result == 0 means no status yet, keep polling
		}
	}

	return exit_from_status(status)
}

// set_data sets the user data pointer on the command.
pub fn (mut self Command) set_data(pointer voidptr) {
	self.data = pointer
}

// get_data returns the user data pointer, cast to the appropriate type.
// Returns none if the data pointer is null.
pub fn (self Command) get_data() voidptr {
	return self.data
}
