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
