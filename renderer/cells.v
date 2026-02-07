module renderer

import terminal

// ============================================================
// Cell content types for GPU rendering
// ============================================================

// AtlasKind identifies which texture atlas a glyph belongs to.
pub enum AtlasKind {
	grayscale
	color
}

// CellTextBools contains boolean flags for text cell rendering.
pub struct CellTextBools {
pub mut:
	// Whether this cell should skip minimum contrast adjustment.
	no_min_contrast bool
	// Whether this cell is a cursor glyph.
	is_cursor_glyph bool
}

// CellText represents a foreground (text) cell for GPU rendering.
// Each glyph rendered to the screen becomes one of these.
pub struct CellText {
pub mut:
	// Which texture atlas this glyph is in.
	atlas AtlasKind = .grayscale
	// Boolean flags.
	bools CellTextBools
	// Grid position [col, row].
	grid_pos [2]u16
	// Color [r, g, b, a].
	color [4]u8
	// Position of the glyph in the atlas [x, y].
	glyph_pos [2]u32
	// Size of the glyph in the atlas [w, h].
	glyph_size [2]u32
	// Bearing offsets [x, y] for positioning.
	bearings [2]i32
}

// CellBg represents a background color for a cell [r, g, b, a].
pub type CellBg = [4]u8

// CellLayer identifies which layer a cell belongs to.
pub enum CellLayer {
	text
	underline
	overline
	strikethrough
}

// ============================================================
// CellContents - manages all cells for a frame
// ============================================================

// CellContents manages the current set of cells to render.
// This is rebuilt on every frame but kept around to avoid reallocation.
pub struct CellContents {
pub mut:
	// The size of the grid (columns x rows).
	size GridSize
	// Background cells, one per grid position (row-major).
	bg_cells []CellBg
	// Foreground (text) cells per row. Each row is a list of CellText.
	fg_rows [][]CellText
	// The cursor cell, if visible.
	cursor ?CellText
	// The cursor style, if visible.
	cursor_style ?CursorStyle
}

// Resize the cell contents to the given grid size.
pub fn (mut c CellContents) resize(size GridSize) ! {
	total := int(size.columns) * int(size.rows)
	c.bg_cells = []CellBg{len: total, init: [u8(0), 0, 0, 0]!}
	c.fg_rows = [][]CellText{len: int(size.rows)}
	c.size = size
}

// Reset all cell contents (clear everything).
pub fn (mut c CellContents) reset() {
	// Clear all background cells to transparent
	for i in 0 .. c.bg_cells.len {
		c.bg_cells[i] = [u8(0), 0, 0, 0]!
	}
	// Clear all foreground rows
	for i in 0 .. c.fg_rows.len {
		c.fg_rows[i] = []CellText{}
	}
	c.cursor = none
	c.cursor_style = none
}

// Clear a specific row's foreground cells.
pub fn (mut c CellContents) clear(row u16) {
	if int(row) < c.fg_rows.len {
		c.fg_rows[int(row)] = []CellText{}
	}
	// Also clear bg cells for this row
	start := int(row) * int(c.size.columns)
	end := start + int(c.size.columns)
	for i in start .. end {
		if i < c.bg_cells.len {
			c.bg_cells[i] = [u8(0), 0, 0, 0]!
		}
	}
}

// Get a pointer to the background cell at [row, col].
pub fn (mut c CellContents) bg_cell(row u16, col u16) &CellBg {
	idx := int(row) * int(c.size.columns) + int(col)
	if idx < c.bg_cells.len {
		return unsafe { &c.bg_cells[idx] }
	}
	// Return a reference to a default (should not happen in practice)
	return unsafe { &c.bg_cells[0] }
}

// Add a foreground cell to the given layer.
pub fn (mut c CellContents) add(layer CellLayer, cell CellText) ! {
	row := int(cell.grid_pos[1])
	if row >= c.fg_rows.len {
		return
	}
	c.fg_rows[row] << cell
}

// Set the cursor cell and style.
pub fn (mut c CellContents) set_cursor(cell ?CellText, style ?CursorStyle) {
	c.cursor = cell
	c.cursor_style = style
}

// Get the cursor glyph, if one is set.
pub fn (c &CellContents) get_cursor_glyph() ?CellText {
	return c.cursor
}

// ============================================================
// UniformBools - boolean uniforms for shader control
// ============================================================

// UniformBools contains boolean flags sent to the shader.
pub struct UniformBools {
pub mut:
	// Whether the cursor occupies a wide (2-cell) character.
	cursor_wide bool
	// Whether to use Display P3 color space.
	use_display_p3 bool
	// Whether to use linear alpha blending.
	use_linear_blending bool
	// Whether to apply linear correction after blending.
	use_linear_correction bool
}

// ============================================================
// PaddingExtend - which padding edges to extend
// ============================================================

// PaddingExtend tracks which padding edges should extend the
// cell background color.
pub struct PaddingExtend {
pub mut:
	up    bool
	down  bool
	left  bool
	right bool
}

// ============================================================
// Uniforms - shader uniform values
// ============================================================

// Uniforms holds all uniform values sent to the GPU shader.
pub struct Uniforms {
pub mut:
	// Orthographic projection matrix (4x4, column-major).
	projection_matrix [16]f32
	// Cell size in pixels [width, height].
	cell_size [2]f32
	// Grid size in cells [columns, rows].
	grid_size [2]u16
	// Padding around the grid [top, right, bottom, left].
	grid_padding [4]f32
	// Screen size in pixels [width, height].
	screen_size [2]f32
	// Which padding edges are extended.
	padding_extend PaddingExtend
	// Minimum contrast ratio.
	min_contrast f32
	// Cursor position in the grid [col, row].
	// Set to max u16 when cursor is not visible.
	cursor_pos [2]u16
	// Cursor text color [r, g, b, a].
	cursor_color [4]u8
	// Background color [r, g, b, a].
	bg_color [4]u8
	// Boolean flags.
	bools UniformBools
}

// ============================================================
// Custom shader uniforms (Shadertoy-compatible)
// ============================================================

// CustomShaderUniforms holds uniforms for custom (Shadertoy) shaders.
pub struct CustomShaderUniforms {
pub mut:
	// Screen resolution [width, height, pixel_aspect_ratio].
	resolution [3]f32
	// Time in seconds since first frame.
	time f32
	// Time delta since last frame in seconds.
	time_delta f32
	// Rendering frame rate.
	frame_rate f32 = 60.0
	// Current frame number.
	frame u32
	// Channel time (4 channels, each has time).
	channel_time [4][4]f32
	// Channel resolution (4 channels, each [w, h, aspect, 0]).
	channel_resolution [4][4]f32
	// Mouse position.
	mouse [4]f32
	// Current date [year, month, day, seconds_since_midnight].
	date [4]f32
	// Audio sample rate (N/A).
	sample_rate f32
	// Current cursor position and size [x, y, w, h].
	current_cursor [4]f32
	// Previous cursor position and size [x, y, w, h].
	previous_cursor [4]f32
	// Current cursor color [r, g, b, a].
	current_cursor_color [4]f32
	// Previous cursor color [r, g, b, a].
	previous_cursor_color [4]f32
	// Time when cursor last changed position.
	cursor_change_time f32
	// Time when window was last focused.
	time_focus f32
	// Whether the window is focused (0 or 1).
	focus u32 = 1
	// 256-color palette as normalized floats [r, g, b, a].
	palette [256][4]f32
	// Background color as normalized floats.
	background_color [4]f32
	// Foreground color as normalized floats.
	foreground_color [4]f32
	// Cursor color as normalized floats.
	cursor_color [4]f32
	// Cursor text color as normalized floats.
	cursor_text [4]f32
	// Selection background color as normalized floats.
	selection_background_color [4]f32
	// Selection foreground color as normalized floats.
	selection_foreground_color [4]f32
}

// ============================================================
// Highlight tags for search matches
// ============================================================

// HighlightTag identifies the type of highlight on a cell.
pub enum HighlightTag as u8 {
	search_match
	search_match_selected
}

// ============================================================
// Helper: ortho2d projection matrix
// ============================================================

// Compute a 2D orthographic projection matrix (column-major).
pub fn ortho2d(left f32, right f32, bottom f32, top f32) [16]f32 {
	mut m := [16]f32{}
	m[0] = 2.0 / (right - left)
	m[5] = 2.0 / (top - bottom)
	m[10] = -1.0
	m[12] = -(right + left) / (right - left)
	m[13] = -(top + bottom) / (top - bottom)
	m[15] = 1.0
	return m
}

// ============================================================
// Background image vertex data
// ============================================================

// BgImagePosition for the background image shader.
pub enum BgImagePosition {
	tl
	tc
	tr
	ml
	mc
	mr
	bl
	bc
	br
}

// BgImageFit for the background image shader.
pub enum BgImageFit {
	contain
	cover
	stretch
	none_
}

// BgImageInfo holds position/fit/repeat info for the background image.
pub struct BgImageInfo {
pub mut:
	position BgImagePosition = .mc
	fit      BgImageFit      = .contain
	repeat   bool
}

// BgImageBuffer is the vertex data for the background image.
pub struct BgImageBuffer {
pub mut:
	opacity f32 = 1.0
	info    BgImageInfo
}
