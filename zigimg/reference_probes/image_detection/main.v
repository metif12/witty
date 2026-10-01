module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	bytes := '#define w 8\n'.bytes()
	match os.args[1] {
		'managed' { _ = zigimg.Image.detect_format_from_memory(bytes) or { panic(err) } }
		'unmanaged' { _ = zigimg.ImageUnmanaged.detect_format_from_memory(bytes) or { panic(err) } }
		else { panic('unknown case') }
	}

	panic('UNEXPECTED: image detection returned')
}
