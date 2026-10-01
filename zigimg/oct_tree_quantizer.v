module zigimg

import math

// Locked OctTreeQuantizer. GC replaces the arena; the root has a stable heap
// address rather than the source's inline field. Lists retain source ordering.
pub struct OctTreeQuantizer {
pub mut:
	root_node &OctTreeNode = unsafe { nil }
	levels    [8]&OctTreeNode
}

pub fn OctTreeQuantizer.init() OctTreeQuantizer {
	mut result := OctTreeQuantizer{
		root_node: &OctTreeNode{}
	}
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
	assert level >= 0 && level < 8
	node.level_next = quantizer.levels[level]
	quantizer.levels[level] = unsafe { &node }
}

pub fn (mut quantizer OctTreeQuantizer) add_color[T](color T) ! {
	quantizer.root_node.add_rgb(quantizer_rgb24(color), 0, mut quantizer)!
}

pub fn (quantizer &OctTreeQuantizer) get_palette_index[T](color T) !usize {
	if quantizer.root_node.is_leaf() { return usize(quantizer.root_node.palette_index) }
	return quantizer.root_node.get_rgb_index(quantizer_rgb24(color), 0)
}

pub fn (mut quantizer OctTreeQuantizer) make_palette(color_count u32, mut palette []Rgba32) []Rgba32 {
	mut leaf_count := quantizer.root_node.count_leaf_nodes()
	mut level := 7
	for level > 0 {
		mut node := quantizer.levels[level]
		for node != unsafe { nil } {
			removed := node.remove_leaves()
			// @intCast(i32 -> usize), followed by checked unsigned subtraction.
			assert removed >= 0 && usize(removed) <= leaf_count
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
	palette       []Rgba32
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
	assert node.reference_count != 0
	red := node.red / node.reference_count
	green := node.green / node.reference_count
	blue := node.blue / node.reference_count
	assert red <= 255 && green <= 255 && blue <= 255
	return Rgba32{
		r: u8(red)
		g: u8(green)
		b: u8(blue)
	}
}

pub fn (mut node OctTreeNode) add_color[T](color T, level i32, mut parent OctTreeQuantizer) ! {
	node.add_rgb(quantizer_rgb24(color), level, mut parent)!
}

fn (mut node OctTreeNode) add_rgb(color Rgb24, level i32, mut parent OctTreeQuantizer) ! {
	if level >= 8 {
		assert node.red <= 0xffffffff - u32(color.r)
		node.red += color.r
		assert node.green <= 0xffffffff - u32(color.g)
		node.green += color.g
		assert node.blue <= 0xffffffff - u32(color.b)
		node.blue += color.b
		assert node.reference_count != 0xffffffff
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
	return node.get_rgb_index(quantizer_rgb24(color), level)
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
		if child != unsafe { nil } { count += child.count_leaf_nodes() }
	}
	return count
}

pub fn (mut node OctTreeNode) make_palette(mut context OctTreePaletteContext) {
	if node.is_leaf() {
		if context.palette_index >= context.color_count { return }
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
	assert level >= 0 && level < 8
	rgb := quantizer_rgb24(color)
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
	assert u32(value) <= maximum
	return u8((u32(value) * 255 + maximum / 2) / maximum)
}

fn quantizer_rgb24[T](color T) Rgb24 {
	$if T is Rgb24 {
		return color
	} $else $if T is Bgr24 {
		return Rgb24{
			r: color.r
			g: color.g
			b: color.b
		}
	} $else $if T is Rgb48 {
		return Rgb24{
			r: u8(color.r >> 8)
			g: u8(color.g >> 8)
			b: u8(color.b >> 8)
		}
	} $else $if T is Rgb332 {
		return Rgb24{
			r: quantizer_scale_small(u16(color.raw & 7), 3)
			g: quantizer_scale_small(u16((color.raw >> 3) & 7), 3)
			b: quantizer_scale_small(u16(color.raw >> 6), 2)
		}
	} $else $if T is Rgb555 {
		return Rgb24{
			r: quantizer_scale_small((color.raw >> 10) & 31, 5)
			g: quantizer_scale_small((color.raw >> 5) & 31, 5)
			b: quantizer_scale_small(color.raw & 31, 5)
		}
	} $else $if T is Bgr555 {
		return Rgb24{
			r: quantizer_scale_small(color.raw & 31, 5)
			g: quantizer_scale_small((color.raw >> 5) & 31, 5)
			b: quantizer_scale_small((color.raw >> 10) & 31, 5)
		}
	} $else $if T is Rgb565 {
		return Rgb24{
			r: quantizer_scale_small(color.raw >> 11, 5)
			g: quantizer_scale_small((color.raw >> 5) & 63, 6)
			b: quantizer_scale_small(color.raw & 31, 5)
		}
	} $else $if T is Rgba32 || T is Bgra32 {
		alpha := f32(color.a) / 255
		return Rgb24{
			r: u8(quantizer_scale_float(f32(color.r) / 255 * alpha, 255))
			g: u8(quantizer_scale_float(f32(color.g) / 255 * alpha, 255))
			b: u8(quantizer_scale_float(f32(color.b) / 255 * alpha, 255))
		}
	} $else $if T is Rgba64 {
		alpha := f32(color.a) / 65535
		return Rgb24{
			r: u8(quantizer_scale_float(f32(color.r) / 65535 * alpha, 65535) >> 8)
			g: u8(quantizer_scale_float(f32(color.g) / 65535 * alpha, 65535) >> 8)
			b: u8(quantizer_scale_float(f32(color.b) / 65535 * alpha, 65535) >> 8)
		}
	} $else $if T is Colorf32 {
		return Rgb24{
			r: u8(quantizer_scale_float(color.r * color.a, 255))
			g: u8(quantizer_scale_float(color.g * color.a, 255))
			b: u8(quantizer_scale_float(color.b * color.a, 255))
		}
	} $else {
		$compile_error('Quantizer colors must have the pinned RGB(A) color surface')
	}
	return Rgb24{}
}
