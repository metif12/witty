module zigimg

fn test_flip_uses_floor_byte_rows_and_keeps_the_remaining_middle_byte() {
	mut bytes := [u8(1), 2, 3, 4, 5]
	image := ImageUnmanaged.from_raw_pixels_owned(99, 2, bytes, .grayscale8)!
	assert image.row_byte_size() == 2 && image.to_managed().row_byte_size() == 2
	image.flip_vertically()!
	assert bytes == [u8(4), 5, 3, 1, 2]
	image.flip_vertically()!
	assert bytes == [u8(1), 2, 3, 4, 5]
}

fn test_empty_crop_skips_wide_offsets_after_copying_the_active_palette() {
	mut indexed := IndexedStorage8.init_palette_size(1, 2)
	indexed.palette[1] = Rgba32{
		r: 37
		a: 99
	}
	image := ImageUnmanaged{
		width:  ~uint(0)
		height: ~uint(0)
		pixels: indexed
	}
	cropped := image.crop(Box{ x: ~uint(0), y: ~uint(0) })!
	assert cropped.width == 0 && cropped.height == 0 && cropped.pixels.len() == 0
	palette := cropped.pixels.get_palette() or { panic('missing palette') }
	assert palette == indexed.palette
	indexed.palette[1].r = 81
	assert palette[1].r == 37
}

fn test_crop_box_and_zero_pixel_dimensions_keep_native_usize_boundaries() {
	assert Box{
		width:  ~uint(0)
		height: ~uint(0)
	}.clamp(8, 9) == Box{
		width:  8
		height: 9
	}
	assert Box{
		x:      8
		y:      9
		width:  2
		height: 3
	}.clamp(8, 9) == Box{
		x: 8
		y: 9
	}
	assert Box{
		x: ~uint(0)
		y: ~uint(0)
	}.clamp(~uint(0), ~uint(0)) == Box{
		x: ~uint(0)
		y: ~uint(0)
	}
	wide := ImageUnmanaged.create(~uint(0), 0, .invalid)!
	assert wide.width == ~uint(0) && wide.height == 0
	assert wide.pixels.len() == 0
	tall := Image.create(0, ~uint(0), .invalid)!
	assert tall.width == 0 && tall.height == ~uint(0)
	assert tall.pixels.len() == 0
}

fn test_vertical_flip_mutates_borrowed_rows_and_keeps_animation_and_palette() {
	mut bytes := []u8{len: 18, init: u8(index + 1)}
	image := ImageUnmanaged.from_raw_pixels_owned(2, 3, bytes, .rgb24)!
	image.flip_vertically()!
	assert bytes == [u8(13), 14, 15, 16, 17, 18, 7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6]
	image.flip_vertically()!
	assert bytes == []u8{len: 18, init: u8(index + 1)}

	mut indexed := IndexedStorage2.init_palette_size(4, 2)
	indexed.indices = [u8(0), 1, 1, 0]
	indexed.palette[1] = Rgba32{
		r: 23
		a: 56
	}
	animated := ImageUnmanaged{
		width:     2
		height:    2
		pixels:    indexed
		animation: Animation{
			frames:     [
				AnimationFrame{
					pixels:   Rgb24Pixels{
						data: [Rgb24{ r: 9 }]
					}
					duration: 0.5
				},
			]
			loop_count: 4
		}
	}
	animated.flip_vertically()!
	assert indexed.indices == [u8(1), 0, 0, 1]
	assert indexed.palette[1] == Rgba32{
		r: 23
		a: 56
	}
	assert animated.animation.loop_count == 4
	assert animated.animation.frames[0].pixels.as_bytes() == [u8(9), 0, 0]
}

fn test_flip_handles_one_row_and_zero_pixels() {
	image := ImageUnmanaged.from_raw_pixels_owned(3, 1, [u8(1), 2, 3], .grayscale8)!
	image.flip_vertically()!
	assert image.raw_bytes() == [u8(1), 2, 3]
	empty := ImageUnmanaged.create(0, 3, .rgba32)!
	empty.flip_vertically()!
	assert empty.pixels.len() == 0
}

fn test_crop_copies_rows_clamps_size_and_discards_animation() {
	mut bytes := []u8{len: 36, init: u8(index)}
	image := ImageUnmanaged{
		width:     4
		height:    3
		pixels:    PixelStorage.init_raw_pixels(bytes, .rgb24)!
		animation: Animation{
			frames:     [AnimationFrame{ pixels: InvalidPixels{}, duration: 0 }]
			loop_count: 7
		}
	}
	cropped := image.crop(Box{ x: 1, y: 1, width: 2, height: 10 })!
	assert cropped.width == 2 && cropped.height == 2
	assert cropped.raw_bytes() == [u8(15), 16, 17, 18, 19, 20, 27, 28, 29, 30, 31, 32]
	assert !cropped.is_animation()
	assert cropped.animation.loop_count == animation_loop_infinite
	bytes[15] = 100
	assert cropped.raw_bytes()[0] == 15
	assert Box{
		x:      3
		y:      2
		width:  10
		height: 10
	}.clamp(4, 3) == Box{
		x:      3
		y:      2
		width:  1
		height: 1
	}
	assert Box{
		x:      4
		y:      3
		width:  1
		height: 1
	}.clamp(4, 3) == Box{
		x: 4
		y: 3
	}
}

fn test_crop_copies_active_indexed_palette_even_for_empty_crop() {
	mut indexed := IndexedStorage4.init_palette_size(6, 3)
	indexed.indices = [u8(0), 1, 2, 2, 1, 0]
	indexed.palette[1] = Rgba32{
		r: 10
		g: 20
		b: 30
		a: 40
	}
	image := ImageUnmanaged{
		width:  3
		height: 2
		pixels: indexed
	}
	cropped := image.crop(Box{ x: 1, width: 9, height: 2 })!
	assert cropped.width == 2 && cropped.height == 2
	assert cropped.pixel_format() == .indexed4
	assert cropped.raw_bytes() == [u8(1), 2, 1, 0]
	palette := cropped.pixels.get_palette() or { panic('missing palette') }
	assert palette == indexed.palette
	assert palette.data != indexed.palette.data
	indexed.palette[1].r = 90
	assert palette[1].r == 10

	empty := image.crop(Box{ x: 3, width: 2, height: 2 })!
	assert empty.width == 0 && empty.height == 2
	assert empty.raw_bytes().len == 0
	assert (empty.pixels.get_palette() or { panic('missing palette') }) == indexed.palette
}

fn test_crop_16_bit_indices_uses_native_pixel_stride() {
	mut indexed := IndexedStorage16.init_palette_size(6, 257)
	indexed.indices = [u16(0), 256, 1, 1, 0, 256]
	indexed.palette[256] = Rgba32{
		r: 255
		a: 128
	}
	image := ImageUnmanaged{
		width:  3
		height: 2
		pixels: indexed
	}
	cropped := image.crop(Box{ x: 1, width: 2, height: 2 })!
	match cropped.pixels {
		IndexedStorage16 {
			assert cropped.pixels.indices == [u16(256), 1, 0, 256]
			assert cropped.pixels.palette.len == 257
			assert cropped.pixels.palette[256] == Rgba32{
				r: 255
				a: 128
			}
		}
		else {
			assert false
		}
	}
}
