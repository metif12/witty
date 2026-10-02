module input

// Scalar branch of Zig 0.15.2 std/unicode.zig utf8ValidateSliceImpl, as
// used by Ghostty's Utf8View.init. Rejects overlong, surrogate, truncated,
// and out-of-range sequences before the key encoder iterates codepoints.
fn source_utf8_validate(text string) bool {
	lo_cb := u8(0x80)
	hi_cb := u8(0xbf)
	xx := u8(0xf1)
	mut first := [256]u8{}
	for i in 0 .. 128 { first[i] = 0xf0 }
	for i in 128 .. 192 { first[i] = xx }
	starts := [u8(0xf1), 0xf1, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
		0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
		0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
		0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
		0x13, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
		0x03, 0x03, 0x03, 0x03, 0x03, 0x23, 0x03, 0x03,
		0x34, 0x04, 0x04, 0x04, 0x44, 0xf1, 0xf1, 0xf1,
		0xf1, 0xf1, 0xf1, 0xf1, 0xf1, 0xf1, 0xf1, 0xf1]
	for i, info in starts { first[192 + i] = info }
	mut i := 0
	for i < text.len {
		first_byte := text[i]
		if first_byte < 0x80 { i++; continue }
		info := first[first_byte]
		if info == xx { return false }
		size := int(info & 7)
		if i + size > text.len { return false }
		mut accept_lo := lo_cb
		mut accept_hi := hi_cb
		match info >> 4 {
			0 {}
			1 { accept_lo = 0xa0 }
			2 { accept_hi = 0x9f }
			3 { accept_lo = 0x90 }
			4 { accept_hi = 0x8f }
			else { panic('unreachable UTF-8 acceptance class') }
		}
		c1 := text[i + 1]
		if c1 < accept_lo || accept_hi < c1 { return false }
		match size {
			2 { i += 2 }
			3 {
				c2 := text[i + 2]
				if c2 < lo_cb || hi_cb < c2 { return false }
				i += 3
			}
			4 {
				c2 := text[i + 2]
				if c2 < lo_cb || hi_cb < c2 { return false }
				c3 := text[i + 3]
				if c3 < lo_cb || hi_cb < c3 { return false }
				i += 4
			}
			else { panic('unreachable UTF-8 sequence size') }
		}
	}
	return true
}
