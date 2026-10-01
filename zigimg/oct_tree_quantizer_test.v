module zigimg

import math

fn test_quantizer_primary_palette_order_missing_color_fallback_and_borrowed_output() {
	mut quantizer := OctTreeQuantizer.init()
	if _ := quantizer.get_palette_index(Rgb24{}) {
		assert false
	} else {
		assert err.msg() == 'ColorNotFound'
	}
	colors := [Rgb24{ r: 255 }, Rgb24{ g: 255 }, Rgb24{ b: 255 }]
	for color in colors {
		quantizer.add_color(color)!
	}
	assert quantizer.root_node.count_leaf_nodes() == 3
	mut storage := []Rgba32{len: 256, init: Rgba32{
		r: 17
		g: 18
		b: 19
	}}
	mut palette := quantizer.make_palette(256, mut storage)
	assert palette == [Rgba32{ b: 255 }, Rgba32{ g: 255 }, Rgba32{ r: 255 }]
	for i, color in colors {
		assert quantizer.get_palette_index(color)! == usize(2 - i)
	}
	assert quantizer.get_palette_index(Rgb24{})! == 0
	assert storage[3] == Rgba32{
		r: 17
		g: 18
		b: 19
	}
	palette[0].r = 11
	assert storage[0].r == 11
	quantizer.deinit()
}

fn test_quantizer_reduction_weighted_average_and_zero_budget() {
	mut quantizer := OctTreeQuantizer.init()
	quantizer.add_color(Rgb24{ r: 10, g: 20, b: 30 })!
	quantizer.add_color(Rgb24{ r: 11, g: 21, b: 31 })!
	quantizer.add_color(Rgb24{ r: 11, g: 21, b: 31 })!
	mut storage := []Rgba32{len: 256}
	assert quantizer.make_palette(1, mut storage) == [Rgba32{ r: 10, g: 20, b: 30 }]
	assert quantizer.root_node.count_leaf_nodes() == 1
	assert quantizer.get_palette_index(Rgb24{ r: 11, g: 21, b: 31 })! == 0
	mut zero := OctTreeQuantizer.init()
	zero.add_color(Rgb24{ r: 128, g: 64, b: 32 })!
	assert zero.make_palette(0, mut storage).len == 0
	assert zero.get_palette_index(Rgb24{ r: 128, g: 64, b: 32 })! == 0
	mut empty := OctTreeQuantizer.init()
	assert empty.make_palette(256, mut storage).len == 0
}

fn quantizer_expect_normalized[T](color T, expected Rgba32) ! {
	mut quantizer := OctTreeQuantizer.init()
	quantizer.add_color(color)!
	mut storage := []Rgba32{len: 256}
	assert quantizer.make_palette(256, mut storage) == [expected]
	assert quantizer.get_palette_index(color)! == 0
}

fn test_quantizer_all_color_storage_types_alpha_round_trip_and_float_limits() {
	quantizer_expect_normalized(Rgb24{ r: 1, g: 2, b: 3 }, Rgba32{
		r: 1
		g: 2
		b: 3
	})!
	quantizer_expect_normalized(Bgr24{ r: 1, g: 2, b: 3 }, Rgba32{
		r: 1
		g: 2
		b: 3
	})!
	quantizer_expect_normalized(Rgba32{ r: 101, g: 151, b: 201, a: 128 }, Rgba32{
		r: 51
		g: 76
		b: 101
	})!
	quantizer_expect_normalized(Bgra32{ r: 101, g: 151, b: 201, a: 128 }, Rgba32{
		r: 51
		g: 76
		b: 101
	})!
	quantizer_expect_normalized(Rgba64{ r: 32768, g: 12345, b: 65535, a: 32768 }, Rgba32{
		r: 64
		g: 24
		b: 128
	})!
	quantizer_expect_normalized(Colorf32{ r: 0.5, g: 0.25, b: 2, a: 0.5 }, Rgba32{
		r: 64
		g: 32
		b: 255
	})!
	quantizer_expect_normalized(Colorf32{ r: -2, g: f32(math.nan()), b: f32(math.inf(1)), a: 1 }, Rgba32{
		r: 0
		g: 255
		b: 255
	})!
	quantizer_expect_normalized(Rgb332{ raw: 5 | 3 << 3 | 2 << 6 }, Rgba32{
		r: 182
		g: 109
		b: 170
	})!
	quantizer_expect_normalized(Rgb555{ raw: 17 << 10 | 9 << 5 | 3 }, Rgba32{
		r: 140
		g: 74
		b: 25
	})!
	quantizer_expect_normalized(Bgr555{ raw: 3 << 10 | 9 << 5 | 17 }, Rgba32{
		r: 140
		g: 74
		b: 25
	})!
	quantizer_expect_normalized(Rgb565{ raw: 17 << 11 | 33 << 5 | 3 }, Rgba32{
		r: 140
		g: 134
		b: 25
	})!
	quantizer_expect_normalized(Rgb48{ r: 0x1234, g: 0x5678, b: 0x9abc }, Rgba32{
		r: 0x12
		g: 0x56
		b: 0x9a
	})!
	quantizer_expect_normalized(Rgba32{ r: 255, g: 255, b: 255, a: 0 }, Rgba32{})!
}

fn test_quantizer_node_registration_floor_averaging_wrap_and_default_indices() {
	mut quantizer := OctTreeQuantizer.init()
	mut first := quantizer.allocate_node()!
	first.init(2, mut quantizer)
	mut second := quantizer.allocate_node()!
	second.init(2, mut quantizer)
	assert voidptr(quantizer.levels[2]) == voidptr(second)
		&& voidptr(second.level_next) == voidptr(first)
	mut children := OctTreeNode{
		red:             0xffffffff
		green:           3
		blue:            5
		reference_count: 1
	}
	children.children[0] = &OctTreeNode{
		red:             2
		green:           10
		blue:            20
		reference_count: 1
	}
	children.children[7] = &OctTreeNode{
		red:             3
		green:           20
		blue:            30
		reference_count: 1
	}
	assert children.remove_leaves() == 1
	assert children.red == 4 && children.green == 33 && children.blue == 55
		&& children.reference_count == 3
	assert children.is_leaf() && children.count_leaf_nodes() == 1
	assert children.get_color() == Rgba32{
		r: 1
		g: 11
		b: 18
	}
	for child in children.children {
		assert voidptr(child) == unsafe { nil }
	}
	assert children.remove_leaves() == -1
	mut storage := []Rgba32{len: 2}
	mut context := OctTreePaletteContext{
		palette:       unsafe { storage }
		color_count:   2
		palette_index: 1
	}
	children.make_palette(mut context)
	assert context.palette_index == 2 && children.palette_index == 1
	assert storage[1] == Rgba32{
		r: 1
		g: 11
		b: 18
	}
	assert children.get_palette_index(Rgb24{ r: 200 }, 100)! == 1 // A leaf ignores the level/color.
	for level in 0 .. 8 {
		assert OctTreeNode.get_color_index(Rgb24{ r: u8(128 >> level), b: u8(128 >> level) },
			i32(level)) == 5
	}
}

fn quantizer_test_word_hash(current u64, value usize) u64 {
	mut hash := current
	mut word := u64(value)
	for _ in 0 .. 8 {
		hash ^= u8(word)
		hash *= 1099511628211
		word >>= 8
	}
	return hash
}

fn quantizer_test_sample(pattern int, i int) Rgba32 {
	value := match pattern {
		0 { 7 }
		1 { i }
		2 { i * 13 }
		else { i / 7 * 17 }
	}

	return Rgba32{
		r: u8(value)
		g: u8(value * 7)
		b: u8(value * 13)
		a: u8(i * 31)
	}
}

fn quantizer_test_sample64(color Rgba32) Rgba64 {
	red := u32(color.r) * 257 + 13
	green := u32(color.g) * 257 + 17
	blue := u32(color.b) * 257 + 19
	alpha := u32(color.a) * 257 + 23
	return Rgba64{
		r: u16(if red > 65535 { 65535 } else { red })
		g: u16(if green > 65535 { 65535 } else { green })
		b: u16(if blue > 65535 { 65535 } else { blue })
		a: u16(if alpha > 65535 { 65535 } else { alpha })
	}
}

fn quantizer_test_add(mut quantizer OctTreeQuantizer, kind int, pattern int, i int) ! {
	color := quantizer_test_sample(pattern, i)
	match kind {
		0 {
			quantizer.add_color(Rgb24{ r: color.r, g: color.g, b: color.b })!
		}
		1 {
			quantizer.add_color(color)!
		}
		2 {
			quantizer.add_color(Bgra32{ r: color.r, g: color.g, b: color.b, a: color.a })!
		}
		3 {
			quantizer.add_color(quantizer_test_sample64(color))!
		}
		4 {
			quantizer.add_color(color.to_colorf32())!
		}
		5 {
			quantizer.add_color(Rgb565{
				raw: u16(color.r & 31) << 11 | u16(color.g & 63) << 5 | u16(color.b & 31)
			})!
		}
		else {
			assert false
		}
	}
}

fn quantizer_test_find(quantizer &OctTreeQuantizer, kind int, pattern int, i int) !usize {
	color := quantizer_test_sample(pattern, i)
	return match kind {
		0 {
			quantizer.get_palette_index(Rgb24{ r: color.r, g: color.g, b: color.b })!
		}
		1 {
			quantizer.get_palette_index(color)!
		}
		2 {
			quantizer.get_palette_index(Bgra32{ r: color.r, g: color.g, b: color.b, a: color.a })!
		}
		3 {
			quantizer.get_palette_index(quantizer_test_sample64(color))!
		}
		4 {
			quantizer.get_palette_index(color.to_colorf32())!
		}
		5 {
			quantizer.get_palette_index(Rgb565{
				raw: u16(color.r & 31) << 11 | u16(color.g & 63) << 5 | u16(color.b & 31)
			})!
		}
		else {
			usize(0)
		}
	}
}

fn test_quantizer_native_hash_of_palettes_indices_and_tree_counts() {
	mut hash := u64(14695981039346656037)
	mut cases := 0
	for kind in 0 .. 6 {
		for pattern in 0 .. 4 {
			for count in [u32(0), 1, 2, 4, 8, 16, 32, 64, 255, 256] {
				for length in [0, 1, 2, 3, 8, 17, 63, 129, 257] {
					mut quantizer := OctTreeQuantizer.init()
					for i in 0 .. length {
						quantizer_test_add(mut quantizer, kind, pattern, i)!
					}
					hash = quantizer_test_word_hash(hash, quantizer.root_node.count_leaf_nodes())
					mut storage := []Rgba32{len: 256, init: Rgba32{
						r: 17
						g: 18
						b: 19
					}}
					palette := quantizer.make_palette(count, mut storage)
					hash = quantizer_test_word_hash(hash, usize(palette.len))
					for color in palette {
						for byte in [color.r, color.g, color.b, color.a] {
							hash ^= byte
							hash *= 1099511628211
						}
					}
					hash = quantizer_test_word_hash(hash, quantizer.root_node.count_leaf_nodes())
					for i in 0 .. length {
						hash = quantizer_test_word_hash(hash, quantizer_test_find(&quantizer, kind,
							pattern, i)!)
					}
					if length > 0 {
						hash = quantizer_test_word_hash(hash, quantizer.get_palette_index(Rgb24{
							r: 31
							g: 63
							b: 95
						})!)
						hash = quantizer_test_word_hash(hash, quantizer.get_palette_index(Rgba32{
							r: 200
							g: 100
							b: 50
							a: 17
						})!)
					}
					cases++
				}
			}
		}
	}
	assert cases == 2160
	assert hash == u64(0xfb25faff7d5b5837)
}

fn quantizer_test_normalization_hash[T](mut quantizer OctTreeQuantizer, current u64, color T) !u64 {
	quantizer.root_node.init(8, mut quantizer)
	quantizer.root_node.add_color(color, 8, mut quantizer)!
	value := quantizer.root_node.get_color()
	mut hash := current
	for byte in [value.r, value.g, value.b, value.a] {
		hash ^= byte
		hash *= 1099511628211
	}
	return hash
}

fn test_quantizer_normalization_hash_full_packed_ranges_and_alpha_values() {
	mut quantizer := OctTreeQuantizer.init()
	mut hash := u64(14695981039346656037)
	mut cases := 0
	for i in 0 .. 65536 {
		red := u8(i >> 8)
		alpha := u8(i)
		color := Rgba32{
			r: red
			g: alpha
			b: u8(i * 13)
			a: alpha
		}
		hash = quantizer_test_normalization_hash(mut quantizer, hash, color)!
		hash = quantizer_test_normalization_hash(mut quantizer, hash, Bgra32{
			r: color.r
			g: color.g
			b: color.b
			a: color.a
		})!
		hash = quantizer_test_normalization_hash(mut quantizer, hash, Rgba64{
			r: u16(i)
			g: u16(i * 13)
			b: u16(i * 29)
			a: u16(i * 17 + 11)
		})!
		hash = quantizer_test_normalization_hash(mut quantizer, hash, Rgb565{ raw: u16(i) })!
		cases += 4
	}
	for i in 0 .. 32768 {
		hash = quantizer_test_normalization_hash(mut quantizer, hash, Rgb555{ raw: u16(i) })!
		hash = quantizer_test_normalization_hash(mut quantizer, hash, Bgr555{ raw: u16(i) })!
		cases += 2
	}
	for i in 0 .. 256 {
		hash = quantizer_test_normalization_hash(mut quantizer, hash, Rgb332{ raw: u8(i) })!
		cases++
	}
	mut random := u32(0x12345678)
	for _ in 0 .. 8192 {
		random ^= random << 13
		random ^= random >> 17
		random ^= random << 5
		red := unsafe { *(&f32(&random)) }
		random ^= random << 13
		random ^= random >> 17
		random ^= random << 5
		green := unsafe { *(&f32(&random)) }
		random ^= random << 13
		random ^= random >> 17
		random ^= random << 5
		blue := unsafe { *(&f32(&random)) }
		random ^= random << 13
		random ^= random >> 17
		random ^= random << 5
		alpha := unsafe { *(&f32(&random)) }
		hash = quantizer_test_normalization_hash(mut quantizer, hash, Colorf32{
			r: red
			g: green
			b: blue
			a: alpha
		})!
		cases++
	}
	assert cases == 336128
	assert hash == u64(0x2e3cf0cdc340afc4)
}
