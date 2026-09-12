module sprite

// Symbols for Legacy Computing | U+1FB00...U+1FBFF
// https://en.wikipedia.org/wiki/Symbols_for_Legacy_Computing
//
// Translated from ghostty/src/font/sprite/draw/symbols_for_legacy_computing.zig

import sprite_types as font
import math

// ============================================================
// SmoothMosaic
// ============================================================

struct SmoothMosaic {
	value u16
}

fn (mosaic SmoothMosaic) tl() bool {
	return mosaic.value & (u16(1) << 0) != 0
}

fn (mosaic SmoothMosaic) ul() bool {
	return mosaic.value & (u16(1) << 1) != 0
}

fn (mosaic SmoothMosaic) ll() bool {
	return mosaic.value & (u16(1) << 2) != 0
}

fn (mosaic SmoothMosaic) bl() bool {
	return mosaic.value & (u16(1) << 3) != 0
}

fn (mosaic SmoothMosaic) bc() bool {
	return mosaic.value & (u16(1) << 4) != 0
}

fn (mosaic SmoothMosaic) br() bool {
	return mosaic.value & (u16(1) << 5) != 0
}

fn (mosaic SmoothMosaic) lr() bool {
	return mosaic.value & (u16(1) << 6) != 0
}

fn (mosaic SmoothMosaic) ur() bool {
	return mosaic.value & (u16(1) << 7) != 0
}

fn (mosaic SmoothMosaic) tr() bool {
	return mosaic.value & (u16(1) << 8) != 0
}

fn (mosaic SmoothMosaic) tc() bool {
	return mosaic.value & (u16(1) << 9) != 0
}

// smooth_mosaic_from creates a SmoothMosaic from a 4-row pattern.
// Each row is a 3-character string where '#' means filled.
// Other characters ('/', '\', '.') represent empty/diagonal areas.
//
// The 10 vertices of the smooth mosaic polygon are:
//   Row 0: [0]=tl  [1]=tc  [2]=tr
//   Row 1: [0]=ul  [1]=--  [2]=ur
//   Row 2: [0]=ll  [1]=--  [2]=lr
//   Row 3: [0]=bl  [1]=bc  [2]=br
//
// Redundant edge vertices (where both neighbors are also filled)
// are removed to produce a clean polygon outline.
fn smooth_mosaic_from(r0 string, r1 string, r2 string, r3 string) SmoothMosaic {
	mut value := u16(0)
	if r0[0] == `#` {
		value |= u16(1) << 0
	}
	if r1[0] == `#` && (r0[0] != `#` || r2[0] != `#`) {
		value |= u16(1) << 1
	}
	if r2[0] == `#` && (r1[0] != `#` || r3[0] != `#`) {
		value |= u16(1) << 2
	}
	if r3[0] == `#` {
		value |= u16(1) << 3
	}
	if r3[1] == `#` && (r3[0] != `#` || r3[2] != `#`) {
		value |= u16(1) << 4
	}
	if r3[2] == `#` {
		value |= u16(1) << 5
	}
	if r2[2] == `#` && (r3[2] != `#` || r1[2] != `#`) {
		value |= u16(1) << 6
	}
	if r1[2] == `#` && (r2[2] != `#` || r0[2] != `#`) {
		value |= u16(1) << 7
	}
	if r0[2] == `#` {
		value |= u16(1) << 8
	}
	if r0[1] == `#` && (r0[2] != `#` || r0[0] != `#`) {
		value |= u16(1) << 9
	}
	return SmoothMosaic{
		value: value
	}
}

struct Sextants {
	value u8
}

fn Sextants.from_int(value u8) Sextants {
	assert value & 0xc0 == 0
	return Sextants{
		value: value
	}
}

fn (sex Sextants) tl() bool {
	return sex.value & (u8(1) << 0) != 0
}

fn (sex Sextants) tr() bool {
	return sex.value & (u8(1) << 1) != 0
}

fn (sex Sextants) ml() bool {
	return sex.value & (u8(1) << 2) != 0
}

fn (sex Sextants) mr() bool {
	return sex.value & (u8(1) << 3) != 0
}

fn (sex Sextants) bl() bool {
	return sex.value & (u8(1) << 4) != 0
}

fn (sex Sextants) br() bool {
	return sex.value & (u8(1) << 5) != 0
}

// ============================================================
// Sextants
// ============================================================

// draw_1fb00_1fb3b draws sextant characters (U+1FB00..U+1FB3B).
// Sextants divide the cell into a 2x3 grid of blocks.
pub fn draw_1fb00_1fb3b(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	assert cp >= 0x1fb00 && cp <= 0x1fb3b
	idx := cp - 0x1fb00
	// The sextant index formula maps codepoints to a 6-bit pattern.
	// Each bit controls one of the six blocks: tl, tr, ml, mr, bl, br.
	sex := Sextants.from_int(u8(idx + (idx / 0x14) + 1))

	if sex.tl() {
		fill(metrics, mut canvas, .zero, .half_, .zero, .one_third)
	}
	if sex.tr() {
		fill(metrics, mut canvas, .half_, .full, .zero, .one_third)
	}
	if sex.ml() {
		fill(metrics, mut canvas, .zero, .half_, .one_third, .two_thirds)
	}
	if sex.mr() {
		fill(metrics, mut canvas, .half_, .full, .one_third, .two_thirds)
	}
	if sex.bl() {
		fill(metrics, mut canvas, .zero, .half_, .two_thirds, .end_)
	}
	if sex.br() {
		fill(metrics, mut canvas, .half_, .full, .two_thirds, .end_)
	}
}

// ============================================================
// Smooth Mosaics
// ============================================================

// draw_1fb3c_1fb67 draws smooth mosaic characters (U+1FB3C..U+1FB67).
// These are triangular/diagonal shapes specified by a hand-written
// lookup table since there is no mathematical pattern in the codepoints.
pub fn draw_1fb3c_1fb67(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	// Hand written lookup table for these shapes since there is
	// no mathematical pattern in the codepoints.
	mosaic := match cp {
		// '🬼'
		0x1fb3c { smooth_mosaic_from('...', '...', '#..', '##.') }
		// '🬽'
		0x1fb3d { smooth_mosaic_from('...', '...', '#\\.', '###') }
		// '🬾'
		0x1fb3e { smooth_mosaic_from('...', '#..', '#\\.', '##.') }
		// '🬿'
		0x1fb3f { smooth_mosaic_from('...', '#..', '##.', '###') }
		// '🭀'
		0x1fb40 { smooth_mosaic_from('#..', '#..', '##.', '##.') }
		// '🭁'
		0x1fb41 { smooth_mosaic_from('/##', '###', '###', '###') }
		// '🭂'
		0x1fb42 { smooth_mosaic_from('./#', '###', '###', '###') }
		// '🭃'
		0x1fb43 { smooth_mosaic_from('.##', '.##', '###', '###') }
		// '🭄'
		0x1fb44 { smooth_mosaic_from('..#', '.##', '###', '###') }
		// '🭅'
		0x1fb45 { smooth_mosaic_from('.##', '.##', '.##', '###') }
		// '🭆'
		0x1fb46 { smooth_mosaic_from('...', './#', '###', '###') }
		// '🭇'
		0x1fb47 { smooth_mosaic_from('...', '...', '..#', '.##') }
		// '🭈'
		0x1fb48 { smooth_mosaic_from('...', '...', './#', '###') }
		// '🭉'
		0x1fb49 { smooth_mosaic_from('...', '..#', './#', '.##') }
		// '🭊'
		0x1fb4a { smooth_mosaic_from('...', '..#', '.##', '###') }
		// '🭋'
		0x1fb4b { smooth_mosaic_from('..#', '..#', '.##', '.##') }
		// '🭌'
		0x1fb4c { smooth_mosaic_from('##\\', '###', '###', '###') }
		// '🭍'
		0x1fb4d { smooth_mosaic_from('#\\.', '###', '###', '###') }
		// '🭎'
		0x1fb4e { smooth_mosaic_from('##.', '##.', '###', '###') }
		// '🭏'
		0x1fb4f { smooth_mosaic_from('#..', '##.', '###', '###') }
		// '🭐'
		0x1fb50 { smooth_mosaic_from('##.', '##.', '##.', '###') }
		// '🭑'
		0x1fb51 { smooth_mosaic_from('...', '#\\.', '###', '###') }
		// '🭒'
		0x1fb52 { smooth_mosaic_from('###', '###', '###', '\\##') }
		// '🭓'
		0x1fb53 { smooth_mosaic_from('###', '###', '###', '.\\#') }
		// '🭔'
		0x1fb54 { smooth_mosaic_from('###', '###', '.##', '.##') }
		// '🭕'
		0x1fb55 { smooth_mosaic_from('###', '###', '.##', '..#') }
		// '🭖'
		0x1fb56 { smooth_mosaic_from('###', '.##', '.##', '.##') }
		// '🭗'
		0x1fb57 { smooth_mosaic_from('##.', '#..', '...', '...') }
		// '🭘'
		0x1fb58 { smooth_mosaic_from('###', '#/.', '...', '...') }
		// '🭙'
		0x1fb59 { smooth_mosaic_from('##.', '#/.', '#..', '...') }
		// '🭚'
		0x1fb5a { smooth_mosaic_from('###', '##.', '#..', '...') }
		// '🭛'
		0x1fb5b { smooth_mosaic_from('##.', '##.', '#..', '#..') }
		// '🭜'
		0x1fb5c { smooth_mosaic_from('###', '###', '#/.', '...') }
		// '🭝'
		0x1fb5d { smooth_mosaic_from('###', '###', '###', '##/') }
		// '🭞'
		0x1fb5e { smooth_mosaic_from('###', '###', '###', '#/.') }
		// '🭟'
		0x1fb5f { smooth_mosaic_from('###', '###', '##.', '##.') }
		// '🭠'
		0x1fb60 { smooth_mosaic_from('###', '###', '##.', '#..') }
		// '🭡'
		0x1fb61 { smooth_mosaic_from('###', '##.', '##.', '##.') }
		// '🭢'
		0x1fb62 { smooth_mosaic_from('.##', '..#', '...', '...') }
		// '🭣'
		0x1fb63 { smooth_mosaic_from('###', '.\\#', '...', '...') }
		// '🭤'
		0x1fb64 { smooth_mosaic_from('.##', '.\\#', '..#', '...') }
		// '🭥'
		0x1fb65 { smooth_mosaic_from('###', '.##', '..#', '...') }
		// '🭦'
		0x1fb66 { smooth_mosaic_from('.##', '.##', '..#', '..#') }
		// '🭧'
		0x1fb67 { smooth_mosaic_from('###', '###', '.\\#', '...') }
		else { panic('unreachable') }
	}

	top_ := f64(0.0)
	upper := Fraction.one_third.to_float(metrics.cell_height)
	lower := Fraction.two_thirds.to_float(metrics.cell_height)
	bottom_ := f64(metrics.cell_height)
	left_ := f64(0.0)
	center_ := Fraction.half_.to_float(metrics.cell_width)
	right_ := f64(metrics.cell_width)

	mut path := canvas.static_path(12)
	if mosaic.tl() {
		path.line_to(left_, top_)
	}
	if mosaic.ul() {
		path.line_to(left_, upper)
	}
	if mosaic.ll() {
		path.line_to(left_, lower)
	}
	if mosaic.bl() {
		path.line_to(left_, bottom_)
	}
	if mosaic.bc() {
		path.line_to(center_, bottom_)
	}
	if mosaic.br() {
		path.line_to(right_, bottom_)
	}
	if mosaic.lr() {
		path.line_to(right_, lower)
	}
	if mosaic.ur() {
		path.line_to(right_, upper)
	}
	if mosaic.tr() {
		path.line_to(right_, top_)
	}
	if mosaic.tc() {
		path.line_to(center_, top_)
	}
	path.close()

	canvas.fill_path(path.wrapped_path, FillOptions{}, .on)!
}

// ============================================================
// Edge triangles and inverted variants
// ============================================================

// draw_1fb68_1fb6f draws edge triangle characters (U+1FB68..U+1FB6F).
// 0x1FB68-0x1FB6B are inverted edge triangles,
// 0x1FB6C-0x1FB6F are regular edge triangles.
pub fn draw_1fb68_1fb6f(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// '🭨'
		0x1fb68 {
			edge_triangle(metrics, mut canvas, .left)!
			canvas.invert()
			// Set the clip so we don't include anything outside of the cell.
			canvas.clip_left = canvas.padding_x
			canvas.clip_right = canvas.padding_x
			canvas.clip_top = canvas.padding_y
			canvas.clip_bottom = canvas.padding_y
		}

		// '🭩'
		0x1fb69 {
			edge_triangle(metrics, mut canvas, .top)!
			canvas.invert()
			// Set the clip so we don't include anything outside of the cell.
			canvas.clip_left = canvas.padding_x
			canvas.clip_right = canvas.padding_x
			canvas.clip_top = canvas.padding_y
			canvas.clip_bottom = canvas.padding_y
		}

		// '🭪'
		0x1fb6a {
			edge_triangle(metrics, mut canvas, .right)!
			canvas.invert()
			// Set the clip so we don't include anything outside of the cell.
			canvas.clip_left = canvas.padding_x
			canvas.clip_right = canvas.padding_x
			canvas.clip_top = canvas.padding_y
			canvas.clip_bottom = canvas.padding_y
		}

		// '🭫'
		0x1fb6b {
			edge_triangle(metrics, mut canvas, .bottom)!
			canvas.invert()
			// Set the clip so we don't include anything outside of the cell.
			canvas.clip_left = canvas.padding_x
			canvas.clip_right = canvas.padding_x
			canvas.clip_top = canvas.padding_y
			canvas.clip_bottom = canvas.padding_y
		}

		// '🭬'
		0x1fb6c {
			edge_triangle(metrics, mut canvas, .left)!
		}

		// '🭭'
		0x1fb6d {
			edge_triangle(metrics, mut canvas, .top)!
		}

		// '🭮'
		0x1fb6e {
			edge_triangle(metrics, mut canvas, .right)!
		}

		// '🭯'
		0x1fb6f {
			edge_triangle(metrics, mut canvas, .bottom)!
		}
		else { panic('unreachable') }
	}
}

// ============================================================
// Vertical one eighth blocks
// ============================================================

// draw_1fb70_1fb75 draws vertical one eighth block characters
// (U+1FB70..U+1FB75). These are thin vertical strips at 1/8 positions.
pub fn draw_1fb70_1fb75(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	n := int(cp + 1 - 0x1fb70)

	fill(
		metrics,
		mut canvas,
		fraction_eighths[n],
		fraction_eighths[n + 1],
		.top,
		.bottom,
	)
}

// ============================================================
// Horizontal one eighth blocks
// ============================================================

// draw_1fb76_1fb7b draws horizontal one eighth block characters
// (U+1FB76..U+1FB7B). These are thin horizontal strips at 1/8 positions.
pub fn draw_1fb76_1fb7b(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	n := int(cp + 1 - 0x1fb76)

	fill(
		metrics,
		mut canvas,
		.left,
		.right,
		fraction_eighths[n],
		fraction_eighths[n + 1],
	)
}

// ============================================================
// Mixed block characters
// ============================================================

// draw_1fb7c_1fb97 draws mixed block characters (U+1FB7C..U+1FB97).
// These include corner eighth blocks, fractional blocks, shade blocks,
// and checkerboard patterns.
pub fn draw_1fb7c_1fb97(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	match cp {
		// '🭼' LEFT AND LOWER ONE EIGHTH BLOCK
		0x1fb7c {
			block_fill(metrics, mut canvas, align_left, one_eighth_f, 1)
			block_fill(metrics, mut canvas, align_lower, 1, one_eighth_f)
		}

		// '🭽' LEFT AND UPPER ONE EIGHTH BLOCK
		0x1fb7d {
			block_fill(metrics, mut canvas, align_left, one_eighth_f, 1)
			block_fill(metrics, mut canvas, align_upper, 1, one_eighth_f)
		}

		// '🭾' RIGHT AND UPPER ONE EIGHTH BLOCK
		0x1fb7e {
			block_fill(metrics, mut canvas, align_right, one_eighth_f, 1)
			block_fill(metrics, mut canvas, align_upper, 1, one_eighth_f)
		}

		// '🭿' RIGHT AND LOWER ONE EIGHTH BLOCK
		0x1fb7f {
			block_fill(metrics, mut canvas, align_right, one_eighth_f, 1)
			block_fill(metrics, mut canvas, align_lower, 1, one_eighth_f)
		}

		// '🮀' UPPER AND LOWER ONE EIGHTH BLOCK
		0x1fb80 {
			block_fill(metrics, mut canvas, align_upper, 1, one_eighth_f)
			block_fill(metrics, mut canvas, align_lower, 1, one_eighth_f)
		}

		// '🮁' Horizontal One Eighth Block 1358
		0x1fb81 {
			// We just call the draw function for each of the relevant codepoints.
			// The first codepoint is actually a lie, it's before the range, but
			// we need it to get the first (0th) block position. This might be a
			// bit brittle, oh well, if it breaks we can fix it.
			draw_1fb76_1fb7b(0x1fb74 + 1, mut canvas, width, height, metrics)!
			draw_1fb76_1fb7b(0x1fb74 + 3, mut canvas, width, height, metrics)!
			draw_1fb76_1fb7b(0x1fb74 + 5, mut canvas, width, height, metrics)!
			draw_1fb76_1fb7b(0x1fb74 + 8, mut canvas, width, height, metrics)!
		}

		// '🮂' UPPER ONE QUARTER BLOCK
		0x1fb82 {
			block_fill(metrics, mut canvas, align_upper, 1, one_quarter_f)
		}

		// '🮃' UPPER THREE EIGHTHS BLOCK
		0x1fb83 {
			block_fill(metrics, mut canvas, align_upper, 1, three_eighths_f)
		}

		// '🮄' UPPER FIVE EIGHTHS BLOCK
		0x1fb84 {
			block_fill(metrics, mut canvas, align_upper, 1, five_eighths_f)
		}

		// '🮅' UPPER THREE QUARTERS BLOCK
		0x1fb85 {
			block_fill(metrics, mut canvas, align_upper, 1, three_quarters_f)
		}

		// '🮆' UPPER SEVEN EIGHTHS BLOCK
		0x1fb86 {
			block_fill(metrics, mut canvas, align_upper, 1, seven_eighths_f)
		}

		// '🮇' RIGHT ONE QUARTER BLOCK
		0x1fb87 {
			block_fill(metrics, mut canvas, align_right, one_quarter_f, 1)
		}

		// '🮈' RIGHT THREE EIGHTHS BLOCK
		0x1fb88 {
			block_fill(metrics, mut canvas, align_right, three_eighths_f, 1)
		}

		// '🮉' RIGHT FIVE EIGHTHS BLOCK
		0x1fb89 {
			block_fill(metrics, mut canvas, align_right, five_eighths_f, 1)
		}

		// '🮊' RIGHT THREE QUARTERS BLOCK
		0x1fb8a {
			block_fill(metrics, mut canvas, align_right, three_quarters_f, 1)
		}

		// '🮋' RIGHT SEVEN EIGHTHS BLOCK
		0x1fb8b {
			block_fill(metrics, mut canvas, align_right, seven_eighths_f, 1)
		}

		// '🮌'
		0x1fb8c {
			block_shade(metrics, mut canvas, align_left, half_f, 1, .medium)
		}

		// '🮍'
		0x1fb8d {
			block_shade(metrics, mut canvas, align_right, half_f, 1, .medium)
		}

		// '🮎'
		0x1fb8e {
			block_shade(metrics, mut canvas, align_upper, 1, half_f, .medium)
		}

		// '🮏'
		0x1fb8f {
			block_shade(metrics, mut canvas, align_lower, 1, half_f, .medium)
		}

		// '🮐'
		0x1fb90 {
			full_block_shade(metrics, mut canvas, .medium)
		}

		// '🮑'
		0x1fb91 {
			full_block_shade(metrics, mut canvas, .medium)
			block_fill(metrics, mut canvas, align_upper, 1, half_f)
		}

		// '🮒'
		0x1fb92 {
			full_block_shade(metrics, mut canvas, .medium)
			block_fill(metrics, mut canvas, align_lower, 1, half_f)
		}
		0x1fb93 {
			// NOTE: This codepoint is currently un-allocated, it's a hole
			//       in the unicode block, so it's safe to just render it
			//       as an empty glyph, probably.
		}

		// '🮔'
		0x1fb94 {
			full_block_shade(metrics, mut canvas, .medium)
			block_fill(metrics, mut canvas, align_right, half_f, 1)
		}

		// '🮕'
		0x1fb95 {
			checkerboard_fill(metrics, mut canvas, 0)
		}

		// '🮖'
		0x1fb96 {
			checkerboard_fill(metrics, mut canvas, 1)
		}

		// '🮗'
		0x1fb97 {
			canvas.draw_box(
				0,
				i32(height / 4),
				i32(width),
				i32(2 * height / 4),
				.on,
			)
			canvas.draw_box(
				0,
				i32(3 * height / 4),
				i32(width),
				i32(height),
				.on,
			)
		}
		else { panic('unreachable') }
	}
}

// ============================================================
// Upper Left to Lower Right Fill
// ============================================================

// draw_1fb98 draws the upper-left to lower-right diagonal fill
// character (U+1FB98). 🮘
pub fn draw_1fb98(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	// Set the clip so we don't include anything outside of the cell.
	canvas.clip_left = canvas.padding_x
	canvas.clip_right = canvas.padding_x
	canvas.clip_top = canvas.padding_y
	canvas.clip_bottom = canvas.padding_y

	// TODO: This doesn't align properly for most cell sizes, fix that.

	thick_px := Thickness.light.height(metrics.box_thickness)
	line_count := metrics.cell_width / (2 * thick_px)

	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)
	float_thick := f64(thick_px)
	stride := math.round(float_width / f64(line_count))

	for ii in u32(0) .. line_count * 2 + 1 {
		i := i32(ii) - i32(line_count)
		top_x := f64(i) * stride
		bottom_x := float_width + top_x
		canvas.line(LineSegment{
			p0: Point{ x: top_x, y: 0 }
			p1: Point{ x: bottom_x, y: float_height }
		}, float_thick, .on) or {}
	}
}

// ============================================================
// Upper Right to Lower Left Fill
// ============================================================

// draw_1fb99 draws the upper-right to lower-left diagonal fill
// character (U+1FB99). 🮙
pub fn draw_1fb99(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	// Set the clip so we don't include anything outside of the cell.
	canvas.clip_left = canvas.padding_x
	canvas.clip_right = canvas.padding_x
	canvas.clip_top = canvas.padding_y
	canvas.clip_bottom = canvas.padding_y

	// TODO: This doesn't align properly for most cell sizes, fix that.

	thick_px := Thickness.light.height(metrics.box_thickness)
	line_count := metrics.cell_width / (2 * thick_px)

	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)
	float_thick := f64(thick_px)
	stride := math.round(float_width / f64(line_count))

	for ii in u32(0) .. line_count * 2 + 1 {
		i := i32(ii) - i32(line_count)
		bottom_x := f64(i) * stride
		top_x := float_width + bottom_x
		canvas.line(LineSegment{
			p0: Point{ x: top_x, y: 0 }
			p1: Point{ x: bottom_x, y: float_height }
		}, float_thick, .on) or {}
	}
}

// ============================================================
// More triangles and corner triangle shades
// ============================================================

// draw_1fb9a_1fb9f draws various triangle and corner triangle
// shade characters (U+1FB9A..U+1FB9F).
pub fn draw_1fb9a_1fb9f(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// '🮚'
		0x1fb9a {
			edge_triangle(metrics, mut canvas, .top)!
			edge_triangle(metrics, mut canvas, .bottom)!
		}

		// '🮛'
		0x1fb9b {
			edge_triangle(metrics, mut canvas, .left)!
			edge_triangle(metrics, mut canvas, .right)!
		}

		// '🮜'
		0x1fb9c {
			corner_triangle_shade(metrics, mut canvas, .tl, .medium)!
		}

		// '🮝'
		0x1fb9d {
			corner_triangle_shade(metrics, mut canvas, .tr, .medium)!
		}

		// '🮞'
		0x1fb9e {
			corner_triangle_shade(metrics, mut canvas, .br, .medium)!
		}

		// '🮟'
		0x1fb9f {
			corner_triangle_shade(metrics, mut canvas, .bl, .medium)!
		}
		else { panic('unreachable') }
	}
}

// ============================================================
// Corner diagonal lines
// ============================================================

// draw_1fba0_1fbae draws corner diagonal line characters
// (U+1FBA0..U+1FBAE). Each character has diagonal lines from
// the center to one or more corners.
pub fn draw_1fba0_1fbae(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// '🮠'
		0x1fba0 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tl)) }
		// '🮡'
		0x1fba1 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tr)) }
		// '🮢'
		0x1fba2 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_bl)) }
		// '🮣'
		0x1fba3 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_br)) }
		// '🮤'
		0x1fba4 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tl | quad_bl)) }
		// '🮥'
		0x1fba5 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tr | quad_br)) }
		// '🮦'
		0x1fba6 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_bl | quad_br)) }
		// '🮧'
		0x1fba7 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tl | quad_tr)) }
		// '🮨'
		0x1fba8 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tl | quad_br)) }
		// '🮩'
		0x1fba9 { corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tr | quad_bl)) }
		// '🮪'
		0x1fbaa {
			corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tr | quad_bl | quad_br))
		}

		// '🮫'
		0x1fbab {
			corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tl | quad_bl | quad_br))
		}

		// '🮬'
		0x1fbac {
			corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tl | quad_tr | quad_br))
		}

		// '🮭'
		0x1fbad {
			corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_tl | quad_tr | quad_bl))
		}

		// '🮮'
		0x1fbae {
			corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quads_mask))
		}
		else { panic('unreachable') }
	}
}

// ============================================================
// Box drawing variant
// ============================================================

// draw_1fbaf draws the heavy vertical light horizontal
// box-drawing character (U+1FBAF). 🮯
pub fn draw_1fbaf(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	lines_char(metrics, mut canvas, Lines.from_int(0x66))
}

// ============================================================
// Diagonal cross variants
// ============================================================

// draw_1fbbd draws the inverted light diagonal cross (U+1FBBD). 🮽
pub fn draw_1fbbd(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	light_diagonal_cross(metrics, mut canvas)
	canvas.invert()
	// Set the clip so we don't include anything outside of the cell.
	canvas.clip_left = canvas.padding_x
	canvas.clip_right = canvas.padding_x
	canvas.clip_top = canvas.padding_y
	canvas.clip_bottom = canvas.padding_y
}

// draw_1fbbe draws the inverted corner diagonal (U+1FBBE). 🮾
pub fn draw_1fbbe(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quad_br))
	canvas.invert()
	// Set the clip so we don't include anything outside of the cell.
	canvas.clip_left = canvas.padding_x
	canvas.clip_right = canvas.padding_x
	canvas.clip_top = canvas.padding_y
	canvas.clip_bottom = canvas.padding_y
}

// draw_1fbbf draws the inverted full corner diagonal (U+1FBBF). 🮿
pub fn draw_1fbbf(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	corner_diagonal_lines(metrics, mut canvas, Quads.from_int(quads_mask))
	canvas.invert()
	// Set the clip so we don't include anything outside of the cell.
	canvas.clip_left = canvas.padding_x
	canvas.clip_right = canvas.padding_x
	canvas.clip_top = canvas.padding_y
	canvas.clip_bottom = canvas.padding_y
}

// ============================================================
// Block width variants
// ============================================================

// draw_1fbce draws the left two-thirds block (U+1FBCE). 🯎
pub fn draw_1fbce(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	block_fill(metrics, mut canvas, align_left, two_thirds_f, 1)
}

// draw_1fbcf draws the left one-third block (U+1FBCF). 🯏
pub fn draw_1fbcf(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width
	_ = height

	block_fill(metrics, mut canvas, align_left, one_third_f, 1)
}

// ============================================================
// Cell diagonals
// ============================================================

// draw_1fbd0_1fbdf draws cell diagonal characters (U+1FBD0..U+1FBDF).
// These are lines connecting various points on the cell edges and center.
pub fn draw_1fbd0_1fbdf(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// '🯐'
		0x1fbd0 { cell_diagonal(metrics, mut canvas, align_middle_right, align_lower_left) }
		// '🯑'
		0x1fbd1 { cell_diagonal(metrics, mut canvas, align_upper_right, align_middle_left) }
		// '🯒'
		0x1fbd2 { cell_diagonal(metrics, mut canvas, align_upper_left, align_middle_right) }
		// '🯓'
		0x1fbd3 { cell_diagonal(metrics, mut canvas, align_middle_left, align_lower_right) }
		// '🯔'
		0x1fbd4 { cell_diagonal(metrics, mut canvas, align_upper_left, align_lower_center) }
		// '🯕'
		0x1fbd5 { cell_diagonal(metrics, mut canvas, align_upper_center, align_lower_right) }
		// '🯖'
		0x1fbd6 { cell_diagonal(metrics, mut canvas, align_upper_right, align_lower_center) }
		// '🯗'
		0x1fbd7 { cell_diagonal(metrics, mut canvas, align_upper_center, align_lower_left) }
		// '🯘'
		0x1fbd8 {
			cell_diagonal(metrics, mut canvas, align_upper_left, align_middle_center)
			cell_diagonal(metrics, mut canvas, align_middle_center, align_upper_right)
		}

		// '🯙'
		0x1fbd9 {
			cell_diagonal(metrics, mut canvas, align_upper_right, align_middle_center)
			cell_diagonal(metrics, mut canvas, align_middle_center, align_lower_right)
		}

		// '🯚'
		0x1fbda {
			cell_diagonal(metrics, mut canvas, align_lower_left, align_middle_center)
			cell_diagonal(metrics, mut canvas, align_middle_center, align_lower_right)
		}

		// '🯛'
		0x1fbdb {
			cell_diagonal(metrics, mut canvas, align_upper_left, align_middle_center)
			cell_diagonal(metrics, mut canvas, align_middle_center, align_lower_left)
		}

		// '🯜'
		0x1fbdc {
			cell_diagonal(metrics, mut canvas, align_upper_left, align_lower_center)
			cell_diagonal(metrics, mut canvas, align_lower_center, align_upper_right)
		}

		// '🯝'
		0x1fbdd {
			cell_diagonal(metrics, mut canvas, align_upper_right, align_middle_left)
			cell_diagonal(metrics, mut canvas, align_middle_left, align_lower_right)
		}

		// '🯞'
		0x1fbde {
			cell_diagonal(metrics, mut canvas, align_lower_left, align_upper_center)
			cell_diagonal(metrics, mut canvas, align_upper_center, align_lower_right)
		}

		// '🯟'
		0x1fbdf {
			cell_diagonal(metrics, mut canvas, align_upper_left, align_middle_right)
			cell_diagonal(metrics, mut canvas, align_middle_right, align_lower_left)
		}
		else { panic('unreachable') }
	}
}

// ============================================================
// Circles
// ============================================================

// draw_1fbe0_1fbef draws circle and block characters (U+1FBE0..U+1FBEF).
// These include half circles (unfilled and filled) at various positions,
// and quarter cell blocks.
pub fn draw_1fbe0_1fbef(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = width
	_ = height

	match cp {
		// '🯠'
		0x1fbe0 { draw_circle(metrics, mut canvas, align_top, false) }
		// '🯡'
		0x1fbe1 { draw_circle(metrics, mut canvas, align_right, false) }
		// '🯢'
		0x1fbe2 { draw_circle(metrics, mut canvas, align_bottom, false) }
		// '🯣'
		0x1fbe3 { draw_circle(metrics, mut canvas, align_left, false) }
		// '🯤'
		0x1fbe4 { block_fill(metrics, mut canvas, align_upper_center, 0.5, 0.5) }
		// '🯥'
		0x1fbe5 { block_fill(metrics, mut canvas, align_lower_center, 0.5, 0.5) }
		// '🯦'
		0x1fbe6 { block_fill(metrics, mut canvas, align_middle_left, 0.5, 0.5) }
		// '🯧'
		0x1fbe7 { block_fill(metrics, mut canvas, align_middle_right, 0.5, 0.5) }
		// '🯨'
		0x1fbe8 { draw_circle(metrics, mut canvas, align_top, true) }
		// '🯩'
		0x1fbe9 { draw_circle(metrics, mut canvas, align_right, true) }
		// '🯪'
		0x1fbea { draw_circle(metrics, mut canvas, align_bottom, true) }
		// '🯫'
		0x1fbeb { draw_circle(metrics, mut canvas, align_left, true) }
		// '🯬'
		0x1fbec { draw_circle(metrics, mut canvas, align_top_right, true) }
		// '🯭'
		0x1fbed { draw_circle(metrics, mut canvas, align_bottom_left, true) }
		// '🯮'
		0x1fbee { draw_circle(metrics, mut canvas, align_bottom_right, true) }
		// '🯯'
		0x1fbef { draw_circle(metrics, mut canvas, align_top_left, true) }
		else { panic('unreachable') }
	}
}

// ============================================================
// Helper functions
// ============================================================

// edge_triangle draws a triangle from the center of the cell to
// an edge.
fn edge_triangle(metrics font.Metrics, mut canvas Canvas, edge Edge) ! {
	upper := f64(0.0)
	middle_y := math.round(f64(metrics.cell_height) / 2)
	lower := f64(metrics.cell_height)
	left_ := f64(0.0)
	center_ := math.round(f64(metrics.cell_width) / 2)
	right_ := f64(metrics.cell_width)

	x0, y0, x1, y1 := match edge {
		.top { right_, upper, left_, upper }
		.left { left_, upper, left_, lower }
		.bottom { left_, lower, right_, lower }
		.right { right_, lower, right_, upper }
	}

	mut path := canvas.static_path(5)
	path.move_to(center_, middle_y)
	path.line_to(x0, y0)
	path.line_to(x1, y1)
	path.close()

	canvas.fill_path(path.wrapped_path, FillOptions{}, .on)!
}

// corner_diagonal_lines draws diagonal lines from the center of the
// cell to the specified corners.
fn corner_diagonal_lines(metrics font.Metrics, mut canvas Canvas, corners Quads) {
	thick_px := Thickness.light.height(metrics.box_thickness)

	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)
	float_thick := f64(thick_px)
	center_x := f64(metrics.cell_width / 2 + metrics.cell_width % 2)
	center_y := f64(metrics.cell_height / 2 + metrics.cell_height % 2)

	if corners.tl() {
		canvas.line(LineSegment{
			p0: Point{ x: center_x, y: 0 }
			p1: Point{ x: 0, y: center_y }
		}, float_thick, .on) or {}
	}

	if corners.tr() {
		canvas.line(LineSegment{
			p0: Point{ x: center_x, y: 0 }
			p1: Point{ x: float_width, y: center_y }
		}, float_thick, .on) or {}
	}

	if corners.bl() {
		canvas.line(LineSegment{
			p0: Point{ x: center_x, y: float_height }
			p1: Point{ x: 0, y: center_y }
		}, float_thick, .on) or {}
	}

	if corners.br() {
		canvas.line(LineSegment{
			p0: Point{ x: center_x, y: float_height }
			p1: Point{ x: float_width, y: center_y }
		}, float_thick, .on) or {}
	}
}

// cell_diagonal draws a diagonal line between two alignment positions.
fn cell_diagonal(metrics font.Metrics, mut canvas Canvas, from Alignment, to Alignment) {
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	x0 := match from.horizontal {
		.left { f64(0) }
		.right { float_width }
		.center { float_width / 2 }
	}
	y0 := match from.vertical {
		.top { f64(0) }
		.bottom { float_height }
		.middle { float_height / 2 }
	}
	x1 := match to.horizontal {
		.left { f64(0) }
		.right { float_width }
		.center { float_width / 2 }
	}
	y1 := match to.vertical {
		.top { f64(0) }
		.bottom { float_height }
		.middle { float_height / 2 }
	}

	canvas.line(
		LineSegment{
			p0: Point{ x: x0, y: y0 }
			p1: Point{ x: x1, y: y1 }
		},
		f64(Thickness.light.height(metrics.box_thickness)),
		.on,
	) or {}
}

// checkerboard_fill fills the cell with a checkerboard pattern.
// parity controls which squares are filled (0 or 1).
fn checkerboard_fill(metrics font.Metrics, mut canvas Canvas, parity u32) {
	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)
	x_size := u32(4)
	y_size := u32(math.round(4 * (float_height / float_width)))
	for x in u32(0) .. x_size {
		x0 := (metrics.cell_width * x) / x_size
		x1 := (metrics.cell_width * (x + 1)) / x_size
		for y in u32(0) .. y_size {
			y0 := (metrics.cell_height * y) / y_size
			y1 := (metrics.cell_height * (y + 1)) / y_size
			if (x + y) % 2 == parity {
				canvas.rect(SpriteRect{
					x: i32(x0)
					y: i32(y0)
					width: i32(if x1 > x0 { x1 - x0 } else { 0 })
					height: i32(if y1 > y0 { y1 - y0 } else { 0 })
				}, .on)
			}
		}
	}
}

// draw_circle draws a circle (or semicircle) at the given position.
// If filled is true, the circle is solid; otherwise it's just an outline.
pub fn draw_circle(metrics font.Metrics, mut canvas Canvas, position Alignment, filled bool) {
	// Set the clip so we don't include anything outside of the cell.
	canvas.clip_left = canvas.padding_x
	canvas.clip_right = canvas.padding_x
	canvas.clip_top = canvas.padding_y
	canvas.clip_bottom = canvas.padding_y

	float_width := f64(metrics.cell_width)
	float_height := f64(metrics.cell_height)

	x := match position.horizontal {
		.left { f64(0) }
		.right { float_width }
		.center { float_width / 2 }
	}
	y := match position.vertical {
		.top { f64(0) }
		.bottom { float_height }
		.middle { float_height / 2 }
	}
	r := 0.5 * math.min(float_width, float_height)

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
	ctx.set_line_width(
		f64(Thickness.light.height(metrics.box_thickness)),
	)

	if filled {
		ctx.arc(x, y, r, 0, math.pi * 2) or { return }
		ctx.close_path() or { return }
		ctx.fill() or { return }
	} else {
		ctx.arc(x, y, r - ctx.line_width / 2, 0, math.pi * 2) or { return }
		ctx.close_path() or { return }
		ctx.stroke() or { return }
	}
}
