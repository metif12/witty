module sprite

// Geometric Shapes | U+25A0...U+25FF
// https://en.wikipedia.org/wiki/Geometric_Shapes_(Unicode_block)
//
// ■ □ ▢ ▣ ▤ ▥ ▦ ▧ ▨ ▩ ▪ ▫ ▬ ▭ ▮ ▯
// ▰ ▱ ▲ △ ▴ ▵ ▶ ▷ ▸ ▹ ► ▻ ▼ ▽ ▾ ▿
// ◀ ◁ ◂ ◃ ◄ ◅ ◆ ◇ ◈ ◉ ◊ ○ ◌ ◍ ◎ ●
// ◐ ◑ ◒ ◓ ◔ ◕ ◖ ◗ ◘ ◙ ◚ ◛ ◜ ◝ ◞ ◟
// ◠ ◡ ◢ ◣ ◤ ◥ ◦ ◧ ◨ ◩ ◪ ◫ ◬ ◭ ◮ ◯
// ◰ ◱ ◲ ◳ ◴ ◵ ◶ ◷ ◸ ◹ ◺ ◻ ◼ ◽︎◾︎◿
//
// Only a subset of this block is viable for sprite drawing; filling
// out this file to have full coverage of this block is not the goal.
//
// Translated from ghostty/src/font/sprite/draw/geometric_shapes.zig

import font

// ◢ ◣ ◤ ◥
pub fn draw_25e2_25e5(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height
	match cp {
		// ◢
		0x25e2 { corner_triangle_shade(metrics, mut canvas, .br, .on)! }
		// ◣
		0x25e3 { corner_triangle_shade(metrics, mut canvas, .bl, .on)! }
		// ◤
		0x25e4 { corner_triangle_shade(metrics, mut canvas, .tl, .on)! }
		// ◥
		0x25e5 { corner_triangle_shade(metrics, mut canvas, .tr, .on)! }

		else {}
	}
}

// ◸ ◹ ◺
pub fn draw_25f8_25fa(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height
	match cp {
		// ◸
		0x25f8 { corner_triangle_outline(metrics, mut canvas, .tl)! }
		// ◹
		0x25f9 { corner_triangle_outline(metrics, mut canvas, .tr)! }
		// ◺
		0x25fa { corner_triangle_outline(metrics, mut canvas, .bl)! }

		else {}
	}
}

// ◿
pub fn draw_25ff(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height
	corner_triangle_outline(metrics, mut canvas, .br)!
}

// corner_triangle_shade draws a corner triangle filled with the given shade.
pub fn corner_triangle_shade_geo(metrics font.Metrics, mut canvas Canvas, corner Corner, shade Shade) ! {
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	x0, y0, x1, y1, x2, y2 := match corner {
		.tl {
			f64(0), f64(0), f64(0), float_height, float_width, f64(0)
		}
		.tr {
			f64(0), f64(0), float_width, float_height, float_width, f64(0)
		}
		.bl {
			f64(0), f64(0), f64(0), float_height, float_width, float_height
		}
		.br {
			f64(0), float_height, float_width, float_height, float_width, f64(0)
		}
	}

	mut path := canvas.static_path(5)
	path.move_to(x0, y0)
	path.line_to(x1, y1)
	path.line_to(x2, y2)
	path.close()

	canvas.fill_path(path.wrapped_path, FillOptions{}, unsafe { Color(u8(shade)) })!
}

// corner_triangle_outline draws a corner triangle as an outline (stroke only).
// Uses individual line segments as an approximation since innerStrokePath
// is not available. The ideal approach would use a stroke with
// line_cap_mode = .butt and line_width = float_thick.
pub fn corner_triangle_outline(metrics font.Metrics, mut canvas Canvas, corner Corner) ! {
	float_thick := f64(Thickness.light.height(metrics.box_thickness))
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	x0, y0, x1, y1, x2, y2 := match corner {
		.tl {
			f64(0), f64(0), f64(0), float_height, float_width, f64(0)
		}
		.tr {
			f64(0), f64(0), float_width, float_height, float_width, f64(0)
		}
		.bl {
			f64(0), f64(0), f64(0), float_height, float_width, float_height
		}
		.br {
			f64(0), float_height, float_width, float_height, float_width, f64(0)
		}
	}

	mut path := canvas.static_path(5)
	path.move_to(x0, y0)
	path.line_to(x1, y1)
	path.line_to(x2, y2)
	path.close()

	// Draw the outline edges as individual line segments.
	canvas.line(LineSegment{ p0: Point{ x: x0, y: y0 }, p1: Point{ x: x1, y: y1 } }, float_thick, .on) or {}
	canvas.line(LineSegment{ p0: Point{ x: x1, y: y1 }, p1: Point{ x: x2, y: y2 } }, float_thick, .on) or {}
	canvas.line(LineSegment{ p0: Point{ x: x2, y: y2 }, p1: Point{ x: x0, y: y0 } }, float_thick, .on) or {}
}
