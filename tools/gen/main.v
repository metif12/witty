module main

import synthetic
import source_startup

fn main() {
	source_startup.prepare()
	synthetic.main() or {
		eprintln(err)
		exit(1)
	}
}
