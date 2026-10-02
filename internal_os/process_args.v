module internal_os

import os

struct ProcessArgsState {
mut:
	args ?[]string
}

const process_args_state = &ProcessArgsState{}

// main_c.zig assigns std.os.argv to the embedding caller's complete argv.
// Keep that vector independently of V's immutable libc-populated os.args.
pub fn set_process_args(argv []string) {
	mut state := unsafe { process_args_state }
	state.args = argv.clone()
}

pub fn process_args() []string {
	return process_args_state.args or { os.args.clone() }
}
