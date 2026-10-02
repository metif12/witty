module renderer

import log
import terminal

const overlay_max_i32 = usize(2147483647)

// The debug overlay that can be drawn on top of the terminal
// during the rendering process.
//
// This is implemented by doing all the drawing on the CPU,
// since the debug overlay isn't that common, and it simplifies
// our implementation quite a bit by not relying on per-platform shaders.
//
// Initialize the overlay, apply features with `apply_features`, then
// get the resulting image with `pending_image` to upload to the GPU.
// Draw it on the GPU as an image composited on top of the terminal output.
pub struct Overlay {
pub mut:
	// RGBA pixel data for the overlay surface.
	pixels []u8
	// Width of the overlay in pixels.
	width u32
	// Height of the overlay in pixels.
	height u32
	// Cell size information so we can map grid coordinates to pixels.
	cell_size CellSize
}

// The colors we use for overlays.
pub enum OverlayColor as u8 {
	hyperlink       // light blue
	semantic_prompt // orange/gold
	semantic_input  // cyan
}

pub struct OverlayRGB {
pub:
	r u8
	g u8
	b u8
}

// OverlayPixel is the premultiplied RGBA pixel value used by the source z2d
// surface. Keeping the color conversion separate from compositing preserves
// Overlay.Color's public helpers even though Witty owns its raster buffer.
pub struct OverlayPixel {
pub:
	r u8
	g u8
	b u8
	a u8
}

pub fn (c OverlayColor) rgb() OverlayRGB {
	return match c {
		.hyperlink {
			OverlayRGB{
				r: 180
				g: 180
				b: 255
			}
		}
		.semantic_prompt {
			OverlayRGB{
				r: 255
				g: 200
				b: 64
			}
		}
		.semantic_input {
			OverlayRGB{
				r: 64
				g: 200
				b: 255
			}
		}
	}
}

// The raw RGB as an opaque premultiplied pixel.
pub fn (c OverlayColor) pixel() OverlayPixel {
	rgb := c.rgb()
	return OverlayPixel{
		r: rgb.r
		g: rgb.g
		b: rgb.b
		a: 255
	}
}

// The fill color for rectangles.
pub fn (c OverlayColor) rect_fill() OverlayPixel {
	return c.alpha_pixel(96)
}

// The border color for rectangles.
pub fn (c OverlayColor) rect_border() OverlayPixel {
	return c.alpha_pixel(200)
}

fn (c OverlayColor) alpha_pixel(alpha u8) OverlayPixel {
	rgb := c.rgb()
	return OverlayPixel{
		// z2d.pixel.RGBA.multiply uses truncating integer division.
		r: u8(u32(rgb.r) * u32(alpha) / 255)
		g: u8(u32(rgb.g) * u32(alpha) / 255)
		b: u8(u32(rgb.b) * u32(alpha) / 255)
		a: alpha
	}
}

// The set of available features and their configuration.
pub enum OverlayFeature as u8 {
	highlight_hyperlinks
	semantic_prompts
}

// Initialize a new, blank overlay.
// Our surface does NOT need to take into account padding because
// we render the overlay using the image subsystem and shaders which
// already take that into account.
pub fn Overlay.init(sz Size) !Overlay {
	term_size := sz.terminal()
	w := term_size.width
	h := term_size.height
	if w == 0 || h == 0 || usize(w) > overlay_max_i32 || usize(h) > overlay_max_i32 {
		return error('invalid dimensions for overlay')
	}
	// V arrays use an `int` length, so reject surfaces whose backing store
	// cannot be represented before performing the multiplication.
	if u64(w) > u64(overlay_max_i32) / u64(h) / 4 {
		return error('invalid dimensions for overlay')
	}
	total := int(u64(w) * u64(h) * 4)
	return Overlay{
		pixels:    []u8{len: total}
		width:     w
		height:    h
		cell_size: sz.cell
	}
}

pub fn (mut self Overlay) deinit() {
	self.pixels = []
}

// Returns a pending image that can be used to copy, convert, upload, etc.
pub fn (self &Overlay) pending_image() PendingImage {
	return PendingImage{
		width:        self.width
		height:       self.height
		pixel_format: .rgba
		data:         self.pixels.clone()
	}
}

// Clear the overlay.
pub fn (mut self Overlay) reset() {
	for i in 0 .. self.pixels.len {
		self.pixels[i] = 0
	}
}

// Apply the given features to this overlay. This will draw on top of
// any pre-existing content in the overlay.
pub fn (mut self Overlay) apply_features(state &terminal.RenderState, features []OverlayFeature) {
	for f in features {
		match f {
			.highlight_hyperlinks {
				self.highlight_hyperlinks(state)
			}
			.semantic_prompts {
				self.highlight_semantic_prompts(state)
			}
		}
	}
}

// Add rectangles around contiguous hyperlinks in the render state.
//
// Note: this currently doesn't take into account unique hyperlink IDs
// because the render state doesn't contain this. This will be added
// later.
fn (mut self Overlay) highlight_hyperlinks(state &terminal.RenderState) {
	for y, row in state.row_data {
		if !row.raw.header.hyperlink {
			continue
		}

		mut x := 0
		for x < row.cells.len {
			if !row.cells[x].raw.has_hyperlink {
				x++
				continue
			}

			start_x := x
			for x < row.cells.len && row.cells[x].raw.has_hyperlink {
				x++
			}
			self.highlight_grid_rect(usize(start_x), usize(y), usize(x - start_x), 1, .hyperlink) or {
				log.warn('Error drawing hyperlink border: ${err}')
			}
		}
	}
}

// Highlight semantic prompts in the render state.
fn (mut self Overlay) highlight_semantic_prompts(state &terminal.RenderState) {
	// Highlight the row-level prompt bars, joining continuation rows.
	mut y := 0
	for y < state.row_data.len {
		if state.row_data[y].raw.header.semantic_prompt == .unknown {
			y++
			continue
		}

		start_y := y
		y++
		for y < state.row_data.len
			&& state.row_data[y].raw.header.semantic_prompt == .prompt_continuation {
			y++
		}
		bar_width := if self.cell_size.width < 5 { int(self.cell_size.width) } else { 5 }
		self.highlight_pixel_rect(0, usize(start_y), usize(bar_width), usize(y - start_y), .semantic_prompt) or {
			log.warn('Error drawing semantic prompt bar: ${err}')
		}
	}

	// Highlight contiguous prompt/input content. Output is intentionally
	// omitted because it would make the debug overlay too noisy.
	for row_y, row in state.row_data {
		mut x := 0
		for x < row.cells.len {
			content := row.cells[x].raw.semantic_content
			if content == .output {
				x++
				continue
			}

			start_x := x
			x++
			for x < row.cells.len && row.cells[x].raw.semantic_content == content {
				x++
			}
			color := if content == .prompt {
				OverlayColor.semantic_prompt
			} else {
				OverlayColor.semantic_input
			}
			self.highlight_grid_rect(usize(start_x), usize(row_y), usize(x - start_x), 1, color) or {
				log.warn('Error drawing semantic content highlight: ${err}')
			}
		}
	}
}

// Draw a filled and bordered rectangle at grid coordinates.
// x/y/width/height are all in grid cells.
fn (mut self Overlay) highlight_grid_rect(x usize, y usize, width usize, height usize, color OverlayColor) ! {
	// All grid-to-pixel products use the same checked i32 boundary as z2d.
	px_x := overlay_mul_i32(x, self.cell_size.width)!
	px_y := overlay_mul_i32(y, self.cell_size.height)!
	px_w := overlay_mul_i32(width, self.cell_size.width)!
	px_h := overlay_mul_i32(height, self.cell_size.height)!

	self.draw_z2d_rectangle(px_x, px_y, px_w, px_h, color.rect_border(),
		color.rect_fill())
}

// Draw a filled and bordered rectangle where x/y are grid cells and
// width_px/height are pixels.
fn (mut self Overlay) highlight_pixel_rect(x usize, y usize, width_px usize, height usize, color OverlayColor) ! {
	px_x := overlay_mul_i32(x, self.cell_size.width)!
	px_y := overlay_mul_i32(y, self.cell_size.height)!
	if width_px > overlay_max_i32 {
		return error('overlay coordinate overflow')
	}
	px_width := int(width_px)
	px_h := overlay_mul_i32(height, self.cell_size.height)!

	self.draw_z2d_rectangle(px_x, px_y, px_width, px_h, color.rect_border(),
		color.rect_fill())
}

// draw_z2d_rectangle is the specialized translation of the exact z2d 0.10.0
// operations used by Overlay.zig. The source builds an integer, axis-aligned
// closed path, fills it with anti-aliasing disabled, then strokes it in
// hairline mode. Keeping that order is observable: the fill uses exclusive
// end coordinates while every hairline segment includes both endpoints, so
// corners composite twice and right/bottom edges sit on the path boundary.
fn (mut self Overlay) draw_z2d_rectangle(start_x int, start_y int, width int, height int, border OverlayPixel, fill OverlayPixel) {
	end_x := start_x + width
	end_y := start_y + height

	// The z2d polyline plotter discards consecutive duplicate path points.
	// A point-only path is painted once; a collapsed line is traversed once
	// in each direction by the closed path. Degenerate polygons have no fill.
	if width == 0 && height == 0 {
		self.composite_xy(start_x, start_y, border)
		return
	}
	if width == 0 {
		self.z2d_hairline(start_x, start_y, start_x, end_y, border)
		self.z2d_hairline(start_x, end_y, start_x, start_y, border)
		return
	}
	if height == 0 {
		self.z2d_hairline(start_x, start_y, end_x, start_y, border)
		self.z2d_hairline(end_x, start_y, start_x, start_y, border)
		return
	}

	// painter.fill -> direct rasterizer for the rectangular non-zero path.
	for y in start_y .. end_y {
		for x in start_x .. end_x {
			self.composite_xy(x, y, fill)
		}
	}

	// painter.stroke(hairline=true) -> polyline plotter -> hairline rasterizer.
	// The four line calls intentionally retain shared endpoints.
	self.z2d_hairline(start_x, start_y, end_x, start_y, border)
	self.z2d_hairline(end_x, start_y, end_x, end_y, border)
	self.z2d_hairline(end_x, end_y, start_x, end_y, border)
	self.z2d_hairline(start_x, end_y, start_x, start_y, border)
}

// z2d_hairline translates the axis-aligned branches of z2d's hairline
// rasterizer. Overlay rectangles never take either Bresenham branch.
fn (mut self Overlay) z2d_hairline(x0 int, y0 int, x1 int, y1 int, pixel OverlayPixel) {
	if x0 == x1 {
		start := if y0 < y1 { y0 } else { y1 }
		end := if y0 > y1 { y0 } else { y1 }
		for y in start .. end + 1 {
			self.composite_xy(x0, y, pixel)
		}
		return
	}
	if y0 == y1 {
		start := if x0 < x1 { x0 } else { x1 }
		end := if x0 > x1 { x0 } else { x1 }
		for x in start .. end + 1 {
			self.composite_xy(x, y0, pixel)
		}
	}
}

// Multiply a grid coordinate by a cell dimension and cast it to the signed
// coordinate range accepted by the source rasterizer.
fn overlay_mul_i32(value usize, scale u32) !int {
	if scale != 0 && value > overlay_max_i32 / usize(scale) {
		return error('overlay coordinate overflow')
	}
	return int(value * usize(scale))
}

fn (mut self Overlay) composite_xy(x int, y int, pixel OverlayPixel) {
	if x < 0 || y < 0 || x >= int(self.width) || y >= int(self.height) {
		return
	}
	idx := (y * int(self.width) + x) * 4
	self.composite_pixel(idx, pixel)
}

// z2d's RGBA surfaces store premultiplied colors. Integer src-over computes
// color as src + dst * (255 - src.a) / 255 and alpha as
// src.a + dst.a - src.a * dst.a / 255, all with truncating division.
fn (mut self Overlay) composite_pixel(idx int, pixel OverlayPixel) {
	src_a := u32(pixel.a)
	inv_a := u32(255) - src_a
	src_r := u32(pixel.r)
	src_g := u32(pixel.g)
	src_b := u32(pixel.b)
	dst_a := u32(self.pixels[idx + 3])
	self.pixels[idx] = u8(src_r + u32(self.pixels[idx]) * inv_a / 255)
	self.pixels[idx + 1] = u8(src_g + u32(self.pixels[idx + 1]) * inv_a / 255)
	self.pixels[idx + 2] = u8(src_b + u32(self.pixels[idx + 2]) * inv_a / 255)
	self.pixels[idx + 3] = u8(src_a + dst_a - src_a * dst_a / 255)
}
