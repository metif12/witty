module renderer

fn test_coordinate_tag_source_layout_and_ordinals() {
	assert sizeof(CoordTag) == 1
	assert u8(CoordTag.surface) == 0
	assert u8(CoordTag.terminal) == 1
	assert u8(CoordTag.grid) == 2
}

// ============================================================
// Size tests - translated from size.zig
// ============================================================

// Test that balanced padding with zero screen doesn't produce negative padding.
fn test_padding_balanced_on_zero() {
	grid := GridSize{ columns: 100, rows: 37 }
	cell := CellSize{ width: 10, height: 20 }
	screen := ScreenSize{ width: 0, height: 0 }
	padding := Padding.balanced(screen, grid, cell)
	assert padding.top == 0
	assert padding.bottom == 0
	assert padding.left == 0
	assert padding.right == 0
}

// Test GridSize update with exact division.
fn test_grid_size_update_exact() {
	mut grid := GridSize{}
	grid.update(ScreenSize{ width: 100, height: 40 }, CellSize{ width: 5, height: 10 })
	assert grid.columns == 20
	assert grid.rows == 4
}

// Test GridSize update with rounding (truncation).
fn test_grid_size_update_rounding() {
	mut grid := GridSize{}
	grid.update(ScreenSize{ width: 20, height: 40 }, CellSize{ width: 6, height: 15 })
	assert grid.columns == 3
	assert grid.rows == 2
}

// Test GridSize minimum of 1.
fn test_grid_size_minimum_one() {
	mut grid := GridSize{}
	grid.update(ScreenSize{ width: 1, height: 1 }, CellSize{ width: 100, height: 100 })
	assert grid.columns == 1
	assert grid.rows == 1
}

fn test_size_grid_minimum_one() {
	sz := Size{
		screen: ScreenSize{ width: 1, height: 1 }
		cell: CellSize{ width: 100, height: 100 }
	}
	assert sz.grid() == GridSize{ columns: 1, rows: 1 }
}

// Test sub_padding basic operation.
fn test_screen_size_sub_padding() {
	screen := ScreenSize{ width: 100, height: 80 }
	result := screen.sub_padding(Padding{ top: 5, bottom: 5, left: 10, right: 10 })
	assert result.width == 80
	assert result.height == 70
}

// Test sub_padding with padding larger than screen (saturating).
fn test_screen_size_sub_padding_saturating() {
	screen := ScreenSize{ width: 10, height: 10 }
	result := screen.sub_padding(Padding{ top: 100, bottom: 100, left: 100, right: 100 })
	assert result.width == 0
	assert result.height == 0
}

// Test blank padding calculation.
fn test_blank_padding() {
	screen := ScreenSize{ width: 100, height: 100 }
	grid := GridSize{ columns: 8, rows: 4 }
	cell := CellSize{ width: 10, height: 20 }
	padding := Padding{ top: 0, bottom: 0, left: 0, right: 0 }

	// Grid is 80x80, screen is 100x100, so leftover is 20x20
	result := screen.blank_padding(padding, grid, cell)
	assert result.left == 0
	assert result.top == 0
	assert result.right == 20
	assert result.bottom == 20
}

// Test padding equality.
fn test_padding_eql() {
	a := Padding{ top: 1, bottom: 2, left: 3, right: 4 }
	b := Padding{ top: 1, bottom: 2, left: 3, right: 4 }
	c := Padding{ top: 5, bottom: 2, left: 3, right: 4 }
	assert a.eql(b)
	assert !a.eql(c)
}

// Test Padding.balanced produces reasonable results.
fn test_padding_balanced() {
	screen := ScreenSize{ width: 1000, height: 800 }
	grid := GridSize{ columns: 80, rows: 24 }
	cell := CellSize{ width: 10, height: 20 }

	// Grid: 800x480, Screen: 1000x800
	// Space right: 200, Space bot: 320
	// Padding: right=left=100, top=bottom=160
	padding := Padding.balanced(screen, grid, cell)
	assert padding.left == padding.right
	assert padding.top == padding.bottom
	assert padding.left == 100
	assert padding.top == 160
}

// Test coordinate conversion: surface to grid, no padding.
fn test_coord_convert_surface_to_grid_no_padding() {
	sz := Size{
		screen: ScreenSize{ width: 100, height: 100 }
		cell: CellSize{ width: 5, height: 10 }
		padding: Padding{}
	}

	// (0,0) surface -> (0,0) grid
	result := Coordinate(SurfaceCoord{ x: 0.0, y: 0.0 }).convert(.grid, sz)
	match result {
		GridCoord {
			assert result.x == 0
			assert result.y == 0
		}
		else {
			assert false
		}
	}

	// (6,0) surface -> (1,0) grid (6/5 = 1.2, truncated to 1)
	result2 := Coordinate(SurfaceCoord{ x: 6.0, y: 0.0 }).convert(.grid, sz)
	match result2 {
		GridCoord {
			assert result2.x == 1
			assert result2.y == 0
		}
		else {
			assert false
		}
	}

	// (6,10) surface -> (1,1) grid
	result3 := Coordinate(SurfaceCoord{ x: 6.0, y: 10.0 }).convert(.grid, sz)
	match result3 {
		GridCoord {
			assert result3.x == 1
			assert result3.y == 1
		}
		else {
			assert false
		}
	}
}

// Test coordinate conversion: negative surface clamped to grid (0,0).
fn test_coord_convert_surface_negative_clamped() {
	sz := Size{
		screen: ScreenSize{ width: 100, height: 100 }
		cell: CellSize{ width: 5, height: 10 }
		padding: Padding{}
	}

	result := Coordinate(SurfaceCoord{ x: -10.0, y: -10.0 }).convert(.grid, sz)
	match result {
		GridCoord {
			assert result.x == 0
			assert result.y == 0
		}
		else {
			assert false
		}
	}
}

// Test coordinate conversion: large surface clamped to max grid.
fn test_coord_convert_surface_large_clamped() {
	sz := Size{
		screen: ScreenSize{ width: 100, height: 100 }
		cell: CellSize{ width: 5, height: 10 }
		padding: Padding{}
	}

	g := sz.grid()
	result := Coordinate(SurfaceCoord{ x: 100000.0, y: 100000.0 }).convert(.grid, sz)
	match result {
		GridCoord {
			assert result.x == g.columns - 1
			assert result.y == g.rows - 1
		}
		else {
			assert false
		}
	}
}

// Test grid to surface conversion.
fn test_coord_convert_grid_to_surface() {
	sz := Size{
		screen: ScreenSize{ width: 100, height: 100 }
		cell: CellSize{ width: 5, height: 10 }
		padding: Padding{ left: 10, top: 20 }
	}

	result := Coordinate(GridCoord{ x: 2, y: 3 }).convert(.surface, sz)
	match result {
		SurfaceCoord {
			// x: 2 * 5 + 10 = 20
			// y: 3 * 10 + 20 = 50
			assert result.x == 20.0
			assert result.y == 50.0
		}
		else {
			assert false
		}
	}
}

// Test surface to terminal conversion (just removes padding).
fn test_coord_convert_surface_to_terminal() {
	sz := Size{
		screen: ScreenSize{ width: 100, height: 100 }
		cell: CellSize{ width: 5, height: 10 }
		padding: Padding{ left: 10, top: 20 }
	}

	result := Coordinate(SurfaceCoord{ x: 30.0, y: 50.0 }).convert(.terminal, sz)
	match result {
		TerminalCoord {
			// x: 30 - 10 = 20
			// y: 50 - 20 = 30
			assert result.x == 20.0
			assert result.y == 30.0
		}
		else {
			assert false
		}
	}
}

// Test Size.grid() computation.
fn test_size_grid() {
	sz := Size{
		screen: ScreenSize{ width: 100, height: 100 }
		cell: CellSize{ width: 5, height: 10 }
		padding: Padding{ left: 10, right: 10, top: 5, bottom: 5 }
	}
	g := sz.grid()
	// Usable: 80x90, cells: 5x10 -> 16 cols, 9 rows
	assert g.columns == 16
	assert g.rows == 9
}

fn test_coordinate_conversion_same_grid_preserves_out_of_bounds_value() {
	sz := Size{
		screen: ScreenSize{ width: 100, height: 100 }
		cell: CellSize{ width: 5, height: 10 }
	}
	result := Coordinate(GridCoord{ x: 500, y: 500 }).convert(.grid, sz)
	match result {
		GridCoord {
			assert result.x == 500
			assert result.y == 500
		}
		else {
			assert false
		}
	}
}

// Test GridSize.init.
fn test_grid_size_init() {
	g := GridSize.init(ScreenSize{ width: 80, height: 48 }, CellSize{ width: 8, height: 16 })
	assert g.columns == 10
	assert g.rows == 3
}
