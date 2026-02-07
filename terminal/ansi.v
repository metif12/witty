module terminal

// Translated from ghostty/src/terminal/ansi.zig

// C0 (7-bit) control characters from ANSI.
//
// This is not complete, control characters are only added to this
// as the terminal emulator handles them.
pub enum C0 {
	// Null
	nul        // 0x00
	// Start of heading
	soh        // 0x01
	// Start of text
	stx        // 0x02
	// Enquiry
	enq        // 0x05
	// Bell
	bel        // 0x07
	// Backspace
	bs         // 0x08
	// Horizontal tab
	ht         // 0x09
	// Line feed
	lf         // 0x0A
	// Vertical Tab
	vt         // 0x0B
	// Form feed
	ff         // 0x0C
	// Carriage return
	cr         // 0x0D
	// Shift out
	so         // 0x0E
	// Shift in
	si         // 0x0F
}

// Build C0 from integer value, or return none if not a recognized control char.
// In Zig this is a non-exhaustive enum; in V we use a lookup function instead.
pub fn C0.from_int(v u8) ?C0 {
	return match v {
		0x00 { .nul }
		0x01 { .soh }
		0x02 { .stx }
		0x05 { .enq }
		0x07 { .bel }
		0x08 { .bs }
		0x09 { .ht }
		0x0A { .lf }
		0x0B { .vt }
		0x0C { .ff }
		0x0D { .cr }
		0x0E { .so }
		0x0F { .si }
		else { none }
	}
}

// Returns the integer value for a C0 control character.
pub fn (self C0) int_val() u8 {
	return match self {
		.nul { 0x00 }
		.soh { 0x01 }
		.stx { 0x02 }
		.enq { 0x05 }
		.bel { 0x07 }
		.bs { 0x08 }
		.ht { 0x09 }
		.lf { 0x0A }
		.vt { 0x0B }
		.ff { 0x0C }
		.cr { 0x0D }
		.so { 0x0E }
		.si { 0x0F }
	}
}

// The SGR rendition aspects that can be set, sometimes known as attributes.
// The value corresponds to the parameter value for the SGR command (ESC [ m).
pub enum RenditionAspect {
	default_    // 0
	bold        // 1
	default_fg  // 39
	default_bg  // 49
}

// Build RenditionAspect from integer value, or return none if not recognized.
// In Zig this is a non-exhaustive enum backed by u16; in V we use a lookup function.
pub fn RenditionAspect.from_int(v u16) ?RenditionAspect {
	return match v {
		0 { .default_ }
		1 { .bold }
		39 { .default_fg }
		49 { .default_bg }
		else { none }
	}
}

// Returns the integer value for a RenditionAspect.
pub fn (self RenditionAspect) int_val() u16 {
	return match self {
		.default_ { 0 }
		.bold { 1 }
		.default_fg { 39 }
		.default_bg { 49 }
	}
}

// The device attribute request type (ESC [ c).
pub enum DeviceAttributeReq {
	primary    // Blank
	secondary  // >
	tertiary   // =
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
pub enum StatusLineType {
	none_       // 0
	indicator   // 1
	host_writable  // 2
}

// Build StatusLineType from integer value, or return none if not recognized.
// In Zig this is a non-exhaustive enum backed by u16; in V we use a lookup function.
pub fn StatusLineType.from_int(v u16) ?StatusLineType {
	return match v {
		0 { .none_ }
		1 { .indicator }
		2 { .host_writable }
		else { none }
	}
}

// Returns the integer value for a StatusLineType.
pub fn (self StatusLineType) int_val() u16 {
	return match self {
		.none_ { 0 }
		.indicator { 1 }
		.host_writable { 2 }
	}
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
// Note: ProtectedMode is also defined in types.v. This is the canonical
// definition from ansi.zig.
pub enum AnsiProtectedMode {
	off
	iso  // ESC V, W
	dec  // CSI Ps " q
}
