module renderer

import terminal

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

pub fn (c OverlayColor) rgb() OverlayRGB {
	return match c {
		.hyperlink { OverlayRGB{
			r: 180
			g: 180
			b: 255
		} }
		.semantic_prompt { OverlayRGB{
			r: 255
			g: 200
			b: 64
		} }
		.semantic_input { OverlayRGB{
			r: 64
			g: 200
			b: 255
		} }
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
	term_size := sz.terminal_size()
	w := term_size.width
	h := term_size.height
	if w == 0 || h == 0 {
		return error('invalid dimensions for overlay')
	}
	total := int(w) * int(h) * 4
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
	// XTODO: Hyperlink highlighting requires render state row_data
	// with hyperlink flags per cell. The algorithm:
	// 1. Iterate rows, skip non-hyperlink rows
	// 2. Find contiguous runs of hyperlink cells
	// 3. Draw highlight rectangles for each run
	_ = state
}

// Highlight semantic prompts in the render state.
fn (mut self Overlay) highlight_semantic_prompts(state &terminal.RenderState) {
	// XTODO: Semantic prompt highlighting requires render state row_data
	// with semantic_prompt metadata. The algorithm:
	// 1. Find prompt rows and their continuations
	// 2. Draw colored bar at the left edge
	// 3. Find contiguous semantic content cells (prompt/input)
	// 4. Draw highlight rectangles for each run
	_ = state
}

// Draw a filled and bordered rectangle at grid coordinates.
// x/y/width/height are all in grid cells.
fn (mut self Overlay) highlight_grid_rect(x int, y int, width int, height int, color OverlayColor) {
	// Calculate pixel coordinates
	px_x := x * int(self.cell_size.width)
	px_y := y * int(self.cell_size.height)
	px_w := width * int(self.cell_size.width)
	px_h := height * int(self.cell_size.height)

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
			if idx >= 0 && idx + 3 < self.pixels.len {
				// Alpha-blend the overlay pixel
				self.pixels[idx + 0] = col.r
				self.pixels[idx + 1] = col.g
				self.pixels[idx + 2] = col.b
				self.pixels[idx + 3] = a
			}
		}
	}
}

// Draw a filled and bordered rectangle where x/y are grid cells and
// width_px/height are pixels.
fn (mut self Overlay) highlight_pixel_rect(x int, y int, width_px int, height int, color OverlayColor) {
	px_x := x * int(self.cell_size.width)
	px_y := y * int(self.cell_size.height)
	px_h := height * int(self.cell_size.height)

	col := color.rgb()
	fill_a := color.fill_alpha()
	border_a := color.border_alpha()

	for row in px_y .. px_y + px_h {
		if row < 0 || row >= int(self.height) {
			continue
		}
		for col_px in px_x .. px_x + width_px {
			if col_px < 0 || col_px >= int(self.width) {
				continue
			}
			is_border := row == px_y || row == px_y + px_h - 1
				|| col_px == px_x || col_px == px_x + width_px - 1
			a := if is_border { border_a } else { fill_a }

			idx := (row * int(self.width) + col_px) * 4
			if idx >= 0 && idx + 3 < self.pixels.len {
				self.pixels[idx + 0] = col.r
				self.pixels[idx + 1] = col.g
				self.pixels[idx + 2] = col.b
				self.pixels[idx + 3] = a
			}
		}
	}
}
