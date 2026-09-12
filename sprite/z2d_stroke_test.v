module sprite

// Direct translations of focused tests alongside z2d v0.10.0's Slope and
// stroke_plotter implementations.

import math

fn test_z2d_slope_normalize() {
	mut slope := Z2dSlope{ dx: 3, dy: 4 }
	assert slope.normalize() == 5
	assert slope.dx == 0.6
	assert slope.dy == 0.8

	slope = Z2dSlope{ dx: 0, dy: -5 }
	assert slope.normalize() == 5
	assert slope.dx == 0
	assert slope.dy == -1
}

fn test_z2d_slope_compare_tie_breakers() {
	assert Z2dSlope{ dx: 0, dy: 0 }.compare(Z2dSlope{ dx: 0, dy: 0 }) == 0
	assert Z2dSlope{ dx: 0, dy: 0 }.compare(Z2dSlope{ dx: 1, dy: 0 }) == 1
	assert Z2dSlope{ dx: 1, dy: 0 }.compare(Z2dSlope{ dx: 0, dy: 0 }) == -1
	assert Z2dSlope{ dx: 1, dy: 0 }.compare(Z2dSlope{ dx: -1, dy: 0 }) == -1
}

fn test_z2d_stroke_plotter_consumes_degenerate_lines() {
	first_duplicate := Path{
		nodes: [
			PathNode{ kind: .move_to, x: 10, y: 10 },
			PathNode{ kind: .line_to, x: 10, y: 10 },
			PathNode{ kind: .line_to, x: 20, y: 20 },
		]
	}
	assert z2d_stroke_plot(first_duplicate, StrokeOptions{ line_width: 2 })!.edges.len == 4

	last_duplicate := Path{
		nodes: [
			PathNode{ kind: .move_to, x: 10, y: 10 },
			PathNode{ kind: .line_to, x: 20, y: 20 },
			PathNode{ kind: .line_to, x: 20, y: 20 },
		]
	}
	assert z2d_stroke_plot(last_duplicate, StrokeOptions{ line_width: 2 })!.edges.len == 4
}

fn test_z2d_stroke_slope_difference_below_epsilon_stays_finite() {
	path := Path{
		nodes: [
			PathNode{ kind: .move_to, x: 2.8641015625e2, y: 1.43154296875e1 },
			PathNode{ kind: .line_to, x: 2.822548828125e2, y: 1.6e1 },
			PathNode{ kind: .line_to, x: 2.80990234375e2, y: 1.65126953125e1 },
		]
	}
	polygon := z2d_stroke_plot(path, StrokeOptions{ line_width: 2 })!
	assert polygon.edges.len == 6
	for edge in polygon.edges {
		assert math.is_finite(edge.y0)
		assert math.is_finite(edge.y1)
		assert math.is_finite(edge.x_start)
		assert math.is_finite(edge.x_inc)
	}
}

fn test_z2d_stroke_rejects_line_without_current_point() {
	path := Path{
		nodes: [PathNode{ kind: .line_to, x: 1, y: 1 }]
	}
	if _ := z2d_stroke_plot(path, StrokeOptions{}) {
		assert false
	} else {
		assert err.msg() == 'invalid stroke path state'
	}
}
