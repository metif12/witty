module termio

// Exec implements the logic for starting and stopping a subprocess with a
// pty as well as spinning up the necessary read thread to read from the
// pty and forward it to the Termio instance.

import configpkg
import internal_os
import os
import pty
import renderer
import terminal

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

// thread_enter is called when the IO thread starts.
// XTODO: needs xev event loop, Thread.spawn, and real pty fd handling.
pub fn (mut self Exec) thread_enter() ! {
	// XTODO: needs real event loop implementation
	// Start our subprocess
	// pty_fds := self.subprocess.start()!
	// Create pipe for quit signaling
	// Start read thread
	// Start process watcher
	// Start termios timer
}

// thread_exit is called when the IO thread exits.
// XTODO: needs real thread join and pipe close.
pub fn (mut self Exec) thread_exit() {
	// XTODO: needs real implementation
	self.subprocess.stop()
}

// focus_gained notifies the exec backend about focus changes.
// This is used to start/stop the termios polling timer.
pub fn (mut self Exec) focus_gained(focused bool) ! {
	_ = self
	// XTODO: needs termios timer integration
	// If we lost focus, flag the timer to end on the next iteration.
	// If we gained focus, restart the timer if needed.
	_ = focused
}

// resize updates the pty subprocess size.
pub fn (mut self Exec) resize(grid_size renderer.GridSize, screen_size renderer.ScreenSize) ! {
	self.subprocess.resize(grid_size, screen_size)!
}

// queue_write queues data to be written to the pty.
// XTODO: needs xev write stream and buffer pool.
pub fn (mut self Exec) queue_write(data []u8, linefeed bool) ! {
	// XTODO: needs real write stream implementation
	// If our process is exited then we don't send any more writes.
	// We go through and chunk the data if necessary to fit into
	// our cached buffers that we can queue to the stream.
	_ = self
	_ = data
	_ = linefeed
}

// ExecThreadData is the thread local data for the exec implementation.
pub struct ExecThreadData {
pub mut:
	// Process start time (monotonic nanoseconds) and boolean of whether
	// its already exited.
	start_ns u64
	exited   bool

	// The data stream is the main IO for the pty.
	// XTODO: needs xev.Stream type
	// write_stream  voidptr

	// The process watcher
	// XTODO: needs xev.Process type
	// process voidptr

	// Reader thread state
	// XTODO: needs real thread type
	// read_thread       voidptr
	read_thread_pipe int
	read_thread_fd   int

	// The timer to detect termios state changes.
	// XTODO: needs xev.Timer type
	// termios_timer voidptr
	termios_timer_running bool = true

	// The last known termios mode. Used for change detection
	// to prevent unnecessary locking of expensive mutexes.
	termios_mode pty.Mode
}

pub fn (mut self ExecThreadData) deinit() {
	// XTODO: needs real cleanup
	// Close read thread pipe
	// Stop process watcher
	// Stop write stream
	// Stop termios timer
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
	env['TERM_PROGRAM_VERSION'] = '0.1.0' // XTODO: use real version

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
// will panic.
// XTODO: needs real fork/exec, pty.open, and process management.
pub fn (mut self Subprocess) start() !PtyFds {
	// XTODO: needs real pty and process implementation
	// assert(self.pty_ == none && !self.running)

	// Create our pty
	mut p := pty.Pty.open(pty.Winsize{
		ws_row: u16(self.grid_size.rows)
		ws_col: u16(self.grid_size.columns)
		ws_xpixel: u16(self.screen_size.width)
		ws_ypixel: u16(self.screen_size.height)
	})!
	self.pty_ = p

	// XTODO: needs real fork/exec implementation
	// Build our subcommand
	// Start the process
	// Close slave fd in parent after start

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

// Stop the subprocess. This is safe to call anytime. This will wait
// for the subprocess to register that it has been signalled, but not
// for it to terminate, so it will not block.
// This does not close the pty.
pub fn (mut self Subprocess) stop() {
	if !self.running {
		return
	}
	// XTODO: needs real signal sending (SIGHUP) and process wait
	// kill_command() or kill_pid() implementation
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
// XTODO: needs real fd operations (read, poll, fcntl) via C interop.
pub fn (r ReadThread) thread_main_posix(fd int, quit int) {
	// XTODO: needs real implementation
	// Always close our end of the pipe when we exit.
	// Set the fd to non-blocking.
	// Build up the list of fds we're going to poll.
	// Loop: try to read, poll, check quit fd.
	_ = r
	_ = fd
	_ = quit
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
