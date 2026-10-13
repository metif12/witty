module zigimg

import math

interface QuantizerRgbGetter {
	to_u32_rgb() u32
}

interface QuantizerRgb8Getter {
	to_u32_rgb() u8
}

interface QuantizerRgb16Getter {
	to_u32_rgb() u16
}

// Locked OctTreeQuantizer. GC replaces the arena; inline root metadata and
// borrowed child/level pointers retain the source's value-copy behavior.
pub struct OctTreeQuantizer {
pub mut:
	root_node OctTreeNode
	levels    [8]&OctTreeNode
}

pub fn OctTreeQuantizer.init() OctTreeQuantizer {
	mut result := OctTreeQuantizer{}
	result.root_node.init(0, mut result)
	return result
}

pub fn (quantizer &OctTreeQuantizer) deinit() {
	_ = quantizer
}

pub fn (quantizer &OctTreeQuantizer) allocate_node() !&OctTreeNode {
	_ = quantizer
	return &OctTreeNode{}
}

pub fn (mut quantizer OctTreeQuantizer) add_level_node(level i32, mut node OctTreeNode) {
	if level < 0 { panic('integer does not fit in destination type') }
	if level >= 8 { panic('index out of bounds: index ${level}, len 8') }
	node.level_next = quantizer.levels[level]
	quantizer.levels[level] = unsafe { &node }
}

pub fn (mut quantizer OctTreeQuantizer) add_color[T](color T) ! {
	quantizer.root_node.add_color(color, 0, mut quantizer)!
}

pub fn (quantizer &OctTreeQuantizer) get_palette_index[T](color T) !usize {
	return quantizer.root_node.get_palette_index(color, 0)
}

pub fn (mut quantizer OctTreeQuantizer) make_palette(color_count u32, mut palette []Rgba32) []Rgba32 {
	mut leaf_count := quantizer.root_node.count_leaf_nodes()
	mut level := 7
	for level > 0 {
		mut node := quantizer.levels[level]
		for node != unsafe { nil } {
			removed := node.remove_leaves()
			// @intCast(i32 -> usize), followed by checked unsigned subtraction.
			if removed < 0 { panic('integer does not fit in destination type') }
			if usize(removed) > leaf_count { panic('integer overflow') }
			leaf_count -= usize(removed)
			if leaf_count <= usize(color_count) {
				break
			}
			node = node.level_next
		}
		if leaf_count <= usize(color_count) {
			break
		}
		level--
	}
	mut context := OctTreePaletteContext{
		palette:     unsafe { palette }
		color_count: color_count
	}
	quantizer.root_node.make_palette(mut context)
	return unsafe { palette[..int(context.palette_index)] }
}

pub struct OctTreePaletteContext {
pub mut:
	palette       []Rgba32 @[required]
	palette_index u32
	color_count   u32
}

pub struct OctTreeNode {
pub mut:
	red             u32
	green           u32
	blue            u32
	reference_count u32
	palette_index   u32
	children        [8]&OctTreeNode
	level_next      &OctTreeNode = unsafe { nil }
}

pub fn (mut node OctTreeNode) init(level i32, mut parent OctTreeQuantizer) {
	node = OctTreeNode{}
	if level < 7 { parent.add_level_node(level, mut node) }
}

pub fn (node &OctTreeNode) is_leaf() bool {
	return node.reference_count > 0
}

pub fn (node &OctTreeNode) get_color() Rgba32 {
	if node.reference_count == 0 { panic('division by zero') }
	red := node.red / node.reference_count
	green := node.green / node.reference_count
	blue := node.blue / node.reference_count
	if red > 255 || green > 255 || blue > 255 { panic('integer does not fit in destination type') }
	return Rgba32{
		r: u8(red)
		g: u8(green)
		b: u8(blue)
	}
}

pub fn (mut node OctTreeNode) add_color[T](color T, level i32, mut parent OctTreeQuantizer) ! {
	$if T.unaliased_typ is Rgb24 || T.unaliased_typ is Bgr24 || T.unaliased_typ is Rgb48
		|| T.unaliased_typ is Rgb332 || T.unaliased_typ is Rgb555 || T.unaliased_typ is Bgr555
		|| T.unaliased_typ is Rgb565 || T.unaliased_typ is Rgba32 || T.unaliased_typ is Bgra32
		|| T.unaliased_typ is Rgba64 || T.unaliased_typ is Colorf32 {
		node.add_rgb(quantizer_rgb24(color), level, mut parent)!
	} $else {
		if level >= 8 {
			node.add_rgb(quantizer_rgb24(color), level, mut parent)!
			return
		}
		// Source evaluates custom getters at each level, including the leaf.
		index := OctTreeNode.get_color_index(color, level)
		if index >= 8 { return error('InvalidColorIndex') }
		mut child := node.children[index]
		if child != unsafe { nil } {
			child.add_color(color, level + 1, mut parent)!
		} else {
			child = parent.allocate_node()!
			child.init(level, mut parent)
			child.add_color(color, level + 1, mut parent)!
			node.children[index] = child
		}
	}
}

fn (mut node OctTreeNode) add_rgb(color Rgb24, level i32, mut parent OctTreeQuantizer) ! {
	if level >= 8 {
		if node.red > 0xffffffff - u32(color.r) { panic('integer overflow') }
		node.red += color.r
		if node.green > 0xffffffff - u32(color.g) { panic('integer overflow') }
		node.green += color.g
		if node.blue > 0xffffffff - u32(color.b) { panic('integer overflow') }
		node.blue += color.b
		if node.reference_count == 0xffffffff { panic('integer overflow') }
		node.reference_count++
		return
	}
	index := OctTreeNode.get_color_index(color, level)
	if index >= 8 { return error('InvalidColorIndex') }
	mut child := node.children[index]
	if child != unsafe { nil } {
		child.add_rgb(color, level + 1, mut parent)!
	} else {
		child = parent.allocate_node()!
		// Source registers the child with the current level, not level + 1.
		child.init(level, mut parent)
		child.add_rgb(color, level + 1, mut parent)!
		node.children[index] = child
	}
}

pub fn (node &OctTreeNode) get_palette_index[T](color T, level i32) !usize {
	if node.is_leaf() { return usize(node.palette_index) }
	$if T.unaliased_typ is Rgb24 || T.unaliased_typ is Bgr24 || T.unaliased_typ is Rgb48
		|| T.unaliased_typ is Rgb332 || T.unaliased_typ is Rgb555 || T.unaliased_typ is Bgr555
		|| T.unaliased_typ is Rgb565 || T.unaliased_typ is Rgba32 || T.unaliased_typ is Bgra32
		|| T.unaliased_typ is Rgba64 || T.unaliased_typ is Colorf32 {
		return node.get_rgb_index(quantizer_rgb24(color), level)
	} $else {
		index := OctTreeNode.get_color_index(color, level)
		child := node.children[index]
		if child != unsafe { nil } { return child.get_palette_index(color, level + 1) }
		for alternative in node.children {
			if alternative != unsafe { nil } {
				return alternative.get_palette_index(color, level + 1)
			}
		}
		return error('ColorNotFound')
	}
}

fn (node &OctTreeNode) get_rgb_index(color Rgb24, level i32) !usize {
	if node.is_leaf() { return usize(node.palette_index) }
	index := OctTreeNode.get_color_index(color, level)
	child := node.children[index]
	if child != unsafe { nil } { return child.get_rgb_index(color, level + 1) }
	for alternative in node.children {
		if alternative != unsafe { nil } { return alternative.get_rgb_index(color, level + 1) }
	}
	return error('ColorNotFound')
}

pub fn (node &OctTreeNode) count_leaf_nodes() usize {
	if node.is_leaf() { return 1 }
	mut count := usize(0)
	for child in node.children {
		if child != unsafe { nil } {
			child_count := child.count_leaf_nodes()
			if child_count > ~usize(0) - count { panic('integer overflow') }
			count += child_count
		}
	}
	return count
}

pub fn (mut node OctTreeNode) make_palette(mut context OctTreePaletteContext) {
	if node.is_leaf() {
		if context.palette_index >= context.color_count { return }
		if usize(context.palette_index) >= usize(context.palette.len) {
			panic('index out of bounds: index ${context.palette_index}, len ${context.palette.len}')
		}
		context.palette[context.palette_index] = node.get_color()
		node.palette_index = context.palette_index
		context.palette_index++
	}
	for index in 0 .. 8 {
		mut child := node.children[index]
		if child != unsafe { nil } { child.make_palette(mut context) }
	}
}

pub fn (mut node OctTreeNode) remove_leaves() i32 {
	mut removed := i32(0)
	for index, child in node.children {
		if child != unsafe { nil } {
			// These additions deliberately wrap, unlike addColor's accumulation.
			node.red += child.red
			node.green += child.green
			node.blue += child.blue
			node.reference_count += child.reference_count
			removed++
			node.children[index] = unsafe { nil }
		}
	}
	return removed - 1
}

fn OctTreeNode.get_color_index[T](color T, level i32) usize {
	rgb := quantizer_rgb24(color)
	if level < 0 || level >= 8 { panic('integer does not fit in destination type') }
	mask := u8(128 >> level)
	mut index := usize(0)
	if rgb.r & mask != 0 { index |= 4 }
	if rgb.g & mask != 0 { index |= 2 }
	if rgb.b & mask != 0 { index |= 1 }
	return index
}

// ScaleValue's f32 multiply/round/clamp. Zig min/max ignore NaN, so a NaN
// channel selects the upper limit. Keep intermediate products at f32 width.
fn quantizer_scale_float(value f32, maximum u32) u32 {
	scaled := value * f32(maximum)
	if scaled < 0 { return 0 }
	if !(scaled <= f32(maximum)) { return maximum }
	return u32(math.round(f64(scaled)))
}

fn quantizer_scale_small(value u16, bits u8) u8 {
	maximum := (u32(1) << bits) - 1
	if u32(value) > maximum { panic('quantizer packed component out of range') }
	return u8((u32(value) * 255 + maximum / 2) / maximum)
}

fn quantizer_premultiplied_rgb24[T](color T) Rgb24 {
	return Rgb24.from_u32_rgba(color.to_u32_rgba())
}

fn quantizer_require_alpha_field[T](color T) {
	_ = color.a
}

fn quantizer_rgb24[T](color T) Rgb24 {
	$if T.unaliased_typ is Rgb24 {
		return Rgb24(color)
	} $else $if T.unaliased_typ is Bgr24 {
		return Rgb24{
			r: color.r
			g: color.g
			b: color.b
		}
	} $else $if T.unaliased_typ is Rgb48 {
		return Rgb24{
			r: u8(color.r >> 8)
			g: u8(color.g >> 8)
			b: u8(color.b >> 8)
		}
	} $else $if T.unaliased_typ is Rgb332 {
		return Rgb24{
			r: quantizer_scale_small(u16(color.raw & 7), 3)
			g: quantizer_scale_small(u16((color.raw >> 3) & 7), 3)
			b: quantizer_scale_small(u16(color.raw >> 6), 2)
		}
	} $else $if T.unaliased_typ is Rgb555 {
		return Rgb24{
			r: quantizer_scale_small((color.raw >> 10) & 31, 5)
			g: quantizer_scale_small((color.raw >> 5) & 31, 5)
			b: quantizer_scale_small(color.raw & 31, 5)
		}
	} $else $if T.unaliased_typ is Bgr555 {
		return Rgb24{
			r: quantizer_scale_small(color.raw & 31, 5)
			g: quantizer_scale_small((color.raw >> 5) & 31, 5)
			b: quantizer_scale_small((color.raw >> 10) & 31, 5)
		}
	} $else $if T.unaliased_typ is Rgb565 {
		return Rgb24{
			r: quantizer_scale_small(color.raw >> 11, 5)
			g: quantizer_scale_small((color.raw >> 5) & 63, 6)
			b: quantizer_scale_small(color.raw & 31, 5)
		}
	} $else $if T.unaliased_typ is Rgba32 || T.unaliased_typ is Bgra32 {
		alpha := f32(color.a) / 255
		return Rgb24{
			r: u8(quantizer_scale_float(f32(color.r) / 255 * alpha, 255))
			g: u8(quantizer_scale_float(f32(color.g) / 255 * alpha, 255))
			b: u8(quantizer_scale_float(f32(color.b) / 255 * alpha, 255))
		}
	} $else $if T.unaliased_typ is Rgba64 {
		alpha := f32(color.a) / 65535
		return Rgb24{
			r: u8(quantizer_scale_float(f32(color.r) / 65535 * alpha, 65535) >> 8)
			g: u8(quantizer_scale_float(f32(color.g) / 65535 * alpha, 65535) >> 8)
			b: u8(quantizer_scale_float(f32(color.b) / 65535 * alpha, 65535) >> 8)
		}
	} $else $if T.unaliased_typ is Colorf32 {
		return Rgb24{
			r: u8(quantizer_scale_float(color.r * color.a, 255))
			g: u8(quantizer_scale_float(color.g * color.a, 255))
			b: u8(quantizer_scale_float(color.b * color.a, 255))
		}
	} $else {
		$for field in T.fields {
			$if field.name == 'a' {
				premultiplied := color.premultiplied_alpha()
				return quantizer_premultiplied_rgb24(premultiplied)
			}
		}
		// V receiver methods represent Source's zero-sized .to namespace.
		$if T is QuantizerRgbGetter || T is QuantizerRgb8Getter || T is QuantizerRgb16Getter {
			return Rgb24.from_u32_rgb(color.to_u32_rgb())
		} $else {
			// The alpha field branch above returns for valid alpha colors.
			// Reject records that provide neither represented color protocol.
			quantizer_require_alpha_field(color)
		}
	}
	return Rgb24{}
}
