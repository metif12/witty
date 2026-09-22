module sprite

// This file contains glyph drawing functions for all of the
// non-Unicode sprite glyphs, such as cursors and underlines.
//
// The naming convention in this file differs from the usual
// because the draw functions for special sprites are found by
// having names that exactly match the enum fields in Sprite.
//
// Translated from ghostty/src/font/sprite/draw/special.zig

import sprite_types as font
import math

// underline draws a single underline decoration.
pub fn underline(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp

	// We can go beyond the height of the cell a bit, but
	// we want to be sure never to exceed the height of the
	// canvas, which extends a quarter cell below the cell
	// height.
	y := if metrics.underline_position < height + canvas.padding_y - metrics.underline_thickness {
		metrics.underline_position
	} else {
		height + canvas.padding_y - metrics.underline_thickness
	}

	canvas.rect(SpriteRect{
		x: 0
		y: i32(y)
		width: i32(width)
		height: i32(metrics.underline_thickness)
	}, .on)
}

// underline_double draws a double underline decoration.
pub fn underline_double(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp

	// We can go beyond the height of the cell a bit, but
	// we want to be sure never to exceed the height of the
	// canvas, which extends a quarter cell below the cell
	// height.
	y := if metrics.underline_position < height + canvas.padding_y - 2 * metrics.underline_thickness {
		metrics.underline_position
	} else {
		height + canvas.padding_y - 2 * metrics.underline_thickness
	}

	// We place one underline above the underline position, and one below
	// by one thickness, creating a "negative" underline where the single
	// underline would be placed.
	y_top := if y >= metrics.underline_thickness { y - metrics.underline_thickness } else { u32(0) }
	canvas.rect(SpriteRect{
		x: 0
		y: i32(y_top)
		width: i32(width)
		height: i32(metrics.underline_thickness)
	}, .on)
	canvas.rect(SpriteRect{
		x: 0
		y: i32(y + metrics.underline_thickness)
		width: i32(width)
		height: i32(metrics.underline_thickness)
	}, .on)
}

// underline_dotted draws a dotted underline decoration.
pub fn underline_dotted(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp

	mut ctx := canvas.get_context()
	defer {
		ctx.deinit()
	}

	float_width := f64(width)
	float_height := f64(height)
	float_pos := f64(metrics.underline_position)
	float_thick := f64(metrics.underline_thickness)

	// The diameter will be sqrt2 * the usual underline thickness
	// since otherwise dotted underlines look somewhat anemic.
	sqrt1_2 := 1.0 / math.sqrt2
	radius := sqrt1_2 * float_thick

	// We can go beyond the height of the cell a bit, but
	// we want to be sure never to exceed the height of the
	// canvas, which extends a quarter cell below the cell
	// height.
	padding := f64(canvas.padding_y)
	y := math.min(
		// The center of the underline stem.
		float_pos + 0.5 * float_thick,
		// The lowest we can go on the canvas and not get clipped.
		float_height + padding - math.ceil(radius),
	)

	dot_count := math.max(
		math.min(
			math.min(
				// We should try to have enough dots that the
				// space between them matches their diameter.
				math.ceil(float_width / (4 * radius)),
				// And not enough that the space between
				// each dot is less than their radius.
				math.floor(float_width / (3 * radius)),
			),
			// And definitely not enough that the space
			// between them is less than a single pixel.
			math.floor(float_width / (2 * radius + 1)),
		),
		// And we must have at least one dot per cell.
		1.0,
	)

	// What we essentially do is divide the cell in to
	// dot_count areas with a dot centered in each one.
	mut x := (float_width / dot_count) / 2
	for _ in 0 .. int(dot_count) {
		ctx.arc(x, y, radius, 0.0, math.tau) or {}
		ctx.close_path() or {}
		x += float_width / dot_count
	}

	ctx.fill() or {}
}

// underline_dashed draws a dashed underline decoration.
pub fn underline_dashed(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp

	// We can go beyond the height of the cell a bit, but
	// we want to be sure never to exceed the height of the
	// canvas, which extends a quarter cell below the cell
	// height.
	y := if metrics.underline_position < height + canvas.padding_y - metrics.underline_thickness {
		metrics.underline_position
	} else {
		height + canvas.padding_y - metrics.underline_thickness
	}

	dash_width := width / 3 + 1
	dash_count := (width / dash_width) + 1
	mut i := u32(0)
	for i < dash_count {
		x := i * dash_width
		canvas.rect(SpriteRect{
			x: i32(x)
			y: i32(y)
			width: i32(dash_width)
			height: i32(metrics.underline_thickness)
		}, .on)
		i += 2
	}
}

// underline_curly draws a curly (wavy) underline decoration.
pub fn underline_curly(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp

	mut ctx := canvas.get_context()
	defer {
		ctx.deinit()
	}

	float_width := f64(width)
	float_height := f64(height)
	float_pos := f64(metrics.underline_position)

	// Because of the way we draw the undercurl, we end up making it around 1px
	// thicker than it should be, to fix this we just reduce the thickness by 1.
	//
	// We use a minimum thickness of 0.414 because this empirically produces
	// the nicest undercurls at 1px underline thickness; thinner tends to look
	// too thin compared to straight underlines and has artefacting.
	ctx.line_width = f64(metrics.underline_thickness)

	// Adjacent underlines overlap these rounded caps, while isolated ends
	// look cleaner than they do with butt caps.
	ctx.line_cap_mode = .round_

	// Empirically this looks good.
	amplitude := float_width / math.pi

	// Make sure we don't exceed the drawable area. This can still be outside
	// of the cell by some amount (one quarter of the height), but we don't
	// want underlines to disappear for fonts with bad metadata or when users
	// set their underline position way too low.
	padding := f64(canvas.padding_y)
	top_ := math.min(
		float_pos,
		// The lowest we can draw this and not get clipped.
		float_height + padding - amplitude - ctx.line_width,
	)
	bottom_ := top_ + amplitude

	// Curvature multiplier.
	// To my eye, 0.4 creates a nice smooth wiggle.
	r := 0.4

	center := 0.5 * float_width

	// We create a single cycle of a wave that peaks at the center of the cell.
	ctx.move_to(0, bottom_)
	ctx.curve_to(center * r, bottom_, center - center * r, top_, center, top_)!
	ctx.curve_to(center + center * r, top_, float_width - center * r, bottom_, float_width, bottom_)!
	ctx.stroke()!
}

// strikethrough draws a strikethrough decoration.
pub fn strikethrough(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = height

	canvas.rect(SpriteRect{
		x: 0
		y: i32(metrics.strikethrough_position)
		width: i32(width)
		height: i32(metrics.strikethrough_thickness)
	}, .on)
}

// overline draws an overline decoration.
pub fn overline(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = height

	// We can go beyond the top of the cell a bit, but we
	// want to be sure never to exceed the height of the
	// canvas, which extends a quarter cell above the top
	// of the cell.
	y := if i32(metrics.overline_position) > -i32(canvas.padding_y) {
		i32(metrics.overline_position)
	} else {
		-i32(canvas.padding_y)
	}

	canvas.rect(SpriteRect{
		x: 0
		y: y
		width: i32(width)
		height: i32(metrics.overline_thickness)
	}, .on)
}

// cursor_rect draws a filled rectangle cursor.
pub fn cursor_rect(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = metrics

	canvas.rect(SpriteRect{
		x: 0
		y: 0
		width: i32(width)
		height: i32(height)
	}, .on)
}

// cursor_hollow_rect draws a hollow rectangle cursor.
pub fn cursor_hollow_rect(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp

	// We fill the entire rect and then hollow out the inside, this isn't very
	// efficient but it doesn't need to be and it's the easiest way to write it.
	cursor_thickness := metrics.cursor_thickness
	canvas.rect(SpriteRect{
		x: 0
		y: 0
		width: i32(width)
		height: i32(height)
	}, .on)
	canvas.rect(SpriteRect{
		x: i32(cursor_thickness)
		y: i32(cursor_thickness)
		width: i32(if width > cursor_thickness * 2 { width - cursor_thickness * 2 } else { 0 })
		height: i32(if height > cursor_thickness * 2 { height - cursor_thickness * 2 } else { 0 })
	}, .off)
}

// cursor_bar draws a bar (beam) cursor.
pub fn cursor_bar(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp
	_ = width

	cursor_thickness := metrics.cursor_thickness

	// We place the bar cursor half of its thickness over the left edge of the
	// cell, so that it sits centered between characters, not biased to a side.
	//
	// We round up (add 1 before dividing by 2) because, empirically, having a
	// 1px cursor shifted left a pixel looks better than having it not shifted.
	canvas.rect(SpriteRect{
		x: -i32((cursor_thickness + 1) / 2)
		y: 0
		width: i32(cursor_thickness)
		height: i32(height)
	}, .on)
}

// cursor_underline draws an underline cursor.
pub fn cursor_underline(cp u32, mut canvas Canvas, width u32, height u32, metrics font.Metrics) ! {
	_ = cp

	cursor_thickness := metrics.cursor_thickness

	// We can go beyond the height of the cell a bit, but
	// we want to be sure never to exceed the height of the
	// canvas, which extends a quarter cell below the cell
	// height.
	y := if metrics.underline_position < height + canvas.padding_y - metrics.underline_thickness {
		metrics.underline_position
	} else {
		height + canvas.padding_y - metrics.underline_thickness
	}

	canvas.rect(SpriteRect{
		x: 0
		y: i32(y)
		width: i32(width)
		height: i32(cursor_thickness)
	}, .on)
}
