module zigimg

struct IteratorCase {
	pixels   PixelStorage
	expected Colorf32
}

fn test_iterator_normalizes_all_nonindexed_storage_without_premultiplication() {
	gray8 := f32(85) / 255
	gray16 := f32(32768) / 65535
	cases := [
		IteratorCase{Grayscale1Pixels{
			data: [Grayscale1{ value: 1 }]
		}, Colorf32{
			r: 1
			g: 1
			b: 1
		}},
		IteratorCase{Grayscale2Pixels{
			data: [Grayscale2{ value: 1 }]
		}, Colorf32{
			r: f32(1) / 3
			g: f32(1) / 3
			b: f32(1) / 3
		}},
		IteratorCase{Grayscale4Pixels{
			data: [Grayscale4{ value: 5 }]
		}, Colorf32{
			r: f32(5) / 15
			g: f32(5) / 15
			b: f32(5) / 15
		}},
		IteratorCase{Grayscale8Pixels{
			data: [Grayscale8{ value: 85 }]
		}, Colorf32{
			r: gray8
			g: gray8
			b: gray8
		}},
		IteratorCase{Grayscale16Pixels{
			data: [Grayscale16{ value: 32768 }]
		}, Colorf32{
			r: gray16
			g: gray16
			b: gray16
		}},
		IteratorCase{Grayscale8AlphaPixels{
			data: [Grayscale8Alpha{ value: 85, alpha: 0 }]
		}, Colorf32{
			r: gray8
			g: gray8
			b: gray8
			a: 0
		}},
		IteratorCase{Grayscale16AlphaPixels{
			data: [Grayscale16Alpha{ value: 32768, alpha: 16384 }]
		}, Colorf32{
			r: gray16
			g: gray16
			b: gray16
			a: f32(16384) / 65535
		}},
		IteratorCase{Rgb332Pixels{
			data: [Rgb332{ raw: 0b10_011_101 }]
		}, Colorf32{
			r: f32(5) / 7
			g: f32(3) / 7
			b: f32(2) / 3
		}},
		IteratorCase{Rgb555Pixels{
			data: [Rgb555{ raw: (u16(17) << 10) | (9 << 5) | 3 }]
		}, Colorf32{
			r: f32(17) / 31
			g: f32(9) / 31
			b: f32(3) / 31
		}},
		IteratorCase{Bgr555Pixels{
			data: [Bgr555{ raw: (u16(3) << 10) | (9 << 5) | 17 }]
		}, Colorf32{
			r: f32(17) / 31
			g: f32(9) / 31
			b: f32(3) / 31
		}},
		IteratorCase{Rgb565Pixels{
			data: [Rgb565{ raw: (u16(17) << 11) | (35 << 5) | 3 }]
		}, Colorf32{
			r: f32(17) / 31
			g: f32(35) / 63
			b: f32(3) / 31
		}},
		IteratorCase{Rgb24Pixels{
			data: [Rgb24{ r: 255, g: 85, b: 0 }]
		}, Colorf32{
			r: 1
			g: gray8
		}},
		IteratorCase{Rgba32Pixels{
			data: [Rgba32{ r: 255, g: 85, b: 0, a: 0 }]
		}, Colorf32{
			r: 1
			g: gray8
			a: 0
		}},
		IteratorCase{Bgr24Pixels{
			data: [Bgr24{ r: 255, g: 85, b: 0 }]
		}, Colorf32{
			r: 1
			g: gray8
		}},
		IteratorCase{Bgra32Pixels{
			data: [Bgra32{ r: 255, g: 85, b: 0, a: 0 }]
		}, Colorf32{
			r: 1
			g: gray8
			a: 0
		}},
		IteratorCase{Rgb48Pixels{
			data: [Rgb48{ r: 65535, g: 32768, b: 0 }]
		}, Colorf32{
			r: 1
			g: gray16
		}},
		IteratorCase{Rgba64Pixels{
			data: [Rgba64{ r: 65535, g: 32768, b: 0, a: 0 }]
		}, Colorf32{
			r: 1
			g: gray16
			a: 0
		}},
		IteratorCase{Colorf32Pixels{
			data: [Colorf32{ r: -2, g: 3, b: 0.25, a: 0.75 }]
		}, Colorf32{
			r: -2
			g: 3
			b: 0.25
			a: 0.75
		}},
	]
	for case in cases {
		pixels := case.pixels
		mut iter := PixelStorageIterator.init(&pixels)
		assert (iter.next() or { panic('missing pixel') }) == case.expected
		assert iter.current_index == 1
		if _ := iter.next() { assert false
		 }
		assert iter.current_index == 1
	}
}

fn test_indexed_iterator_uses_palette_and_native_indices_for_all_widths() {
	for format in [PixelFormat.indexed1, .indexed2, .indexed4, .indexed8, .indexed16] {
		mut pixels := PixelStorage.init(format, 2)!
		pixels.resize_palette(2)
		mut palette := pixels.get_palette() or { panic('missing palette') }
		palette[0] = Rgba32{
			r: 255
			g: 85
			a: 0
		}
		palette[1] = Rgba32{
			b: 255
			a: 128
		}
		match mut pixels {
			IndexedStorage1 { pixels.indices = [u8(1), 0] }
			IndexedStorage2 { pixels.indices = [u8(1), 0] }
			IndexedStorage4 { pixels.indices = [u8(1), 0] }
			IndexedStorage8 { pixels.indices = [u8(1), 0] }
			IndexedStorage16 { pixels.indices = [u16(1), 0] }
			else { assert false }
		}

		mut iter := PixelStorageIterator.init(&pixels)
		assert (iter.next() or { panic('missing pixel') }) == Colorf32{
			b: 1
			a: f32(128) / 255
		}
		assert (iter.next() or { panic('missing pixel') }) == Colorf32{
			r: 1
			g: f32(85) / 255
			a: 0
		}
		if _ := iter.next() { assert false
		 }
	}
}

fn test_iterator_retains_live_storage_and_captures_only_initial_length() {
	mut pixels := PixelStorage(Rgb24Pixels{
		data: [Rgb24{ r: 1 }, Rgb24{ r: 2 }]
	})
	mut iter := PixelStorageIterator.init(&pixels)
	assert iter.end == 2
	pixels = Colorf32Pixels{
		data: [Colorf32{ g: 0.25 }, Colorf32{ g: 0.5 }, Colorf32{ g: 0.75 }]
	}
	assert (iter.next() or { panic('missing pixel') }) == Colorf32{
		g: 0.25
	}
	assert (iter.next() or { panic('missing pixel') }) == Colorf32{
		g: 0.5
	}
	if _ := iter.next() { assert false
	 }

	mut image := ImageUnmanaged{
		width:     1
		height:    1
		pixels:    pixels
		animation: Animation{
			frames: [
				AnimationFrame{
					pixels:   Rgb24Pixels{
						data: [Rgb24{ r: 255 }]
					}
					duration: 0
				},
			]
		}
	}
	mut image_iter := image.iterator()
	image.pixels = Colorf32Pixels{
		data: [Colorf32{ b: 0.25 }, Colorf32{}, Colorf32{}]
	}
	assert (image_iter.next() or { panic('missing image pixel') }) == Colorf32{
		b: 0.25
	}
	invalid := PixelStorage(InvalidPixels{})
	mut empty := PixelStorageIterator.init(&invalid)
	if _ := empty.next() { assert false
	 }
	// Source's public fields allow an invalid tag with a manually supplied end.
	empty.end = 1
	assert (empty.next() or { panic('missing invalid pixel') }) == Colorf32{}
}

fn test_iterator_copies_keep_independent_cursors_and_borrow_live_elements() {
	mut pixels := PixelStorage(Rgb24Pixels{
		data: [Rgb24{ r: 1 }, Rgb24{ r: 2 }]
	})
	mut iter := PixelStorageIterator.init(&pixels)
	mut copied := iter
	_ = iter.next() or { panic('missing pixel') }
	assert iter.current_index == 1
	assert copied.current_index == 0
	match mut pixels {
		Rgb24Pixels { pixels.data[0].r = 255 }
		else { assert false }
	}

	assert (copied.next() or { panic('missing copied pixel') }).r == 1
	assert iter.current_index == 1 && copied.current_index == 1
}

fn test_iterator_exhaustion_precedes_pointer_access_and_invalid_tag_keeps_wide_cursor() {
	mut empty := PixelStorageIterator{}
	assert empty.next() == none
	empty.current_index = ~uint(0)
	empty.end = ~uint(0)
	assert empty.next() == none
	invalid := PixelStorage(InvalidPixels{})
	mut iter := PixelStorageIterator.init(&invalid)
	iter.current_index = ~uint(0) - 1
	iter.end = ~uint(0)
	assert (iter.next() or { panic('missing invalid pixel') }) == Colorf32{}
	assert iter.current_index == ~uint(0)
	assert iter.next() == none
}
