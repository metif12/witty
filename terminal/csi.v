module terminal

// Translated from ghostty/src/terminal/csi.zig

// Modes for the ED CSI command.
pub enum CsiEraseDisplay {
	below            // 0
	above            // 1
	complete         // 2
	scrollback       // 3
	// This is an extension added by Kitty to move the viewport into the
	// scrollback and then erase the display.
	scroll_complete  // 22
}

// Build CsiEraseDisplay from integer value, or return none if not recognized.
pub fn CsiEraseDisplay.from_int(v u8) ?CsiEraseDisplay {
	return match v {
		0 { .below }
		1 { .above }
		2 { .complete }
		3 { .scrollback }
		22 { .scroll_complete }
		else { none }
	}
}

// Returns the integer value for a CsiEraseDisplay.
pub fn (self CsiEraseDisplay) int_val() u8 {
	return match self {
		.below { 0 }
		.above { 1 }
		.complete { 2 }
		.scrollback { 3 }
		.scroll_complete { 22 }
	}
}

// Modes for the EL CSI command.
pub enum CsiEraseLine {
	right                       // 0
	left                        // 1
	complete                    // 2
	right_unless_pending_wrap   // 4
}

// Build CsiEraseLine from integer value, or return none if not recognized.
// In Zig this is a non-exhaustive enum backed by u8; in V we use a lookup function.
pub fn CsiEraseLine.from_int(v u8) ?CsiEraseLine {
	return match v {
		0 { .right }
		1 { .left }
		2 { .complete }
		4 { .right_unless_pending_wrap }
		else { none }
	}
}

// Returns the integer value for a CsiEraseLine.
pub fn (self CsiEraseLine) int_val() u8 {
	return match self {
		.right { 0 }
		.left { 1 }
		.complete { 2 }
		.right_unless_pending_wrap { 4 }
	}
}

// Modes for the TBC (tab clear) command.
pub enum TabClear {
	current   // 0
	all       // 3
}

// Build TabClear from integer value, or return none if not recognized.
// In Zig this is a non-exhaustive enum backed by u8; in V we use a lookup function.
pub fn TabClear.from_int(v u8) ?TabClear {
	return match v {
		0 { .current }
		3 { .all }
		else { none }
	}
}

// Returns the integer value for a TabClear.
pub fn (self TabClear) int_val() u8 {
	return match self {
		.current { 0 }
		.all { 3 }
	}
}

// Style formats for terminal size reports.
pub enum SizeReportStyle {
	// XTWINOPS
	csi_14_t
	csi_16_t
	csi_18_t
	csi_21_t
}

// XTWINOPS CSI 22/23
pub struct TitlePushPop {
pub:
	op    TitlePushPopOp
	index u16
}

pub enum TitlePushPopOp {
	push
	pop
}
