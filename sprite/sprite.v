module sprite

// This file contains the Canvas type and common helper types
// and functions for drawing sprite font glyphs. These are
// generally applicable to multiple sets of glyphs rather than
// being single-use.
//
// Translated from:
//   ghostty/src/font/sprite/Canvas.zig
//   ghostty/src/font/sprite/draw/common.zig
//   ghostty/src/font/sprite/draw/box.zig (Lines/linesChar/arc/dashes/diagonals)
//   ghostty/src/font/sprite/draw/block.zig (fill helpers)
//
// The original Ghostty Canvas is backed by the `z2d` 2D vector graphics
// library. We don't have z2d in V, so this file additionally implements
// (faithfully to z2d's semantics) the rasterization primitives that z2d
// provided: scanline polygon fill (non-zero winding, anti-aliased via
// supersampling), path stroking (butt caps, miter joins approximated by
// filling the union of per-segment quads), and cubic Bezier flattening
// for `curveTo`/`arc`.

import font
import math

// ============================================================
// Color
// ============================================================

// Color represents a pixel shade value used for sprite drawing.
// We only use the alpha channel, so a pixel is essentially "on"
// or "off", but intermediate shades are used for the block shade
// characters.
pub enum Color as u8 {
	off    = 0x00
	light_ = 0x40
	medium = 0x80
	dark   = 0xc0
	on     = 0xff
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
// The underlying `data` buffer is a single-channel (alpha8) surface
// of dimensions `(width + 2*padding_x) x (height + 2*padding_y)`.
// All drawing coordinates are cell-relative; the padding offset is
// applied internally.
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

// sfc_width returns the full surface width (including padding).
pub fn (c &Canvas) sfc_width() u32 {
	return c.width + 2 * c.padding_x
}

// sfc_height returns the full surface height (including padding).
pub fn (c &Canvas) sfc_height() u32 {
	return c.height + 2 * c.padding_y
}

// init creates a new Canvas with the given dimensions.
// We add padding to both sides (hence `2 *`).
pub fn Canvas.init(w u32, h u32, pad_x u32, pad_y u32) Canvas {
	total := (w + 2 * pad_x) * (h + 2 * pad_y)
	return Canvas{
		width: w
		height: h
		padding_x: pad_x
		padding_y: pad_y
		data: []u8{len: int(total)}
	}
}

// Draw and fill a single pixel. The coordinate is cell-relative;
// the padding offset is applied here. Out of bounds writes are
// silently ignored, matching z2d's `putPixel` behavior.
pub fn (mut c Canvas) pixel(x i32, y i32, color Color) {
	px := x + i32(c.padding_x)
	py := y + i32(c.padding_y)
	if px < 0 || py < 0 {
		return
	}
	w := i32(c.sfc_width())
	h := i32(c.sfc_height())
	if px >= w || py >= h {
		return
	}
	c.data[py * w + px] = u8(color)
}

// blend_pixel writes an anti-aliased (coverage-weighted) pixel value.
// `alpha` is the coverage in [0,255] scaled by the color intensity.
// We take the maximum with the existing value so overlapping fills of
// the same color don't darken seams (z2d composites with src_over onto
// a transparent surface, but for the single opaque color we draw with,
// max is equivalent and avoids double-counting on shared edges).
fn (mut c Canvas) blend_pixel(px i32, py i32, value u8) {
	if px < 0 || py < 0 {
		return
	}
	w := i32(c.sfc_width())
	h := i32(c.sfc_height())
	if px >= w || py >= h {
		return
	}
	idx := py * w + px
	if value > c.data[idx] {
		c.data[idx] = value
	}
}

// Draw and fill a rectangle. This is the main primitive for drawing
// lines as well (which are just generally skinny rectangles).
pub fn (mut c Canvas) rect(v SpriteRect, color Color) {
	mut y := v.y
	for y < v.y + v.height {
		mut x := v.x
		for x < v.x + v.width {
			c.pixel(x, y, color)
			x += 1
		}
		y += 1
	}
}

// Convenience wrapper for `Canvas.rect`, taking two corners.
// The corners may be given in any order.
pub fn (mut c Canvas) draw_box(x0 i32, y0 i32, x1 i32, y1 i32, color Color) {
	tl_x := if x0 < x1 { x0 } else { x1 }
	tl_y := if y0 < y1 { y0 } else { y1 }
	br_x := if x0 > x1 { x0 } else { x1 }
	br_y := if y0 > y1 { y0 } else { y1 }
	c.rect(SpriteRect{
		x: tl_x
		y: tl_y
		width: br_x - tl_x
		height: br_y - tl_y
	}, color)
}

// Stroke a line of the given thickness.
pub fn (mut c Canvas) line(l LineSegment, thickness f64, color Color) ! {
	mut path := c.static_path(2)
	path.move_to(l.p0.x, l.p0.y)
	path.line_to(l.p1.x, l.p1.y)
	c.stroke_path(path.wrapped_path, StrokeOptions{
		line_cap_mode: .butt
		line_width: thickness
	}, color)!
}

// Draw and fill a quad.
pub fn (mut c Canvas) quad(q Quad, color Color) ! {
	mut path := c.static_path(6)
	path.move_to(q.p0.x, q.p0.y)
	path.line_to(q.p1.x, q.p1.y)
	path.line_to(q.p2.x, q.p2.y)
	path.line_to(q.p3.x, q.p3.y)
	path.close()
	c.fill_path(path.wrapped_path, FillOptions{}, color)!
}

// Draw and fill a triangle.
pub fn (mut c Canvas) triangle(t Triangle, color Color) ! {
	mut path := c.static_path(5)
	path.move_to(t.p0.x, t.p0.y)
	path.line_to(t.p1.x, t.p1.y)
	path.line_to(t.p2.x, t.p2.y)
	path.close()
	c.fill_path(path.wrapped_path, FillOptions{}, color)!
}

// static_path creates a StaticPath for vector path operations.
// Use this function instead of making the path manually since it
// ensures that the padding transformation is applied.
pub fn (mut c Canvas) static_path(max_nodes int) StaticPath {
	return StaticPath{
		canvas: unsafe { &c }
		nodes: []PathNode{cap: max_nodes}
	}
}

// get_context returns a drawing context for the canvas.
pub fn (mut c Canvas) get_context() Context {
	return Context{
		canvas: unsafe { &c }
		line_width: 2.0
	}
}

// Invert all pixels on the canvas.
pub fn (mut c Canvas) invert() {
	for i in 0 .. c.data.len {
		c.data[i] = 255 - c.data[i]
	}
}

// Mirror the canvas horizontally.
pub fn (mut c Canvas) flip_horizontal() {
	w := int(c.sfc_width())
	h := int(c.sfc_height())
	clone := c.data.clone()
	for y in 0 .. h {
		for x in 0 .. w {
			c.data[y * w + x] = clone[y * w + w - x - 1]
		}
	}
	c.clip_left, c.clip_right = c.clip_right, c.clip_left
}

// Mirror the canvas vertically.
pub fn (mut c Canvas) flip_vertical() {
	w := int(c.sfc_width())
	h := int(c.sfc_height())
	clone := c.data.clone()
	for y in 0 .. h {
		for x in 0 .. w {
			c.data[y * w + x] = clone[(h - y - 1) * w + x]
		}
	}
	c.clip_top, c.clip_bottom = c.clip_bottom, c.clip_top
}

// Adjust clip boundaries to trim off any fully transparent rows or columns.
fn (mut c Canvas) trim() {
	width := c.sfc_width()
	height := c.sfc_height()

	// top
	for c.clip_top < height - c.clip_bottom {
		y := c.clip_top
		x0 := c.clip_left
		x1 := width - c.clip_right
		mut found := false
		for x in x0 .. x1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_top += 1
	}

	// bottom
	for c.clip_bottom < height - c.clip_top {
		y := sat_sub(height - c.clip_bottom, 1)
		x0 := c.clip_left
		x1 := width - c.clip_right
		mut found := false
		for x in x0 .. x1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_bottom += 1
	}

	// left
	for c.clip_left < width - c.clip_right {
		x := c.clip_left
		y0 := c.clip_top
		y1 := height - c.clip_bottom
		mut found := false
		for y in y0 .. y1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_left += 1
	}

	// right
	for c.clip_right < width - c.clip_left {
		x := sat_sub(width - c.clip_right, 1)
		y0 := c.clip_top
		y1 := height - c.clip_bottom
		mut found := false
		for y in y0 .. y1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_right += 1
	}
}

// sat_sub is a saturating subtraction for u32 (matches Zig's `-|`).
fn sat_sub(a u32, b u32) u32 {
	return if a > b { a - b } else { u32(0) }
}

// write_atlas writes the data in this drawing to the atlas and returns
// the resulting glyph region. Fully-transparent margins are trimmed
// first so the atlas region is as tight as possible.
//
// The witty `font.Atlas` doesn't expose z2d's reserve/setFromLarger
// allocator, so we perform a simple linear (shelf-free) reservation
// directly into the atlas data buffer. This is sufficient for the
// sprite face since these glyphs are relatively small and few.
pub fn (mut c Canvas) write_atlas(mut atlas font.Atlas) !GlyphRegion {
	c.trim()

	sfc_width := c.sfc_width()
	sfc_height := c.sfc_height()

	// Subtract our clip margins from the width and height to
	// get the region size (saturating, matching Zig's `-|`).
	region_width := sat_sub(sat_sub(sfc_width, c.clip_left), c.clip_right)
	region_height := sat_sub(sat_sub(sfc_height, c.clip_top), c.clip_bottom)

	region := atlas_reserve(mut atlas, region_width, region_height)!

	if region.width > 0 && region.height > 0 {
		// Copy the (trimmed) sub-rectangle of our surface in to the atlas.
		set_from_larger(mut atlas, region, c.data, sfc_width, c.clip_left, c.clip_top)
	}

	return region
}

// ============================================================
// GlyphRegion + minimal atlas allocation
// ============================================================

// A region within the texture atlas.
pub struct GlyphRegion {
pub mut:
	x      u32
	y      u32
	width  u32
	height u32
}

// atlas_reserve reserves a `width x height` region within the atlas,
// growing the atlas if necessary.
//
// The witty `font.Atlas` doesn't expose z2d/ghostty's rectangle-node
// allocator, so — to remain self-contained without module-level state —
// we find a free region by scanning the (initially-zeroed) atlas data
// for a rectangle (plus a 1px transparent border) that is entirely
// empty. Sprite glyphs are small and few, so the scan cost is
// negligible. If no free region is found the atlas is grown and the
// scan retried.
fn atlas_reserve(mut atlas font.Atlas, width u32, height u32) !GlyphRegion {
	// If our width/height are 0, then we return the region as-is. This
	// may seem like an error case but it simplifies downstream callers.
	if width == 0 || height == 0 {
		return GlyphRegion{
			width: width
			height: height
		}
	}

	// We keep a 1px border on all sides to avoid sampling artifacts.
	bordered_w := width + 1
	bordered_h := height + 1

	for {
		size := atlas.size
		if bordered_w + 1 <= size && bordered_h + 1 <= size {
			mut y := u32(1)
			for y + bordered_h <= size {
				mut x := u32(1)
				for x + bordered_w <= size {
					if region_is_free(atlas, x, y, bordered_w, bordered_h) {
						atlas.modified += 1
						return GlyphRegion{
							x: x
							y: y
							width: width
							height: height
						}
					}
					x += 1
				}
				y += 1
			}
		}
		// No space; enlarge the atlas and retry.
		atlas.grow(size * 2)
	}
	return GlyphRegion{}
}

// region_is_free returns true if every pixel in the `w x h` rectangle at
// (x0, y0) in the atlas is currently zero (fully transparent).
fn region_is_free(atlas font.Atlas, x0 u32, y0 u32, w u32, h u32) bool {
	for y in y0 .. y0 + h {
		base := y * atlas.size
		for x in x0 .. x0 + w {
			if atlas.data[base + x] != 0 {
				return false
			}
		}
	}
	return true
}

// set_from_larger copies a `region.width x region.height` sub-rectangle
// out of `src` (which has stride `src_width`, starting at `src_x,src_y`)
// in to the atlas at `region`.
fn set_from_larger(mut atlas font.Atlas, region GlyphRegion, src []u8, src_width u32, src_x u32, src_y u32) {
	bpp := u32(1) // sprite atlas is grayscale
	for row in 0 .. region.height {
		for col in 0 .. region.width {
			s := (src_y + row) * src_width + (src_x + col)
			d := ((region.y + row) * atlas.size + (region.x + col)) * bpp
			if int(s) < src.len && int(d) < atlas.data.len {
				atlas.data[d] = src[s]
			}
		}
	}
}

// ============================================================
// Path types
// ============================================================

pub enum PathNodeKind {
	move_to
	line_to
	curve_to
	close
}

pub struct PathNode {
pub:
	kind PathNodeKind
	x    f64
	y    f64
	// Control points, only used for `curve_to`.
	c1x f64
	c1y f64
	c2x f64
	c2y f64
}

pub struct Path {
pub:
	nodes []PathNode
}

pub struct FillOptions {}

pub enum LineCapMode {
	butt
	round_
	square
}

pub struct StrokeOptions {
pub:
	line_cap_mode LineCapMode = .butt
	line_width    f64 = 2.0
}

// StaticPath is a fixed-capacity path builder. It mirrors z2d's
// `StaticPath` including the automatic transform (padding offset)
// applied to every coordinate.
pub struct StaticPath {
pub mut:
	canvas       &Canvas = unsafe { nil }
	nodes        []PathNode
	wrapped_path Path
}

// px/py apply the padding transformation to a coordinate, matching
// z2d's `wrapped_path.transformation` set in `Canvas.staticPath`.
fn (p &StaticPath) tx(x f64) f64 {
	return x + f64(p.canvas.padding_x)
}

fn (p &StaticPath) ty(y f64) f64 {
	return y + f64(p.canvas.padding_y)
}

// move_to adds a move-to node.
pub fn (mut p StaticPath) move_to(x f64, y f64) {
	p.nodes << PathNode{
		kind: .move_to
		x: p.tx(x)
		y: p.ty(y)
	}
	p.wrapped_path = Path{
		nodes: p.nodes
	}
}

// line_to adds a line-to node.
pub fn (mut p StaticPath) line_to(x f64, y f64) {
	p.nodes << PathNode{
		kind: .line_to
		x: p.tx(x)
		y: p.ty(y)
	}
	p.wrapped_path = Path{
		nodes: p.nodes
	}
}

// curve_to adds a cubic Bezier curve node with the two control points
// (c1, c2) and the end point (x, y). Matches z2d `path.curveTo`.
pub fn (mut p StaticPath) curve_to(c1x f64, c1y f64, c2x f64, c2y f64, x f64, y f64) {
	p.nodes << PathNode{
		kind: .curve_to
		x: p.tx(x)
		y: p.ty(y)
		c1x: p.tx(c1x)
		c1y: p.ty(c1y)
		c2x: p.tx(c2x)
		c2y: p.ty(c2y)
	}
	p.wrapped_path = Path{
		nodes: p.nodes
	}
}

// close closes the current path.
//
// z2d's `StaticPath.close` reserves two nodes (a close node plus an
// implicit move back to the subpath start). We only need one closing
// marker; the rasterizer closes each subpath implicitly, so this
// simply records a `.close`.
pub fn (mut p StaticPath) close() {
	p.nodes << PathNode{
		kind: .close
	}
	p.wrapped_path = Path{
		nodes: p.nodes
	}
}

// ============================================================
// Polygon extraction + Bezier flattening
// ============================================================

// bezier_segments controls how finely cubic Bezier curves are
// flattened in to line segments.
const bezier_segments = 24

// flatten_path converts a Path in to a list of closed polygons (each
// polygon is a list of Points). Bezier curves are flattened in to line
// segments. This is the input to both the fill and stroke rasterizers.
fn flatten_path(path Path) [][]Point {
	mut polys := [][]Point{}
	mut cur := []Point{}
	mut last := Point{}
	for node in path.nodes {
		match node.kind {
			.move_to {
				if cur.len > 0 {
					polys << cur
				}
				cur = []Point{}
				last = Point{
					x: node.x
					y: node.y
				}
				cur << last
			}
			.line_to {
				last = Point{
					x: node.x
					y: node.y
				}
				cur << last
			}
			.curve_to {
				p0 := last
				p1 := Point{
					x: node.c1x
					y: node.c1y
				}
				p2 := Point{
					x: node.c2x
					y: node.c2y
				}
				p3 := Point{
					x: node.x
					y: node.y
				}
				for i in 1 .. bezier_segments + 1 {
					t := f64(i) / f64(bezier_segments)
					cur << cubic_bezier(p0, p1, p2, p3, t)
				}
				last = p3
			}
			.close {
				if cur.len > 0 {
					if cur.len > 1 && (cur.last().x != cur[0].x || cur.last().y != cur[0].y) {
						cur << cur[0]
					}
					polys << cur
					cur = []Point{}
				}
			}
		}
	}
	if cur.len > 0 {
		polys << cur
	}
	return polys
}

// cubic_bezier evaluates a cubic Bezier at parameter t.
fn cubic_bezier(p0 Point, p1 Point, p2 Point, p3 Point, t f64) Point {
	mt := 1.0 - t
	a := mt * mt * mt
	b := 3.0 * mt * mt * t
	c := 3.0 * mt * t * t
	d := t * t * t
	return Point{
		x: a * p0.x + b * p1.x + c * p2.x + d * p3.x
		y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
	}
}

// ============================================================
// Scanline polygon fill (non-zero winding, anti-aliased)
// ============================================================

// Supersampling factor per axis for anti-aliasing. z2d defaults to a
// tolerance-based analytic rasterizer; we approximate with 4x4 vertical
// supersampling which gives visually equivalent smooth edges.
const aa_samples = 4

// fill_path fills a closed path using the non-zero winding rule, with
// anti-aliasing. This is the workhorse used by `fill`, `quad`,
// `triangle`, and Context.fill.
pub fn (mut c Canvas) fill_path(path Path, opts FillOptions, color Color) ! {
	_ = opts
	polys := flatten_path(path)
	if polys.len == 0 {
		return
	}
	c.fill_polys(polys, color)
}

// fill_polys rasterizes a set of polygons with non-zero winding + AA.
fn (mut c Canvas) fill_polys(polys [][]Point, color Color) {
	w := int(c.sfc_width())
	h := int(c.sfc_height())

	// Compute the vertical bounds so we only scan relevant rows.
	mut min_y := f64(h)
	mut max_y := f64(0)
	for poly in polys {
		for pt in poly {
			if pt.y < min_y {
				min_y = pt.y
			}
			if pt.y > max_y {
				max_y = pt.y
			}
		}
	}
	mut y0 := int(math.floor(min_y))
	mut y1 := int(math.ceil(max_y))
	if y0 < 0 {
		y0 = 0
	}
	if y1 > h {
		y1 = h
	}

	// Coverage accumulation buffer for one row of pixels.
	mut coverage := []f64{len: w}

	color_val := f64(u8(color))

	for py in y0 .. y1 {
		for i in 0 .. w {
			coverage[i] = 0.0
		}
		// Sample `aa_samples` sub-scanlines within this pixel row.
		for s in 0 .. aa_samples {
			sy := f64(py) + (f64(s) + 0.5) / f64(aa_samples)
			// Gather winding-aware crossings for this sub-scanline.
			mut xs := []XCross{}
			for poly in polys {
				n := poly.len
				if n < 2 {
					continue
				}
				for k in 0 .. n {
					a := poly[k]
					b := poly[(k + 1) % n]
					ay := a.y
					by := b.y
					if ay == by {
						continue
					}
					// dir: +1 for downward edge, -1 for upward.
					mut dir := 1
					mut lo := a
					mut hi := b
					if ay > by {
						dir = -1
						lo = b
						hi = a
					}
					if sy < lo.y || sy >= hi.y {
						continue
					}
					t := (sy - lo.y) / (hi.y - lo.y)
					x := lo.x + t * (hi.x - lo.x)
					xs << XCross{
						x: x
						dir: dir
					}
				}
			}
			if xs.len < 2 {
				continue
			}
			xs.sort(a.x < b.x)
			// Walk crossings accumulating winding number; spans where
			// winding != 0 are inside (non-zero rule).
			mut winding := 0
			for idx in 0 .. xs.len - 1 {
				winding += xs[idx].dir
				if winding != 0 {
					accumulate_span(mut coverage, xs[idx].x, xs[idx + 1].x, w)
				}
			}
		}
		// Emit the accumulated coverage for this pixel row.
		for px in 0 .. w {
			cov := coverage[px] / f64(aa_samples)
			if cov <= 0.0 {
				continue
			}
			cc := if cov > 1.0 { 1.0 } else { cov }
			val := u8(math.round(color_val * cc))
			if val > 0 {
				c.blend_pixel(px, py, val)
			}
		}
	}
}

// XCross is an edge crossing on a scanline with its winding direction.
struct XCross {
	x   f64
	dir int
}

// accumulate_span adds fractional horizontal coverage for the interval
// [xa, xb) in to the per-row coverage buffer, with partial coverage on
// the boundary pixels for horizontal anti-aliasing.
fn accumulate_span(mut coverage []f64, xa f64, xb f64, w int) {
	if xb <= xa {
		return
	}
	mut a := xa
	mut b := xb
	if a < 0 {
		a = 0
	}
	if b > f64(w) {
		b = f64(w)
	}
	if b <= a {
		return
	}
	ia := int(math.floor(a))
	ib := int(math.floor(b - 0.0000001))
	if ia == ib {
		if ia >= 0 && ia < w {
			coverage[ia] += (b - a)
		}
		return
	}
	// Left partial pixel.
	if ia >= 0 && ia < w {
		coverage[ia] += (f64(ia + 1) - a)
	}
	// Full middle pixels.
	for px in ia + 1 .. ib {
		if px >= 0 && px < w {
			coverage[px] += 1.0
		}
	}
	// Right partial pixel.
	if ib >= 0 && ib < w {
		coverage[ib] += (b - f64(ib))
	}
}

// ============================================================
// Path stroking
// ============================================================

// stroke_path strokes the given (open or closed) path with the given
// options. Each segment is expanded in to a quad of the requested width
// and filled; the union of these quads produces the stroke.
pub fn (mut c Canvas) stroke_path(path Path, opts StrokeOptions, color Color) ! {
	half := opts.line_width / 2.0
	polys := stroke_to_polys(path, half, opts.line_cap_mode)
	if polys.len == 0 {
		return
	}
	// Fill each stroke quad independently. Because the fill uses `max`
	// blending, overlapping quads at joints combine cleanly without
	// darkening.
	for poly in polys {
		c.fill_polys([poly], color)
	}

	if opts.line_cap_mode == .round_ {
		for sub in flatten_path(path) {
			if sub.len < 2 || points_equal(sub[0], sub.last()) {
				continue
			}
			c.fill_polys([circle_polygon(sub[0], half), circle_polygon(sub.last(), half)], color)
		}
	}
}

// inner_stroke_path strokes only the portion of a path that lies inside
// the shape produced by closing it. Ghostty uses the same two-surface mask
// technique around z2d; the V renderer performs that alpha multiplication
// directly on two temporary canvases.
pub fn (mut c Canvas) inner_stroke_path(path Path, opts StrokeOptions, color Color) ! {
	mut closed_nodes := path.nodes.clone()
	closed_nodes << PathNode{
		kind: .close
	}

	mut fill_canvas := Canvas.init(c.width, c.height, c.padding_x, c.padding_y)
	fill_canvas.fill_path(Path{ nodes: closed_nodes }, FillOptions{}, .on)!

	mut stroke_canvas := Canvas.init(c.width, c.height, c.padding_x, c.padding_y)
	stroke_canvas.stroke_path(path, StrokeOptions{
		line_cap_mode: opts.line_cap_mode
		line_width: opts.line_width * 2.0
	}, color)!

	for i in 0 .. c.data.len {
		masked := u8(math.round(f64(fill_canvas.data[i]) * f64(stroke_canvas.data[i]) / 255.0))
		dst := u32(c.data[i])
		src := u32(masked)
		c.data[i] = u8(src + (dst * (255 - src) + 127) / 255)
	}
}

// stroke_to_polys converts a path in to a list of quad polygons, one
// per line segment, each offset by `half` on either side of the segment.
fn stroke_to_polys(path Path, half f64, cap LineCapMode) [][]Point {
	mut polys := [][]Point{}
	subs := flatten_path(path)
	for sub in subs {
		if sub.len < 2 {
			continue
		}
		for k in 0 .. sub.len - 1 {
			mut a := sub[k]
			mut b := sub[k + 1]
			dx := b.x - a.x
			dy := b.y - a.y
			len := math.sqrt(dx * dx + dy * dy)
			if len == 0 {
				continue
			}
			// Unit normal.
			nx := -dy / len * half
			ny := dx / len * half
			if cap == .square && !points_equal(sub[0], sub.last()) {
				if k == 0 {
					a = Point{
						x: a.x - dx / len * half
						y: a.y - dy / len * half
					}
				}
				if k == sub.len - 2 {
					b = Point{
						x: b.x + dx / len * half
						y: b.y + dy / len * half
					}
				}
			}
			polys << [
				Point{
					x: a.x + nx
					y: a.y + ny
				},
				Point{
					x: b.x + nx
					y: b.y + ny
				},
				Point{
					x: b.x - nx
					y: b.y - ny
				},
				Point{
					x: a.x - nx
					y: a.y - ny
				},
			]
		}
	}
	return polys
}

fn points_equal(a Point, b Point) bool {
	return a.x == b.x && a.y == b.y
}

fn circle_polygon(center Point, radius f64) []Point {
	segments := 24
	mut points := []Point{cap: segments}
	for i in 0 .. segments {
		angle := f64(i) * math.tau / f64(segments)
		points << Point{
			x: center.x + radius * math.cos(angle)
			y: center.y + radius * math.sin(angle)
		}
	}
	return points
}

// ============================================================
// Context (for arc/circle drawing)
// ============================================================

// Context provides a higher-level, path-building drawing interface,
// mirroring z2d's `Context`. Coordinates are cell-relative; the
// padding transform is applied through the underlying StaticPath.
pub struct Context {
pub mut:
	canvas        &Canvas = unsafe { nil }
	line_width    f64 = 2.0
	line_cap_mode LineCapMode = .butt
	color         Color = .on
	nodes         []PathNode
	// Tracks the current point for relative operations like `arc`.
	has_current bool
	cur_x       f64
	cur_y       f64
	start_x     f64
	start_y     f64
	has_start   bool
}

pub fn (mut ctx Context) deinit() {
	// no-op; nothing to free
}

// SourcePattern for setting the drawing source color.
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
	ctx.color = unsafe { Color(source.opaque_pattern.pixel.alpha8.a) }
}

pub fn (mut ctx Context) set_line_width(width f64) {
	ctx.line_width = width
}

fn (ctx &Context) tx(x f64) f64 {
	return x + f64(ctx.canvas.padding_x)
}

fn (ctx &Context) ty(y f64) f64 {
	return y + f64(ctx.canvas.padding_y)
}

pub fn (mut ctx Context) move_to(x f64, y f64) {
	ctx.nodes << PathNode{
		kind: .move_to
		x: ctx.tx(x)
		y: ctx.ty(y)
	}
	ctx.cur_x = x
	ctx.cur_y = y
	ctx.start_x = x
	ctx.start_y = y
	ctx.has_current = true
	ctx.has_start = true
}

pub fn (mut ctx Context) line_to(x f64, y f64) {
	if !ctx.has_current {
		ctx.move_to(x, y)
		return
	}
	ctx.nodes << PathNode{
		kind: .line_to
		x: ctx.tx(x)
		y: ctx.ty(y)
	}
	ctx.cur_x = x
	ctx.cur_y = y
	ctx.has_current = true
}

pub fn (mut ctx Context) curve_to(c1x f64, c1y f64, c2x f64, c2y f64, x f64, y f64) {
	ctx.nodes << PathNode{
		kind: .curve_to
		x: ctx.tx(x)
		y: ctx.ty(y)
		c1x: ctx.tx(c1x)
		c1y: ctx.ty(c1y)
		c2x: ctx.tx(c2x)
		c2y: ctx.ty(c2y)
	}
	ctx.cur_x = x
	ctx.cur_y = y
	ctx.has_current = true
}

// arc appends a circular arc centered at (x, y) with radius r, going
// from start_angle to end_angle (radians, positive = counter-clockwise
// in the standard math sense, i.e. y-down here it sweeps clockwise on
// screen). It is approximated with a sequence of cubic Bezier curves,
// matching z2d's arc rendering behavior closely enough for our sprites.
pub fn (mut ctx Context) arc(x f64, y f64, r f64, start_angle f64, end_angle f64) ! {
	sweep := end_angle - start_angle
	// Number of Bezier segments; each covers at most ~90 degrees.
	half_pi := math.pi / 2.0
	mut n := int(math.ceil(math.abs(sweep) / half_pi))
	if n < 1 {
		n = 1
	}
	seg := sweep / f64(n)
	// Control-point distance coefficient for a Bezier approximation of
	// a circular arc of angle `seg`.
	alpha := 4.0 / 3.0 * math.tan(seg / 4.0)

	mut a := start_angle
	sx := x + r * math.cos(a)
	sy := y + r * math.sin(a)
	if !ctx.has_current {
		ctx.move_to(sx, sy)
	} else {
		ctx.line_to(sx, sy)
	}

	for _ in 0 .. n {
		a1 := a
		a2 := a + seg
		p1x := x + r * math.cos(a1)
		p1y := y + r * math.sin(a1)
		p2x := x + r * math.cos(a2)
		p2y := y + r * math.sin(a2)
		c1x := p1x - alpha * r * math.sin(a1)
		c1y := p1y + alpha * r * math.cos(a1)
		c2x := p2x + alpha * r * math.sin(a2)
		c2y := p2y - alpha * r * math.cos(a2)
		ctx.curve_to(c1x, c1y, c2x, c2y, p2x, p2y)
		a = a2
	}
}

pub fn (mut ctx Context) close_path() ! {
	ctx.nodes << PathNode{
		kind: .close
	}
	if ctx.has_start {
		ctx.cur_x = ctx.start_x
		ctx.cur_y = ctx.start_y
	}
}

pub fn (mut ctx Context) reset_path() {
	ctx.nodes = []PathNode{}
	ctx.has_current = false
	ctx.has_start = false
}

// fill fills the currently-built path with the context's source color.
pub fn (mut ctx Context) fill() ! {
	path := Path{
		nodes: ctx.nodes
	}
	ctx.canvas.fill_path(path, FillOptions{}, ctx.color)!
}

// stroke strokes the currently-built path with the context's source
// color and line width.
pub fn (mut ctx Context) stroke() ! {
	path := Path{
		nodes: ctx.nodes
	}
	ctx.canvas.stroke_path(path, StrokeOptions{
		line_cap_mode: ctx.line_cap_mode
		line_width: ctx.line_width
	}, ctx.color)!
}

// ============================================================
// Triangle / Quad geometry
// ============================================================

pub struct Triangle {
pub:
	p0 Point
	p1 Point
	p2 Point
}

pub struct Quad {
pub:
	p0 Point
	p1 Point
	p2 Point
	p3 Point
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
		.super_light {
			if base / 2 > 1 { base / 2 } else { u32(1) }
		}
		.light { base }
		.heavy { base * 2 }
	}
}

// ============================================================
// Shade
// ============================================================

// Shades.
pub enum Shade as u8 {
	off    = 0x00
	light_ = 0x40
	medium = 0x80
	dark   = 0xc0
	on     = 0xff
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
pub const align_upper = Alignment{
	vertical: .top
}
pub const align_lower = Alignment{
	vertical: .bottom
}
pub const align_left = Alignment{
	horizontal: .left
}
pub const align_right = Alignment{
	horizontal: .right
}
pub const align_upper_left = Alignment{
	vertical: .top
	horizontal: .left
}
pub const align_upper_right = Alignment{
	vertical: .top
	horizontal: .right
}
pub const align_lower_left = Alignment{
	vertical: .bottom
	horizontal: .left
}
pub const align_lower_right = Alignment{
	vertical: .bottom
	horizontal: .right
}
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
pub const fraction_eighths = [Fraction.zero, .one_eighth, .two_eighths, .three_eighths, .four_eighths,
	.five_eighths, .six_eighths, .seven_eighths, .one]

// This can be indexed to get the fraction for i/4.
pub const fraction_quarters = [Fraction.zero, .one_quarter, .two_quarters, .three_quarters, .one]

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
	canvas.draw_box(x0.to_min(metrics.cell_width), y0.to_min(metrics.cell_height), x1.to_max(metrics.cell_width), y1.to_max(metrics.cell_height), .on)
}

// ============================================================
// Helper line functions from common.zig
// ============================================================

// Centered vertical line of the provided thickness.
pub fn vline_middle(metrics font.Metrics, mut canvas Canvas, thickness Thickness) {
	thick_px := thickness.height(metrics.box_thickness)
	vline(mut canvas, 0, i32(metrics.cell_height), i32(sat_sub(metrics.cell_width, thick_px) / 2), thick_px)
}

// Centered horizontal line of the provided thickness.
pub fn hline_middle(metrics font.Metrics, mut canvas Canvas, thickness Thickness) {
	thick_px := thickness.height(metrics.box_thickness)
	hline(mut canvas, 0, i32(metrics.cell_width), i32(sat_sub(metrics.cell_height, thick_px) / 2), thick_px)
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
// block fill helpers (from block.zig)
// ============================================================

// block_fill fills a block at the given alignment with fractional
// width and height relative to the cell.
pub fn block_fill(metrics font.Metrics, mut canvas Canvas, alignment Alignment, bwidth f64, bheight f64) {
	block_shade(metrics, mut canvas, alignment, bwidth, bheight, .on)
}

// block_shade fills a block at the given alignment with a shade pattern.
pub fn block_shade(metrics font.Metrics, mut canvas Canvas, alignment Alignment, bwidth f64, bheight f64, shade Shade) {
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

// full_block_shade fills the entire cell with a shade pattern.
pub fn full_block_shade(metrics font.Metrics, mut canvas Canvas, shade Shade) {
	canvas.draw_box(0, 0, i32(metrics.cell_width), i32(metrics.cell_height), unsafe { Color(u8(shade)) })
}
