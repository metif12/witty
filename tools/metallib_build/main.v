module main

import native_metallib
import os

fn main() {
	root := if os.args.len > 1 { os.real_path(os.args[1]) } else { os.getwd() }
	result := native_metallib.build(root, native_metallib.Options{}) or {
		eprintln(err)
		exit(1)
	}
	if path := result.output { println(path) }
}
