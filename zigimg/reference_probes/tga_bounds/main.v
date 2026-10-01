module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	mut bytes := []u8{len: 48}
	bytes[2] = 1 // Indexed, zero dimensions.
	bytes[3] = 1 // First palette entry is outside its one-element active slice.
	bytes[5] = 1
	bytes[7] = 24
	bytes[16] = 8
	match os.args[1] {
		'palette_index' {}
		'palette_sum' {
			bytes[3] = 255
			bytes[4] = 255
		}
		'pixel_byte_sum' {
			bytes[2] = 11
			bytes[16] = 249
		}
		'palette_capacity' {
			bytes[3] = 0
			bytes[5] = 1
			bytes[6] = 1
		}
		else {
			panic('unknown case')
		}
	}

	mut source := zigimg.ReadStream.init_memory(bytes)
	mut codec := zigimg.TGA{}
	if _ := codec.read(mut source) {
		eprintln('UNEXPECTED: decoder returned')
	} else {
		eprintln('UNEXPECTED: recoverable ${err}')
	}
}
