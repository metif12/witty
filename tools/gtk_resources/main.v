module main

import gtk_resources
import os

fn main() {
	root := if os.args.len > 1 { os.real_path(os.args[1]) } else { os.getwd() }
	version := if os.args.len > 2 { os.args[2] } else {
		result := os.execute('pkg-config --modversion libadwaita-1')
		if result.exit_code != 0 { eprintln(result.output); exit(1) }
		result.output.trim_space()
	}
	path := gtk_resources.build(root, version) or { eprintln(err); exit(1) }
	println(path)
}
