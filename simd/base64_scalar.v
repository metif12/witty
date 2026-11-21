module simd

// src/simd/base64_scalar.zig: the source lookup-table/block decoder, including
// the deliberately disabled tail-bit checks required by Kitty graphics.
const base64_invalid_char = u8(0xff)
const base64_invalid_char_test = u32(0xff000000)
const scalar_decoder = base64_decoder_init('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.bytes(),
	none)

struct ScalarBase64Decoder {
mut:
	char_to_index      [256]u8
	fast_char_to_index [4][256]u32
	pad_char           ?u8
}

fn base64_decoder_init(alphabet []u8, pad_char ?u8) ScalarBase64Decoder {
	assert alphabet.len == 64
	mut result := ScalarBase64Decoder{
		pad_char: pad_char
	}
	mut seen := [256]bool{}
	for c in 0 .. 256 {
		result.char_to_index[c] = base64_invalid_char
		for i in 0 .. 4 {
			result.fast_char_to_index[i][c] = base64_invalid_char_test
		}
	}
	for i, c in alphabet {
		assert !seen[c]
		if pad := pad_char { assert c != pad
		 }
		ci := u32(i)
		result.fast_char_to_index[0][c] = ci << 2
		result.fast_char_to_index[1][c] = (ci >> 4) | ((ci & 0x0f) << 12)
		result.fast_char_to_index[2][c] = ((ci & 0x3) << 22) | ((ci & 0x3c) << 6)
		result.fast_char_to_index[3][c] = ci << 16
		result.char_to_index[c] = u8(i)
		seen[c] = true
	}
	return result
}

pub fn calc_size_upper_bound(source_len uint) !uint {
	return scalar_decoder.calc_size_upper_bound(source_len)
}

fn (decoder &ScalarBase64Decoder) calc_size_upper_bound(source_len uint) !uint {
	mut result := source_len / 4 * 3
	leftover := source_len % 4
	if _ := decoder.pad_char {
		if leftover != 0 { return error('InvalidPadding') }
	} else {
		if leftover == 1 { return error('InvalidPadding') }
		result += leftover * 3 / 4
	}
	return result
}

pub fn calc_size_for_slice(source []u8) !uint {
	return scalar_decoder.calc_size_for_slice(source)
}

fn (decoder &ScalarBase64Decoder) calc_size_for_slice(source []u8) !uint {
	mut result := decoder.calc_size_upper_bound(uint(source.len))!
	if pad := decoder.pad_char {
		if source.len >= 1 && source[source.len - 1] == pad { result-- }
		if source.len >= 2 && source[source.len - 2] == pad { result-- }
	}
	return result
}

fn scalar_base64_decode(source []u8, mut dest []u8) ! {
	scalar_decoder.decode(mut dest, source)!
}

fn (decoder &ScalarBase64Decoder) decode(mut dest []u8, source []u8) ! {
	if decoder.pad_char != none && source.len % 4 != 0 {
		return error('InvalidPadding')
	}
	mut dest_idx := 0
	mut fast_src_idx := 0
	mut acc := u16(0) // Explicit truncation represents the source u12.
	mut acc_len := u8(0)
	mut leftover_idx := ?int(none)
	for fast_src_idx + 16 < source.len && dest_idx + 15 < dest.len {
		// Two u64 words represent the source u128. Validate all four quanta
		// before performing its overlapping sixteen-byte write.
		mut low := u64(0)
		mut high := u64(0)
		for i in 0 .. 4 {
			mut bits := decoder.fast_char_to_index[0][source[fast_src_idx + i * 4]]
			bits |= decoder.fast_char_to_index[1][source[fast_src_idx + i * 4 + 1]]
			bits |= decoder.fast_char_to_index[2][source[fast_src_idx + i * 4 + 2]]
			bits |= decoder.fast_char_to_index[3][source[fast_src_idx + i * 4 + 3]]
			if bits & base64_invalid_char_test != 0 { return error('InvalidCharacter') }
			shift := i * 24
			if shift < 64 {
				low |= u64(bits) << u32(shift)
				if shift > 32 { high |= u64(bits) >> u32(64 - shift) }
			} else {
				high |= u64(bits) << u32(shift - 64)
			}
		}
		for i in 0 .. 8 {
			dest[dest_idx + i] = u8(low >> u32(i * 8))
			dest[dest_idx + i + 8] = u8(high >> u32(i * 8))
		}
		fast_src_idx += 16
		dest_idx += 12
	}
	for fast_src_idx + 4 < source.len && dest_idx + 3 < dest.len {
		mut bits := decoder.fast_char_to_index[0][source[fast_src_idx]]
		bits |= decoder.fast_char_to_index[1][source[fast_src_idx + 1]]
		bits |= decoder.fast_char_to_index[2][source[fast_src_idx + 2]]
		bits |= decoder.fast_char_to_index[3][source[fast_src_idx + 3]]
		if bits & base64_invalid_char_test != 0 { return error('InvalidCharacter') }
		for i in 0 .. 4 {
			dest[dest_idx + i] = u8(bits >> u32(i * 8))
		}
		fast_src_idx += 4
		dest_idx += 3
	}
	for index in fast_src_idx .. source.len {
		c := source[index]
		d := decoder.char_to_index[c]
		if d == base64_invalid_char {
			if pad := decoder.pad_char {
				if c != pad { return error('InvalidCharacter') }
			} else {
				return error('InvalidCharacter')
			}
			leftover_idx = index
			break
		}
		acc = ((acc << 6) & 0xfff) + u16(d)
		acc_len += 6
		if acc_len >= 8 {
			acc_len -= 8
			dest[dest_idx] = u8(acc >> acc_len)
			dest_idx++
		}
	}
	if index := leftover_idx {
		if pad := decoder.pad_char {
			padding_len := int(acc_len / 2)
			mut padding_chars := 0
			for c in source[index..] {
				if c != pad {
					if c == base64_invalid_char { return error('InvalidCharacter') }
					return error('InvalidPadding')
				}
				padding_chars++
			}
			if padding_chars != padding_len { return error('InvalidPadding') }
		}
	}
}
