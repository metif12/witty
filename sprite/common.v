module sprite

// This file contains a set of useful helper functions
// and types for drawing our sprite font glyphs. These
// are generally applicable to multiple sets of glyphs
// rather than being single-use.
//
// Translated from ghostty/src/font/sprite/draw/common.zig
//
// NOTE: The core types (Thickness, Shade, Quads, Corner, Edge,
// Alignment, Fraction, fill, vline, hline, vline_middle, hline_middle)
// are already defined in sprite.v. This file contains additional
// helpers from common.zig that weren't already present.

import sprite_types as font
import math

// ============================================================
// Additional line helpers from common.zig
// ============================================================

// light_diagonal_upper_right_to_lower_left draws a light diagonal
// line from the upper right to the lower left corner.
pub fn light_diagonal_upper_right_to_lower_left(metrics font.Metrics, mut canvas Canvas) {
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	// We overshoot the corners by a tiny bit, but we need to
	// maintain the correct slope, so we calculate that here.
	slope_x := math.min(1.0, float_width / float_height)
	slope_y := math.min(1.0, float_height / float_width)

	canvas.line(LineSegment{
		p0: Point{
			x: float_width + 0.5 * slope_x
			y: -0.5 * slope_y
		}
		p1: Point{
			x: -0.5 * slope_x
			y: float_height + 0.5 * slope_y
		}
	}, f64(Thickness.light.height(metrics.box_thickness)), .on) or {}
}

// light_diagonal_upper_left_to_lower_right draws a light diagonal
// line from the upper left to the lower right corner.
pub fn light_diagonal_upper_left_to_lower_right(metrics font.Metrics, mut canvas Canvas) {
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	// We overshoot the corners by a tiny bit, but we need to
	// maintain the correct slope, so we calculate that here.
	slope_x := math.min(1.0, float_width / float_height)
	slope_y := math.min(1.0, float_height / float_width)

	canvas.line(LineSegment{
		p0: Point{
			x: -0.5 * slope_x
			y: -0.5 * slope_y
		}
		p1: Point{
			x: float_width + 0.5 * slope_x
			y: float_height + 0.5 * slope_y
		}
	}, f64(Thickness.light.height(metrics.box_thickness)), .on) or {}
}
