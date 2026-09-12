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

import sprite_types as font
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
		0x2596 { quadrant(metrics, mut canvas, Quads.from_int(quad_bl)) }
		// '▗'
		0x2597 { quadrant(metrics, mut canvas, Quads.from_int(quad_br)) }
		// '▘'
		0x2598 { quadrant(metrics, mut canvas, Quads.from_int(quad_tl)) }
		// '▙'
		0x2599 { quadrant(metrics, mut canvas, Quads.from_int(quad_tl | quad_bl | quad_br)) }
		// '▚'
		0x259a { quadrant(metrics, mut canvas, Quads.from_int(quad_tl | quad_br)) }
		// '▛'
		0x259b { quadrant(metrics, mut canvas, Quads.from_int(quad_tl | quad_tr | quad_bl)) }
		// '▜'
		0x259c { quadrant(metrics, mut canvas, Quads.from_int(quad_tl | quad_tr | quad_br)) }
		// '▝'
		0x259d { quadrant(metrics, mut canvas, Quads.from_int(quad_tr)) }
		// '▞'
		0x259e { quadrant(metrics, mut canvas, Quads.from_int(quad_tr | quad_bl)) }
		// '▟'
		0x259f { quadrant(metrics, mut canvas, Quads.from_int(quad_tr | quad_bl | quad_br)) }
		else { panic('unreachable') }
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
	if quads.tl() {
		fill(metrics, mut canvas, .zero, .half_, .zero, .half_)
	}
	if quads.tr() {
		fill(metrics, mut canvas, .half_, .full, .zero, .half_)
	}
	if quads.bl() {
		fill(metrics, mut canvas, .zero, .half_, .half_, .full)
	}
	if quads.br() {
		fill(metrics, mut canvas, .half_, .full, .half_, .full)
	}
}

// ============================================================
// Box Drawing | U+2500...U+257F
// Translated from ghostty/src/font/sprite/draw/box.zig
// ============================================================

// draw_2500_257f dispatches drawing for box-drawing characters.
pub fn draw_2500_257f(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// '─'
		0x2500 { lines_char(metrics, mut canvas, Lines.from_int(0x44)) }
		// '━'
		0x2501 { lines_char(metrics, mut canvas, Lines.from_int(0x88)) }
		// '│'
		0x2502 { lines_char(metrics, mut canvas, Lines.from_int(0x11)) }
		// '┃'
		0x2503 { lines_char(metrics, mut canvas, Lines.from_int(0x22)) }
		// '┄'
		0x2504 {
			dash_horizontal(metrics, mut canvas, 3, Thickness.light.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┅'
		0x2505 {
			dash_horizontal(metrics, mut canvas, 3, Thickness.heavy.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┆'
		0x2506 {
			dash_vertical(metrics, mut canvas, 3, Thickness.light.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┇'
		0x2507 {
			dash_vertical(metrics, mut canvas, 3, Thickness.heavy.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┈'
		0x2508 {
			dash_horizontal(metrics, mut canvas, 4, Thickness.light.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┉'
		0x2509 {
			dash_horizontal(metrics, mut canvas, 4, Thickness.heavy.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┊'
		0x250a {
			dash_vertical(metrics, mut canvas, 4, Thickness.light.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┋'
		0x250b {
			dash_vertical(metrics, mut canvas, 4, Thickness.heavy.height(metrics.box_thickness), max_u32(4, Thickness.light.height(metrics.box_thickness)))
		}

		// '┌'
		0x250c { lines_char(metrics, mut canvas, Lines.from_int(0x14)) }
		// '┍'
		0x250d { lines_char(metrics, mut canvas, Lines.from_int(0x18)) }
		// '┎'
		0x250e { lines_char(metrics, mut canvas, Lines.from_int(0x24)) }
		// '┏'
		0x250f { lines_char(metrics, mut canvas, Lines.from_int(0x28)) }

		// '┐'
		0x2510 { lines_char(metrics, mut canvas, Lines.from_int(0x50)) }
		// '┑'
		0x2511 { lines_char(metrics, mut canvas, Lines.from_int(0x90)) }
		// '┒'
		0x2512 { lines_char(metrics, mut canvas, Lines.from_int(0x60)) }
		// '┓'
		0x2513 { lines_char(metrics, mut canvas, Lines.from_int(0xa0)) }
		// '└'
		0x2514 { lines_char(metrics, mut canvas, Lines.from_int(0x05)) }
		// '┕'
		0x2515 { lines_char(metrics, mut canvas, Lines.from_int(0x09)) }
		// '┖'
		0x2516 { lines_char(metrics, mut canvas, Lines.from_int(0x06)) }
		// '┗'
		0x2517 { lines_char(metrics, mut canvas, Lines.from_int(0x0a)) }
		// '┘'
		0x2518 { lines_char(metrics, mut canvas, Lines.from_int(0x41)) }
		// '┙'
		0x2519 { lines_char(metrics, mut canvas, Lines.from_int(0x81)) }
		// '┚'
		0x251a { lines_char(metrics, mut canvas, Lines.from_int(0x42)) }
		// '┛'
		0x251b { lines_char(metrics, mut canvas, Lines.from_int(0x82)) }
		// '├'
		0x251c { lines_char(metrics, mut canvas, Lines.from_int(0x15)) }
		// '┝'
		0x251d { lines_char(metrics, mut canvas, Lines.from_int(0x19)) }
		// '┞'
		0x251e { lines_char(metrics, mut canvas, Lines.from_int(0x16)) }
		// '┟'
		0x251f { lines_char(metrics, mut canvas, Lines.from_int(0x25)) }

		// '┠'
		0x2520 { lines_char(metrics, mut canvas, Lines.from_int(0x26)) }
		// '┡'
		0x2521 { lines_char(metrics, mut canvas, Lines.from_int(0x1a)) }
		// '┢'
		0x2522 { lines_char(metrics, mut canvas, Lines.from_int(0x29)) }
		// '┣'
		0x2523 { lines_char(metrics, mut canvas, Lines.from_int(0x2a)) }
		// '┤'
		0x2524 { lines_char(metrics, mut canvas, Lines.from_int(0x51)) }
		// '┥'
		0x2525 { lines_char(metrics, mut canvas, Lines.from_int(0x91)) }
		// '┦'
		0x2526 { lines_char(metrics, mut canvas, Lines.from_int(0x52)) }
		// '┧'
		0x2527 { lines_char(metrics, mut canvas, Lines.from_int(0x61)) }
		// '┨'
		0x2528 { lines_char(metrics, mut canvas, Lines.from_int(0x62)) }
		// '┩'
		0x2529 { lines_char(metrics, mut canvas, Lines.from_int(0x92)) }
		// '┪'
		0x252a { lines_char(metrics, mut canvas, Lines.from_int(0xa1)) }
		// '┫'
		0x252b { lines_char(metrics, mut canvas, Lines.from_int(0xa2)) }
		// '┬'
		0x252c {
			lines_char(metrics, mut canvas, Lines.from_int(0x54))
		}

		// '┭'
		0x252d {
			lines_char(metrics, mut canvas, Lines.from_int(0x94))
		}

		// '┮'
		0x252e {
			lines_char(metrics, mut canvas, Lines.from_int(0x58))
		}

		// '┯'
		0x252f {
			lines_char(metrics, mut canvas, Lines.from_int(0x98))
		}

		// '┰'
		0x2530 {
			lines_char(metrics, mut canvas, Lines.from_int(0x64))
		}

		// '┱'
		0x2531 {
			lines_char(metrics, mut canvas, Lines.from_int(0xa4))
		}

		// '┲'
		0x2532 {
			lines_char(metrics, mut canvas, Lines.from_int(0x68))
		}

		// '┳'
		0x2533 {
			lines_char(metrics, mut canvas, Lines.from_int(0xa8))
		}

		// '┴'
		0x2534 { lines_char(metrics, mut canvas, Lines.from_int(0x45)) }
		// '┵'
		0x2535 { lines_char(metrics, mut canvas, Lines.from_int(0x85)) }
		// '┶'
		0x2536 { lines_char(metrics, mut canvas, Lines.from_int(0x49)) }
		// '┷'
		0x2537 { lines_char(metrics, mut canvas, Lines.from_int(0x89)) }
		// '┸'
		0x2538 { lines_char(metrics, mut canvas, Lines.from_int(0x46)) }
		// '┹'
		0x2539 { lines_char(metrics, mut canvas, Lines.from_int(0x86)) }
		// '┺'
		0x253a { lines_char(metrics, mut canvas, Lines.from_int(0x4a)) }
		// '┻'
		0x253b { lines_char(metrics, mut canvas, Lines.from_int(0x8a)) }
		// '┼'
		0x253c {
			lines_char(metrics, mut canvas, Lines.from_int(0x55))
		}

		// '┽'
		0x253d {
			lines_char(metrics, mut canvas, Lines.from_int(0x95))
		}

		// '┾'
		0x253e {
			lines_char(metrics, mut canvas, Lines.from_int(0x59))
		}

		// '┿'
		0x253f {
			lines_char(metrics, mut canvas, Lines.from_int(0x99))
		}

		// '╀'
		0x2540 {
			lines_char(metrics, mut canvas, Lines.from_int(0x56))
		}

		// '╁'
		0x2541 {
			lines_char(metrics, mut canvas, Lines.from_int(0x65))
		}

		// '╂'
		0x2542 {
			lines_char(metrics, mut canvas, Lines.from_int(0x66))
		}

		// '╃'
		0x2543 {
			lines_char(metrics, mut canvas, Lines.from_int(0x96))
		}

		// '╄'
		0x2544 {
			lines_char(metrics, mut canvas, Lines.from_int(0x5a))
		}

		// '╅'
		0x2545 {
			lines_char(metrics, mut canvas, Lines.from_int(0xa5))
		}

		// '╆'
		0x2546 {
			lines_char(metrics, mut canvas, Lines.from_int(0x69))
		}

		// '╇'
		0x2547 {
			lines_char(metrics, mut canvas, Lines.from_int(0x9a))
		}

		// '╈'
		0x2548 {
			lines_char(metrics, mut canvas, Lines.from_int(0xa9))
		}

		// '╉'
		0x2549 {
			lines_char(metrics, mut canvas, Lines.from_int(0xa6))
		}

		// '╊'
		0x254a {
			lines_char(metrics, mut canvas, Lines.from_int(0x6a))
		}

		// '╋'
		0x254b {
			lines_char(metrics, mut canvas, Lines.from_int(0xaa))
		}

		// '╌'
		0x254c {
			dash_horizontal(metrics, mut canvas, 2, Thickness.light.height(metrics.box_thickness), Thickness.light.height(metrics.box_thickness))
		}

		// '╍'
		0x254d {
			dash_horizontal(metrics, mut canvas, 2, Thickness.heavy.height(metrics.box_thickness), Thickness.heavy.height(metrics.box_thickness))
		}

		// '╎'
		0x254e {
			dash_vertical(metrics, mut canvas, 2, Thickness.light.height(metrics.box_thickness), Thickness.heavy.height(metrics.box_thickness))
		}

		// '╏'
		0x254f {
			dash_vertical(metrics, mut canvas, 2, Thickness.heavy.height(metrics.box_thickness), Thickness.heavy.height(metrics.box_thickness))
		}

		// '═'
		0x2550 { lines_char(metrics, mut canvas, Lines.from_int(0xcc)) }
		// '║'
		0x2551 { lines_char(metrics, mut canvas, Lines.from_int(0x33)) }
		// '╒'
		0x2552 { lines_char(metrics, mut canvas, Lines.from_int(0x1c)) }
		// '╓'
		0x2553 { lines_char(metrics, mut canvas, Lines.from_int(0x34)) }
		// '╔'
		0x2554 { lines_char(metrics, mut canvas, Lines.from_int(0x3c)) }
		// '╕'
		0x2555 { lines_char(metrics, mut canvas, Lines.from_int(0xd0)) }
		// '╖'
		0x2556 { lines_char(metrics, mut canvas, Lines.from_int(0x70)) }
		// '╗'
		0x2557 { lines_char(metrics, mut canvas, Lines.from_int(0xf0)) }
		// '╘'
		0x2558 { lines_char(metrics, mut canvas, Lines.from_int(0x0d)) }
		// '╙'
		0x2559 { lines_char(metrics, mut canvas, Lines.from_int(0x07)) }
		// '╚'
		0x255a { lines_char(metrics, mut canvas, Lines.from_int(0x0f)) }
		// '╛'
		0x255b { lines_char(metrics, mut canvas, Lines.from_int(0xc1)) }
		// '╜'
		0x255c { lines_char(metrics, mut canvas, Lines.from_int(0x43)) }
		// '╝'
		0x255d { lines_char(metrics, mut canvas, Lines.from_int(0xc3)) }
		// '╞'
		0x255e {
			lines_char(metrics, mut canvas, Lines.from_int(0x1d))
		}

		// '╟'
		0x255f {
			lines_char(metrics, mut canvas, Lines.from_int(0x37))
		}

		// '╠'
		0x2560 {
			lines_char(metrics, mut canvas, Lines.from_int(0x3f))
		}

		// '╡'
		0x2561 {
			lines_char(metrics, mut canvas, Lines.from_int(0xd1))
		}

		// '╢'
		0x2562 {
			lines_char(metrics, mut canvas, Lines.from_int(0x73))
		}

		// '╣'
		0x2563 {
			lines_char(metrics, mut canvas, Lines.from_int(0xf3))
		}

		// '╤'
		0x2564 {
			lines_char(metrics, mut canvas, Lines.from_int(0xdc))
		}

		// '╥'
		0x2565 {
			lines_char(metrics, mut canvas, Lines.from_int(0x74))
		}

		// '╦'
		0x2566 {
			lines_char(metrics, mut canvas, Lines.from_int(0xfc))
		}

		// '╧'
		0x2567 {
			lines_char(metrics, mut canvas, Lines.from_int(0xcd))
		}

		// '╨'
		0x2568 {
			lines_char(metrics, mut canvas, Lines.from_int(0x47))
		}

		// '╩'
		0x2569 {
			lines_char(metrics, mut canvas, Lines.from_int(0xcf))
		}

		// '╪'
		0x256a {
			lines_char(metrics, mut canvas, Lines.from_int(0xdd))
		}

		// '╫'
		0x256b {
			lines_char(metrics, mut canvas, Lines.from_int(0x77))
		}

		// '╬'
		0x256c {
			lines_char(metrics, mut canvas, Lines.from_int(0xff))
		}

		// '╭'
		0x256d { box_arc(metrics, mut canvas, .br, .light)! }
		// '╮'
		0x256e { box_arc(metrics, mut canvas, .bl, .light)! }
		// '╯'
		0x256f { box_arc(metrics, mut canvas, .tl, .light)! }

		// '╰'
		0x2570 { box_arc(metrics, mut canvas, .tr, .light)! }
		// '╱'
		0x2571 { light_diagonal_upper_right_to_lower_left(metrics, mut canvas) }
		// '╲'
		0x2572 { light_diagonal_upper_left_to_lower_right(metrics, mut canvas) }
		// '╳'
		0x2573 { light_diagonal_cross(metrics, mut canvas) }
		// '╴'
		0x2574 { lines_char(metrics, mut canvas, Lines.from_int(0x40)) }
		// '╵'
		0x2575 { lines_char(metrics, mut canvas, Lines.from_int(0x01)) }
		// '╶'
		0x2576 { lines_char(metrics, mut canvas, Lines.from_int(0x04)) }
		// '╷'
		0x2577 { lines_char(metrics, mut canvas, Lines.from_int(0x10)) }
		// '╸'
		0x2578 { lines_char(metrics, mut canvas, Lines.from_int(0x80)) }
		// '╹'
		0x2579 { lines_char(metrics, mut canvas, Lines.from_int(0x02)) }
		// '╺'
		0x257a { lines_char(metrics, mut canvas, Lines.from_int(0x08)) }
		// '╻'
		0x257b { lines_char(metrics, mut canvas, Lines.from_int(0x20)) }
		// '╼'
		0x257c { lines_char(metrics, mut canvas, Lines.from_int(0x48)) }
		// '╽'
		0x257d { lines_char(metrics, mut canvas, Lines.from_int(0x21)) }
		// '╾'
		0x257e { lines_char(metrics, mut canvas, Lines.from_int(0x84)) }
		// '╿'
		0x257f { lines_char(metrics, mut canvas, Lines.from_int(0x12)) }
		else { panic('unreachable') }
	}
}

// max_u32 returns the larger of two u32 values.
fn max_u32(a u32, b u32) u32 {
	return if a > b { a } else { b }
}

// lines_char draws a traditional intersection-style box-drawing character,
// which can have a different style of line from each edge to the center.
pub fn lines_char(metrics font.Metrics, mut canvas Canvas, lines Lines) {
	light_px := Thickness.light.height(metrics.box_thickness)
	heavy_px := Thickness.heavy.height(metrics.box_thickness)
	up := lines.up()
	right := lines.right()
	down := lines.down()
	left := lines.left()

	// Top of light horizontal strokes
	h_light_top := sat_sub(metrics.cell_height, light_px) / 2
	// Bottom of light horizontal strokes
	h_light_bottom := sat_add(h_light_top, light_px)

	// Top of heavy horizontal strokes
	h_heavy_top := sat_sub(metrics.cell_height, heavy_px) / 2
	// Bottom of heavy horizontal strokes
	h_heavy_bottom := sat_add(h_heavy_top, heavy_px)

	// Top of the top doubled horizontal stroke (bottom is `h_light_top`)
	h_double_top := sat_sub(h_light_top, light_px)
	// Bottom of the bottom doubled horizontal stroke (top is `h_light_bottom`)
	h_double_bottom := sat_add(h_light_bottom, light_px)

	// Left of light vertical strokes
	v_light_left := sat_sub(metrics.cell_width, light_px) / 2
	// Right of light vertical strokes
	v_light_right := sat_add(v_light_left, light_px)

	// Left of heavy vertical strokes
	v_heavy_left := sat_sub(metrics.cell_width, heavy_px) / 2
	// Right of heavy vertical strokes
	v_heavy_right := sat_add(v_heavy_left, heavy_px)

	// Left of the left doubled vertical stroke (right is `v_light_left`)
	v_double_left := sat_sub(v_light_left, light_px)
	// Right of the right doubled vertical stroke (left is `v_light_right`)
	v_double_right := sat_add(v_light_right, light_px)

	// The bottom of the up line
	up_bottom := if left == .heavy || right == .heavy {
		h_heavy_bottom
	} else if left != right || down == up {
		if left == .double_ || right == .double_ {
			h_double_bottom
		} else {
			h_light_bottom
		}
	} else if left == .none_ && right == .none_ {
		h_light_bottom
	} else {
		h_light_top
	}

	// The top of the down line
	down_top := if left == .heavy || right == .heavy {
		h_heavy_top
	} else if left != right || up == down {
		if left == .double_ || right == .double_ {
			h_double_top
		} else {
			h_light_top
		}
	} else if left == .none_ && right == .none_ {
		h_light_top
	} else {
		h_light_bottom
	}

	// The right of the left line
	left_right := if up == .heavy || down == .heavy {
		v_heavy_right
	} else if up != down || left == right {
		if up == .double_ || down == .double_ {
			v_double_right
		} else {
			v_light_right
		}
	} else if up == .none_ && down == .none_ {
		v_light_right
	} else {
		v_light_left
	}

	// The left of the right line
	right_left := if up == .heavy || down == .heavy {
		v_heavy_left
	} else if up != down || right == left {
		if up == .double_ || down == .double_ {
			v_double_left
		} else {
			v_light_left
		}
	} else if up == .none_ && down == .none_ {
		v_light_left
	} else {
		v_light_right
	}

	match up {
		.none_ {}
		.light {
			canvas.draw_box(i32(v_light_left), 0, i32(v_light_right), i32(up_bottom), .on)
		}
		.heavy {
			canvas.draw_box(i32(v_heavy_left), 0, i32(v_heavy_right), i32(up_bottom), .on)
		}
		.double_ {
			left_bottom := if left == .double_ { h_light_top } else { up_bottom }
			right_bottom := if right == .double_ { h_light_top } else { up_bottom }
			canvas.draw_box(i32(v_double_left), 0, i32(v_light_left), i32(left_bottom), .on)
			canvas.draw_box(i32(v_light_right), 0, i32(v_double_right), i32(right_bottom), .on)
		}
	}

	match right {
		.none_ {}
		.light {
			canvas.draw_box(i32(right_left), i32(h_light_top), i32(metrics.cell_width), i32(h_light_bottom), .on)
		}
		.heavy {
			canvas.draw_box(i32(right_left), i32(h_heavy_top), i32(metrics.cell_width), i32(h_heavy_bottom), .on)
		}
		.double_ {
			top_left := if up == .double_ { v_light_right } else { right_left }
			bottom_left := if down == .double_ { v_light_right } else { right_left }
			canvas.draw_box(i32(top_left), i32(h_double_top), i32(metrics.cell_width), i32(h_light_top), .on)
			canvas.draw_box(i32(bottom_left), i32(h_light_bottom), i32(metrics.cell_width), i32(h_double_bottom), .on)
		}
	}

	match down {
		.none_ {}
		.light {
			canvas.draw_box(i32(v_light_left), i32(down_top), i32(v_light_right), i32(metrics.cell_height), .on)
		}
		.heavy {
			canvas.draw_box(i32(v_heavy_left), i32(down_top), i32(v_heavy_right), i32(metrics.cell_height), .on)
		}
		.double_ {
			left_top := if left == .double_ { h_light_bottom } else { down_top }
			right_top := if right == .double_ { h_light_bottom } else { down_top }
			canvas.draw_box(i32(v_double_left), i32(left_top), i32(v_light_left), i32(metrics.cell_height), .on)
			canvas.draw_box(i32(v_light_right), i32(right_top), i32(v_double_right), i32(metrics.cell_height), .on)
		}
	}

	match left {
		.none_ {}
		.light {
			canvas.draw_box(0, i32(h_light_top), i32(left_right), i32(h_light_bottom), .on)
		}
		.heavy {
			canvas.draw_box(0, i32(h_heavy_top), i32(left_right), i32(h_heavy_bottom), .on)
		}
		.double_ {
			top_right := if up == .double_ { v_light_left } else { left_right }
			bottom_right := if down == .double_ { v_light_left } else { left_right }
			canvas.draw_box(0, i32(h_double_top), i32(top_right), i32(h_light_top), .on)
			canvas.draw_box(0, i32(h_light_bottom), i32(bottom_right), i32(h_double_bottom), .on)
		}
	}
}

// light_diagonal_cross draws '╳' (both light diagonals).
// The two diagonal helpers themselves live in common.v (from common.zig).
pub fn light_diagonal_cross(metrics font.Metrics, mut canvas Canvas) {
	light_diagonal_upper_right_to_lower_left(metrics, mut canvas)
	light_diagonal_upper_left_to_lower_right(metrics, mut canvas)
}

// box_arc draws a rounded box-drawing corner (╭╮╯╰) using a Bezier arc.
// Translated from ghostty box.zig `arc`.
pub fn box_arc(metrics font.Metrics, mut canvas Canvas, corner Corner, thickness Thickness) ! {
	thick_px := thickness.height(metrics.box_thickness)
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)
	float_thick := f64(thick_px)
	center_x := f64(sat_sub(metrics.cell_width, thick_px) / 2) + float_thick / 2
	center_y := f64(sat_sub(metrics.cell_height, thick_px) / 2) + float_thick / 2

	r := math.min(float_width, float_height) / 2

	// Fraction away from the center to place the middle control points.
	s := f64(0.25)

	mut path := canvas.static_path(4)

	match corner {
		.tl {
			path.move_to(center_x, 0)
			path.line_to(center_x, center_y - r)
			path.curve_to(center_x, center_y - s * r, center_x - s * r, center_y, center_x - r, center_y)
			path.line_to(0, center_y)
		}
		.tr {
			path.move_to(center_x, 0)
			path.line_to(center_x, center_y - r)
			path.curve_to(center_x, center_y - s * r, center_x + s * r, center_y, center_x + r, center_y)
			path.line_to(float_width, center_y)
		}
		.bl {
			path.move_to(center_x, float_height)
			path.line_to(center_x, center_y + r)
			path.curve_to(center_x, center_y + s * r, center_x - s * r, center_y, center_x - r, center_y)
			path.line_to(0, center_y)
		}
		.br {
			path.move_to(center_x, float_height)
			path.line_to(center_x, center_y + r)
			path.curve_to(center_x, center_y + s * r, center_x + s * r, center_y, center_x + r, center_y)
			path.line_to(float_width, center_y)
		}
	}

	canvas.stroke_path(path.wrapped_path, StrokeOptions{
		line_cap_mode: .butt
		line_width: float_thick
	}, .on)!
}

// dash_horizontal draws a horizontal dashed line with `count` dashes.
// Translated from ghostty box.zig `dashHorizontal`.
fn dash_horizontal(metrics font.Metrics, mut canvas Canvas, count u8, thick_px u32, desired_gap u32) {
	// Our dashed line should be made such that when tiled horizontally
	// it creates one consistent line with no uneven gap or segment sizes.
	// In order to make sure this is the case, we should have half-sized
	// gaps on the left and right so that it is centered properly.

	// For N dashes, there are N - 1 gaps between them, but we also have
	// half-sized gaps on either side, adding up to N total gaps.
	gap_count := i32(count)

	// We need at least 1 pixel for each gap and each dash, if we don't
	// have that then we can't draw our dashed line correctly so we just
	// draw a solid line and return.
	if metrics.cell_width < u32(count) + u32(count) {
		hline_middle(metrics, mut canvas, .light)
		return
	}

	// We never want the gaps to take up more than 50% of the space,
	// because if they do the dashes are too small and look wrong.
	gap_width := i32(min_u32(desired_gap, metrics.cell_width / (2 * u32(count))))
	total_gap_width := gap_count * gap_width
	total_dash_width := i32(metrics.cell_width) - total_gap_width
	dash_width := total_dash_width / i32(count)
	remaining := total_dash_width % i32(count)

	// Our dashes should be centered vertically.
	y := i32(sat_sub(metrics.cell_height, thick_px) / 2)

	// We start at half a gap from the left edge, in order to center
	// our dashes properly.
	mut x := gap_width / 2

	// We'll distribute the extra space in to dash widths, 1px at a time.
	mut extra := remaining

	for _ in 0 .. count {
		mut x1 := x + dash_width
		// We distribute left-over size in to dash widths.
		if extra > 0 {
			extra -= 1
			x1 += 1
		}
		hline(mut canvas, x, x1, y, thick_px)
		// Advance by the width of the dash we drew and the width
		// of a gap to get the start of the next dash.
		x = x1 + gap_width
	}
}

// dash_vertical draws a vertical dashed line with `count` dashes.
// Translated from ghostty box.zig `dashVertical`.
fn dash_vertical(metrics font.Metrics, mut canvas Canvas, count u8, thick_px u32, desired_gap u32) {
	// Our dashed line should be made such that when tiled vertically it
	// creates one consistent line with no uneven gap or segment sizes.
	// In order to make sure this is the case, we should have an extra
	// gap at the bottom.

	// Because of the extra gap at the bottom, there are as many gaps as
	// there are dashes.
	gap_count := i32(count)

	// We need at least 1 pixel for each gap and each dash, if we don't
	// have that then we can't draw our dashed line correctly so we just
	// draw a solid line and return.
	if metrics.cell_height < u32(count) + u32(count) {
		vline_middle(metrics, mut canvas, .light)
		return
	}

	// We never want the gaps to take up more than 50% of the space.
	gap_height := i32(min_u32(desired_gap, metrics.cell_height / (2 * u32(count))))
	total_gap_height := gap_count * gap_height
	total_dash_height := i32(metrics.cell_height) - total_gap_height
	dash_height := total_dash_height / i32(count)
	remaining := total_dash_height % i32(count)

	// Our dashes should be centered horizontally.
	x := i32(sat_sub(metrics.cell_width, thick_px) / 2)

	// We start at the top of the cell.
	mut y := i32(0)

	// We'll distribute the extra space in to dash heights, 1px at a time.
	mut extra := remaining

	for _ in 0 .. count {
		mut y1 := y + dash_height
		// We distribute left-over size in to dash widths.
		if extra > 0 {
			extra -= 1
			y1 += 1
		}
		vline(mut canvas, y, y1, x, thick_px)
		// Advance by the height of the dash we drew and the height
		// of a gap to get the start of the next dash.
		y = y1 + gap_height
	}
}

// min_u32 returns the smaller of two u32 values.
fn min_u32(a u32, b u32) u32 {
	return if a < b { a } else { b }
}
