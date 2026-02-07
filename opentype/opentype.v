module opentype

// Stub module for OpenType table parsing.
// XTODO: Replace with real OpenType parsing when available.
//
// This module provides types for reading OpenType font tables
// such as 'head' and 'OS/2'. Used by the font discovery system
// to derive font properties.

// ============================================================
// Head table ('head')
// ============================================================

// Head represents the OpenType 'head' (font header) table.
pub struct Head {
pub:
	// macStyle flags:
	//   bit 0 = bold
	//   bit 1 = italic
	mac_style u16
}

// init parses a Head table from raw bytes.
pub fn Head.init(data []u8) !Head {
	// XTODO: parse the head table from raw font data.
	// The macStyle field is at offset 44 in the head table.
	if data.len < 46 {
		return error('head table too short')
	}
	mac_style := (u16(data[44]) << 8) | u16(data[45])
	return Head{
		mac_style: mac_style
	}
}

// ============================================================
// OS/2 table ('OS/2')
// ============================================================

// FsSelection holds the OS/2 fsSelection flags.
pub struct FsSelection {
pub:
	// Bit 0: italic
	italic bool
	// Bit 5: bold
	bold bool
}

// OS2 represents the OpenType 'OS/2' table.
pub struct OS2 {
pub:
	fs_selection FsSelection
}

// init parses an OS2 table from raw bytes.
pub fn OS2.init(data []u8) !OS2 {
	// XTODO: parse the OS/2 table from raw font data.
	// The fsSelection field is at offset 62 in the OS/2 table.
	if data.len < 64 {
		return error('OS/2 table too short')
	}
	fs := (u16(data[62]) << 8) | u16(data[63])
	return OS2{
		fs_selection: FsSelection{
			italic: (fs & 0x01) != 0
			bold: (fs & 0x20) != 0
		}
	}
}
