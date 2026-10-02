module main

import benchmark
import source_startup

fn main() {
	source_startup.prepare()
	benchmark.main() or {
		eprintln(err)
		exit(1)
	}
}
