module termio

// Exec implements the logic for starting and stopping a subprocess with a
// pty as well as spinning up the necessary read thread to read from the
// pty and forward it to the Termio instance.

import apprt
import configpkg
import internal_os
import os
import pty
import renderer
import terminal
import time

// C interop declarations for process management.
#include <signal.h>
#include <unistd.h>
#include <poll.h>
#include <fcntl.h>
#include <sys/wait.h>

fn C.pipe(fds voidptr) int
fn C.fork() int
fn C.setsid() int
fn C.dup2(oldfd int, newfd int) int
fn C.execvpe(file &char, argv &&char, envp &&char) int
fn C.execvp(file &char, argv &&char) int
fn C.close(fd int) int
fn C.read(fd int, buf voidptr, count usize) int
fn C.write(fd int, buf voidptr, count usize) int
fn C.poll(fds voidptr, nfds u32, timeout int) int
fn C.fcntl(fd int, cmd int, arg int) int
fn C.kill(pid int, sig int) int
fn C.killpg(pgrp int, sig int) int
fn C.getpgid(pid int) int
fn C.waitpid(pid int, status &int, options int) int
fn C._exit(status int)

// Signal constants
const sig_hup = 1

// fcntl constants
const f_getfl = 3
const f_setfl = 4
const o_nonblock = 0x0004 // macOS value

// poll event flags
const pollin = i16(0x0001)
const pollhup = i16(0x0004)

// waitpid options
const wnohang = 1

// pollfd struct for C.poll()
struct PollFd {
mut:
	fd      int
	events  i16
	revents i16
}

const log_tag = 'io_exec'

// The version string reported via TERM_PROGRAM_VERSION.
const term_program_version = '0.1.0'

// The termios poll rate in milliseconds.
const termios_poll_ms = 200

// PtyFds holds the read and write file descriptors returned on subprocess start.
pub struct PtyFds {
pub:
	read  pty.Fd
	write pty.Fd
}

// Exec holds the subprocess state for the exec backend.
pub struct Exec {
pub mut:
	// The subprocess state for our exec backend.
	subprocess Subprocess
	// Thread-local data for the exec implementation.
	thread_data ExecThreadData
	// The read thread handle (V thread).
	read_thread ?thread = none
	// The process-exit watcher thread handle (V thread).
	exit_thread ?thread = none
}

// Initialize the exec state. This will NOT start it, this only sets
// up the internal state necessary to start it later.
pub fn Exec.init(cfg ExecConfig) !Exec {
	subprocess := Subprocess.init(cfg)!
	return Exec{
		subprocess: subprocess
	}
}

pub fn (mut self Exec) deinit() {
	self.subprocess.deinit()
}

// Call to initialize the terminal state as necessary for this backend.
// This is called before any termio begins. This should not be called
// after termio begins because it may put the internal terminal state
// into a bad state.
pub fn (mut self Exec) init_terminal(mut term terminal.Terminal) {
	// If we have an initial pwd requested by the subprocess, then we
	// set that on the terminal now. This allows rapidly initializing
	// new surfaces to use the proper pwd.
	if cwd := self.subprocess.cwd {
		term.set_pwd(cwd) or {}
	}

	// Setup our initial grid/screen size from the terminal. This
	// can't fail because the pty should not exist at this point.
	self.resize(renderer.GridSize{
		columns: term.cols
		rows: term.rows
	}, renderer.ScreenSize{
		width: term.width_px
		height: term.height_px
	}) or {}
}

// thread_enter is called when the IO thread starts.
// Starts the subprocess, creates a quit pipe, and spawns the read thread.
// This variant does NOT forward data to a Termio; use thread_enter_io to
// wire the read thread to a Termio instance.
pub fn (mut self Exec) thread_enter() ! {
	self.thread_enter_common(unsafe { nil })!
}

// thread_enter_io is called when the IO thread starts. It starts the
// subprocess, spawns the read thread (which forwards pty data to the given
// Termio), and starts the process-exit watcher.
pub fn (mut self Exec) thread_enter_io(io &Termio) ! {
	self.thread_enter_common(io)!
}

fn (mut self Exec) thread_enter_common(io &Termio) ! {
	// Start our subprocess
	pty_fds := self.subprocess.start()!

	// Create pipe for quit signaling.
	// pipe_fds[0] is the read end, pipe_fds[1] is the write end.
	mut pipe_fds := [2]int{}
	if C.pipe(&pipe_fds) != 0 {
		return error('failed to create quit pipe')
	}

	// Track our process start time
	start_ns := u64(time.sys_mono_now())

	// Store thread data
	self.thread_data = ExecThreadData{
		start_ns: start_ns
		read_thread_pipe: pipe_fds[1] // write end - we write to signal quit
		read_thread_fd: pty_fds.read
	}

	// Spawn the read thread. The read thread gets the pty read fd, the read
	// end of the quit pipe, and (optionally) the Termio to forward data to.
	read_fd := pty_fds.read
	quit_fd := pipe_fds[0] // read end - the thread reads to detect quit
	self.read_thread = spawn thread_main_posix(read_fd, quit_fd, io)

	// Start our process-exit watcher. This waits for the child to exit and
	// notifies the surface. This replaces ghostty's xev.Process watcher.
	pid := self.subprocess.child_pid
	if pid > 0 {
		self.exit_thread = spawn process_exit_watcher(pid, start_ns, io)
	}
}

// thread_exit is called when the IO thread exits.
// Signals the read thread to quit, joins it, and stops the subprocess.
pub fn (mut self Exec) thread_exit() {
	if self.thread_data.exited {
		self.subprocess.external_exit()
	}
	self.subprocess.stop()

	// Signal the read thread to quit by writing to the quit pipe.
	// The read thread polls on the read end and will exit when it
	// sees data. We then close the write end.
	quit_byte := [u8(0x78)] // 'x'
	C.write(self.thread_data.read_thread_pipe, quit_byte.data, 1)

	// Join the read thread to wait for it to finish.
	if t := self.read_thread {
		t.wait()
	}
	self.read_thread = none

	// Join the process-exit watcher thread if we spawned one.
	if t := self.exit_thread {
		t.wait()
	}
	self.exit_thread = none

	// Clean up thread data
	self.thread_data.deinit()
}

// focus_gained notifies the exec backend about focus changes.
// This is used to start/stop the termios polling timer.
// When we lose focus, we flag the timer to stop on the next tick.
// When we gain focus, we restart the timer if needed.
pub fn (mut self Exec) focus_gained(focused bool) ! {
	if !focused {
		// Flag the timer to end on the next iteration. This is
		// a lot cheaper than doing full timer cancellation.
		self.thread_data.termios_timer_running = false
	} else {
		// Always set this to true. There is a race condition if we lose
		// focus and regain focus before the termios timer ticks where
		// if we don't set this unconditionally the timer will end on
		// the next iteration.
		self.thread_data.termios_timer_running = true
	}
}

// resize updates the pty subprocess size.
pub fn (mut self Exec) resize(grid_size renderer.GridSize, screen_size renderer.ScreenSize) ! {
	self.subprocess.resize(grid_size, screen_size)!
}

// queue_write writes data to the pty. If linefeed is true, carriage
// returns (\r) are replaced with CRLF (\r\n) sequences.
pub fn (mut self Exec) queue_write(data []u8, linefeed bool) ! {
	// If our process has exited then we don't send any more writes.
	if self.thread_data.exited {
		return
	}

	// Get the pty master fd to write to.
	p := self.subprocess.pty_ or { return error('no pty available for writing') }
	fd := p.master
	if fd < 0 {
		return error('pty master fd is invalid')
	}

	if !linefeed {
		// Fast path: write data directly, chunking as needed.
		mut offset := 0
		for offset < data.len {
			n := C.write(fd, unsafe { voidptr(usize(data.data) + usize(offset)) }, usize(data.len - offset))
			if n < 0 {
				return error('write to pty failed')
			}
			offset += int(n)
		}
	} else {
		// Slow path: replace \r with \r\n.
		mut buf := []u8{cap: 128}
		for i := 0; i < data.len; i++ {
			ch := data[i]
			if ch == `\r` {
				buf << `\r`
				buf << `\n`
			} else {
				buf << ch
			}

			// Flush when buffer is getting full.
			if buf.len >= 126 || i == data.len - 1 {
				mut written := 0
				for written < buf.len {
					n := C.write(fd, unsafe { voidptr(usize(buf.data) + usize(written)) }, usize(buf.len - written))
					if n < 0 {
						return error('write to pty failed')
					}
					written += int(n)
				}
				buf.clear()
			}
		}
	}
}

// ExecThreadData is the thread local data for the exec implementation.
pub struct ExecThreadData {
pub mut:
	// Process start time (monotonic nanoseconds) and boolean of whether
	// its already exited.
	start_ns u64
	exited   bool

	// Reader thread state.
	// read_thread_pipe is the write end of the quit pipe.
	// read_thread_fd is the pty master fd used for reading.
	read_thread_pipe int = -1
	read_thread_fd   int = -1

	// Whether the termios polling timer is running.
	// When focus is lost, this is set to false to stop polling.
	termios_timer_running bool = true

	// The last known termios mode. Used for change detection
	// to prevent unnecessary locking of expensive mutexes.
	termios_mode pty.Mode
}

pub fn (mut self ExecThreadData) deinit() {
	// Close the write end of the read thread quit pipe.
	if self.read_thread_pipe >= 0 {
		C.close(self.read_thread_pipe)
		self.read_thread_pipe = -1
	}
	self.read_thread_fd = -1
}

// ExecConfig holds the configuration for starting a subprocess.
pub struct ExecConfig {
pub:
	command                    ?configpkg.Command
	env                        map[string]string
	env_override               configpkg.RepeatableStringMap
	shell_integration          configpkg.ShellIntegration = .detect
	shell_integration_features configpkg.ShellIntegrationFeatures
	working_directory          ?string
	resources_dir              ?string
	term                       string = 'xterm-ghostty'
}

// Subprocess manages the child process lifecycle.
pub struct Subprocess {
pub mut:
	cwd         ?string
	env         ?map[string]string
	args        []string
	grid_size   renderer.GridSize
	screen_size renderer.ScreenSize
	pty_        ?pty.Pty
	running     bool
	child_pid   int = -1
}

// init initializes the subprocess configuration. This will NOT start it,
// this only sets up the internal state necessary to start it later.
pub fn Subprocess.init(cfg ExecConfig) !Subprocess {
	mut env := cfg.env.clone()

	// If we have a resources dir then set our env var
	if dir := cfg.resources_dir {
		env['GHOSTTY_RESOURCES_DIR'] = dir
	}

	// Set our TERM var. This is a bit complicated because we want to use
	// the ghostty TERM value but we want to only do that if we have
	// ghostty in the TERMINFO database.
	//
	// For now, we just look up a bundled dir but in the future we should
	// also load the terminfo database and look for it.
	if base := cfg.resources_dir {
		env['TERM'] = cfg.term
		env['COLORTERM'] = 'truecolor'

		// Assume that the resources directory is adjacent to the terminfo
		// database
		parent := os.dir(base)
		if parent.len > 0 {
			env['TERMINFO'] = '${parent}/terminfo'
		}
	} else {
		$if macos {
			// On macOS the terminfo SHOULD exist, warn if missing
		}
		env['TERM'] = 'xterm-256color'
		env['COLORTERM'] = 'truecolor'
	}

	// Add our binary to the path if we can find it.
	exe_path := os.executable()
	if exe_path.len > 0 {
		exe_dir := os.dir(exe_path)
		if exe_dir.len > 0 {
			// We always set this so that if the shell overwrites the path
			// scripts still have a way to find the Ghostty binary when
			// running in Ghostty.
			env['GHOSTTY_BIN_DIR'] = exe_dir

			// Append if we have a path. We want to append so that ghostty is
			// the last priority in the path.
			if existing_path := env['PATH'] {
				// Verify that our path doesn't already contain this entry
				mut found := false
				parts := existing_path.split(':')
				for entry in parts {
					if entry == exe_dir {
						found = true
						break
					}
				}
				if !found {
					env['PATH'] = internal_os.append_env(existing_path, exe_dir)
				}
			} else {
				env['PATH'] = exe_dir
			}
		}
	}

	// On macOS, export additional data directories from our
	// application bundle.
	$if macos {
		if resources_dir := cfg.resources_dir {
			data_dir := '${resources_dir}/..'
			xdg_data_dirs_key := 'XDG_DATA_DIRS'
			existing_xdg := if v := env[xdg_data_dirs_key] {
				v
			} else {
				'/usr/local/share:/usr/share'
			}
			env[xdg_data_dirs_key] = internal_os.append_env(existing_xdg, data_dir)

			manpath_key := 'MANPATH'
			man_dir := '${resources_dir}/../man'
			// Always append with colon in front, as it mean that if
			// `MANPATH` is empty, then it should be treated as an extra
			// path instead of overriding all paths set by OS.
			existing_man := env[manpath_key] or { '' }
			env[manpath_key] = internal_os.append_env_always(existing_man, man_dir)
		}
	}

	// Set environment variables used by some programs (such as neovim) to detect
	// which terminal emulator and version they're running under.
	env['TERM_PROGRAM'] = 'ghostty'
	env['TERM_PROGRAM_VERSION'] = term_program_version

	// VTE_VERSION is set by gnome-terminal and other VTE-based terminals.
	// We don't want our child processes to think we're running under VTE.
	env.delete('VTE_VERSION')

	// Setup our shell integration, if we can.
	default_shell_command := cfg.command or { configpkg.ShellCmd{ shell: 'sh' } }

	// Always set up shell features (GHOSTTY_SHELL_FEATURES). These are
	// used by both automatic and manual shell integrations.
	setup_features(mut env, cfg.shell_integration_features)

	shell_command := setup_shell_command(cfg.shell_integration, cfg.resources_dir,
		default_shell_command, mut env)

	// Add the environment variables that override any others.
	mut it := cfg.env_override.iterator()
	for {
		entry := it.next() or { break }
		env[entry.key] = entry.value
	}

	// Build our args list
	args := exec_command(shell_command)

	// We have to copy the cwd because there is no guarantee that
	// pointers in full_config remain valid.
	cwd := cfg.working_directory

	// Propagate the current working directory (CWD) to the shell, enabling
	// the shell to display the current directory name rather than the
	// resolved path for symbolic links.
	// https://bugs.kde.org/show_bug.cgi?id=242114
	// https://github.com/kovidgoyal/kitty/issues/1595
	// https://github.com/ghostty-org/ghostty/discussions/7769
	if pwd := cwd {
		env['PWD'] = pwd
	}

	return Subprocess{
		env: env
		cwd: cwd
		args: args
		// Should be initialized with init_terminal call.
		grid_size: renderer.GridSize{}
		screen_size: renderer.ScreenSize{
			width: 1
			height: 1
		}
	}
}

// Clean up the subprocess. This will stop the subprocess if it is started.
pub fn (mut self Subprocess) deinit() {
	self.stop()
	if mut p := self.pty_ {
		p.deinit()
	}
	self.env = none
}

// Start the subprocess. If the subprocess is already started this
// will return an error. This forks and execs the configured command
// with the pty slave connected to stdin/stdout/stderr.
pub fn (mut self Subprocess) start() !PtyFds {
	if self.running {
		return error('subprocess already running')
	}

	// Create our pty
	mut p := pty.Pty.open(pty.Winsize{
		ws_row: u16(self.grid_size.rows)
		ws_col: u16(self.grid_size.columns)
		ws_xpixel: u16(self.screen_size.width)
		ws_ypixel: u16(self.screen_size.height)
	})!
	self.pty_ = p

	// If we can't access the cwd, then don't use it. This is important
	// because our cwd can be set by the shell (OSC 7) and we don't
	// want to break new windows.
	cwd := if c := self.cwd {
		if os.is_dir(c) { c } else { '' }
	} else {
		''
	}

	// Build the argv for execvp. We need null-terminated C strings.
	if self.args.len == 0 {
		return error('no command specified')
	}

	// Build null-terminated argv array for execvp.
	mut c_argv := []&char{cap: self.args.len + 1}
	for arg in self.args {
		c_argv << arg.str
	}
	c_argv << &char(unsafe { nil })

	// Build null-terminated envp array if env is set. We build this before
	// fork so we have stable pointers. We also track whether env was set
	// so we can use it in the child without accessing self after fork.
	has_env := if _ := self.env { true } else { false }
	mut c_envp := []&char{}
	if env := self.env {
		for k, v in env {
			entry := '${k}=${v}'
			c_envp << entry.str
		}
	}
	c_envp << &char(unsafe { nil })

	// Fork the process.
	pid := C.fork()
	if pid < 0 {
		return error('fork failed')
	}

	if pid == 0 {
		// === CHILD PROCESS ===
		// Dup the slave fd to stdin/stdout/stderr.
		C.dup2(p.slave, 0) // stdin
		C.dup2(p.slave, 1) // stdout
		C.dup2(p.slave, 2) // stderr

		// Perform child-side pty setup (setsid, set controlling terminal,
		// close master/slave fds).
		p.child_pre_exec() or {
			C._exit(1)
		}

		// Change to the requested working directory if specified.
		if cwd.len > 0 {
			os.chdir(cwd) or {}
		}

		// Set environment variables if we had an env map.
		// execvpe is not available on macOS, so we set env vars
		// manually via os.setenv, then use execvp.
		if has_env {
			for i := 0; i < c_envp.len - 1; i++ {
				entry_str := unsafe { cstring_to_vstring(c_envp[i]) }
				eq_pos := entry_str.index('=') or { continue }
				k := entry_str[..eq_pos]
				v := entry_str[eq_pos + 1..]
				os.setenv(k, v, true)
			}
		}

		C.execvp(c_argv[0], c_argv.data)

		// If execvp returns, exec failed.
		C._exit(127)
	}

	// === PARENT PROCESS ===
	// Store the child pid for later signal sending.
	self.child_pid = pid

	// Close the slave fd in the parent. The child has already
	// inherited it via fork and duped it to stdin/stdout/stderr.
	p.close_slave()

	// We can free the env now that the child has it.
	self.env = none

	self.running = true
	return PtyFds{
		read: p.master
		write: p.master
	}
}

// Called to notify that we exited externally so we can unset our
// running state.
pub fn (mut self Subprocess) external_exit() {
	self.running = false
}

// Stop the subprocess. This is safe to call anytime. This will send
// SIGHUP to the process group to signal it to exit.
// This does not close the pty.
pub fn (mut self Subprocess) stop() {
	if !self.running {
		return
	}

	if self.child_pid > 0 {
		// Get the process group ID. Before the child calls setsid
		// the pgid will be ours because we forked it. We spin until
		// the child has its own pgid.
		my_pgid := C.getpgid(0)
		mut pgid := -1
		for {
			pgid = C.getpgid(self.child_pid)
			if pgid < 0 {
				// Process doesn't exist anymore, we're done.
				break
			}
			if pgid != my_pgid {
				break
			}
			// pgid is still ours; the child hasn't called setsid yet.
			time.sleep(10 * time.millisecond)
		}

		if pgid > 0 {
			// Send SIGHUP to the entire process group so that
			// grandchildren are also signaled.
			for {
				C.killpg(pgid, sig_hup)

				// Wait with WNOHANG so we don't block. If the child
				// is still alive, loop and kill again.
				mut status := 0
				res := C.waitpid(self.child_pid, &status, wnohang)
				if res != 0 {
					break
				}
				time.sleep(10 * time.millisecond)
			}
		}

		self.child_pid = -1
	}

	self.running = false
}

// Resize the pty subprocess. This is safe to call anytime.
pub fn (mut self Subprocess) resize(grid_size renderer.GridSize, screen_size renderer.ScreenSize) ! {
	self.grid_size = grid_size
	self.screen_size = screen_size

	if mut p := self.pty_ {
		// It is theoretically possible for the grid or screen size to
		// exceed u16, although the terminal in that case isn't very
		// usable. This should be protected upstream but we still clamp
		// in case there is a bad caller which has happened before.
		p.set_size(pty.Winsize{
			ws_row: clamp_u16(grid_size.rows)
			ws_col: clamp_u16(grid_size.columns)
			ws_xpixel: clamp_u16(screen_size.width)
			ws_ypixel: clamp_u16(screen_size.height)
		})!
	}
}

// clamp_u16 clamps a u32 value to u16 range.
fn clamp_u16(v u32) u16 {
	if v > 0xFFFF {
		return 0xFFFF
	}
	return u16(v)
}

// The read thread sits in a loop doing the following pseudo code:
//
//   while (true) { blocking_read(); exit_if_eof(); process(); }
//
// Almost all terminal-modifying activity is from the pty read, so
// putting this on a dedicated thread keeps performance very predictable
// while also almost optimal. "Locking is fast, lock contention is slow."
// and since we rarely have contention, this is fast.
//
// This is also empirically fast compared to putting the read into
// an async mechanism like io_uring/epoll because the reads are generally
// small.
//
// We use a basic poll syscall here because we are only monitoring two
// fds and this is still much faster and lower overhead than any async
// mechanism.
pub struct ReadThread {}

// thread_main_posix is the main function for the POSIX read thread.
// It reads data from the pty fd in a tight loop, falling back to poll()
// when there is no data available. The quit fd is checked during poll
// to allow clean shutdown. Each chunk of data read is forwarded to the
// Termio's process_output which parses the escape codes and mutates the
// terminal state.
//
// io may be null (e.g. in tests / non-wired usage) in which case data is
// simply drained.
pub fn thread_main_posix(fd int, quit int, io &Termio) {
	// Always close our end of the pipe when we exit.
	defer {
		C.close(quit)
	}

	// Take a mutable alias to the Termio so we can call process_output.
	mut tio := unsafe { io }

	// Set the fd to non-blocking so we can try to read in a tight loop
	// and only fall back to poll when there's no data.
	flags := C.fcntl(fd, f_getfl, 0)
	if flags >= 0 {
		C.fcntl(fd, f_setfl, flags | o_nonblock)
	}

	// Build up the list of fds we're going to poll. We watch for data
	// on the pty fd and our quit notification pipe.
	mut pollfds := [2]PollFd{}
	pollfds[0] = PollFd{
		fd: fd
		events: pollin
		revents: 0
	}
	pollfds[1] = PollFd{
		fd: quit
		events: pollin
		revents: 0
	}

	mut buf := [1024]u8{}
	for {
		// Inner loop: try to read as much as possible without blocking.
		// We only check the quit fd when the main fd blocks. This optimizes
		// for the realistic scenario that data will eventually stop while
		// we're trying to quit.
		for {
			n := C.read(fd, &buf[0], usize(1024))
			if n < 0 {
				// Check errno - on macOS, EAGAIN is 35
				// For WouldBlock / EAGAIN, break to poll.
				// For other errors (EIO, EBADF), the pty is closed.
				break
			}
			if n == 0 {
				// EOF - this happens on macOS when the child process dies.
				break
			}
			// Successfully read data. Forward it to the Termio for
			// processing (escape-code parsing + terminal state mutation).
			if tio != unsafe { nil } {
				chunk := unsafe { buf[..int(n)].clone() }
				tio.process_output(chunk)
			}
		}

		// Wait for data using poll with infinite timeout (-1).
		pollfds[0].revents = 0
		pollfds[1].revents = 0
		poll_result := C.poll(&pollfds[0], u32(2), -1)
		if poll_result < 0 {
			// poll failed, exit the thread.
			return
		}

		// If our quit fd is readable, we're done.
		if pollfds[1].revents & pollin != 0 {
			return
		}

		// If the pty fd has HUP, the child process has closed the pty.
		if pollfds[0].revents & pollhup != 0 {
			return
		}
	}
}

// process_exit_watcher waits (blocking) for the child process to exit and
// then notifies the surface via process_exit_common. This replaces
// ghostty's xev.Process watcher which asynchronously waits for exit.
//
// io may be null in which case only the exited flag on the backend is set.
fn process_exit_watcher(pid int, start_ns u64, io &Termio) {
	// Blocking wait for the child to exit.
	mut status := 0
	for {
		res := C.waitpid(pid, &status, 0)
		if res == pid {
			break
		}
		if res < 0 {
			// waitpid failed (e.g. child already reaped elsewhere). We
			// still report exit with a zero code.
			break
		}
		// res == 0 shouldn't happen without WNOHANG, but loop to be safe.
	}

	// Extract the exit code. WIFEXITED/WEXITSTATUS: on POSIX the low 8 bits
	// hold signal/exit info. If the process exited normally, the exit code
	// is in bits 8-15.
	exit_code := u32((status >> 8) & 0xFF)

	process_exit_common(pid, start_ns, exit_code, io)
}

// process_exit_common is called when the child process exits. It records
// the exit on the backend thread data and notifies the surface with the
// exit metadata. Faithful to Exec.zig processExitCommon.
fn process_exit_common(pid int, start_ns u64, exit_code u32, io &Termio) {
	if io != unsafe { nil } {
		mut tio := unsafe { io }
		tio.backend.thread_data.exited = true

		// Determine how long the process was running for.
		now := u64(time.sys_mono_now())
		runtime_ms := if now > start_ns {
			(now - start_ns) / u64(time.millisecond)
		} else {
			u64(0)
		}

		// We always notify the surface immediately that the child has
		// exited and some metadata about the exit.
		tio.surface_mailbox.push(apprt.SurfaceMessage{
			kind: .child_exited
			child_exited: apprt.ChildExited{
				exit_code: exit_code
				runtime_ms: runtime_ms
			}
		})
	}
}

// setup_shell_command handles the shell integration dispatch based on the
// configured shell integration mode and resources directory.
fn setup_shell_command(integration configpkg.ShellIntegration, resources_dir ?string, default_cmd configpkg.Command, mut env map[string]string) configpkg.Command {
	if integration == .none_ {
		// Shell integration disabled by configuration
		return default_cmd
	}

	dir := resources_dir or {
		// No resources dir, can't do shell integration
		return default_cmd
	}

	force := match integration {
		.detect { ?Shell(none) }
		.bash { ?Shell(Shell.bash) }
		.elvish { ?Shell(Shell.elvish) }
		.fish { ?Shell(Shell.fish) }
		.nushell { ?Shell(Shell.nushell) }
		.zsh { ?Shell(Shell.zsh) }
		.none_ { ?Shell(none) } // handled above
	}

	result := setup_shell_integration(dir, default_cmd, mut env, force)
	if r := result {
		return r.command
	}
	return default_cmd
}

// Builds the argv array for the process we should exec for the
// configured command. This isn't as straightforward as it seems since
// we deal with shell-wrapping, macOS login shells, etc.
//
// On macOS, we use login(1) to get all of the proper environment
// variables set, a login shell, and proper hushlogin behavior.
// On other platforms, we wrap shell commands with /bin/sh.
fn exec_command(command configpkg.Command) []string {
	// If we're on macOS, we have to use `login(1)` to get all of
	// the proper environment variables set, a login shell, and proper
	// hushlogin behavior.
	$if macos {
		passwd := internal_os.get_passwd() or { internal_os.PasswdEntry{} }

		username := passwd.name or {
			// No username, fall back to non-login behavior
			return exec_command_posix(command)
		}

		hush := if h := passwd.home {
			os.exists(os.join_path(h, '.hushlogin'))
		} else {
			false
		}

		// The reason for executing login this way is unclear. This
		// comment will attempt to explain but prepare for a truly
		// unhinged reality.
		//
		// The first major issue is that on macOS, a lot of users
		// put shell configurations in ~/.bash_profile instead of
		// ~/.bashrc (or equivalent for another shell). This file is only
		// loaded for a login shell so macOS users expect all their terminals
		// to be login shells. No other platform behaves this way and its
		// totally braindead but somehow the entire dev community on
		// macOS has cargo culted their way to this reality so we have to
		// do it...
		//
		// To get a login shell, you COULD just prepend argv0 with a `-`
		// but that doesn't fully work because `getlogin()` C API will
		// return the wrong value, SHELL won't be set, and various
		// other login behaviors that macOS users expect.
		//
		// The proper way is to use `login(1)`. But login(1) forces
		// the working directory to change to the home directory,
		// which we may not want. If we specify "-l" then we can avoid
		// this behavior but now the shell isn't a login shell.
		//
		// There is another issue: `login(1)` on macOS 14.3 and earlier
		// checked for ".hushlogin" in the working directory. This means
		// that if we specify "-l" then we won't get hushlogin honored
		// if its in the home directory (which is standard). To get
		// around this, we check for hushlogin ourselves and if present
		// specify the "-q" flag to login(1).
		//
		// So to get all the behaviors we want, we specify "-l" but
		// execute "bash" (which is built-in to macOS). We then use
		// the bash builtin "exec" to replace the process with a login
		// shell ("-l" on exec) with the command we really want.
		//
		// We use "bash" instead of other shells that ship with macOS
		// because as of macOS Sonoma, we found with a microbenchmark
		// that bash can `exec` into the desired command ~2x faster
		// than zsh.
		//
		// To figure out a lot of this logic I read the login.c
		// source code in the OSS distribution Apple provides for
		// macOS.
		//
		// Awesome.
		mut args := []string{}
		args << '/usr/bin/login'
		if hush {
			args << '-q'
		}
		args << '-flp'
		args << username

		match command {
			configpkg.DirectCmd {
				// Direct args can be passed directly to login, since
				// login uses execvp we don't need to worry about PATH
				// searching.
				for a in command.direct {
					args << a
				}
			}
			configpkg.ShellCmd {
				// Use "exec" to replace the bash process with
				// our intended command so we don't have a parent
				// process hanging around.
				cmd_str := 'exec -l ${command.shell}'

				// We execute bash with "--noprofile --norc" so that it doesn't
				// load startup files so that (1) our shell integration doesn't
				// break and (2) user configuration doesn't mess this process
				// up.
				args << '/bin/bash'
				args << '--noprofile'
				args << '--norc'
				args << '-c'
				args << cmd_str
			}
		}
		return args
	}

	return exec_command_posix(command)
}

// exec_command_posix builds the command args for non-macOS platforms.
fn exec_command_posix(command configpkg.Command) []string {
	match command {
		configpkg.DirectCmd {
			// We need to clone the command since there's no guarantee the
			// config remains valid.
			return command.direct.clone()
		}
		configpkg.ShellCmd {
			mut args := []string{}
			// We run our shell wrapped in `/bin/sh` so that we don't have
			// to parse the command line ourselves if it has arguments.
			// Additionally, some environments (NixOS, I found) use /bin/sh
			// to setup some environment variables that are important to
			// have set.
			args << '/bin/sh'
			if internal_os.is_flatpak() {
				args << '-l'
			}
			args << '-c'
			args << command.shell
			return args
		}
	}
}
