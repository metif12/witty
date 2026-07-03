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

import font
import math

// Specification of a branch drawing node, which consists of a
// circle which is either empty or filled, and lines connecting
// optionally between the circle and each of the 4 edges.
struct BranchNode {
	up     bool
	right  bool
	down   bool
	left   bool
	filled bool
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
		0x0f5d6 { draw_arc(metrics, mut canvas, .br, .light)! }
		// ''
		0x0f5d7 { draw_arc(metrics, mut canvas, .bl, .light)! }
		// ''
		0x0f5d8 { draw_arc(metrics, mut canvas, .tr, .light)! }
		// ''
		0x0f5d9 { draw_arc(metrics, mut canvas, .tl, .light)! }
		// ''
		0x0f5da {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tr, .light)!
		}
		// ''
		0x0f5db {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .br, .light)!
		}
		// ''
		0x0f5dc {
			draw_arc(metrics, mut canvas, .tr, .light)!
			draw_arc(metrics, mut canvas, .br, .light)!
		}
		// ''
		0x0f5dd {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tl, .light)!
		}
		// ''
		0x0f5de {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .bl, .light)!
		}
		// ''
		0x0f5df {
			draw_arc(metrics, mut canvas, .tl, .light)!
			draw_arc(metrics, mut canvas, .bl, .light)!
		}

		// ''
		0x0f5e0 {
			draw_arc(metrics, mut canvas, .bl, .light)!
			hline_middle(metrics, mut canvas, .light)
		}
		// ''
		0x0f5e1 {
			draw_arc(metrics, mut canvas, .br, .light)!
			hline_middle(metrics, mut canvas, .light)
		}
		// ''
		0x0f5e2 {
			draw_arc(metrics, mut canvas, .br, .light)!
			draw_arc(metrics, mut canvas, .bl, .light)!
		}
		// ''
		0x0f5e3 {
			draw_arc(metrics, mut canvas, .tl, .light)!
			hline_middle(metrics, mut canvas, .light)
		}
		// ''
		0x0f5e4 {
			draw_arc(metrics, mut canvas, .tr, .light)!
			hline_middle(metrics, mut canvas, .light)
		}
		// ''
		0x0f5e5 {
			draw_arc(metrics, mut canvas, .tr, .light)!
			draw_arc(metrics, mut canvas, .tl, .light)!
		}
		// ''
		0x0f5e6 {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tl, .light)!
			draw_arc(metrics, mut canvas, .tr, .light)!
		}
		// ''
		0x0f5e7 {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .bl, .light)!
			draw_arc(metrics, mut canvas, .br, .light)!
		}
		// ''
		0x0f5e8 {
			hline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .bl, .light)!
			draw_arc(metrics, mut canvas, .tl, .light)!
		}
		// ''
		0x0f5e9 {
			hline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tr, .light)!
			draw_arc(metrics, mut canvas, .br, .light)!
		}
		// ''
		0x0f5ea {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tl, .light)!
			draw_arc(metrics, mut canvas, .br, .light)!
		}
		// ''
		0x0f5eb {
			vline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tr, .light)!
			draw_arc(metrics, mut canvas, .bl, .light)!
		}
		// ''
		0x0f5ec {
			hline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tl, .light)!
			draw_arc(metrics, mut canvas, .br, .light)!
		}
		// ''
		0x0f5ed {
			hline_middle(metrics, mut canvas, .light)
			draw_arc(metrics, mut canvas, .tr, .light)!
			draw_arc(metrics, mut canvas, .bl, .light)!
		}
		// ''
		0x0f5ee { branch_node(metrics, mut canvas, BranchNode{ filled: true }, .light) }
		// ''
		0x0f5ef { branch_node(metrics, mut canvas, BranchNode{}, .light) }

		// ''
		0x0f5f0 {
			branch_node(metrics, mut canvas, BranchNode{
				right:  true
				filled: true
			}, .light)
		}
		// ''
		0x0f5f1 {
			branch_node(metrics, mut canvas, BranchNode{
				right: true
			}, .light)
		}
		// ''
		0x0f5f2 {
			branch_node(metrics, mut canvas, BranchNode{
				left:   true
				filled: true
			}, .light)
		}
		// ''
		0x0f5f3 {
			branch_node(metrics, mut canvas, BranchNode{
				left: true
			}, .light)
		}
		// ''
		0x0f5f4 {
			branch_node(metrics, mut canvas, BranchNode{
				left:   true
				right:  true
				filled: true
			}, .light)
		}
		// ''
		0x0f5f5 {
			branch_node(metrics, mut canvas, BranchNode{
				left:  true
				right: true
			}, .light)
		}
		// ''
		0x0f5f6 {
			branch_node(metrics, mut canvas, BranchNode{
				down:   true
				filled: true
			}, .light)
		}
		// ''
		0x0f5f7 {
			branch_node(metrics, mut canvas, BranchNode{
				down: true
			}, .light)
		}
		// ''
		0x0f5f8 {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				filled: true
			}, .light)
		}
		// ''
		0x0f5f9 {
			branch_node(metrics, mut canvas, BranchNode{
				up: true
			}, .light)
		}
		// ''
		0x0f5fa {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				down:   true
				filled: true
			}, .light)
		}
		// ''
		0x0f5fb {
			branch_node(metrics, mut canvas, BranchNode{
				up:   true
				down: true
			}, .light)
		}
		// ''
		0x0f5fc {
			branch_node(metrics, mut canvas, BranchNode{
				right:  true
				down:   true
				filled: true
			}, .light)
		}
		// ''
		0x0f5fd {
			branch_node(metrics, mut canvas, BranchNode{
				right: true
				down:  true
			}, .light)
		}
		// ''
		0x0f5fe {
			branch_node(metrics, mut canvas, BranchNode{
				left:   true
				down:   true
				filled: true
			}, .light)
		}
		// ''
		0x0f5ff {
			branch_node(metrics, mut canvas, BranchNode{
				left: true
				down: true
			}, .light)
		}

		// ''
		0x0f600 {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				right:  true
				filled: true
			}, .light)
		}
		// ''
		0x0f601 {
			branch_node(metrics, mut canvas, BranchNode{
				up:    true
				right: true
			}, .light)
		}
		// ''
		0x0f602 {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				left:   true
				filled: true
			}, .light)
		}
		// ''
		0x0f603 {
			branch_node(metrics, mut canvas, BranchNode{
				up:   true
				left: true
			}, .light)
		}
		// ''
		0x0f604 {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				down:   true
				right:  true
				filled: true
			}, .light)
		}
		// ''
		0x0f605 {
			branch_node(metrics, mut canvas, BranchNode{
				up:    true
				down:  true
				right: true
			}, .light)
		}
		// ''
		0x0f606 {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				down:   true
				left:   true
				filled: true
			}, .light)
		}
		// ''
		0x0f607 {
			branch_node(metrics, mut canvas, BranchNode{
				up:   true
				down: true
				left: true
			}, .light)
		}
		// ''
		0x0f608 {
			branch_node(metrics, mut canvas, BranchNode{
				down:   true
				left:   true
				right:  true
				filled: true
			}, .light)
		}
		// ''
		0x0f609 {
			branch_node(metrics, mut canvas, BranchNode{
				down:  true
				left:  true
				right: true
			}, .light)
		}
		// ''
		0x0f60a {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				left:   true
				right:  true
				filled: true
			}, .light)
		}
		// ''
		0x0f60b {
			branch_node(metrics, mut canvas, BranchNode{
				up:    true
				left:  true
				right: true
			}, .light)
		}
		// ''
		0x0f60c {
			branch_node(metrics, mut canvas, BranchNode{
				up:     true
				down:   true
				left:   true
				right:  true
				filled: true
			}, .light)
		}
		// ''
		0x0f60d {
			branch_node(metrics, mut canvas, BranchNode{
				up:    true
				down:  true
				left:  true
				right: true
			}, .light)
		}

		else {}
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
	h_top := (metrics.cell_height - thick_px) / 2
	// Bottom of horizontal strokes
	h_bottom := h_top + thick_px
	// Left of vertical strokes
	v_left := (metrics.cell_width - thick_px) / 2
	// Right of vertical strokes
	v_right := v_left + thick_px

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
	if node.up {
		canvas.draw_box(
			i32(v_left),
			0,
			i32(v_right),
			int(math.ceil(cy - r + float_thick / 2)),
			.on,
		)
	}
	if node.right {
		canvas.draw_box(
			int(math.floor(cx + r - float_thick / 2)),
			i32(h_top),
			i32(metrics.cell_width),
			i32(h_bottom),
			.on,
		)
	}
	if node.down {
		canvas.draw_box(
			i32(v_left),
			int(math.floor(cy + r - float_thick / 2)),
			i32(v_right),
			i32(metrics.cell_height),
			.on,
		)
	}
	if node.left {
		canvas.draw_box(
			0,
			i32(h_top),
			int(math.ceil(cx - r + float_thick / 2)),
			i32(h_bottom),
			.on,
		)
	}

	if node.filled {
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
	h_top := (metrics.cell_height - thick_px) / 2
	// Bottom of horizontal strokes
	h_bottom := h_top + thick_px
	// Left of vertical strokes
	v_left := (metrics.cell_width - thick_px) / 2
	// Right of vertical strokes
	v_right := v_left + thick_px

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

// draw_arc draws a rounded corner arc for box drawing.
// Uses multiple line segments computed via sin/cos to approximate the
// quarter-circle arc, since curveTo is not available on StaticPath.
fn draw_arc(metrics font.Metrics, mut canvas Canvas, corner Corner, thickness Thickness) ! {
	thick_px := thickness.height(metrics.box_thickness)
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)
	float_thick := f64(thick_px)
	center_x := f64((metrics.cell_width - thick_px) / 2) + float_thick / 2
	center_y := f64((metrics.cell_height - thick_px) / 2) + float_thick / 2

	r := math.min(float_width, float_height) / 2

	// Number of segments for the arc approximation.
	arc_segments := 8

	// Compute the start/end points for the straight segments leading to
	// and from the arc, plus the arc points themselves using sin/cos.
	//
	// For each corner the arc sweeps a quarter circle. We compute
	// arc_segments + 1 points along the arc and draw line segments
	// between consecutive points, plus the straight line segments
	// connecting the arc endpoints to the cell edges.

	// Determine start angle and arc center based on corner.
	// The arc center is at (center_x, center_y) offset by radius in the
	// appropriate direction.
	mut arc_cx := f64(0)
	mut arc_cy := f64(0)
	mut start_angle := f64(0)
	mut edge_start_x := f64(0)
	mut edge_start_y := f64(0)
	mut edge_end_x := f64(0)
	mut edge_end_y := f64(0)

	match corner {
		.tl {
			// Arc goes from top-center to left-center
			arc_cx = center_x - r
			arc_cy = center_y - r
			start_angle = 0 // 0 to pi/2 sweeps from right to bottom
			// but we want from bottom (center_x, center_y-r+r=center_y) to right (center_x-r+r=center_x)
			// Actually: arc center is at (center_x - r, center_y - r), radius r
			// Point at angle 0: (arc_cx + r, arc_cy) = (center_x, center_y - r) -- on vertical line going up
			// Point at angle pi/2: (arc_cx, arc_cy + r) = (center_x - r, center_y) -- on horizontal line going left
			edge_start_x = center_x
			edge_start_y = 0
			edge_end_x = 0
			edge_end_y = center_y
		}
		.tr {
			// Arc goes from top-center to right-center
			arc_cx = center_x + r
			arc_cy = center_y - r
			start_angle = math.pi / 2 // pi/2 to pi
			edge_start_x = center_x
			edge_start_y = 0
			edge_end_x = float_width
			edge_end_y = center_y
		}
		.bl {
			// Arc goes from bottom-center to left-center
			arc_cx = center_x - r
			arc_cy = center_y + r
			start_angle = 3 * math.pi / 2 // 3pi/2 to 2pi
			edge_start_x = center_x
			edge_start_y = float_height
			edge_end_x = 0
			edge_end_y = center_y
		}
		.br {
			// Arc goes from bottom-center to right-center
			arc_cx = center_x + r
			arc_cy = center_y + r
			start_angle = math.pi // pi to 3pi/2
			edge_start_x = center_x
			edge_start_y = float_height
			edge_end_x = float_width
			edge_end_y = center_y
		}
	}

	// Build the arc points.
	mut arc_points_x := []f64{len: arc_segments + 1}
	mut arc_points_y := []f64{len: arc_segments + 1}
	for i in 0 .. arc_segments + 1 {
		t := f64(i) / f64(arc_segments)
		angle := start_angle + t * math.pi / 2
		arc_points_x[i] = arc_cx + r * math.cos(angle)
		arc_points_y[i] = arc_cy + r * math.sin(angle)
	}

	// Draw the straight segment from the edge to the first arc point.
	canvas.line(LineSegment{
		p0: Point{ x: edge_start_x, y: edge_start_y }
		p1: Point{ x: arc_points_x[0], y: arc_points_y[0] }
	}, float_thick, .on) or {}

	// Draw the arc segments.
	for i in 0 .. arc_segments {
		canvas.line(LineSegment{
			p0: Point{ x: arc_points_x[i], y: arc_points_y[i] }
			p1: Point{ x: arc_points_x[i + 1], y: arc_points_y[i + 1] }
		}, float_thick, .on) or {}
	}

	// Draw the straight segment from the last arc point to the edge.
	canvas.line(LineSegment{
		p0: Point{ x: arc_points_x[arc_segments], y: arc_points_y[arc_segments] }
		p1: Point{ x: edge_end_x, y: edge_end_y }
	}, float_thick, .on) or {}
}
