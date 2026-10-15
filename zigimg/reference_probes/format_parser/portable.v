module main

import zigimg

fn main() {
	mut parser := zigimg.FormatParser{
		bytes: '[name]42'.bytes()
		i:     0
	}
	spec := parser.specifier() or { panic(err) }
	if spec is zigimg.FormatNamed {
		assert spec.bytes.bytestr() == 'name'
	} else {
		assert false
	}
	assert (parser.number() or { panic('none') }) == 42
	mut args := zigimg.FormatArgState{
		args_len: 1
	}
	assert (args.next_arg(none) or { panic('none') }) == 0
	assert !args.has_unused_args()
}
