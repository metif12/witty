module main

import json2
import os
import lib_abi

fn main() {
	if os.args.len != 3 {
		eprintln('usage: lib_abi_generate schema.json output-directory')
		exit(1)
	}
	schema := json2.decode[lib_abi.Schema](os.read_file(os.args[1]) or { panic(err) }) or {
		panic(err)
	}
	output := os.real_path(os.args[2])
	os.mkdir_all(output) or { panic(err) }
	generated := lib_abi.generate(schema, output + '/types.h') or { panic(err) }
	os.write_file(output + '/types.h', generated.c_declarations) or { panic(err) }
	os.write_file(output + '/types.v', generated.v_declarations) or { panic(err) }
}
