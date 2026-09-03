module global_state

import os
import internal_os
import cli_args
import crash

// Global process state. This is initialized in main() for exe artifacts
// and by ghostty_init() for lib artifacts. This should ONLY be used by
// the C API. The Zig API should NOT use any global state and should
// rely on allocators being passed in as parameters.
// Global state singleton. Using a struct wrapper and const pointer
// to avoid requiring -enable-globals for test compilation.
struct GlobalStateSingleton {
mut:
	gs GlobalState
}

const global_state_instance = &GlobalStateSingleton{}

// get_state returns a mutable reference to the global state singleton.
pub fn get_state() &GlobalState {
	return unsafe { &global_state_instance.gs }
}

// get_state_mut returns a mutable reference for initialization.
pub fn get_state_mut() &GlobalState {
	return unsafe { &global_state_instance.gs }
}

// This represents the global process state. There should only
// be one of these at any given moment. This is extracted into a dedicated
// struct because it is reused by main and the static C lib.
pub struct GlobalState {
pub mut:
	// The action to execute, if any. This is detected from CLI args.
	action Action = .none

	// Where logging should go.
	logging Logging

	// Unix resource limits that we set for our process.
	rlimits ResourceLimits

	// The app resources directory, equivalent to zig-out/share when we build
	// from source. This is empty if we can't detect it.
	resources_dir ResourcesDir
}

// Where logging should go.
pub struct Logging {
pub mut:
	// Whether to log to stderr. For lib mode we always disable stderr
	// logging by default. Otherwise it's enabled by default.
	stderr bool = true

	// Whether to log to macOS's unified logging. Enabled by default
	// on macOS.
	macos bool = is_macos
}

// is_macos is true on macOS, false otherwise. Used as a struct field default
// since V does not support $if in struct field initializers.
const is_macos = $if macos { true } $else { false }

// Action represents the special commands accepted through +<action>.
pub enum Action {
	none
	version
	help
	list_fonts
	list_keybinds
	list_themes
	list_colors
	list_actions
	ssh_cache
	edit_config
	show_config
	validate_config
	show_face
	crash_report
	boo
	new_window
}

pub fn (action Action) cli_name() string {
	return action.str().replace('_', '-')
}

// detect_action translates cli/action.zig's generic action detector and
// cli/ghostty.zig's special-case handling.
pub fn detect_action(args []string) !Action {
	mut fallback := Action.none
	mut pending := Action.none
	for arg in args {
		if arg == '--version' {
			return .version
		}
		if arg == '--help' || arg == '-h' {
			fallback = .help
		}
		if arg == '-e' && pending == .none {
			return .none
		}
		if !arg.starts_with('+') {
			continue
		}
		if pending != .none {
			return error('multiple actions')
		}
		pending = action_from_name(arg[1..]) or { return error('invalid action: ${arg[1..]}') }
	}
	if pending != .none {
		return pending
	}
	return fallback
}

fn action_from_name(name string) ?Action {
	for action in [Action.version, .help, .list_fonts, .list_keybinds, .list_themes, .list_colors,
		.list_actions, .ssh_cache, .edit_config, .show_config, .validate_config, .show_face,
		.crash_report, .boo, .new_window] {
		if action.cli_name() == name {
			return action
		}
	}
	return none
}

// Initialize the global state.
pub fn (mut self GlobalState) init() ! {
	// Initialize ourself to nothing so we don't have any extra state.
	// IMPORTANT: this MUST be initialized before any log output because
	// the log function uses the global state.
	self.action = .none
	self.logging = Logging{}
	self.rlimits = ResourceLimits{}
	self.resources_dir = ResourcesDir{}

	self.action = detect_action(if os.args.len > 1 { os.args[1..] } else { []string{} })!

	// If we have an action executing, we disable logging by default
	// since we write to stderr we don't want logs messing up our
	// output.
	if self.action != .none {
		self.logging.stderr = false
	}

	// I don't love the env var name but I don't have it in my heart
	// to parse CLI args 3 times (once for actions, once for config,
	// maybe once for logging) so for now this is an easy way to do
	// this. Env vars are useful for logging too because they are
	// easy to set.
	if v := os.getenv_opt('GHOSTTY_LOG') {
		self.logging = cli_args.parse_packed_struct[Logging](v) or { Logging{} }
	}

	// Setup our signal handlers before logging
	init_signals()

	// As early as possible, initialize our resource limits.
	self.rlimits = ResourceLimits.new()

	// Initialize crash reporting. This is a no-op for builds such as Witty
	// that do not link Ghostty's optional Sentry native SDK.
	crash.initialize() or { eprintln('crash reporting initialization failed: ${err}') }

	// Find our resources directory once for the app so every launch
	// hereafter can use this cached value.
	self.resources_dir = ResourcesDir.detect()
}

// Cleans up the global state. This doesn't _need_ to be called but
// doing so in dev modes will check for memory leaks.
pub fn (mut self GlobalState) deinit() {
	self.rlimits.restore()
	self.resources_dir = ResourcesDir{}
	crash.shutdown()
}

// init_signals sets up process signal handlers.
fn init_signals() {
	$if !windows {
		// We ignore SIGPIPE because it is a common signal we may get
		// due to how we implement termio. When a terminal is closed we
		// often write to a broken pipe to exit the read thread. This should
		// be fixed one day but for now this helps make this a bit more
		// robust.
		unsafe {
			C.signal(C.SIGPIPE, voidptr(C.SIG_IGN))
		}
	}
}

// Maintains the Unix resource limits that we set for our process. This
// can be used to restore the limits to their original values.
pub struct ResourceLimits {
pub mut:
	// The saved previous nofile limit, so we can restore it later.
	nofile ?internal_os.Rlimit
}

// new creates a ResourceLimits, maximizing file descriptor limits.
pub fn ResourceLimits.new() ResourceLimits {
	// Maximize the number of file descriptors we can have open
	// because we can consume a lot of them if we make many terminals.
	mut limits := ResourceLimits{}
	if lim := internal_os.fix_max_files() {
		limits.nofile = lim
	}
	return limits
}

// restore restores the resource limits to their original values.
pub fn (self &ResourceLimits) restore() {
	if lim := self.nofile {
		internal_os.restore_max_files(lim)
	}
}

// ResourcesDir holds the application resources directory path. This is a
// faithful translation of ghostty's src/os/resourcesdir.zig ResourcesDir.
pub struct ResourcesDir {
pub mut:
	// Avoid accessing these directly, use the app() and host() methods instead.
	app_path  ?string
	host_path ?string
}

// app returns the directory to the bundled resources directory accessible
// by the application, or an empty string if not detected.
pub fn (r ResourcesDir) app() string {
	return r.app_path or { '' }
}

// host returns the directory to the bundled resources directory accessible
// by the host environment (i.e. for sandboxed applications). The returned
// directory might not be accessible from the application itself.
//
// In a non-sandboxed environment this is the same as app().
pub fn (r ResourcesDir) host() string {
	if p := r.host_path {
		return p
	}
	return r.app_path or { '' }
}

// The sentinel values we look for in the path to know we've found the
// resources directory. This mirrors ghostty's per-target sentinel list;
// we include both the generic Linux/BSD sentinels and the macOS one so
// detection works regardless of how resources were laid out.
const resources_sentinels = $if windows { ['terminfo/ghostty.terminfo'] } $else $if macos { [
	'terminfo/78/xterm-ghostty',
	'terminfo/g/ghostty',
	'terminfo/x/xterm-ghostty',
] } $else { ['terminfo/g/ghostty', 'terminfo/x/xterm-ghostty'] }

// detect gets the directory to the bundled resources directory, if it
// exists (not all platforms or packages have it). This is a faithful
// translation of ghostty's resourcesDir().
//
// It uses the GHOSTTY_RESOURCES_DIR environment variable if set, otherwise
// it climbs the tree from the running binary looking for a terminfo bundle.
pub fn ResourcesDir.detect() ResourcesDir {
	// Use the GHOSTTY_RESOURCES_DIR environment variable if set.
	if dir := os.getenv_opt('GHOSTTY_RESOURCES_DIR') {
		if dir.len > 0 {
			return ResourcesDir{
				app_path: dir
			}
		}
	}

	// Get the path to our running binary and climb the tree.
	exe := os.executable()
	return resources_dir_from_exe(exe)
}

// resources_dir_from_exe climbs the directory tree starting from the given
// executable path, looking for the terminfo bundle as we expect it. This is
// the core loop of ghostty's resourcesDir().
pub fn resources_dir_from_exe(exe_path string) ResourcesDir {
	mut exe := exe_path

	// We have an exe path! Climb the tree looking for the terminfo bundle
	// as we expect it.
	for {
		dir := os.dir(exe)
		// os.dir returns the same path (or ".") when there is no parent.
		if dir == exe || dir == '.' || dir.len == 0 {
			break
		}
		exe = dir

		// On macOS, we look for the app bundle path.
		$if macos {
			for sentinel in resources_sentinels {
				if v := maybe_dir(dir, 'Contents/Resources', sentinel) {
					return ResourcesDir{
						app_path: os.join_path(v, 'ghostty')
					}
				}
			}
		}

		// On all platforms (except BSD), we look for a /usr/share style
		// path. This is valid even on Mac since there is nothing that
		// requires Ghostty to be in an app bundle.
		sub := $if freebsd { 'local/share' } $else { 'share' }
		for sentinel in resources_sentinels {
			if v := maybe_dir(dir, sub, sentinel) {
				return ResourcesDir{
					app_path: os.join_path(v, 'ghostty')
				}
			}
		}
	}

	return ResourcesDir{}
}

// maybe_dir checks if the "base/sub/suffix" path exists and if so returns
// the "base/sub" directory. The "suffix" is used to verify a directory
// seems roughly right. Faithful translation of ghostty's maybeDir().
fn maybe_dir(base string, sub string, suffix string) ?string {
	path := '${base}/${sub}/${suffix}'
	if os.exists(path) {
		// Return the path without the trailing "/suffix".
		return '${base}/${sub}'
	}
	return none
}

// C interop declarations for signal handling.
fn C.signal(signum int, handler voidptr) voidptr
