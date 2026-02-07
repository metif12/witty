module sprite

// This file contains the Canvas type and common helper types
// and functions for drawing sprite font glyphs. These are
// generally applicable to multiple sets of glyphs rather than
// being single-use.
//
// Translated from:
//   ghostty/src/font/sprite/Canvas.zig
//   ghostty/src/font/sprite/draw/common.zig
//   ghostty/src/font/sprite/draw/box.zig (stubs)
//   ghostty/src/font/sprite/draw/block.zig (stubs)
//   ghostty/src/font/sprite/draw/geometric_shapes.zig (stubs)

import font
import math

// ============================================================
// Color
// ============================================================

// Color represents a pixel shade value used for sprite drawing.
pub enum Color as u8 {
	off = 0x00
	light_ = 0x40
	medium = 0x80
	dark = 0xc0
	on = 0xff
}

// ============================================================
// Point / Line / Rect types
// ============================================================

pub struct Point {
pub:
	x f64
	y f64
}

pub struct LineSegment {
pub:
	p0 Point
	p1 Point
}

pub struct SpriteRect {
pub:
	x      i32
	y      i32
	width  i32
	height i32
}

// ============================================================
// Canvas
// ============================================================

// Canvas wraps a pixel surface for drawing sprite font glyphs.
pub struct Canvas {
pub mut:
	width       u32
	height      u32
	padding_x   u32
	padding_y   u32
	clip_top    u32
	clip_left   u32
	clip_right  u32
	clip_bottom u32
	data        []u8
}

// init creates a new Canvas with the given dimensions.
pub fn Canvas.init(w u32, h u32, pad_x u32, pad_y u32) Canvas {
	total := (w + 2 * pad_x) * (h + 2 * pad_y)
	return Canvas{
		width:     w
		height:    h
		padding_x: pad_x
		padding_y: pad_y
		data:      []u8{len: int(total)}
	}
}

// draw_box fills a rectangular region from (x0,y0) to (x1,y1).
pub fn (mut c Canvas) draw_box(x0 i32, y0 i32, x1 i32, y1 i32, color Color) {
	// XTODO: actual pixel filling implementation
	// Should iterate from (x0,y0) to (x1,y1) and set pixels.
	_ = x0
	_ = y0
	_ = x1
	_ = y1
	_ = color
}

// rect fills a rectangle specified by position and size.
pub fn (mut c Canvas) rect(r SpriteRect, color Color) {
	c.draw_box(r.x, r.y, r.x + r.width, r.y + r.height, color)
}

// line draws a line with the given thickness.
pub fn (mut c Canvas) line(l LineSegment, thickness f64, color Color) ! {
	// XTODO: implement line rasterization using z2d or similar.
	_ = l
	_ = thickness
	_ = color
}

// invert inverts all pixels in the canvas.
pub fn (mut c Canvas) invert() {
	// XTODO: invert pixel data (255 - value for each pixel)
}

// pixel sets a single pixel at the given coordinates.
pub fn (mut c Canvas) pixel(x i32, y i32, color Color) {
	// XTODO: implement single pixel write.
	// Should check bounds (including padding) and set the pixel value.
	_ = x
	_ = y
	_ = color
}

// static_path creates a StaticPath for vector path operations.
pub fn (mut c Canvas) static_path(max_nodes int) StaticPath {
	return StaticPath{
		canvas: unsafe { &c }
		nodes:  []PathNode{cap: max_nodes}
	}
}

// fill_path fills a closed path.
pub fn (mut c Canvas) fill_path(path Path, opts FillOptions, color Color) ! {
	// XTODO: path filling implementation using scanline or similar.
	_ = path
	_ = opts
	_ = color
}

// get_context returns a drawing context for the canvas.
pub fn (mut c Canvas) get_context() Context {
	return Context{
		canvas: unsafe { &c }
	}
}

// ============================================================
// Path types
// ============================================================

pub enum PathNodeKind {
	move_to
	line_to
	close
}

pub struct PathNode {
pub:
	kind PathNodeKind
	x    f64
	y    f64
}

pub struct Path {
pub:
	nodes []PathNode
}

pub struct FillOptions {}

// StaticPath is a fixed-capacity path builder.
pub struct StaticPath {
pub mut:
	canvas       &Canvas = unsafe { nil }
	nodes        []PathNode
	wrapped_path Path
}

// move_to adds a move-to node.
pub fn (mut p StaticPath) move_to(x f64, y f64) {
	p.nodes << PathNode{ kind: .move_to, x: x, y: y }
	p.wrapped_path = Path{ nodes: p.nodes }
}

// line_to adds a line-to node.
pub fn (mut p StaticPath) line_to(x f64, y f64) {
	p.nodes << PathNode{ kind: .line_to, x: x, y: y }
	p.wrapped_path = Path{ nodes: p.nodes }
}

// close closes the current path by adding a closing segment
// back to the first point.
pub fn (mut p StaticPath) close() {
	if p.nodes.len > 0 {
		first := p.nodes[0]
		p.nodes << PathNode{ kind: .close, x: first.x, y: first.y }
	}
	p.nodes << PathNode{ kind: .close, x: 0, y: 0 }
	p.wrapped_path = Path{ nodes: p.nodes }
}

// ============================================================
// Context (for arc/circle drawing)
// ============================================================

// Context provides a higher-level drawing interface for paths
// and arcs, similar to a 2D graphics context.
pub struct Context {
pub mut:
	canvas     &Canvas = unsafe { nil }
	line_width f64
}

pub fn (mut ctx Context) deinit() {
	// no-op in stub
}

// SourcePattern for setting drawing source.
pub struct SourcePattern {
pub:
	opaque_pattern OpaquePattern
}

pub struct OpaquePattern {
pub:
	pixel PixelUnion
}

pub struct PixelUnion {
pub:
	alpha8 Alpha8
}

pub struct Alpha8 {
pub:
	a u8
}

pub fn (mut ctx Context) set_source(source SourcePattern) {
	// XTODO: set the drawing source/color
	_ = source
}

pub fn (mut ctx Context) set_line_width(width f64) {
	ctx.line_width = width
}

pub fn (mut ctx Context) arc(x f64, y f64, r f64, start_angle f64, end_angle f64) ! {
	// XTODO: implement arc rasterization
	_ = x
	_ = y
	_ = r
	_ = start_angle
	_ = end_angle
}

pub fn (mut ctx Context) close_path() ! {
	// XTODO: close current subpath
}

pub fn (mut ctx Context) fill() ! {
	// XTODO: fill the current path
}

pub fn (mut ctx Context) stroke() ! {
	// XTODO: stroke the current path
}

// ============================================================
// Thickness
// ============================================================

// The thickness of a line.
pub enum Thickness {
	super_light
	light
	heavy
}

// Calculate the real height of a line based on its
// thickness and a base thickness value. The base
// thickness value is expected to be in pixels.
pub fn (t Thickness) height(base u32) u32 {
	return match t {
		.super_light { if base / 2 > 1 { base / 2 } else { u32(1) } }
		.light { base }
		.heavy { base * 2 }
	}
}

// ============================================================
// Shade
// ============================================================

// Shades.
pub enum Shade as u8 {
	off = 0x00
	light_ = 0x40
	medium = 0x80
	dark = 0xc0
	on = 0xff
}

// ============================================================
// Quads
// ============================================================

// Applicable to any set of glyphs with features
// that may be present or not in each quadrant.
pub struct Quads {
pub:
	tl bool
	tr bool
	bl bool
	br bool
}

// ============================================================
// Corner
// ============================================================

// A corner of a cell.
pub enum Corner {
	tl
	tr
	bl
	br
}

// ============================================================
// Edge
// ============================================================

// An edge of a cell.
pub enum Edge {
	top
	left
	bottom
	right
}

// ============================================================
// HorizontalAlignment / VerticalAlignment / Alignment
// ============================================================

pub enum HorizontalAlignment {
	left
	right
	center
}

pub enum VerticalAlignment {
	top
	bottom
	middle
}

// Alignment of a figure within a cell.
pub struct Alignment {
pub:
	horizontal HorizontalAlignment = .center
	vertical   VerticalAlignment = .middle
}

// Named alignment constants.
pub const align_upper = Alignment{ vertical: .top }
pub const align_lower = Alignment{ vertical: .bottom }
pub const align_left = Alignment{ horizontal: .left }
pub const align_right = Alignment{ horizontal: .right }
pub const align_upper_left = Alignment{ vertical: .top, horizontal: .left }
pub const align_upper_right = Alignment{ vertical: .top, horizontal: .right }
pub const align_lower_left = Alignment{ vertical: .bottom, horizontal: .left }
pub const align_lower_right = Alignment{ vertical: .bottom, horizontal: .right }
pub const align_center = Alignment{}
pub const align_upper_center = align_upper
pub const align_lower_center = align_lower
pub const align_middle_left = align_left
pub const align_middle_right = align_right
pub const align_middle_center = align_center
pub const align_top = align_upper
pub const align_bottom = align_lower
pub const align_center_top = align_top
pub const align_center_bottom = align_bottom
pub const align_top_left = align_upper_left
pub const align_top_right = align_upper_right
pub const align_bottom_left = align_lower_left
pub const align_bottom_right = align_lower_right

// ============================================================
// Fraction
// ============================================================

// A value that indicates some fraction across
// the cell either horizontally or vertically.
//
// This has some redundant names in it so that you can
// use whichever one feels most semantically appropriate.
pub enum Fraction {
	// Names for the min edge
	start
	left
	top
	zero
	// Names based on eighths
	eighth
	one_eighth
	two_eighths
	three_eighths
	four_eighths
	five_eighths
	six_eighths
	seven_eighths
	// Names based on quarters
	quarter
	one_quarter
	two_quarters
	three_quarters
	// Names based on thirds
	third
	one_third
	two_thirds
	// Names based on halves
	half_
	one_half
	// Alternative names for 1/2
	center
	middle
	// Names for the max edge
	end_
	right
	bottom
	one
	full
}

// This can be indexed to get the fraction for i/8.
pub const fraction_eighths = [Fraction.zero, .one_eighth, .two_eighths, .three_eighths,
	.four_eighths, .five_eighths, .six_eighths, .seven_eighths, .one]

// This can be indexed to get the fraction for i/4.
pub const fraction_quarters = [Fraction.zero, .one_quarter, .two_quarters, .three_quarters,
	.one]

// This can be indexed to get the fraction for i/3.
pub const fraction_thirds = [Fraction.zero, .one_third, .two_thirds, .one]

// This can be indexed to get the fraction for i/2.
pub const fraction_halves = [Fraction.zero, .one_half, .one]

// Get a float for the fraction this represents.
pub fn (f Fraction) fraction_val() f64 {
	return match f {
		.start, .left, .top, .zero { 0.0 }
		.eighth, .one_eighth { 0.125 }
		.quarter, .one_quarter, .two_eighths { 0.25 }
		.third, .one_third { 1.0 / 3.0 }
		.three_eighths { 0.375 }
		.half_, .one_half, .two_quarters, .four_eighths, .center, .middle { 0.5 }
		.five_eighths { 0.625 }
		.two_thirds { 2.0 / 3.0 }
		.three_quarters, .six_eighths { 0.75 }
		.seven_eighths { 0.875 }
		.end_, .right, .bottom, .one, .full { 1.0 }
	}
}

// Get the x position for this fraction across a particular
// size (width or height), assuming it will be used as the
// min (left/top) coordinate for a block.
//
// For min coordinates, we want to align with the complementary
// fraction taken from the end, this ensures that rounding evens
// out, so that for example, if size is 7, and we're looking
// at the half line, size - round((1 - 0.5) * size) => 3;
// whereas the max coordinate directly rounds, which means that
// both start -> half and half -> end will be 4px, from
// 0 -> 4 and 3 -> 7.
pub fn (f Fraction) to_min(size u32) i32 {
	s := f64(size)
	return int(s - math.round((1.0 - f.fraction_val()) * s))
}

// Get the x position for this fraction across a particular
// size (width or height), assuming it will be used as the
// max (right/bottom) coordinate for a block.
pub fn (f Fraction) to_max(size u32) i32 {
	s := f64(size)
	return int(math.round(f.fraction_val() * s))
}

// Get this fraction across a particular size (width/height).
// If you need an integer, use to_min or to_max instead, since
// they contain special logic for consistent alignment. This
// is for when you're drawing with paths and don't care about
// pixel alignment.
pub fn (f Fraction) to_float(size u32) f64 {
	return f.fraction_val() * f64(size)
}

// ============================================================
// Utility names for common fractions
// ============================================================

pub const one_eighth_f = f64(0.125)
pub const one_quarter_f = f64(0.25)
pub const one_third_f = 1.0 / 3.0
pub const three_eighths_f = f64(0.375)
pub const half_f = f64(0.5)
pub const five_eighths_f = f64(0.625)
pub const two_thirds_f = 2.0 / 3.0
pub const three_quarters_f = f64(0.75)
pub const seven_eighths_f = f64(0.875)

// ============================================================
// fill function
// ============================================================

// Fill a section of the cell, specified by a
// horizontal and vertical pair of fraction lines.
pub fn fill(metrics font.Metrics, mut canvas Canvas, x0 Fraction, x1 Fraction, y0 Fraction, y1 Fraction) {
	canvas.draw_box(
		x0.to_min(metrics.cell_width),
		y0.to_min(metrics.cell_height),
		x1.to_max(metrics.cell_width),
		y1.to_max(metrics.cell_height),
		.on,
	)
}

// ============================================================
// Helper line functions from common.zig
// ============================================================

// Centered vertical line of the provided thickness.
pub fn vline_middle(metrics font.Metrics, mut canvas Canvas, thickness Thickness) {
	thick_px := thickness.height(metrics.box_thickness)
	vline(mut canvas, 0, i32(metrics.cell_height), i32((metrics.cell_width - thick_px) / 2), thick_px)
}

// Centered horizontal line of the provided thickness.
pub fn hline_middle(metrics font.Metrics, mut canvas Canvas, thickness Thickness) {
	thick_px := thickness.height(metrics.box_thickness)
	hline(mut canvas, 0, i32(metrics.cell_width), i32((metrics.cell_height - thick_px) / 2), thick_px)
}

// Vertical line with the left edge at x, between y1 and y2.
pub fn vline(mut canvas Canvas, y1 i32, y2 i32, x i32, thickness_px u32) {
	canvas.draw_box(x, y1, x + i32(thickness_px), y2, .on)
}

// Horizontal line with the top edge at y, between x1 and x2.
pub fn hline(mut canvas Canvas, x1 i32, x2 i32, y i32, thickness_px u32) {
	canvas.draw_box(x1, y, x2, y + i32(thickness_px), .on)
}

// ============================================================
// Lines struct (for box-drawing line styles)
// ============================================================

pub enum LineStyle {
	none_
	light
	heavy
	double_
}

pub struct Lines {
pub:
	up    LineStyle = .none_
	right LineStyle = .none_
	down  LineStyle = .none_
	left  LineStyle = .none_
}

// ============================================================
// Stub functions from box.zig
// ============================================================

// lines_char draws box-drawing lines with the specified styles.
pub fn lines_char(metrics font.Metrics, mut canvas Canvas, lines Lines) {
	// XTODO: implement box-drawing line rendering.
	// Each direction (up/down/left/right) draws a line from the center
	// of the cell to the respective edge with the given thickness style.
	_ = metrics
	_ = lines
}

// light_diagonal_cross draws a light diagonal cross.
pub fn light_diagonal_cross(metrics font.Metrics, mut canvas Canvas) {
	// XTODO: implement diagonal cross rendering.
	// Draws two diagonal lines from corner to corner.
	_ = metrics
}

// ============================================================
// Stub functions from block.zig
// ============================================================

// block_fill fills a block at the given alignment with fractional
// width and height relative to the cell.
pub fn block_fill(metrics font.Metrics, mut canvas Canvas, alignment Alignment, bwidth f64, bheight f64) {
	// XTODO: implement block fill with alignment.
	// The alignment determines where the block is positioned within the cell,
	// and width/height are fractions of the cell dimensions.
	_ = metrics
	_ = alignment
	_ = bwidth
	_ = bheight
}

// block_shade fills a block at the given alignment with a shade pattern.
pub fn block_shade(metrics font.Metrics, mut canvas Canvas, alignment Alignment, bwidth f64, bheight f64, shade Shade) {
	// XTODO: implement shaded block fill.
	// Similar to block_fill but uses a shade pattern instead of solid fill.
	_ = metrics
	_ = alignment
	_ = bwidth
	_ = bheight
	_ = shade
}

// full_block_shade fills the entire cell with a shade pattern.
pub fn full_block_shade(metrics font.Metrics, mut canvas Canvas, shade Shade) {
	// XTODO: implement full cell shade fill.
	// Fills every pixel in the cell with the given shade level.
	_ = metrics
	_ = shade
}

// ============================================================
// Stub functions from geometric_shapes.zig
// ============================================================

// corner_triangle_shade draws a shaded triangle in a corner of the cell.
pub fn corner_triangle_shade(metrics font.Metrics, mut canvas Canvas, corner Corner, shade Shade) ! {
	// XTODO: implement corner triangle shade rendering.
	// Draws a right triangle filling the specified corner of the cell.
	_ = metrics
	_ = corner
	_ = shade
}
