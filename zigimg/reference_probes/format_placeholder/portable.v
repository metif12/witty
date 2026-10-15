module main

import zigimg

fn main() {
	value := zigimg.FormatPlaceholder.parse('[name]x:0>12.3'.bytes()) or { panic(err) }
	assert value.fill == `0` && value.alignment == .right
	assert value.specifier_arg.bytestr() == 'x'
	if value.width is zigimg.FormatNumber {
		assert value.width.value == 12
	} else {
		assert false
	}
}
