module terminal

// Translated from ghostty/src/terminal/csi.zig

// Modes for the ED CSI command.
pub enum CsiEraseDisplay as u8 {
	below           = 0
	above           = 1
	complete        = 2
	scrollback      = 3
	// This is an extension added by Kitty to move the viewport into the
	// scrollback and then erase the display.
	scroll_complete = 22
}

// Modes for the EL CSI command.
pub enum CsiEraseLine as u8 {
	right                     = 0
	left                      = 1
	complete                  = 2
	right_unless_pending_wrap = 4
}

// Modes for the TBC (tab clear) command.
pub enum TabClear as u8 {
	current = 0
	all     = 3
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
