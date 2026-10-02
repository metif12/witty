module simd

// DecodeResult reports how many source bytes were consumed and how many
// Unicode codepoints were written.
pub struct DecodeResult {
pub:
	consumed usize
	decoded  usize
}

// utf8_sequence_length matches std.unicode.utf8ByteSequenceLength: it only
// classifies the leading-byte shape. Full scalar validity is checked while
// decoding the selected sequence.
@[inline]
fn utf8_sequence_length(lead u8) ?usize {
	if lead < 0x80 {
		return usize(1)
	}
	if lead & 0xe0 == 0xc0 {
		return usize(2)
	}
	if lead & 0xf0 == 0xe0 {
		return usize(3)
	}
	if lead & 0xf8 == 0xf0 {
		return usize(4)
	}
	return none
}

@[inline]
fn utf8_continuation(value u8) bool {
	return value & 0xc0 == 0x80
}

// utf8_decode_sequence translates std.unicode.utf8Decode for one complete
// byte sequence, rejecting overlong encodings, surrogates, and values beyond
// Unicode's maximum scalar value.
fn utf8_decode_sequence(bytes []u8) ?u32 {
	match bytes.len {
		1 {
			if bytes[0] < 0x80 {
				return u32(bytes[0])
			}
		}
		2 {
			if bytes[0] >= 0xc2 && bytes[0] <= 0xdf && utf8_continuation(bytes[1]) {
				return (u32(bytes[0] & 0x1f) << 6) | u32(bytes[1] & 0x3f)
			}
		}
		3 {
			b0 := bytes[0]
			b1 := bytes[1]
			b2 := bytes[2]
			if b0 >= 0xe0 && b0 <= 0xef && utf8_continuation(b1) && utf8_continuation(b2)
				&& !(b0 == 0xe0 && b1 < 0xa0) && !(b0 == 0xed && b1 >= 0xa0) {
				return (u32(b0 & 0x0f) << 12) | (u32(b1 & 0x3f) << 6) | u32(b2 & 0x3f)
			}
		}
		4 {
			b0 := bytes[0]
			b1 := bytes[1]
			b2 := bytes[2]
			b3 := bytes[3]
			if b0 >= 0xf0 && b0 <= 0xf4 && utf8_continuation(b1) && utf8_continuation(b2)
				&& utf8_continuation(b3) && !(b0 == 0xf0 && b1 < 0x90) && !(b0 == 0xf4 && b1 > 0x8f) {
				return (u32(b0 & 0x07) << 18) | (u32(b1 & 0x3f) << 12) | (u32(b2 & 0x3f) << 6) | u32(b3 & 0x3f)
			}
		}
		else {}
	}

	return none
}

// utf8_decode_until_control_seq decodes UTF-8 until the first ESC byte. It
// preserves Ghostty's SIMD behavior for incomplete and malformed sequences:
// incomplete input is deferred, malformed complete input replaces only its
// leading byte, and an invalid leading byte is left unconsumed.
pub fn utf8_decode_until_control_seq(input []u8, mut output []u32) DecodeResult {
	assert output.len >= input.len
	$if !js && !wasm32 && !no_simd ? {
		mut decoded := usize(0)
		consumed := C.ghostty_simd_decode_utf8_until_control_seq(input.data, usize(input.len),
			output.data, &decoded)
		return DecodeResult{
			consumed: consumed
			decoded:  decoded
		}
	}
	escape_idx := index_of(input, 0x1b) or { usize(input.len) }
	decode_input := input[..escape_idx]

	mut decode_offset := usize(0)
	mut decode_count := usize(0)
	for decode_offset < usize(decode_input.len) {
		remaining := decode_input[int(decode_offset)..]
		cp_len := utf8_sequence_length(remaining[0]) or { break }
		if usize(remaining.len) < cp_len {
			break
		}

		cp_bytes := remaining[..int(cp_len)]
		decode_offset += cp_len
		if cp := utf8_decode_sequence(cp_bytes) {
			output[int(decode_count)] = cp
			decode_count++
		} else {
			output[int(decode_count)] = 0xfffd
			decode_count++
			decode_offset -= cp_len - 1
		}
	}

	return DecodeResult{
		consumed: decode_offset
		decoded:  decode_count
	}
}
