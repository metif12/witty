module main

import build_data
import os

fn main() {
	action := build_data.detect_action(os.args) or { eprintln(err); exit(1) }
	text := build_data.generate_build_data(action)
	mut stdout := os.stdout()
	stdout.write_full_buffer(text.str, usize(text.len)) or { eprintln(err); exit(1) }
}
