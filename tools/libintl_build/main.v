module main

import native_libintl
import os

fn main() {
	root := if os.args.len > 1 { os.real_path(os.args[1]) } else { os.getwd() }
	compiler := os.getenv_opt('CC') or { 'cc' }
	archive := native_libintl.build(root, compiler, []) or { eprintln(err); exit(1) }
	println(archive)
}
