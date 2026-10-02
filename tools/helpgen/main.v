module main

import help_strings
import os

fn main() {
 mut stdout := os.stdout()
 help_strings.write_zig(mut stdout) or { eprintln(err); exit(1) }
 if directory := os.getenv_opt('WITTY_HELP_RECORDS') {
  help_strings.write_records(directory) or { eprintln(err); exit(1) }
 }
}
