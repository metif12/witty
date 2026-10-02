module main

import native_shaders
import os

fn main() {
	root := if os.args.len > 1 { os.real_path(os.args[1]) } else { os.getwd() }
	archives := native_shaders.build(root, native_shaders.Options{ compiler: os.getenv_opt('CXX') or {
		'c++'
	} }) or {
		eprintln(err)
		exit(1)
	}
	for archive in archives {
		println(archive)
	}
}
