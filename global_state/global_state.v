module global_state

import os
import internal_os
import cli_args
import crash
import oniguruma

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
	action ?Action

	// Where logging should go.
	logging Logging

	// Unix resource limits that we set for our process.
	rlimits ResourceLimits

	// The app resources directory, equivalent to zig-out/share when we build
	// from source. This is empty if we can't detect it.
	resources_dir internal_os.ResourcesDir

	// Process arguments after argv[0]. The embedded C entrypoint supplies
	// these directly because its argv may differ from V's os.args.
	cli_args []string
}

// Where logging should go.
pub struct Logging {
mut:
	value u8 = default_logging_bits
}

// These mirror the selected application runtime and builtin.os.tag.isDarwin().
// Constants are used because V does not support $if in field initializers.
const default_logging_stderr = $if linux || freebsd { true } $else { false }
const is_darwin = $if macos || ios { true } $else { false }
const default_logging_bits = u8(default_logging_stderr) | (u8(is_darwin) << 1)

// Whether to log to stderr. For lib mode we always disable stderr logging by
// default. Otherwise it is enabled by default.
pub fn (self Logging) stderr() bool {
	return self.value & 0b01 != 0
}

pub fn (mut self Logging) set_stderr(value bool) {
	self.set_bit(0b01, value)
}

// Whether to log to macOS's unified logging. Enabled by default on macOS.
pub fn (self Logging) macos() bool {
	return self.value & 0b10 != 0
}

pub fn (mut self Logging) set_macos(value bool) {
	self.set_bit(0b10, value)
}

pub fn (self Logging) int() u8 {
	return self.value
}

fn (mut self Logging) set_bit(mask u8, enabled bool) {
	if enabled {
		self.value |= mask
	} else {
		self.value &= ~mask
	}
}

fn parse_logging(value string) !Logging {
	mut result := Logging{}
	if all := cli_args.parse_bool(value) {
		result.set_stderr(all)
		result.set_macos(all)
		return result
	}

	for raw_part in value.split(',') {
		mut part := raw_part.trim(cli_args.whitespace)
		mut enabled := true
		if part.starts_with('no-') {
			part = part[3..]
			enabled = false
		}
		match part {
			'stderr' { result.set_stderr(enabled) }
			'macos' { result.set_macos(enabled) }
			else { return error('invalid value') }
		}
	}
	return result
}

// Action represents the special commands accepted through +<action>.
pub enum Action as u8 {
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

// DetectActionResult preserves Ghostty's `!?Action` return contract. V cannot
// combine an optional value with an error result directly, so `action == none`
// represents successful detection with no CLI action.
pub struct DetectActionResult {
pub:
	action ?Action
}

pub fn (action Action) cli_name() string {
	return action.str().replace('_', '-')
}

pub fn actions() []Action {
	return [.version, .help, .list_fonts, .list_keybinds, .list_themes, .list_colors, .list_actions,
		.ssh_cache, .edit_config, .show_config, .validate_config, .show_face, .crash_report, .boo,
		.new_window]
}

// detect_action translates cli/action.zig's generic action detector and
// cli/ghostty.zig's special-case handling.
pub fn detect_action(args []string) !DetectActionResult {
	mut fallback := ?Action(none)
	mut pending := ?Action(none)
	for arg in args {
		if arg == '--version' {
			return DetectActionResult{ action: .version }
		}
		if arg == '--help' || arg == '-h' {
			fallback = .help
		}
		if arg == '-e' && pending == none {
			return DetectActionResult{}
		}
		if !arg.starts_with('+') {
			continue
		}
		if pending != none {
			return error('multiple actions')
		}
		pending = action_from_name(arg[1..]) or { return error('invalid action: ${arg[1..]}') }
	}
	if action := pending {
		return DetectActionResult{ action: action }
	}
	return DetectActionResult{ action: fallback }
}

fn action_from_name(name string) ?Action {
	for action in actions() {
		if action.cli_name() == name {
			return action
		}
	}
	return none
}

// Initialize the global state.
pub fn (mut self GlobalState) init() ! {
	self.init_args(if os.args.len > 1 { os.args[1..] } else { []string{} })!
}

// init_args initializes global state using an explicit argument vector.
pub fn (mut self GlobalState) init_args(args []string) ! {
	// Initialize ourself to nothing so we don't have any extra state.
	// IMPORTANT: this MUST be initialized before any log output because
	// the log function uses the global state.
	self.action = none
	self.logging = Logging{}
	self.rlimits = ResourceLimits{}
	self.resources_dir = internal_os.ResourcesDir{}
	self.cli_args = args.clone()

	self.action = detect_action(args)!.action

	// If we have an action executing, we disable logging by default
	// since we write to stderr we don't want logs messing up our
	// output.
	if self.action != none {
		self.logging.set_stderr(false)
	}

	// I don't love the env var name but I don't have it in my heart
	// to parse CLI args 3 times (once for actions, once for config,
	// maybe once for logging) so for now this is an easy way to do
	// this. Env vars are useful for logging too because they are
	// easy to set.
	if v := os.getenv_opt('GHOSTTY_LOG') {
		self.logging = parse_logging(v) or { Logging{} }
	}

	// Setup our signal handlers before logging
	init_signals()

	// As early as possible, initialize our resource limits.
	self.rlimits = ResourceLimits.new()

	// Initialize crash reporting. This is a no-op for builds such as Witty
	// that do not link Ghostty's optional Sentry native SDK.
	crash.initialize() or { eprintln('crash reporting initialization failed: ${err}') }

	// Locale affects libc, gettext, and every child shell, so initialize it
	// before loading translated resources or starting an application runtime.
	internal_os.ensure_locale()!

	// Initialize Oniguruma for regular-expression link matching.
	oniguruma.init([.utf8])!

	// Find our resources directory once for the app so every launch
	// hereafter can use this cached value.
	self.resources_dir = internal_os.resources_dir()
	if resources_dir := self.resources_dir.app() {
		internal_os.init_i18n(resources_dir) or {
			eprintln('failed to initialize translations: ${err}')
		}
	}
}

// Cleans up the global state. This doesn't _need_ to be called but
// doing so in dev modes will check for memory leaks.
pub fn (mut self GlobalState) deinit() {
	self.resources_dir = internal_os.ResourcesDir{}
	self.cli_args.clear()
	internal_os.shutdown_i18n()
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

// C interop declarations for signal handling.
fn C.signal(signum int, handler voidptr) voidptr
