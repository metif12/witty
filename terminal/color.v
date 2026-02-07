module terminal

// ============================================================
// TerminalColor - a color that can be an explicit color or
// derived from cell foreground/background.
// ============================================================

pub enum TerminalColorKind {
	color
	cell_foreground
	cell_background
}

pub struct TerminalColor {
pub mut:
	kind  TerminalColorKind = .color
	color RGB
}

pub fn (tc TerminalColor) to_terminal_rgb() RGB {
	return tc.color
}

// ============================================================
// BoldColor
// ============================================================

pub struct BoldColor {
pub:
	bright bool = true
}

// ============================================================
// RenderState - snapshot of terminal state for rendering
// ============================================================

// DirtyState tracks what level of rebuild is needed.
pub enum DirtyState {
	false_
	partial
	full
}

// RenderState holds a snapshot of terminal state used by the renderer.
// This is updated once per frame from the terminal under a mutex.
pub struct RenderState {
pub mut:
	// Whether the state needs rebuilding.
	dirty DirtyState = .false_
	// The colors currently in effect.
	colors RenderColors
	// Cursor state for rendering.
	cursor RenderCursor
	// Row count.
	rows u16
	// Column count.
	cols u16
}

// Update render state from terminal state.
pub fn (mut s RenderState) update(t &Terminal) ! {
	// XTODO: Full render state update from terminal
}

pub fn (mut s RenderState) deinit() {
	// stub
}

// Search for OSC8 link cells at the given viewport position.
pub fn (s &RenderState) link_cells(vp ViewportPoint) !CellSet {
	return CellSet{}
}

// Update flattened highlights for search matches.
pub fn (mut s RenderState) update_highlights_flattened(tag u8, matches []Selection) ! {
	// stub
}

// RenderColors holds the current color palette and defaults.
pub struct RenderColors {
pub mut:
	// The 256-color palette.
	palette [256]RGB
	// Default background color.
	background RGB = RGB{
		r: 0
		g: 0
		b: 0
	}
	// Default foreground color.
	foreground RGB = RGB{
		r: 255
		g: 255
		b: 255
	}
	// Cursor color, if set by OSC 12.
	cursor ?RGB
}

// RenderCursor holds cursor rendering state.
pub struct RenderCursor {
pub mut:
	// Cursor position in viewport coordinates, if visible.
	viewport ?ViewportPoint
	// The cell data at the cursor position.
	cell RenderCursorCell
}

pub struct RenderCursorCell {
pub mut:
	wide CellWide = .narrow
}

pub struct ViewportPoint {
pub mut:
	x u16
	y u16
	// Whether this is the tail of a wide character.
	wide_tail bool
}

// CellSet is a set of cell coordinates (for link highlighting etc).
pub struct CellSet {
mut:
	cells map[u64]bool
}

pub fn (cs &CellSet) contains(p CellCoord) bool {
	key := u64(p.x) | (u64(p.y) << 16)
	return cs.cells[key] or { false }
}

pub struct CellCoord {
pub:
	x u16
	y u16
}
