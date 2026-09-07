module terminal

fn test_utf8_decoder_ascii() {
	mut decoder := UTF8Decoder{}
	mut out := []u8{len: 13}
	for i, byte in 'Hello, World!'.bytes() {
		result := decoder.next(byte)
		assert result.consumed
		if codepoint := result.codepoint {
			out[i] = u8(codepoint)
		}
	}

	assert out.bytestr() == 'Hello, World!'
}

fn test_utf8_decoder_well_formed_utf8() {
	mut decoder := UTF8Decoder{}
	mut out := []u32{}
	// 4 bytes, 3 bytes, 2 bytes, 1 byte
	for byte in '😄✤ÁA'.bytes() {
		mut consumed := false
		for !consumed {
			result := decoder.next(byte)
			consumed = result.consumed
			// There are no errors in this sequence, so every byte should be
			// consumed first try.
			assert consumed
			if codepoint := result.codepoint {
				out << codepoint
			}
		}
	}

	assert out == [u32(0x1f604), 0x2724, 0xc1, 0x41]
}

fn test_utf8_decoder_partially_invalid_utf8() {
	mut decoder := UTF8Decoder{}
	mut out := []u32{}
	// Illegally terminated sequence, valid sequence, illegal surrogate pair.
	input := [u8(0xf0), 0x9f, 0xf0, 0x9f, 0x98, 0x84, 0xed, 0xa0, 0x80]
	for byte in input {
		mut consumed := false
		for !consumed {
			result := decoder.next(byte)
			consumed = result.consumed
			if codepoint := result.codepoint {
				out << codepoint
			}
		}
	}

	assert out == [u32(0xfffd), 0x1f604, 0xfffd, 0xfffd, 0xfffd]
}
