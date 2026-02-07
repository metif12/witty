module terminal

// Tests for charsets.v.
// Translated from Ghostty's terminal/charsets.zig tests.

// ============================================================
// Table length tests
// ============================================================

// Test that all charset tables have the expected length of 256.
// Yes, we could use `charset_table_len` here, but we want to
// explicitly use a hardcoded constant so that if there are
// issues, we catch them.
fn test_charset_table_lengths() {
	// ASCII table
	ascii_tbl := charset_table(.ascii)
	assert ascii_tbl.len == 256

	// British table
	british_tbl := charset_table(.british)
	assert british_tbl.len == 256

	// DEC Special Graphics table
	dec_tbl := charset_table(.dec_special)
	assert dec_tbl.len == 256
}

// ============================================================
// ASCII table identity tests
// ============================================================

// Test that the ASCII table is an identity mapping.
fn test_charset_ascii_identity() {
	tbl := charset_table(.ascii)
	for i in 0 .. 256 {
		assert tbl[i] == u16(i), 'ASCII table mismatch at index ${i}'
	}
}

// ============================================================
// British charset tests
// ============================================================

// Test that the British charset maps '#' to the pound sign.
fn test_charset_british_pound() {
	tbl := charset_table(.british)
	// 0x23 = '#' should map to U+00A3 (pound sign)
	assert tbl[0x23] == u16(0x00A3)
}

// Test that the British charset is identity for all other characters.
fn test_charset_british_identity_except_hash() {
	tbl := charset_table(.british)
	for i in 0 .. 256 {
		if i == 0x23 {
			continue // skip the pound sign mapping
		}
		assert tbl[i] == u16(i), 'British table mismatch at index ${i}'
	}
}

// ============================================================
// DEC Special Graphics tests
// ============================================================

// Test specific DEC Special Graphics mappings.
fn test_charset_dec_special_mappings() {
	tbl := charset_table(.dec_special)

	// '`' (0x60) -> Black Diamond (U+25C6)
	assert tbl[0x60] == u16(0x25C6)

	// 'a' (0x61) -> Medium Shade (U+2592)
	assert tbl[0x61] == u16(0x2592)

	// 'j' (0x6A) -> Box Drawings Light Up and Left (U+2518)
	assert tbl[0x6A] == u16(0x2518)

	// 'k' (0x6B) -> Box Drawings Light Down and Left (U+2510)
	assert tbl[0x6B] == u16(0x2510)

	// 'l' (0x6C) -> Box Drawings Light Down and Right (U+250C)
	assert tbl[0x6C] == u16(0x250C)

	// 'm' (0x6D) -> Box Drawings Light Up and Right (U+2514)
	assert tbl[0x6D] == u16(0x2514)

	// 'n' (0x6E) -> Box Drawings Light Vertical and Horizontal (U+253C)
	assert tbl[0x6E] == u16(0x253C)

	// 'q' (0x71) -> Box Drawings Light Horizontal (U+2500)
	assert tbl[0x71] == u16(0x2500)

	// 'x' (0x78) -> Box Drawings Light Vertical (U+2502)
	assert tbl[0x78] == u16(0x2502)

	// 'y' (0x79) -> Less-Than or Equal To (U+2264)
	assert tbl[0x79] == u16(0x2264)

	// 'z' (0x7A) -> Greater-Than or Equal To (U+2265)
	assert tbl[0x7A] == u16(0x2265)

	// '{' (0x7B) -> Greek Small Letter Pi (U+03C0)
	assert tbl[0x7B] == u16(0x03C0)

	// '|' (0x7C) -> Not Equal To (U+2260)
	assert tbl[0x7C] == u16(0x2260)

	// '}' (0x7D) -> Pound Sign (U+00A3)
	assert tbl[0x7D] == u16(0x00A3)

	// '~' (0x7E) -> Middle Dot (U+00B7)
	assert tbl[0x7E] == u16(0x00B7)
}

// Test that DEC Special Graphics is identity for characters
// outside the 0x60-0x7E range.
fn test_charset_dec_special_identity_outside_range() {
	tbl := charset_table(.dec_special)
	for i in 0 .. 0x60 {
		assert tbl[i] == u16(i), 'DEC Special table mismatch at index ${i}'
	}
	for i in 0x7F .. 256 {
		assert tbl[i] == u16(i), 'DEC Special table mismatch at index ${i}'
	}
}

// ============================================================
// UTF-8 fallback test
// ============================================================

// Test that requesting a table for utf8 returns the ascii table
// as a safe fallback (utf8 is not table-based).
fn test_charset_utf8_fallback() {
	tbl := charset_table(.utf8)
	assert tbl.len == 256
	// Should be identity (ascii fallback)
	for i in 0 .. 256 {
		assert tbl[i] == u16(i)
	}
}
