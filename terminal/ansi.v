module terminal

// Translated from ghostty/src/terminal/ansi.zig

// C0 (7-bit) control characters from ANSI.
//
// This is not complete, control characters are only added to this
// as the terminal emulator handles them.
pub enum C0 as u8 {
	// Null
	nul = 0x00
	// Start of heading
	soh = 0x01
	// Start of text
	stx = 0x02
	// Enquiry
	enq = 0x05
	// Bell
	bel = 0x07
	// Backspace
	bs  = 0x08
	// Horizontal tab
	ht  = 0x09
	// Line feed
	lf  = 0x0A
	// Vertical Tab
	vt  = 0x0B
	// Form feed
	ff  = 0x0C
	// Carriage return
	cr  = 0x0D
	// Shift out
	so  = 0x0E
	// Shift in
	si  = 0x0F
}

// The SGR rendition aspects that can be set, sometimes known as attributes.
// The value corresponds to the parameter value for the SGR command (ESC [ m).
pub enum RenditionAspect as u16 {
	default_   = 0
	bold       = 1
	default_fg = 39
	default_bg = 49
}

// The device attribute request type (ESC [ c).
pub enum DeviceAttributeReq {
	primary // Blank
	secondary // >
	tertiary // =
}

// Possible cursor styles (ESC [ q)
pub enum AnsiCursorStyle {
	default_
	blinking_block
	steady_block
	blinking_underline
	steady_underline
	blinking_bar
	steady_bar
}

// The status line type for DECSSDT.
pub enum StatusLineType as u16 {
	none_         = 0
	indicator     = 1
	host_writable = 2
}

// The display to target for status updates (DECSASD).
pub enum StatusDisplay {
	main
	status_line
}

// The possible modify key formats to ESC[>{a};{b}m
// Note: this is not complete, we should add more as we support more
pub enum ModifyKeyFormat {
	legacy
	cursor_keys
	function_keys
	other_keys_none
	other_keys_numeric_except
	other_keys_numeric
}

// The protection modes that can be set for the terminal. See DECSCA and
// ESC V, W.
pub enum ProtectedMode as u8 {
	off
	iso // ESC V, W
	dec // CSI Ps " q
}
