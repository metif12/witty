module terminal

// Translated from ghostty/src/terminal/cursor.zig

// The visual style of the cursor. Whether or not it blinks
// is determined by mode 12 (modes.zig). This mode is synchronized
// with CSI q, the same as xterm.
//
// Note: CursorStyle is also defined in types.v. This is the canonical
// definition from cursor.zig with the full Ghostty comments.
pub enum CursorVisualStyle {
	bar           // DECSCUSR 5, 6
	block         // DECSCUSR 1, 2
	underline     // DECSCUSR 3, 4
	// The cursor styles below aren't known by DECSCUSR and are custom
	// implemented in Ghostty. They are reported as some standard style
	// if requested, though.
	// Hollow block cursor. This is a block cursor with the center empty.
	// Reported as DECSCUSR 1 or 2 (block).
	block_hollow
}
