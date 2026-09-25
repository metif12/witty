module termio

// Exec implements the logic for starting and stopping a subprocess with a
// pty as well as spinning up the necessary read thread to read from the
// pty and forward it to the Termio instance.

import apprt
import build_meta
import command as commandpkg
import configpkg
import crash
import datastruct
import internal_os
import os
import pty
import renderer
import terminal
import time
import xev

#include "@VMODROOT/command_exec.h"

// C interop declarations for process management.
#include <signal.h>

#include <unistd.h>

#include <poll.h>

#include <fcntl.h>

#include <sys/wait.h>

fn C.pipe(fds voidptr) int

fn C.close(fd int) int

fn C.witty_read_retry(fd int, buf voidptr, count usize) int

fn C.witty_read_error_kind() int

fn C.write(fd int, buf voidptr, count usize) int

fn C.poll(fds voidptr, nfds u32, timeout int) int

fn C.fcntl(fd i32, cmd i32, arg ...voidptr) i32

fn C.kill(pid int, sig int) int

fn C.killpg(pgrp int, sig int) int

fn C.getpgid(pid int) int

fn C.waitpid(pid int, status &int, options int) int

fn C._exit(status int)

// Signal constants
const sig_hup = int(C.SIGHUP)

// fcntl constants
const f_getfl = int(C.F_GETFL)
const f_setfl = int(C.F_SETFL)
const o_nonblock = int(C.O_NONBLOCK)

// poll event flags
const pollin = i16(int(C.POLLIN))
const pollhup = i16(int(C.POLLHUP))

// waitpid options
const wnohang = int(C.WNOHANG)

// pollfd struct for C.poll()
struct PollFd {
mut:
	fd      int
	events  i16
	revents i16
}

const log_tag = 'io_exec'

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

pub fn (mut self Exec) thread_enter(mut io Termio, mut td ThreadData) ! {
	// Start our subprocess
	pty_fds := self.subprocess.start() or {
		// If we specifically got this error then we are in the forked
		// process and our child failed to execute. If we DIDN'T
		// get this specific error then we're in the parent and
		// we need to bubble it up.
		if !commandpkg.is_exec_failed_in_child(err) {
			return err
		}

		// We're in the child. Nothing more we can do but abnormal exit.
		// The Command will output some additional information.
		C._exit(1)
		return err
	}
	// Zig's errdefers are emulated by reached defers that run until setup succeeds.
	mut ok := false
	defer {
		if !ok {
			self.subprocess.stop()
		}
	}

	// Watcher to detect subprocess exit
	mut process := ?xev.Process(none)
	if !isnil(self.subprocess.flatpak_command) {
		// If we're executing via Flatpak then we can't do
		// traditional process watching (its implemented
		// as a special case in os/flatpak.zig) since the
		// command is on the host.
	} else if cmd := self.subprocess.process {
		pid := cmd.pid or { return error('ProcessNoPid') }
		process = xev.Process.init(pid)!
	} else {
		return error('ProcessNotStarted')
	}
	defer {
		if !ok {
			if mut p := process {
				p.deinit()
			}
		}
	}

	// Track our process start time for abnormal exits
	process_start := time.sys_mono_now()

	// Create our pipe that we'll use to kill our read thread.
	// pipe[0] is the read end, pipe[1] is the write end.
	pipe := internal_os.pipe()!
	defer {
		if !ok {
			C.close(pipe[0])
			C.close(pipe[1])
		}
	}

	// Setup our stream so that we can write.
	stream := xev.Stream.init_fd(pty_fds.write)
	defer {
		if !ok {
			stream.deinit()
		}
	}

	// Start our timer to read termios state changes. This is used
	// to detect things such as when password input is being done
	// so we can render the terminal in a different way.
	termios_timer := xev.Timer.init()!
	defer {
		if !ok {
			termios_timer.deinit()
		}
	}

	// Start our read thread
	read_thread := spawn thread_main_posix(pty_fds.read, pipe[0], io)
	ok = true

	// Setup our threadata backend state to be our own
	td.backend = ExecThreadData{
		start:            process_start
		write_stream:     stream
		process:          process
		write_req_pool:   datastruct.SegmentedPool.init[xev.WriteRequest](exec_write_req_prealloc)
		write_buf_pool:   datastruct.SegmentedPool.init[ExecWriteBuf](exec_write_req_prealloc)
		read_thread:      read_thread
		read_thread_pipe: pipe[1]
		read_thread_fd:   pty_fds.read
		termios_timer:    termios_timer
	}

	// Start our process watcher. If we have an xev.Process use it.
	if p := td.backend.process {
		p.wait(mut td.loop, &td.backend.process_wait_c, td, exec_process_exit)
	} else if !isnil(self.subprocess.flatpak_command) {
		// If we're in flatpak and we have a flatpak command
		// then we can run the special flatpak logic for watching.
		mut command := self.subprocess.flatpak_command
		command.wait_xev(mut td.loop, &td.backend.flatpak_wait_c, td, exec_flatpak_exit)
	}

	// Start our termios timer. We don't support this on Windows.
	// Fundamentally, we could support this on Windows so we're just
	// waiting for someone to implement it.
	$if !windows {
		td.backend.termios_timer.run(mut td.loop, &td.backend.termios_timer_c, termios_poll_ms,
			td, exec_termios_timer)
	}
}

pub fn (mut self Exec) thread_exit(mut td ThreadData) {
	mut exec := &td.backend

	if exec.exited {
		self.subprocess.external_exit()
	}
	self.subprocess.stop()

	// Quit our read thread after exiting the subprocess so that
	// we don't get stuck waiting for data to stop flowing if it is
	// a particularly noisy process.
	quit_byte := [u8(`x`)]
	if C.write(exec.read_thread_pipe, quit_byte.data, 1) < 0 {
		// BrokenPipe means that our read thread is closed already,
		// which is completely fine since that is what we were trying
		// to achieve.
		if C.errno != C.EPIPE {
			eprintln('error writing to read thread quit pipe err=${os.posix_get_error_msg(C.errno)}')
		}
	}

	if t := exec.read_thread {
		t.wait()
	}
}

pub fn (mut self Exec) focus_gained(mut td ThreadData, focused bool) ! {
	_ = self

	mut execdata := &td.backend

	if !focused {
		// Flag the timer to end on the next iteration. This is
		// a lot cheaper than doing full timer cancellation.
		execdata.termios_timer_running = false
	} else {
		// Always set this to true. There is a race condition if we lose
		// focus and regain focus before the termios timer ticks where
		// if we don't set this unconditionally the timer will end on
		// the next iteration.
		execdata.termios_timer_running = true

		// If we're focused, we want to start our termios timer. We
		// only do this if it isn't already running. We use the termios
		// callback because that'll trigger an immediate state check AND
		// start the timer.
		if execdata.termios_timer_c.state() != .active {
			_ = exec_termios_timer(td, unsafe { nil }, unsafe { nil }, none)
		}
	}
}

// resize updates the pty subprocess size.
pub fn (mut self Exec) resize(grid_size renderer.GridSize, screen_size renderer.ScreenSize) ! {
	self.subprocess.resize(grid_size, screen_size)!
}

fn exec_process_exit_common(mut td ThreadData, exit_code u32) {
	mut execdata := &td.backend
	execdata.exited = true

	// Determine how long the process was running for.
	runtime_ns := time.sys_mono_now() - execdata.start
	runtime_ms := runtime_ns / u64(time.millisecond)

	// We always notify the surface immediately that the child has
	// exited and some metadata about the exit.
	td.surface_mailbox.push(apprt.SurfaceMessage{
		kind:         .child_exited
		child_exited: apprt.ChildExited{
			exit_code:  exit_code
			runtime_ms: runtime_ms
		}
	}, datastruct.blocking_queue_forever)
}

fn exec_process_exit(td_ voidptr, _ &xev.Loop, _ &xev.Completion, r ?xev.ErrorKind, exit_code u32) xev.CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut td := unsafe { &ThreadData(td_) }
	exec_process_exit_common(mut td, exit_code)
	return .disarm
}

fn exec_termios_timer(td_ voidptr, _ &xev.Loop, _ &xev.Completion, r ?xev.ErrorKind) xev.CallbackAction {
	// log.debug("termios timer fired", .{});

	// This should never happen because we guard starting our
	// timer on windows but we want this assertion to fire if
	// we ever do start the timer on windows.
	// TODO: support on windows
	$if windows {
		panic('termios timer not implemented on Windows')
	}

	if err := r {
		match err {
			// This is sent when our timer is canceled. That's fine.
			.canceled {
				return .disarm
			}
			else {
				eprintln('error in termios timer callback err=${err}')
				panic('crash in termios timer callback')
			}
		}
	}

	mut td := unsafe { &ThreadData(td_) }
	mut exec := &td.backend

	$if !windows {
		// This is kind of hacky but we rebuild a Pty struct to get the
		// termios data.
		mode := pty.Pty{
			master: exec.read_thread_fd
		}.get_mode() or {
			eprintln('error getting termios mode err=${err}')

			// If we have an error we return the default mode values
			// which are the likely values.
			pty.Mode{}
		}

		// If the mode changed, then we process it.
		if mode != exec.termios_mode {
			exec.termios_mode = mode

			// We assume we're in some sort of password input if we're
			// in canonical mode and not echoing. This is a heuristic.
			password_input := mode.canonical() && !mode.echo()

			// If our password input state changed on the terminal then
			// we notify the surface.
			td.renderer_state.mutex.lock()
			t := td.renderer_state.terminal_
			unchanged := t.flags.password_input() == password_input
			td.renderer_state.mutex.unlock()

			if !unchanged {
				// We have to notify the surface that we're in password input.
				// We must block on this because the balanced true/false state
				// of this is critical to apprt behavior.
				td.surface_mailbox.push(apprt.SurfaceMessage{
					kind:           .password_input
					password_input: password_input
				}, datastruct.blocking_queue_forever)
			}
		}
	}

	// Repeat the timer
	if exec.termios_timer_running {
		exec.termios_timer.run(mut td.loop, &exec.termios_timer_c, termios_poll_ms, td,
			exec_termios_timer)
	}

	return .disarm
}

pub fn (mut self Exec) queue_write(mut td ThreadData, data []u8, linefeed bool) ! {
	_ = self
	mut exec := &td.backend

	// If our process is exited then we don't send any more writes.
	if exec.exited {
		return
	}

	// We go through and chunk the data if necessary to fit into
	// our cached buffers that we can queue to the stream.
	mut i := 0
	for i < data.len {
		req := exec.write_req_pool.get_grow()!
		mut buf := exec.write_buf_pool.get_grow()!
		mut slice := []u8{}
		if !linefeed {
			// The maximum end index is either the end of our data or
			// the end of our buffer, whichever is smaller.
			max := if data.len < i + exec_write_buf_len { data.len } else { i + exec_write_buf_len }

			// Fast
			len := max - i
			unsafe { vmemcpy(&buf.bytes[0], &data[i], len) }
			i = max
			slice = unsafe { (&u8(&buf.bytes[0])).vbytes(len) }
		} else {
			// Slow, have to replace \r with \r\n
			mut buf_i := 0
			for i < data.len && buf_i < exec_write_buf_len - 1 {
				ch := data[i]
				i += 1

				if ch != `\r` {
					buf.bytes[buf_i] = ch
					buf_i += 1
					continue
				}

				// CRLF
				buf.bytes[buf_i] = `\r`
				buf.bytes[buf_i + 1] = `\n`
				buf_i += 2
			}

			slice = unsafe { (&u8(&buf.bytes[0])).vbytes(buf_i) }
		}

		//for (slice) |b| log.warn("write: {x}", .{b});

		exec.write_stream.queue_write(mut td.loop, &exec.write_queue, req, xev.WriteBuffer{
			kind:  .slice
			slice: slice
		}, exec, exec_tty_write)
	}
}

fn exec_tty_write(td_ voidptr, _ &xev.Loop, _ &xev.Completion, _ xev.Stream, _ xev.WriteBuffer, r ?xev.ErrorKind, n usize) xev.CallbackAction {
	mut td := unsafe { &ExecThreadData(td_) }
	td.write_req_pool.put()
	td.write_buf_pool.put()

	if err := r {
		eprintln('write error: ${err}')
		return .disarm
	}
	_ = n
	//log.info("WROTE: {d}", .{d});

	return .disarm
}

// The preallocation size for the write request pool. This should be big
// enough to satisfy most write requests. It must be a power of 2.
const exec_write_req_prealloc = 32

// The size of each pooled pty write buffer.
const exec_write_buf_len = 64

// A pooled pty write buffer (Zig's [64]u8 pool element).
pub struct ExecWriteBuf {
pub mut:
	bytes [64]u8
}

// The thread local data for the exec implementation.
pub struct ExecThreadData {
pub mut:
	// Process start time and boolean of whether its already exited.
	start  u64
	exited bool

	// The data stream is the main IO for the pty.
	write_stream xev.Stream

	// The process watcher
	process ?xev.Process

	// This is the pool of available (unused) write requests. If you grab
	// one from the pool, you must put it back when you're done!
	write_req_pool datastruct.SegmentedPool[xev.WriteRequest]

	// The pool of available buffers for writing to the pty.
	write_buf_pool datastruct.SegmentedPool[ExecWriteBuf]

	// The write queue for the data stream.
	write_queue xev.WriteQueue

	// This is used for both waiting for the process to exit and then
	// subsequently to wait for the data_stream to close.
	process_wait_c xev.Completion

	// The completion specific to Flatpak process waiting.
	flatpak_wait_c internal_os.FlatpakCompletion

	// Reader thread state
	read_thread      ?thread
	read_thread_pipe int = -1
	read_thread_fd   int = -1

	// The timer to detect termios state changes.
	termios_timer         xev.Timer
	termios_timer_c       xev.Completion
	termios_timer_running bool = true

	// The last known termios mode. Used for change detection
	// to prevent unnecessary locking of expensive mutexes.
	termios_mode pty.Mode
}

pub fn (mut self ExecThreadData) deinit() {
	C.close(self.read_thread_pipe)

	// Clear our write pools. We know we aren't ever going to do
	// any more IO since we stop our data stream below so we can just
	// drop this.
	self.write_req_pool.deinit()
	self.write_buf_pool.deinit()

	// Stop our process watcher
	if mut p := self.process {
		p.deinit()
	}

	// Stop our write stream
	self.write_stream.deinit()

	// Stop our termios timer
	self.termios_timer.deinit()
}

// change_config mirrors backend.ThreadData.changeConfig. The pinned exec
// backend currently has no thread-local configuration to update.
pub fn (mut self ExecThreadData) change_config(config &DerivedConfig) {
	_ = config
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
	linux_cgroup               ?string
}

// Subprocess manages the child process lifecycle.
pub struct Subprocess {
pub mut:
	cwd          ?string
	env          ?map[string]string
	args         []string
	grid_size    renderer.GridSize
	screen_size  renderer.ScreenSize
	pty_         ?pty.Pty
	running      bool
	process      ?commandpkg.Command
	linux_cgroup ?string
	// Stable native command state when the process was launched on a Flatpak
	// host. A host PID cannot be watched or signalled with local POSIX calls.
	flatpak_command &internal_os.FlatpakHostCommand = unsafe { nil }
}

// Add our executable directory to the child environment. Flatpak commands run
// on the host, where a binary inside the sandbox cannot be reached.
fn add_executable_to_path(mut env map[string]string, executable string, flatpak bool) {
	if flatpak || executable.len == 0 {
		return
	}

	exe_dir := os.dir(executable)
	if exe_dir.len == 0 {
		return
	}

	// We always set this so that if the shell overwrites the path scripts
	// still have a way to find the Ghostty binary when running in Ghostty.
	env['GHOSTTY_BIN_DIR'] = exe_dir

	// Append so that Ghostty is the last priority in PATH, avoiding a duplicate
	// entry when the executable directory is already present.
	if existing_path := env['PATH'] {
		for entry in existing_path.split(os.path_delimiter) {
			if entry == exe_dir {
				return
			}
		}
		env['PATH'] = internal_os.append_env(existing_path, exe_dir)
	} else {
		env['PATH'] = exe_dir
	}
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

	// Add our binary to the path if we can find it. Skip this for Flatpak
	// because the command runs on the host and cannot reach sandbox binaries.
	add_executable_to_path(mut env, os.executable(), internal_os.is_flatpak())

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
	env['TERM_PROGRAM_VERSION'] = build_meta.version_string

	// VTE_VERSION is set by gnome-terminal and other VTE-based terminals.
	// We don't want our child processes to think we're running under VTE.
	env.delete('VTE_VERSION')

	// Setup our shell integration, if we can.
	default_shell_command := cfg.command or { configpkg.ShellCmd{ shell: 'sh' } }

	// Always set up shell features (GHOSTTY_SHELL_FEATURES). These are
	// used by both automatic and manual shell integrations.
	setup_features(mut env, cfg.shell_integration_features)

	shell_command := setup_shell_command(cfg.shell_integration, cfg.resources_dir, default_shell_command, mut env)!

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
		linux_cgroup: cfg.linux_cgroup
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
	self.flatpak_command = unsafe { nil }
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
		$if linux {
			if internal_os.is_flatpak() {
				if flatpak_cwd_accessible(c)! { c } else { '' }
			} else {
				if os.is_dir(c) { c } else { '' }
			}
		} $else {
			if os.is_dir(c) { c } else { '' }
		}
	} else {
		''
	}

	if self.args.len == 0 {
		p.close_slave()
		p.deinit()
		self.pty_ = none
		return error('no command specified')
	}

	// Flatpak cannot fork a sandbox child into the host namespace. Use the
	// Development portal with the same argv, environment, cwd, and PTY slave
	// descriptors as the pinned implementation.
	$if linux {
		if internal_os.is_flatpak() {
			mut command := &internal_os.FlatpakHostCommand{
				argv: self.args
				cwd: if cwd.len > 0 { cwd } else { none }
				env: self.env
				stdin: p.slave
				stdout: p.slave
				stderr: p.slave
			}
			_ = command.spawn() or {
				p.close_slave()
				p.deinit()
				self.pty_ = none
				return err
			}
			self.flatpak_command = command
			p.close_slave()
			self.env = none
			self.running = true
			return PtyFds{
				read: p.master
				write: p.master
			}
		}
	}

	// Build and start the shared Command translation used by Ghostty's exec
	// backend. Command owns the fork/exec, environment, descriptor, cgroup,
	// working-directory, and pre-exec contracts.
	mut cmd := commandpkg.Command{
		path: self.args[0]
		args: self.args
		env: self.env
		cwd: if cwd.len > 0 { cwd } else { none }
		stdin_fd: p.slave
		stdout_fd: p.slave
		stderr_fd: p.slave
		pre_exec: subprocess_child_pre_exec
		linux_cgroup: self.linux_cgroup
		data: voidptr(self)
	}
	cmd.start() or {
		if commandpkg.is_exec_failed_in_child(err) {
			return err
		}
		p.close_slave()
		p.deinit()
		self.pty_ = none
		return err
	}
	self.process = cmd

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
	self.process = none
	self.running = false
}

// Stop the subprocess. This is safe to call anytime. This will send
// SIGHUP to the process group to signal it to exit.
// This does not close the pty.
pub fn (mut self Subprocess) stop() {
	if !self.running {
		return
	}

	if !isnil(self.flatpak_command) {
		mut command := unsafe { self.flatpak_command }
		kill_command_flatpak(mut command) or {
			eprintln('error sending SIGHUP to command, may hang: ${err}')
		}
		_ = command.wait() or {
			eprintln('error waiting for command to exit: ${err}')
			u8(0)
		}
	} else if process := self.process {
		// Note: this will also wait for the command to exit, so
		// DO NOT call cmd.wait
		kill_command(process) or { eprintln('error sending SIGHUP to command, may hang: ${err}') }
	}

	self.process = none
	self.running = false
}

// Kill the underlying subprocess. This sends a SIGHUP to the child
// process. This also waits for the command to exit and will return the
// exit code.
fn kill_command(command commandpkg.Command) ! {
	if pid := command.pid {
		kill_pid(pid)!
	}
}

fn kill_pid(pid int) ! {
	pgid := subprocess_getpgid(pid) or { return }

	// It is possible to send a killpg between the time that
	// our child process calls setsid but before or simultaneous
	// to calling execve. In this case, the direct child dies
	// but grandchildren survive. To work around this, we loop
	// and repeatedly kill the process group until all
	// descendents are well and truly dead. We will not rest
	// until the entire family tree is obliterated.
	for {
		if C.killpg(pgid, sig_hup) != 0 {
			errno := C.errno
			mut ignore := false
			$if macos {
				// killpg failed with EPERM, expected on Darwin and ignoring
				ignore = errno == C.EPERM
			}
			if !ignore {
				eprintln('error killing process group pgid=${pgid} err=${errno}')
				return error('KillFailed')
			}
		}

		// See Command.zig wait for why we specify WNOHANG.
		// The gist is that it lets us detect when children
		// are still alive without blocking so that we can
		// kill them again.
		mut status := 0
		res := C.waitpid(pid, &status, wnohang)
		if res != 0 {
			break
		}
		time.sleep(10 * time.millisecond)
	}
}

fn subprocess_getpgid(pid int) ?int {
	// Get our process group ID. Before the child pid calls setsid
	// the pgid will be ours because we forked it. Its possible that
	// we may be calling this before setsid if we are killing a surface
	// VERY quickly after starting it.
	my_pgid := C.getpgid(0)

	// We loop while pgid == my_pgid. The expectation if we have a valid
	// pid is that setsid will eventually be called because it is the
	// FIRST thing the child process does and as far as I can tell,
	// setsid cannot fail. I'm sure that's not true, but I'd rather
	// have a bug reported than defensively program against it now.
	for {
		pgid := C.getpgid(pid)
		if pgid == my_pgid {
			eprintln('pgid is our own, retrying')
			time.sleep(10 * time.millisecond)
			continue
		}

		// Don't know why it would be zero but its not a valid pid
		if pgid == 0 {
			return none
		}

		// If the pid doesn't exist then... we're done!
		if pgid == C.ESRCH {
			return none
		}

		// If we have an error we're done.
		if pgid < 0 {
			eprintln('error getting pgid for kill')
			return none
		}

		return pgid
	}
	return none
}

// Kill the underlying process started via Flatpak host command.
// This sends a signal via the Flatpak API.
fn kill_command_flatpak(mut command internal_os.FlatpakHostCommand) ! {
	command.signal(u8(sig_hup), true)!
}

// This runs in the forked child after Command has redirected the standard
// descriptors and before it replaces the process image.
fn subprocess_child_pre_exec(mut cmd commandpkg.Command) {
	mut subprocess := unsafe { &Subprocess(cmd.get_data()) }
	subprocess.child_pre_exec() or {
		eprintln('error initializing child: ${err}')
	}
}

fn (self &Subprocess) child_pre_exec() ! {
	p := self.pty_ or { return error('subprocess pty is unavailable') }
	p.child_pre_exec()!
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

	$if macos {
		internal_os.set_thread_name('io-reader')
	}

	has_crash_state := io != unsafe { nil }
	if has_crash_state {
		crash.set_thread_state(crash.ThreadState{
			kind: .io
			surface: io.surface_mailbox.surface
		})
	}
	defer {
		if has_crash_state {
			crash.clear_thread_state()
		}
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
			n := C.witty_read_retry(fd, &buf[0], usize(1024))
			if n < 0 {
				match C.witty_read_error_kind() {
					// No more data, fall back to poll and check for exit
					// conditions.
					1 {
						break
					}

					// The pty is closed. We're probably gracefully shutting down.
					2 {
						return
					}

					// The pinned implementation treats all other read errors as
					// unreachable because continuing would hide an IO failure.
					else { panic('unexpected pty read error') }
				}
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
		eprintln('cannot spawn command at cwd, ignoring: ${err}')
		return false
	}
	_ = command.wait()!

	return true
}

// setup_shell_command handles the shell integration dispatch based on the
// configured shell integration mode and resources directory.
fn setup_shell_command(integration configpkg.ShellIntegration, resources_dir ?string, default_cmd configpkg.Command, mut env map[string]string) !configpkg.Command {
	if integration == .none_ {
		// This is a source of confusion for users despite being
		// opt-in since it results in some Ghostty features not
		// working. We always want to log it.
		eprintln('shell integration disabled by configuration')
		return default_cmd
	}

	dir := resources_dir or {
		eprintln('no resources dir set, shell integration disabled')
		return default_cmd
	}

	force := match integration {
		.detect { ?Shell(none) }
		.bash { ?Shell(Shell.bash) }
		.elvish { ?Shell(Shell.elvish) }
		.fish { ?Shell(Shell.fish) }
		.nushell { ?Shell(Shell.nushell) }
		.zsh { ?Shell(Shell.zsh) }
		.none_ { // handled above
			?Shell(none)
		}
	}

	integration_result := setup(dir, default_cmd, mut env, force)!
	result := integration_result.value or {
		eprintln('shell could not be detected, no automatic shell integration will be injected')
		return default_cmd
	}

	return result.command
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
