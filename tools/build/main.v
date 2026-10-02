module main

import build_support
import json
import os

fn main() {
	if '--help' in os.args {
		println('V translation of Ghostty build.zig\n\nUsage: v run tools/build [step] [-Dname=value] [--prefix path] [-- args]\n\nSteps: install, run, lib-vt, test, test-lib-vt, run-valgrind, test-valgrind,\n       dist, distcheck, update-translations, resources, docs, locales, webdata, config\n\nOptions match src/build/Config.zig; --system and -fsys=NAME control system libraries.')
		return
	}
	root := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	cfg := build_support.init_config(root, os.args[1..]) or { eprintln(err); exit(1) }
	driver := build_support.Driver{cfg: cfg}
	for step in cfg.steps {
		match step {
			'install' { driver.install() or { eprintln(err); exit(1) } }
			'run' { driver.run_executable(false) or { eprintln(err); exit(1) } }
			'run-valgrind' { driver.run_executable(true) or { eprintln(err); exit(1) } }
			'lib-vt' { driver.build_vt() or { eprintln(err); exit(1) } }
			'test-lib-vt' { driver.run_tests(true, false, false) or { eprintln(err); exit(1) } }
			'test' { driver.run_tests(false, false, false) or { eprintln(err); exit(1) } }
			'test-valgrind' { driver.run_tests(false, true, false) or { eprintln(err); exit(1) } }
			'dist' { driver.build_distribution(false) or { eprintln(err); exit(1) } }
			'distcheck' { driver.build_distribution(true) or { eprintln(err); exit(1) } }
			'framegen' { driver.generate_frame_data() or { eprintln(err); exit(1) } }
			'unicode-tables' { driver.generate_unicode_tables() or { eprintln(err); exit(1) } }
			'helpgen' { driver.install_help_generator() or { eprintln(err); exit(1) } }
			'xcframework' { driver.build_xcframework(false) or { eprintln(err); exit(1) } }
			'config' { println(json.encode(cfg)) }
			'resources' { driver.install_resources() or { eprintln(err); exit(1) } }
			'docs' { driver.install_docs() or { eprintln(err); exit(1) } }
			'locales' { driver.install_locales() or { eprintln(err); exit(1) } }
			'webdata' { driver.install_webdata() or { eprintln(err); exit(1) } }
			'update-translations' { driver.update_translations() or { eprintln(err); exit(1) } }
			else { eprintln('unknown build step: ${step}'); exit(1) }
		}
	}
}
