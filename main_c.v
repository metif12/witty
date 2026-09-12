// Translated from Ghostty's main_c.zig
//
// This is the main file for the C API. The C API is used to embed Ghostty
// within other applications. Depending on the build settings some APIs
// may not be available (i.e. embedding into macOS exposes various Metal
// support).
//
// This currently isn't supported as a general purpose embedding API.
// This is currently used only to embed ghostty within a macOS app. However,
// it could be expanded to be general purpose in the future.

module main

import cli
import core
import global_state
import internal_os

// Install the runtime-neutral bridge used by the embedded/libghostty API.
// This keeps apprt free of a circular dependency while ensuring its C-facing
// CoreApp/CoreSurface wrappers use the canonical translated implementations.
fn init() {
	core.install_embedded_bridge()
}

// BuildMode mirrors the C enum ghostty_build_mode_e.
pub enum BuildMode {
	debug
	release_safe
	release_fast
	release_small
}

// Info corresponds to ghostty_info_s. Contains metadata about the
// Ghostty build such as version and build mode.
pub struct Info {
pub:
	mode        BuildMode
	version     &u8 = unsafe { nil }
	version_len usize
}

// GhosttyString corresponds to ghostty_string_s. A string type used
// across the C API boundary with explicit length and sentinel tracking.
pub struct GhosttyString {
pub:
	ptr      &u8 = unsafe { nil }
	len      usize
	sentinel bool
}

// empty returns an empty GhosttyString with null pointer.
pub fn GhosttyString.empty() GhosttyString {
	return GhosttyString{
		ptr: unsafe { nil }
		len: 0
		sentinel: false
	}
}

// from_string creates a GhosttyString from a V string.
pub fn GhosttyString.from_string(s string) GhosttyString {
	if s.len == 0 {
		return GhosttyString.empty()
	}
	ptr := unsafe { malloc(s.len + 1) }
	unsafe {
		vmemcpy(ptr, s.str, s.len)
		(&u8(ptr))[s.len] = 0
	}
	return GhosttyString{
		ptr: &u8(ptr)
		len: usize(s.len)
		sentinel: true
	}
}

// from_bytes creates a GhosttyString from a byte slice.
pub fn GhosttyString.from_bytes(b []u8) GhosttyString {
	if b.len == 0 {
		return GhosttyString.empty()
	}
	ptr := unsafe { malloc(b.len) }
	unsafe {
		vmemcpy(ptr, b.data, b.len)
	}
	return GhosttyString{
		ptr: &u8(ptr)
		len: usize(b.len)
		sentinel: false
	}
}

pub fn (str GhosttyString) bytes() []u8 {
	if isnil(str.ptr) || str.len == 0 {
		return []u8{}
	}
	return unsafe { str.ptr.vbytes(int(str.len)) }
}

// ghostty_init initializes ghostty global state. In Ghostty's C API this
// receives (argc, argv) from the embedder; in V we rely on `os.args` which
// is already populated. The signature is kept so it can be called from a
// host that wants to pass through process args. Returns 0 on success and
// 1 on initialization failure (matching the Zig return).
pub fn ghostty_init(argc int, argv []string) int {
	// Ghostty's Zig version sets `std.os.argv = argv[0..argc]` here before
	// initializing global state. V's `os.args` is populated automatically
	// from libc and exposed as an immutable const, so we don't reassign it;
	// any embedder that needs a different argv should set it through env
	// inheritance instead.
	mut state := global_state.get_state_mut()
	args := if argc > 1 && argv.len > 1 {
		argv[1..min_int(argc, argv.len)]
	} else {
		[]string{}
	}
	state.init_args(args) or {
		eprintln('failed to initialize ghostty error=${err}')
		return 1
	}
	return 0
}

// ghostty_cli_try_action runs the detected CLI action if one was set during
// global state init. If there is no action this returns; otherwise it runs
// the action and exits the process with its return code.
pub fn ghostty_cli_try_action() {
	state := global_state.get_state()
	if state.action == .none {
		return
	}
	code := run_cli_action(state.action, state.cli_args) or {
		eprintln('CLI action failed: ${err}')
		exit(1)
	}
	exit(code)
}

pub fn run_cli_action(action global_state.Action, args []string) !int {
	return run_cli_action_main(action, args) or {
		if cli.is_action_help_requested(err) {
			help := cli.action_help_output(action.cli_name()) or { return err }
			print(help)
			return 0
		}
		return err
	}
}

fn run_cli_action_main(action global_state.Action, args []string) !int {
	return match action {
		.none { 0 }
		.version {
			println('Ghostty ${version_string}')
			println('')
			println('Version')
			println('  - version: ${version_string}')
			println('  - channel: ${release_channel}')
			println('Build Config')
			println('  - V version     : ${@VEXE}')
			println('  - build mode    : ${if is_debug { 'debug' } else { 'release' }}')
			println('  - app runtime   : ${artifact}')
			$if linux {
				kernel := internal_os.get_kernel_info() or { 'Kernel information unavailable' }
				println('  - kernel version: ${kernel}')
				println('  - desktop env   : ${internal_os.desktop_environment()}')
			}
			0
		}
		.help {
			print_cli_help()
			0
		}
		.list_themes { cli.run_list_themes(action_args(args, action))! }
		.list_fonts { cli.run_list_fonts(action_args(args, action))! }
		.list_colors { cli.run_list_colors(action_args(args, action))! }
		.list_keybinds { cli.run_list_keybinds(action_args(args, action))! }
		.validate_config { cli.run_validate_config(action_args(args, action))! }
		.edit_config { cli.run_edit_config(action_args(args, action))! }
		.show_config { cli.run_show_config(action_args(args, action))! }
		.show_face { cli.run_show_face(action_args(args, action))! }
		.ssh_cache { cli.run_ssh_cache(action_args(args, action))! }
		.crash_report { cli.run_crash_report(action_args(args, action))! }
		.boo { cli.run_boo(action_args(args, action))! }
		.new_window { cli.run_new_window(action_args(args, action))! }
		.list_actions { cli.run_list_actions(action_args(args, action))! }
	}
}

fn action_args(args []string, action global_state.Action) []string {
	needle := '+${action.cli_name()}'
	return args.filter(it != needle)
}

fn print_cli_help() {
	print(cli_help_output())
}

// cli_help_output is the translated `cli/help.zig` help text. The help action
// is deliberately the one CLI action that accepts `--help` itself, so the
// action list is generated from the same enum used by action detection.
fn cli_help_output() string {
	mut output := 'Usage: ghostty [+action] [options]\n\n'
	output += 'Run the Ghostty terminal emulator or a specific helper action.\n\n'
	output += 'If no `+action` is specified, run the Ghostty terminal emulator.\n'
	output += 'All configuration keys are available as command line options.\n'
	output += 'To specify a configuration key, use the `--<key>=<value>` syntax\n'
	output += "where key and value are the same format you'd put into a configuration\n"
	output += 'file. For example, `--font-size=12` or `--font-family="Fira Code"`.\n\n'
	output += 'To see a list of all available configuration options, please see\n'
	output += 'the `src/config/Config.zig` file. A future update will allow seeing\n'
	output += 'the list of configuration options from the command line.\n\n'
	output += 'A special command line argument `-e <command>` can be used to run\n'
	output += 'the specific command inside the terminal emulator. For example,\n'
	output += '`ghostty -e top` will run the `top` command inside the terminal.\n\n'
	output += 'On macOS, launching the terminal emulator from the CLI is not\n'
	output += 'supported and only actions are supported. Use `open -na Ghostty.app`\n'
	output += 'instead, or `open -na ghostty.app --args --foo=bar --baz=quz` to pass\n'
	output += 'arguments.\n\n'
	output += 'Available actions:\n\n'
	for action in global_state.actions() {
		if action != .none {
			output += '  +${action.cli_name()}\n'
		}
	}
	output += '\nSpecify `+<action> --help` to see the help for a specific action,\n'
	output += 'where `<action>` is one of actions listed above.\n'
	return output
}

// ghostty_info: Return metadata about Ghostty, such as version, build mode, etc.
pub fn ghostty_info() Info {
	return Info{
		mode: if is_debug { .debug } else { .release_fast }
		version: version_string.str
		version_len: usize(version_string.len)
	}
}

// ghostty_translate: Translate a string maintained by libghostty into the
// current application language. This will return the same string (same pointer)
// if no translation is found, so the pointer must be stable through
// the function call.
//
// This should only be used for singular strings maintained by Ghostty.
pub fn ghostty_translate(msgid string) string {
	return internal_os.translate(msgid)
}

// ghostty_string_free: Free a string allocated by Ghostty.
pub fn ghostty_string_free(str GhosttyString) {
	if !isnil(str.ptr) {
		unsafe {
			free(str.ptr)
		}
	}
}

fn min_int(a int, b int) int {
	return if a < b { a } else { b }
}

// C ABI entrypoints. The V-facing helpers above remain convenient for tests
// and native callers while these wrappers preserve Ghostty's public symbols.
@[export: 'ghostty_init']
fn ghostty_init_export(argc usize, argv &&char) int {
	mut args := []string{cap: int(argc)}
	unsafe {
		for i in 0 .. int(argc) {
			value := argv[i]
			args << if isnil(value) { '' } else { cstring_to_vstring(value) }
		}
	}
	return ghostty_init(int(argc), args)
}

@[export: 'ghostty_cli_try_action']
fn ghostty_cli_try_action_export() {
	ghostty_cli_try_action()
}

@[export: 'ghostty_info']
fn ghostty_info_export() Info {
	return ghostty_info()
}

@[export: 'ghostty_translate']
fn ghostty_translate_export(msgid &char) &char {
	return internal_os.translate_c(msgid)
}

@[export: 'ghostty_string_free']
fn ghostty_string_free_export(str GhosttyString) {
	ghostty_string_free(str)
}
