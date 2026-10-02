module main

import os
import unicode

fn main() {
	gen := unicode.LutGenerator[bool, unicode.SymbolsGeneratorContext]{}
	tables := gen.generate() or { eprintln(err); exit(1) }
	mut stdout := os.stdout()
	tables.write_zig(mut stdout) or { eprintln(err); exit(1) }
	if path := os.getenv_opt('WITTY_UNICODE_BINARY') {
		unicode.write_table_binary(tables, path) or { eprintln(err); exit(1) }
	}
}
