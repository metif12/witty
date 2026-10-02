module main

import native_sentry
import os

fn main() {
	root := if os.args.len > 1 { os.real_path(os.args[1]) } else { os.getwd() }
	outputs := native_sentry.build(root, native_sentry.Options{
		c_compiler:   os.getenv_opt('CC') or { 'cc' }
		cpp_compiler: os.getenv_opt('CXX') or { 'c++' }
	}) or {
		eprintln(err)
		exit(1)
	}
	for output in outputs { println(output) }
}
