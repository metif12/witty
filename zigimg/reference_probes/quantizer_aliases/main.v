module main

import math
import zigimg

type AliasRgb24 = zigimg.Rgb24
type AliasBgr24 = zigimg.Bgr24
type AliasRgb48 = zigimg.Rgb48
type AliasRgb332 = zigimg.Rgb332
type AliasRgb555 = zigimg.Rgb555
type AliasBgr555 = zigimg.Bgr555
type AliasRgb565 = zigimg.Rgb565
type AliasRgba32 = zigimg.Rgba32
type AliasBgra32 = zigimg.Bgra32
type AliasRgba64 = zigimg.Rgba64
type AliasColorf32 = zigimg.Colorf32

fn emit[T](kind int, sample int, color T) ! {
	mut quantizer := zigimg.OctTreeQuantizer.init()
	defer { quantizer.deinit() }
	quantizer.add_color(color)!
	quantizer.add_color(color)!
	mut storage := []zigimg.Rgba32{len: 256}
	palette := quantizer.make_palette(256, mut storage)
	value := palette[0]
	index := quantizer.get_palette_index(color)!
	root_index := quantizer.root_node.get_palette_index(color, 0)!
	mut node := zigimg.OctTreeNode{}
	node.add_color(color, 8, mut quantizer)!
	node.add_color(color, 100, mut quantizer)!
	average := node.get_color()
	leaf_index := node.get_palette_index(color, 100)!
	println('${kind},${sample},${palette.len},${value.r},${value.g},${value.b},${value.a},${index},${root_index},${average.r},${average.g},${average.b},${average.a},${node.reference_count},${leaf_index},${node.count_leaf_nodes()}')
}

fn sample16(value u8, offset u32) u16 {
	result := u32(value) * 257 + offset
	return u16(if result > 65535 { 65535 } else { result })
}

fn main() {
	for sample in 0 .. 256 {
		r := u8(sample)
		g := u8(sample * 7)
		b := u8(sample * 13)
		a := u8(sample * 31)
		emit(0, sample, AliasRgb24{ r: r, g: g, b: b }) or { panic(err) }
		emit(1, sample, AliasBgr24{ r: r, g: g, b: b }) or { panic(err) }
		emit(2, sample, AliasRgb48{ r: sample16(r, 13), g: sample16(g, 17), b: sample16(b, 19) }) or { panic(err) }
		emit(3, sample, AliasRgb332{ raw: (r & 7) | (g & 7) << 3 | (b & 3) << 6 }) or { panic(err) }
		emit(4, sample, AliasRgb555{ raw: u16(r & 31) << 10 | u16(g & 31) << 5 | u16(b & 31) }) or { panic(err) }
		emit(5, sample, AliasBgr555{ raw: u16(b & 31) << 10 | u16(g & 31) << 5 | u16(r & 31) }) or { panic(err) }
		emit(6, sample, AliasRgb565{ raw: u16(r & 31) << 11 | u16(g & 63) << 5 | u16(b & 31) }) or { panic(err) }
		emit(7, sample, AliasRgba32{ r: r, g: g, b: b, a: a }) or { panic(err) }
		emit(8, sample, AliasBgra32{ r: r, g: g, b: b, a: a }) or { panic(err) }
		emit(9, sample, AliasRgba64{ r: sample16(r, 13), g: sample16(g, 17), b: sample16(b, 19), a: sample16(a, 23) }) or { panic(err) }
		float_color := match sample {
			254 { AliasColorf32{ r: -2, g: f32(math.nan()), b: f32(math.inf(1)), a: 1 } }
			255 { AliasColorf32{ r: f32(math.inf(-1)), g: 0.5, b: 2, a: 0 } }
			else { AliasColorf32{ r: f32(r) / 255, g: f32(g) / 255, b: f32(b) / 255, a: f32(a) / 255 } }
		}
		emit(10, sample, float_color) or { panic(err) }
	}
}
