module renderer

// A coordinate. This is defined as a tagged union to allow for different
// coordinate systems to be represented.
//
// A coordinate is only valid within the context of a stable Size value.
// If any of the sizes in the Size struct change, the coordinate is no
// longer valid and must be recalculated.
//
// The coordinate systems are:
//
//   * surface: (0, 0) is the top-left of the surface (with padding). Negative
//     values are allowed and are off the surface. Units are pixels.
//
//   * terminal: (0, 0) is the top-left of the terminal grid. This is the
//     same as the surface but with the padding removed. Units are pixels.
//
//   * grid: (0, 0) is the top-left of the grid. Units are in cells. Negative
//     values are not allowed but values greater than the grid size are
//     possible and are off the grid.
pub type SizeCoordinate = SurfaceCoord | TerminalCoord | GridCoord

pub struct SurfaceCoord {
pub:
	x f64
	y f64
}

pub struct TerminalCoord {
pub:
	x f64
	y f64
}

pub struct GridCoord {
pub:
	x u32
	y u32
}

// Coordinate system tag for conversion.
pub enum CoordTag {
	surface
	terminal
	grid
}

// Convert a coordinate to a different space within the same Size.
pub fn coord_convert(c SizeCoordinate, to CoordTag, sz Size) SizeCoordinate {
	// First convert to surface coordinates.
	surface := coord_to_surface(c, sz)

	if to == .surface {
		return SizeCoordinate(SurfaceCoord{
			x: surface.x
			y: surface.y
		})
	} else if to == .terminal {
		return SizeCoordinate(TerminalCoord{
			x: surface.x - f64(sz.padding.left)
			y: surface.y - f64(sz.padding.top)
		})
	} else {
		// .grid
		// Get rid of the padding.
		term_x := surface.x - f64(sz.padding.left)
		term_y := surface.y - f64(sz.padding.top)

		// We need our grid to clamp
		g := sz.grid()

		// Calculate the grid position.
		cell_width := f64(sz.cell.width)
		cell_height := f64(sz.cell.height)
		clamped_x := if term_x > 0 { term_x } else { 0.0 }
		clamped_y := if term_y > 0 { term_y } else { 0.0 }
		col := u32(clamped_x / cell_width)
		row := u32(clamped_y / cell_height)
		clamped_col := if col < g.columns - 1 { col } else { g.columns - 1 }
		clamped_row := if row < g.rows - 1 { row } else { g.rows - 1 }
		return SizeCoordinate(GridCoord{
			x: clamped_col
			y: clamped_row
		})
	}
}

// Convert a coordinate to the surface coordinate system.
fn coord_to_surface(c SizeCoordinate, sz Size) SurfaceCoord {
	match c {
		SurfaceCoord {
			return SurfaceCoord{
				x: c.x
				y: c.y
			}
		}
		TerminalCoord {
			return SurfaceCoord{
				x: c.x + f64(sz.padding.left)
				y: c.y + f64(sz.padding.top)
			}
		}
		GridCoord {
			col := f64(c.x)
			row := f64(c.y)
			cell_width := f64(sz.cell.width)
			cell_height := f64(sz.cell.height)
			padding_left := f64(sz.padding.left)
			padding_top := f64(sz.padding.top)
			return SurfaceCoord{
				x: col * cell_width + padding_left
				y: row * cell_height + padding_top
			}
		}
	}
}

// Subtract padding from the screen size.
pub fn (self ScreenSize) sub_padding(padding Padding) ScreenSize {
	lr := padding.left + padding.right
	tb := padding.top + padding.bottom
	return ScreenSize{
		width: if self.width > lr { self.width - lr } else { 0 }
		height: if self.height > tb { self.height - tb } else { 0 }
	}
}

// Calculates the amount of blank space around the grid. This is possible
// when padding isn't balanced.
//
// The "self" screen size here should be the unpadded screen.
pub fn (self ScreenSize) blank_padding_calc(padding Padding, g GridSize, cell CellSize) Padding {
	grid_width := g.columns * cell.width
	grid_height := g.rows * cell.height
	padded_width := grid_width + (padding.left + padding.right)
	padded_height := grid_height + (padding.top + padding.bottom)

	// Note these use saturating subtraction to avoid underflow
	// because our padding can cause the padded sizes to be larger than
	// our real screen if the screen is shrunk to a minimal size.
	leftover_width := if self.width > padded_width {
		self.width - padded_width
	} else {
		u32(0)
	}
	leftover_height := if self.height > padded_height {
		self.height - padded_height
	} else {
		u32(0)
	}

	return Padding{
		top: 0
		bottom: leftover_height
		right: leftover_width
		left: 0
	}
}

// Returns padding that balances the whitespace around the screen
// for the given grid and cell sizes.
pub fn Padding.balanced(screen ScreenSize, g GridSize, cell CellSize) Padding {
	// Turn our cell sizes into floats for the math
	cell_width := f32(cell.width)
	cell_height := f32(cell.height)

	// The size of our full grid
	grid_width := f32(g.columns) * cell_width
	grid_height := f32(g.rows) * cell_height

	// The empty space to the right of a line and bottom of the last row
	space_right := f32(screen.width) - grid_width
	space_bot := f32(screen.height) - grid_height

	// The padding is split equally along both axes.
	padding_right := int(space_right / 2)
	padding_left := padding_right

	padding_bot := int(space_bot / 2)
	padding_top := padding_bot

	return Padding{
		top: u32(if padding_top > 0 { padding_top } else { 0 })
		bottom: u32(if padding_bot > 0 { padding_bot } else { 0 })
		right: u32(if padding_right > 0 { padding_right } else { 0 })
		left: u32(if padding_left > 0 { padding_left } else { 0 })
	}
}

// Equality test between two paddings.
pub fn (self Padding) eql(other Padding) bool {
	return self.top == other.top && self.bottom == other.bottom
		&& self.right == other.right && self.left == other.left
}

// Initialize a grid size based on a screen and cell size.
pub fn GridSize.init_from_screen(screen ScreenSize, cell CellSize) GridSize {
	mut result := GridSize{}
	result.update_from_screen(screen, cell)
	return result
}

// Update the columns/rows for the grid based on the given screen and
// cell size.
pub fn (mut self GridSize) update_from_screen(screen ScreenSize, cell CellSize) {
	cell_width := f32(cell.width)
	cell_height := f32(cell.height)
	screen_width := f32(screen.width)
	screen_height := f32(screen.height)
	calc_cols := u32(screen_width / cell_width)
	calc_rows := u32(screen_height / cell_height)
	self.columns = if calc_cols > 1 { calc_cols } else { 1 }
	self.rows = if calc_rows > 1 { calc_rows } else { 1 }
}
