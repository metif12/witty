module terminal

// Character set types and lookup tables.
// Translated from Ghostty's terminal/charsets.zig.
//
// The Charset enum and CharsetSlot enum are defined in types.v.
// The ActiveSlot enum is defined in terminal.v.
// This file provides the character mapping tables for each charset
// and the lookup function to get the appropriate table.

// ============================================================
// Table length
// ============================================================

// Our table length is 256 so we can contain all ASCII chars.
const charset_table_len = 256

// ============================================================
// Charset lookup tables
// ============================================================

// Returns the charset mapping table for the given charset.
// The returned array maps byte values (0-255) to Unicode codepoints (u16).
// For most characters the mapping is identity (ASCII value = codepoint).
// Only specific characters are remapped for non-ASCII charsets.
//
// Note: utf8 is not a table-based charset. Callers should check if the
// charset is utf8 and NOT use tables in that case.
pub fn charset_table(set Charset) []u16 {
	return match set {
		.british { charset_british[..] }
		.dec_special { charset_dec_special[..] }
		// ascii is a direct identity mapping but we support a table
		.ascii { charset_ascii[..] }
		// UTF-8 is not table based. Reaching this branch is a caller bug,
		// matching Ghostty's unreachable branch.
		.utf8 { panic('UTF-8 does not have a charset lookup table') }
	}
}

// ============================================================
// ASCII table - identity mapping
// ============================================================

// Just a basic c => c ASCII table. Every byte maps to itself.
const charset_ascii = init_charset_table()

// ============================================================
// British charset table
// ============================================================

// https://vt100.net/docs/vt220-rm/chapter2.html
// The British charset replaces '#' (0x23) with the pound sign (U+00A3).
const charset_british = init_british_table()

fn init_british_table() [256]u16 {
	mut tbl := init_charset_table()
	tbl[0x23] = u16(0x00A3) // '#' -> pound sign
	return tbl
}

// ============================================================
// DEC Special Graphics charset table
// ============================================================

// https://en.wikipedia.org/wiki/DEC_Special_Graphics
// The DEC Special Graphics charset maps various ASCII characters
// in the range 0x60-0x7E to box-drawing and other special characters.
const charset_dec_special = init_dec_special_table()

fn init_dec_special_table() [256]u16 {
	mut tbl := init_charset_table()
	tbl[0x60] = u16(0x25C6) // '`' -> Black Diamond
	tbl[0x61] = u16(0x2592) // 'a' -> Medium Shade
	tbl[0x62] = u16(0x2409) // 'b' -> Symbol for Horizontal Tabulation
	tbl[0x63] = u16(0x240C) // 'c' -> Symbol for Form Feed
	tbl[0x64] = u16(0x240D) // 'd' -> Symbol for Carriage Return
	tbl[0x65] = u16(0x240A) // 'e' -> Symbol for Line Feed
	tbl[0x66] = u16(0x00B0) // 'f' -> Degree Sign
	tbl[0x67] = u16(0x00B1) // 'g' -> Plus-Minus Sign
	tbl[0x68] = u16(0x2424) // 'h' -> Symbol for Newline
	tbl[0x69] = u16(0x240B) // 'i' -> Symbol for Vertical Tabulation
	tbl[0x6A] = u16(0x2518) // 'j' -> Box Drawings Light Up and Left
	tbl[0x6B] = u16(0x2510) // 'k' -> Box Drawings Light Down and Left
	tbl[0x6C] = u16(0x250C) // 'l' -> Box Drawings Light Down and Right
	tbl[0x6D] = u16(0x2514) // 'm' -> Box Drawings Light Up and Right
	tbl[0x6E] = u16(0x253C) // 'n' -> Box Drawings Light Vertical and Horizontal
	tbl[0x6F] = u16(0x23BA) // 'o' -> Horizontal Scan Line-1
	tbl[0x70] = u16(0x23BB) // 'p' -> Horizontal Scan Line-3
	tbl[0x71] = u16(0x2500) // 'q' -> Box Drawings Light Horizontal
	tbl[0x72] = u16(0x23BC) // 'r' -> Horizontal Scan Line-7
	tbl[0x73] = u16(0x23BD) // 's' -> Horizontal Scan Line-9
	tbl[0x74] = u16(0x251C) // 't' -> Box Drawings Light Vertical and Right
	tbl[0x75] = u16(0x2524) // 'u' -> Box Drawings Light Vertical and Left
	tbl[0x76] = u16(0x2534) // 'v' -> Box Drawings Light Up and Horizontal
	tbl[0x77] = u16(0x252C) // 'w' -> Box Drawings Light Down and Horizontal
	tbl[0x78] = u16(0x2502) // 'x' -> Box Drawings Light Vertical
	tbl[0x79] = u16(0x2264) // 'y' -> Less-Than or Equal To
	tbl[0x7A] = u16(0x2265) // 'z' -> Greater-Than or Equal To
	tbl[0x7B] = u16(0x03C0) // '{' -> Greek Small Letter Pi
	tbl[0x7C] = u16(0x2260) // '|' -> Not Equal To
	tbl[0x7D] = u16(0x00A3) // '}' -> Pound Sign
	tbl[0x7E] = u16(0x00B7) // '~' -> Middle Dot
	return tbl
}

// ============================================================
// Table initialization helper
// ============================================================

// Creates a table that maps ASCII to ASCII as a starting point.
// Every index i maps to the value i (identity mapping).
fn init_charset_table() [256]u16 {
	mut result := [256]u16{}
	for i in 0 .. charset_table_len {
		result[i] = u16(i)
	}
	return result
}
