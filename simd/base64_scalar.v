module simd

// Scalar Base64 decoder used when Ghostty's optional C++ SIMD backend is not
// linked. This follows src/simd/base64_scalar.zig, including its intentionally
// permissive Kitty-graphics padding behavior.

const base64_invalid_char = u8(0xff)

// base64_char_to_index maps the standard Base64 alphabet to its six-bit value.
@[inline]
fn base64_char_to_index(c u8) u8 {
	return match c {
		`A`...`Z` { c - `A` }
		`a`...`z` { c - `a` + 26 }
		`0`...`9` { c - `0` + 52 }
		`+` { 62 }
		`/` { 63 }
		else { base64_invalid_char }
	}
}

// scalar_base64_calc_size returns the exact decoded size for an unpadded
// input. A remainder of one byte cannot form a Base64 quantum.
fn scalar_base64_calc_size(source []u8) !usize {
	mut result := usize(source.len / 4 * 3)
	leftover := usize(source.len % 4)
	if leftover == 1 {
		return error('InvalidPadding')
	}
	result += leftover * 3 / 4
	return result
}

// scalar_base64_decode decodes the standard alphabet. As in Ghostty's copied
// Zig decoder, unused low bits in the final quantum are deliberately not
// rejected because the Kitty graphics protocol accepts non-canonical padding.
fn scalar_base64_decode(source []u8, mut dest []u8) ! {
	mut dest_idx := 0
	mut acc := u32(0)
	mut acc_len := 0
	for c in source {
		d := base64_char_to_index(c)
		if d == base64_invalid_char {
			return error('InvalidCharacter')
		}
		acc = (acc << 6) | u32(d)
		acc_len += 6
		if acc_len >= 8 {
			acc_len -= 8
			if dest_idx >= dest.len {
				return error('NoSpaceLeft')
			}
			dest[dest_idx] = u8(acc >> u32(acc_len))
			dest_idx++
			if acc_len == 0 {
				acc = 0
			} else {
				acc &= (u32(1) << u32(acc_len)) - 1
			}
		}
	}
}
