module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	name := os.args[1]
	mut image := zigimg.Image.init()
	mut unmanaged := zigimg.ImageUnmanaged{}
	match name {
		'managed_create' {
			image = zigimg.Image.create(~uint(0), 2, .invalid) or { panic(err) }
		}
		'unmanaged_create' {
			unmanaged = zigimg.ImageUnmanaged.create(~uint(0), 2, .invalid) or { panic(err) }
		}
		'managed_row' {
			_ = image.row_byte_size()
		}
		'unmanaged_row' {
			_ = unmanaged.row_byte_size()
		}
		'managed_flip' {
			image.flip_vertically() or { panic(err) }
		}
		'unmanaged_flip' {
			unmanaged.flip_vertically() or { panic(err) }
		}
		'managed_crop' {
			image.width = ~uint(0)
			image.height = 2
			_ = image.crop(zigimg.Box{ width: ~uint(0), height: 2 }) or { panic(err) }
		}
		'unmanaged_crop' {
			unmanaged.width = ~uint(0)
			unmanaged.height = 2
			_ = unmanaged.crop(zigimg.Box{ width: ~uint(0), height: 2 }) or { panic(err) }
		}
		else {
			panic('unknown case')
		}
	}

	eprintln('UNEXPECTED: image operation returned')
}
