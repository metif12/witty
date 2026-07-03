module sprite

// --- Original Ghostty Comments Start: src/font/sprite/draw/box.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/font/sprite/draw/box.zig
//
// Box Drawing | U+2500...U+257F
// https://en.wikipedia.org/wiki/Box_Drawing
//
// ─━│┃┄┅┆┇┈┉┊┋┌┍┎┏
// ┐┑┒┓└┕┖┗┘┙┚┛├┝┞┟
// ┠┡┢┣┤┥┦┧┨┩┪┫┬┭┮┯
// ┰┱┲┳┴┵┶┷┸┹┺┻┼┽┾┿
// ╀╁╂╃╄╅╆╇╈╉╊╋╌╍╎╏
// ═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟
// ╠╡╢╣╤╥╦╧╨╩╪╫╬╭╮╯
// ╰╱╲╳╴╵╶╷╸╹╺╻╼╽╾╿
//
// Specification of a traditional intersection-style line/box-drawing char,
// which can have a different style of line from each edge to the center.
// '─'
// '━'
// '│'
// '┃'
// '┄'
// '┅'
// '┆'
// '┇'
// '┈'
// '┉'
// '┊'
// '┋'
// '┌'
// '┍'
// '┎'
// '┏'
// '┐'
// '┑'
// '┒'
// '┓'
// '└'
// '┕'
// '┖'
// '┗'
// '┘'
// '┙'
// '┚'
// '┛'
// '├'
// '┝'
// '┞'
// '┟'
// '┠'
// '┡'
// '┢'
// '┣'
// '┤'
// '┥'
// '┦'
// '┧'
// '┨'
// '┩'
// '┪'
// '┫'
// '┬'
// '┭'
// '┮'
// '┯'
// '┰'
// '┱'
// '┲'
// '┳'
// '┴'
// '┵'
// '┶'
// '┷'
// '┸'
// '┹'
// '┺'
// '┻'
// '┼'
// '┽'
// '┾'
// '┿'
// '╀'
// '╁'
// '╂'
// '╃'
// '╄'
// '╅'
// '╆'
// '╇'
// '╈'
// '╉'
// '╊'
// '╋'
// '╌'
// '╍'
// '╎'
// '╏'
// '═'
// '║'
// '╒'
// '╓'
// '╔'
// '╕'
// '╖'
// '╗'
// '╘'
// '╙'
// '╚'
// '╛'
// '╜'
// '╝'
// '╞'
// '╟'
// '╠'
// '╡'
// '╢'
// '╣'
// '╤'
// '╥'
// '╦'
// '╧'
// '╨'
// '╩'
// '╪'
// '╫'
// '╬'
// '╭'
// '╮'
// '╯'
// '╰'
// '╱'
// '╲'
// '╳'
// '╴'
// '╵'
// '╶'
// '╷'
// '╸'
// '╹'
// '╺'
// '╻'
// '╼'
// '╽'
// '╾'
// '╿'
// Top of light horizontal strokes
// Bottom of light horizontal strokes
// Top of heavy horizontal strokes
// Bottom of heavy horizontal strokes
// Top of the top doubled horizontal stroke (bottom is `h_light_top`)
// Bottom of the bottom doubled horizontal stroke (top is `h_light_bottom`)
// Left of light vertical strokes
// Right of light vertical strokes
// Left of heavy vertical strokes
// Right of heavy vertical strokes
// Left of the left doubled vertical stroke (right is `v_light_left`)
// Right of the right doubled vertical stroke (left is `v_light_right`)
// The bottom of the up line
// The top of the down line
// The right of the left line
// The left of the right line
// We overshoot the corners by a tiny bit, but we need to
// maintain the correct slope, so we calculate that here.
// We overshoot the corners by a tiny bit, but we need to
// maintain the correct slope, so we calculate that here.
// Fraction away from the center to place the middle control points,
// +------------+
// |            |
// |            |
// |            |
// |            |
// | --  --  -- |
// |            |
// |            |
// |            |
// |            |
// +------------+
// Our dashed line should be made such that when tiled horizontally
// it creates one consistent line with no uneven gap or segment sizes.
// In order to make sure this is the case, we should have half-sized
// gaps on the left and right so that it is centered properly.
// For N dashes, there are N - 1 gaps between them, but we also have
// half-sized gaps on either side, adding up to N total gaps.
// We need at least 1 pixel for each gap and each dash, if we don't
// have that then we can't draw our dashed line correctly so we just
// draw a solid line and return.
// We never want the gaps to take up more than 50% of the space,
// because if they do the dashes are too small and look wrong.
// Our dashes should be centered vertically.
// We start at half a gap from the left edge, in order to center
// our dashes properly.
// We'll distribute the extra space in to dash widths, 1px at a
// time. We prefer this to making gaps larger since that is much
// more visually obvious.
// We distribute left-over size in to dash widths,
// since it's less obvious there than in the gaps.
// Advance by the width of the dash we drew and the width
// of a gap to get the the start of the next dash.
// +-----------+
// |     |     |
// |     |     |
// |           |
// |     |     |
// |     |     |
// |           |
// |     |     |
// |     |     |
// |           |
// +-----------+
// Our dashed line should be made such that when tiled vertically it
// it creates one consistent line with no uneven gap or segment sizes.
// In order to make sure this is the case, we should have an extra gap
// gap at the bottom.
//
// A single full-sized extra gap is preferred to two half-sized ones for
// vertical to allow better joining to solid characters without creating
// visible half-sized gaps. Unlike horizontal, centering is a lot less
// important, visually.
// Because of the extra gap at the bottom, there are as many gaps as
// there are dashes.
// We need at least 1 pixel for each gap and each dash, if we don't
// have that then we can't draw our dashed line correctly so we just
// draw a solid line and return.
// We never want the gaps to take up more than 50% of the space,
// because if they do the dashes are too small and look wrong.
// Our dashes should be centered horizontally.
// We start at the top of the cell.
// We'll distribute the extra space in to dash heights, 1px at a
// time. We prefer this to making gaps larger since that is much
// more visually obvious.
// We distribute left-over size in to dash widths,
// since it's less obvious there than in the gaps.
// Advance by the height of the dash we drew and the height
// of a gap to get the the start of the next dash.
//
// --- Original Ghostty Comments End: src/font/sprite/draw/box.zig


// Block Elements | U+2580...U+259F
// https://en.wikipedia.org/wiki/Block_Elements
//
// ▀▁▂▃▄▅▆▇█▉▊▋▌▍▎▏
// ▐░▒▓▔▕▖▗▘▙▚▛▜▝▞▟
//
// Translated from ghostty/src/font/sprite/draw/block.zig

import font
import math

// draw_2580_259f dispatches drawing for block element characters.
pub fn draw_2580_259f(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// '▀' UPPER HALF BLOCK
		0x2580 { block(metrics, mut canvas, align_upper, 1, half_f) }
		// '▁' LOWER ONE EIGHTH BLOCK
		0x2581 { block(metrics, mut canvas, align_lower, 1, one_eighth_f) }
		// '▂' LOWER ONE QUARTER BLOCK
		0x2582 { block(metrics, mut canvas, align_lower, 1, one_quarter_f) }
		// '▃' LOWER THREE EIGHTHS BLOCK
		0x2583 { block(metrics, mut canvas, align_lower, 1, three_eighths_f) }
		// '▄' LOWER HALF BLOCK
		0x2584 { block(metrics, mut canvas, align_lower, 1, half_f) }
		// '▅' LOWER FIVE EIGHTHS BLOCK
		0x2585 { block(metrics, mut canvas, align_lower, 1, five_eighths_f) }
		// '▆' LOWER THREE QUARTERS BLOCK
		0x2586 { block(metrics, mut canvas, align_lower, 1, three_quarters_f) }
		// '▇' LOWER SEVEN EIGHTHS BLOCK
		0x2587 { block(metrics, mut canvas, align_lower, 1, seven_eighths_f) }
		// '█' FULL BLOCK
		0x2588 { block_full_shade(metrics, mut canvas, .on) }
		// '▉' LEFT SEVEN EIGHTHS BLOCK
		0x2589 { block(metrics, mut canvas, align_left, seven_eighths_f, 1) }
		// '▊' LEFT THREE QUARTERS BLOCK
		0x258a { block(metrics, mut canvas, align_left, three_quarters_f, 1) }
		// '▋' LEFT FIVE EIGHTHS BLOCK
		0x258b { block(metrics, mut canvas, align_left, five_eighths_f, 1) }
		// '▌' LEFT HALF BLOCK
		0x258c { block(metrics, mut canvas, align_left, half_f, 1) }
		// '▍' LEFT THREE EIGHTHS BLOCK
		0x258d { block(metrics, mut canvas, align_left, three_eighths_f, 1) }
		// '▎' LEFT ONE QUARTER BLOCK
		0x258e { block(metrics, mut canvas, align_left, one_quarter_f, 1) }
		// '▏' LEFT ONE EIGHTH BLOCK
		0x258f { block(metrics, mut canvas, align_left, one_eighth_f, 1) }

		// '▐' RIGHT HALF BLOCK
		0x2590 { block(metrics, mut canvas, align_right, half_f, 1) }
		// '░'
		0x2591 { block_full_shade(metrics, mut canvas, .light_) }
		// '▒'
		0x2592 { block_full_shade(metrics, mut canvas, .medium) }
		// '▓'
		0x2593 { block_full_shade(metrics, mut canvas, .dark) }
		// '▔' UPPER ONE EIGHTH BLOCK
		0x2594 { block(metrics, mut canvas, align_upper, 1, one_eighth_f) }
		// '▕' RIGHT ONE EIGHTH BLOCK
		0x2595 { block(metrics, mut canvas, align_right, one_eighth_f, 1) }
		// '▖'
		0x2596 { quadrant(metrics, mut canvas, Quads{ bl: true }) }
		// '▗'
		0x2597 { quadrant(metrics, mut canvas, Quads{ br: true }) }
		// '▘'
		0x2598 { quadrant(metrics, mut canvas, Quads{ tl: true }) }
		// '▙'
		0x2599 { quadrant(metrics, mut canvas, Quads{ tl: true, bl: true, br: true }) }
		// '▚'
		0x259a { quadrant(metrics, mut canvas, Quads{ tl: true, br: true }) }
		// '▛'
		0x259b { quadrant(metrics, mut canvas, Quads{ tl: true, tr: true, bl: true }) }
		// '▜'
		0x259c { quadrant(metrics, mut canvas, Quads{ tl: true, tr: true, br: true }) }
		// '▝'
		0x259d { quadrant(metrics, mut canvas, Quads{ tr: true }) }
		// '▞'
		0x259e { quadrant(metrics, mut canvas, Quads{ tr: true, bl: true }) }
		// '▟'
		0x259f { quadrant(metrics, mut canvas, Quads{ tr: true, bl: true, br: true }) }

		else {}
	}
}

// block draws a block at the given alignment with fractional
// width and height relative to the cell.
pub fn block(metrics font.Metrics, mut canvas Canvas, alignment Alignment, bwidth f64, bheight f64) {
	block_with_shade(metrics, mut canvas, alignment, bwidth, bheight, .on)
}

// block_with_shade draws a block at the given alignment with a shade pattern.
pub fn block_with_shade(metrics font.Metrics, mut canvas Canvas, alignment Alignment, bwidth f64, bheight f64, shade Shade) {
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	w := u32(math.round(float_width * bwidth))
	h := u32(math.round(float_height * bheight))

	x := match alignment.horizontal {
		.left { u32(0) }
		.right { metrics.cell_width - w }
		.center { (metrics.cell_width - w) / 2 }
	}
	y := match alignment.vertical {
		.top { u32(0) }
		.bottom { metrics.cell_height - h }
		.middle { (metrics.cell_height - h) / 2 }
	}

	canvas.rect(SpriteRect{
		x: i32(x)
		y: i32(y)
		width: i32(w)
		height: i32(h)
	}, unsafe { Color(u8(shade)) })
}

// block_full_shade fills the entire cell with a shade pattern.
pub fn block_full_shade(metrics font.Metrics, mut canvas Canvas, shade Shade) {
	canvas.draw_box(
		0,
		0,
		i32(metrics.cell_width),
		i32(metrics.cell_height),
		unsafe { Color(u8(shade)) },
	)
}

// quadrant fills the specified quadrants of the cell.
fn quadrant(metrics font.Metrics, mut canvas Canvas, quads Quads) {
	if quads.tl {
		fill(metrics, mut canvas, .zero, .half_, .zero, .half_)
	}
	if quads.tr {
		fill(metrics, mut canvas, .half_, .full, .zero, .half_)
	}
	if quads.bl {
		fill(metrics, mut canvas, .zero, .half_, .half_, .full)
	}
	if quads.br {
		fill(metrics, mut canvas, .half_, .full, .half_, .full)
	}
}
