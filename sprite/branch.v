module sprite

// --- Original Ghostty Comments Start: src/font/sprite/draw/branch.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/font/sprite/draw/branch.zig
//
// Branch Drawing Characters | U+F5D0...U+F60D
//
// Branch drawing character set, used for drawing git-like
// graphs in the terminal. Originally implemented in Kitty.
// Ref:
// - https://github.com/kovidgoyal/kitty/pull/7681
// - https://github.com/kovidgoyal/kitty/pull/7805
// NOTE: Kitty is GPL licensed, and its code was not referenced
//       for these characters, only the loose specification of
//       the character set in the pull request descriptions.
//
//                
//                
//                
//              
//
// Specification of a branch drawing node, which consists of a
// circle which is either empty or filled, and lines connecting
// optionally between the circle and each of the 4 edges.
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// ''
// Top of horizontal strokes
// Bottom of horizontal strokes
// Left of vertical strokes
// Right of vertical strokes
// We calculate the center of the circle this way
// to ensure it aligns with box drawing characters
// since the lines are sometimes off center to
// make sure they aren't split between pixels.
// The radius needs to be the smallest distance from the center to an edge.
// These @intFromFloat casts shouldn't ever fail since r can never
// be greater than cx or cy, so when subtracting it from them the
// result can never be negative.
// Top of horizontal strokes
// Bottom of horizontal strokes
// Left of vertical strokes
// Right of vertical strokes
// If we're fading to the top or left, we start with 0.0
// and increment up as we progress, otherwise we start
// at 255.0 and increment down (negative).
//
// --- Original Ghostty Comments End: src/font/sprite/draw/branch.zig

// Branch Drawing Characters | U+F5D0...U+F60D
//
// Branch drawing character set, used for drawing git-like
// graphs in the terminal. Originally implemented in Kitty.
// Ref:
// - https://github.com/kovidgoyal/kitty/pull/7681
// - https://github.com/kovidgoyal/kitty/pull/7805
// NOTE: Kitty is GPL licensed, and its code was not referenced
//       for these characters, only the loose specification of
//       the character set in the pull request descriptions.
//
// Translated from ghostty/src/font/sprite/draw/branch.zig

import sprite_types as font
import math

// Specification of a branch drawing node, which consists of a
// circle which is either empty or filled, and lines connecting
// optionally between the circle and each of the 4 edges.
const branch_node_up = u8(1 << 0)
const branch_node_right = u8(1 << 1)
const branch_node_down = u8(1 << 2)
const branch_node_left = u8(1 << 3)
const branch_node_filled = u8(1 << 4)
const branch_node_mask = u8(0x1f)

// V has no packed structs, so the source's packed struct(u5) is stored in the
// smallest available integer with the same declaration-order bit layout.
struct BranchNode {
	value u8
}

fn BranchNode.from_int(value u8) BranchNode {
	assert value & ~branch_node_mask == 0
	return BranchNode{
		value: value
	}
}

fn (node BranchNode) up() bool {
	return node.value & branch_node_up != 0
}

fn (node BranchNode) right() bool {
	return node.value & branch_node_right != 0
}

fn (node BranchNode) down() bool {
	return node.value & branch_node_down != 0
}

fn (node BranchNode) left() bool {
	return node.value & branch_node_left != 0
}

fn (node BranchNode) filled() bool {
	return node.value & branch_node_filled != 0
}

// draw_f5d0_f60d dispatches drawing for branch drawing characters.
pub fn draw_f5d0_f60d(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// ''
		0x0f5d0 { hline_middle(metrics, mut canvas, .light) }
		// ''
		0x0f5d1 { vline_middle(metrics, mut canvas, .light) }
		// ''
		0x0f5d2 { fading_line(metrics, mut canvas, .right, .light) }
		// ''
		0x0f5d3 { fading_line(metrics, mut canvas, .left, .light) }
		// ''
		0x0f5d4 { fading_line(metrics, mut canvas, .bottom, .light) }
		// ''
		0x0f5d5 { fading_line(metrics, mut canvas, .top, .light) }
		// ''
		0x0f5d6 { box_arc(metrics, mut canvas, .br, .light)! }
		// ''
		0x0f5d7 { box_arc(metrics, mut canvas, .bl, .light)! }
		// ''
		0x0f5d8 { box_arc(metrics, mut canvas, .tr, .light)! }
		// ''
		0x0f5d9 { box_arc(metrics, mut canvas, .tl, .light)! }
		// ''
		0x0f5da {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tr, .light)!
		}

		// ''
		0x0f5db {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .br, .light)!
		}

		// ''
		0x0f5dc {
			box_arc(metrics, mut canvas, .tr, .light)!
			box_arc(metrics, mut canvas, .br, .light)!
		}

		// ''
		0x0f5dd {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tl, .light)!
		}

		// ''
		0x0f5de {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .bl, .light)!
		}

		// ''
		0x0f5df {
			box_arc(metrics, mut canvas, .tl, .light)!
			box_arc(metrics, mut canvas, .bl, .light)!
		}

		// ''
		0x0f5e0 {
			box_arc(metrics, mut canvas, .bl, .light)!
			hline_middle(metrics, mut canvas, .light)
		}

		// ''
		0x0f5e1 {
			box_arc(metrics, mut canvas, .br, .light)!
			hline_middle(metrics, mut canvas, .light)
		}

		// ''
		0x0f5e2 {
			box_arc(metrics, mut canvas, .br, .light)!
			box_arc(metrics, mut canvas, .bl, .light)!
		}

		// ''
		0x0f5e3 {
			box_arc(metrics, mut canvas, .tl, .light)!
			hline_middle(metrics, mut canvas, .light)
		}

		// ''
		0x0f5e4 {
			box_arc(metrics, mut canvas, .tr, .light)!
			hline_middle(metrics, mut canvas, .light)
		}

		// ''
		0x0f5e5 {
			box_arc(metrics, mut canvas, .tr, .light)!
			box_arc(metrics, mut canvas, .tl, .light)!
		}

		// ''
		0x0f5e6 {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tl, .light)!
			box_arc(metrics, mut canvas, .tr, .light)!
		}

		// ''
		0x0f5e7 {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .bl, .light)!
			box_arc(metrics, mut canvas, .br, .light)!
		}

		// ''
		0x0f5e8 {
			hline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .bl, .light)!
			box_arc(metrics, mut canvas, .tl, .light)!
		}

		// ''
		0x0f5e9 {
			hline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tr, .light)!
			box_arc(metrics, mut canvas, .br, .light)!
		}

		// ''
		0x0f5ea {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tl, .light)!
			box_arc(metrics, mut canvas, .br, .light)!
		}

		// ''
		0x0f5eb {
			vline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tr, .light)!
			box_arc(metrics, mut canvas, .bl, .light)!
		}

		// ''
		0x0f5ec {
			hline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tl, .light)!
			box_arc(metrics, mut canvas, .br, .light)!
		}

		// ''
		0x0f5ed {
			hline_middle(metrics, mut canvas, .light)
			box_arc(metrics, mut canvas, .tr, .light)!
			box_arc(metrics, mut canvas, .bl, .light)!
		}

		// ''
		0x0f5ee {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_filled), .light)
		}

		// ''
		0x0f5ef { branch_node(metrics, mut canvas, BranchNode.from_int(0), .light) }

		// ''
		0x0f5f0 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_right | branch_node_filled), .light)
		}

		// ''
		0x0f5f1 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_right), .light)
		}

		// ''
		0x0f5f2 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_left | branch_node_filled), .light)
		}

		// ''
		0x0f5f3 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_left), .light)
		}

		// ''
		0x0f5f4 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_left | branch_node_right | branch_node_filled), .light)
		}

		// ''
		0x0f5f5 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_left | branch_node_right), .light)
		}

		// ''
		0x0f5f6 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_down | branch_node_filled), .light)
		}

		// ''
		0x0f5f7 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_down), .light)
		}

		// ''
		0x0f5f8 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_filled), .light)
		}

		// ''
		0x0f5f9 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up), .light)
		}

		// ''
		0x0f5fa {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down | branch_node_filled), .light)
		}

		// ''
		0x0f5fb {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down), .light)
		}

		// ''
		0x0f5fc {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_right | branch_node_down | branch_node_filled), .light)
		}

		// ''
		0x0f5fd {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_right | branch_node_down), .light)
		}

		// ''
		0x0f5fe {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_left | branch_node_down | branch_node_filled), .light)
		}

		// ''
		0x0f5ff {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_left | branch_node_down), .light)
		}

		// ''
		0x0f600 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_right | branch_node_filled), .light)
		}

		// ''
		0x0f601 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_right), .light)
		}

		// ''
		0x0f602 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_left | branch_node_filled), .light)
		}

		// ''
		0x0f603 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_left), .light)
		}

		// ''
		0x0f604 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down | branch_node_right | branch_node_filled), .light)
		}

		// ''
		0x0f605 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down | branch_node_right), .light)
		}

		// ''
		0x0f606 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down | branch_node_left | branch_node_filled), .light)
		}

		// ''
		0x0f607 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down | branch_node_left), .light)
		}

		// ''
		0x0f608 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_down | branch_node_left | branch_node_right | branch_node_filled), .light)
		}

		// ''
		0x0f609 {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_down | branch_node_left | branch_node_right), .light)
		}

		// ''
		0x0f60a {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_left | branch_node_right | branch_node_filled), .light)
		}

		// ''
		0x0f60b {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_left | branch_node_right), .light)
		}

		// ''
		0x0f60c {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down | branch_node_left | branch_node_right | branch_node_filled), .light)
		}

		// ''
		0x0f60d {
			branch_node(metrics, mut canvas, BranchNode.from_int(branch_node_up | branch_node_down | branch_node_left | branch_node_right), .light)
		}
		else { panic('unreachable') }
	}
}

// branch_node draws a branch node: a circle (filled or hollow) with
// optional lines connecting to the 4 edges.
fn branch_node(metrics font.Metrics, mut canvas Canvas, node BranchNode, thickness Thickness) {
	thick_px := thickness.height(metrics.box_thickness)
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)
	float_thick := f64(thick_px)

	// Top of horizontal strokes
	h_top := sat_sub(metrics.cell_height, thick_px) / 2
	// Bottom of horizontal strokes
	h_bottom := sat_add(h_top, thick_px)
	// Left of vertical strokes
	v_left := sat_sub(metrics.cell_width, thick_px) / 2
	// Right of vertical strokes
	v_right := sat_add(v_left, thick_px)

	// We calculate the center of the circle this way
	// to ensure it aligns with box drawing characters
	// since the lines are sometimes off center to
	// make sure they aren't split between pixels.
	cx := f64(v_left) + float_thick / 2
	cy := f64(h_top) + float_thick / 2
	// The radius needs to be the smallest distance from the center to an edge.
	r := math.min(
		math.min(cx, cy),
		math.min(float_width - cx, float_height - cy),
	)

	mut ctx := canvas.get_context()
	defer {
		ctx.deinit()
	}
	ctx.set_source(SourcePattern{
		opaque_pattern: OpaquePattern{
			pixel: PixelUnion{
				alpha8: Alpha8{ a: u8(Shade.on) }
			}
		}
	})
	ctx.set_line_width(float_thick)

	// These @intFromFloat casts shouldn't ever fail since r can never
	// be greater than cx or cy, so when subtracting it from them the
	// result can never be negative.
	if node.up() {
		canvas.box(
			i32(v_left),
			0,
			i32(v_right),
			int(math.ceil(cy - r + float_thick / 2)),
			.on,
		)
	}
	if node.right() {
		canvas.box(
			int(math.floor(cx + r - float_thick / 2)),
			i32(h_top),
			i32(metrics.cell_width),
			i32(h_bottom),
			.on,
		)
	}
	if node.down() {
		canvas.box(
			i32(v_left),
			int(math.floor(cy + r - float_thick / 2)),
			i32(v_right),
			i32(metrics.cell_height),
			.on,
		)
	}
	if node.left() {
		canvas.box(
			0,
			i32(h_top),
			int(math.ceil(cx - r + float_thick / 2)),
			i32(h_bottom),
			.on,
		)
	}

	if node.filled() {
		ctx.arc(cx, cy, r, 0, math.pi * 2) or { return }
		ctx.close_path() or { return }
		ctx.fill() or { return }
	} else {
		ctx.arc(cx, cy, r - float_thick / 2, 0, math.pi * 2) or { return }
		ctx.close_path() or { return }
		ctx.stroke() or { return }
	}
}

// fading_line draws a line that fades toward the given edge.
fn fading_line(metrics font.Metrics, mut canvas Canvas, to Edge, thickness Thickness) {
	thick_px := thickness.height(metrics.box_thickness)
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	// Top of horizontal strokes
	h_top := sat_sub(metrics.cell_height, thick_px) / 2
	// Bottom of horizontal strokes
	h_bottom := sat_add(h_top, thick_px)
	// Left of vertical strokes
	v_left := sat_sub(metrics.cell_width, thick_px) / 2
	// Right of vertical strokes
	v_right := sat_add(v_left, thick_px)

	// If we're fading to the top or left, we start with 0.0
	// and increment up as we progress, otherwise we start
	// at 255.0 and increment down (negative).
	mut color_val := match to {
		.top, .left { f64(0.0) }
		.bottom, .right { f64(255.0) }
	}
	inc := 255.0 / match to {
		.top { float_height }
		.bottom { -float_height }
		.left { float_width }
		.right { -float_width }
	}

	match to {
		.top, .bottom {
			for y in u32(0) .. metrics.cell_height {
				for x in v_left .. v_right {
					canvas.pixel(
						i32(x),
						i32(y),
						unsafe { Color(u8(math.round(color_val))) },
					)
				}
				color_val += inc
			}
		}
		.left, .right {
			for x in u32(0) .. metrics.cell_width {
				for y in h_top .. h_bottom {
					canvas.pixel(
						i32(x),
						i32(y),
						unsafe { Color(u8(math.round(color_val))) },
					)
				}
				color_val += inc
			}
		}
	}
}
