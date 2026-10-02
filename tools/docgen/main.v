module main

import build
import os

fn main() {
	if os.args.len != 2 { eprintln('NoAction'); exit(1) }
	text := match os.args[1] {
		'mdgen_ghostty_1' { build.ghostty_1() }
		'mdgen_ghostty_5' { build.ghostty_5() }
		'webgen_config' { build.gen_web_config() }
		'webgen_actions' { build.gen_web_keybind_actions() }
		'webgen_commands' { build.gen_web_actions() }
		else { eprintln('InvalidAction'); exit(1) }
	}
	mut stdout := os.stdout()
	stdout.write_full_buffer(text.str, usize(text.len)) or { eprintln(err); exit(1) }
}
