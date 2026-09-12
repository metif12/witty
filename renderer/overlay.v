module renderer

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
pub enum OverlayColor {
	hyperlink // light blue
	semantic_prompt // orange/gold
	semantic_input // cyan
}

pub struct OverlayRGB {
pub:
	r u8
	g u8
	b u8
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

// The fill alpha for rectangles.
pub fn (c OverlayColor) fill_alpha() u8 {
	return 96
}

// The border alpha for rectangles.
pub fn (c OverlayColor) border_alpha() u8 {
	return 200
}

// The set of available features and their configuration.
pub enum OverlayFeature {
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
		pixels: []u8{len: total}
		width: w
		height: h
		cell_size: sz.cell
	}
}

pub fn (mut self Overlay) deinit() {
	self.pixels = []
}

// Returns a pending image that can be used to copy, convert, upload, etc.
pub fn (self &Overlay) pending_image() PendingImage {
	return PendingImage{
		width: self.width
		height: self.height
		pixel_format: .rgba
		data: self.pixels.clone()
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
		if !row.raw.hyperlink {
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
			self.highlight_grid_rect(usize(start_x), usize(y), usize(x - start_x), 1, .hyperlink) or {}
		}
	}
}

// Highlight semantic prompts in the render state.
fn (mut self Overlay) highlight_semantic_prompts(state &terminal.RenderState) {
	// Highlight the row-level prompt bars, joining continuation rows.
	mut y := 0
	for y < state.row_data.len {
		if state.row_data[y].raw.semantic_prompt == .unknown {
			y++
			continue
		}

		start_y := y
		y++
		for y < state.row_data.len
			&& state.row_data[y].raw.semantic_prompt == .prompt_continuation {
			y++
		}
		bar_width := if self.cell_size.width < 5 { int(self.cell_size.width) } else { 5 }
		self.highlight_pixel_rect(0, usize(start_y), usize(bar_width), usize(y - start_y), .semantic_prompt) or {}
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
			self.highlight_grid_rect(usize(start_x), usize(row_y), usize(x - start_x), 1, color) or {}
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

	col := color.rgb()
	fill_a := color.fill_alpha()
	border_a := color.border_alpha()

	// Fill the rectangle
	for row in px_y .. px_y + px_h {
		if row < 0 || row >= int(self.height) {
			continue
		}
		for col_px in px_x .. px_x + px_w {
			if col_px < 0 || col_px >= int(self.width) {
				continue
			}
			// Check if this is a border pixel
			is_border := row == px_y || row == px_y + px_h - 1
				|| col_px == px_x || col_px == px_x + px_w - 1
			a := if is_border { border_a } else { fill_a }

			idx := (row * int(self.width) + col_px) * 4
			self.composite_pixel(idx, col, a)
		}
	}
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

	col := color.rgb()
	fill_a := color.fill_alpha()
	border_a := color.border_alpha()

	for row in px_y .. px_y + px_h {
		if row < 0 || row >= int(self.height) {
			continue
		}
		for col_px in px_x .. px_x + px_width {
			if col_px < 0 || col_px >= int(self.width) {
				continue
			}
			is_border := row == px_y || row == px_y + px_h - 1
				|| col_px == px_x || col_px == px_x + px_width - 1
			a := if is_border { border_a } else { fill_a }

			idx := (row * int(self.width) + col_px) * 4
			self.composite_pixel(idx, col, a)
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

// z2d's RGBA surfaces store premultiplied colors and composite with src-over.
fn (mut self Overlay) composite_pixel(idx int, color OverlayRGB, alpha u8) {
	if idx < 0 || idx + 3 >= self.pixels.len {
		return
	}
	src_a := u32(alpha)
	inv_a := u32(255) - src_a
	src_r := (u32(color.r) * src_a + 127) / 255
	src_g := (u32(color.g) * src_a + 127) / 255
	src_b := (u32(color.b) * src_a + 127) / 255
	self.pixels[idx] = u8(src_r + (u32(self.pixels[idx]) * inv_a + 127) / 255)
	self.pixels[idx + 1] = u8(src_g + (u32(self.pixels[idx + 1]) * inv_a + 127) / 255)
	self.pixels[idx + 2] = u8(src_b + (u32(self.pixels[idx + 2]) * inv_a + 127) / 255)
	self.pixels[idx + 3] = u8(src_a + (u32(self.pixels[idx + 3]) * inv_a + 127) / 255)
}
