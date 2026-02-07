module terminal

// UTF8Decoder decodes UTF-8 byte sequences one byte at a time.
// Based on Bjoern Hoehrmann's DFA-based approach.
//
// The decoder accepts bytes individually and produces codepoints.
// Invalid sequences produce the replacement character U+FFFD.
pub struct UTF8Decoder {
mut:
	// Current state: 0 = accept (ground), >0 = continuation bytes remaining
	state u8
	// Accumulated codepoint value
	acc u32
	// Minimum valid value for current sequence (overlong detection)
	min_val u32
}

// UTF8DecodeResult is the result of processing a single byte.
pub struct UTF8DecodeResult {
pub:
	// The decoded codepoint, if a complete sequence was formed.
	codepoint ?u32
	// Whether the input byte was consumed.
	consumed bool
}

// next processes a single byte and returns a decode result.
//
// If a codepoint is produced, it will be in the codepoint field.
// The consumed field indicates whether the byte was accepted. If consumed
// is false, the caller should retry with the same byte (the decoder has
// been reset due to an invalid continuation byte).
pub fn (mut self UTF8Decoder) next(byte u8) UTF8DecodeResult {
	if self.state == 0 {
		// Ground state - start of new sequence
		if byte < 0x80 {
			// ASCII
			return UTF8DecodeResult{
				codepoint: u32(byte)
				consumed: true
			}
		}
		if byte & 0xE0 == 0xC0 {
			// 2-byte sequence start (110xxxxx)
			self.state = 1
			self.acc = u32(byte & 0x1F)
			self.min_val = 0x80
			return UTF8DecodeResult{ consumed: true }
		}
		if byte & 0xF0 == 0xE0 {
			// 3-byte sequence start (1110xxxx)
			self.state = 2
			self.acc = u32(byte & 0x0F)
			self.min_val = 0x800
			return UTF8DecodeResult{ consumed: true }
		}
		if byte & 0xF8 == 0xF0 && byte <= 0xF4 {
			// 4-byte sequence start (11110xxx), max F4 for U+10FFFF
			self.state = 3
			self.acc = u32(byte & 0x07)
			self.min_val = 0x10000
			return UTF8DecodeResult{ consumed: true }
		}
		// Invalid start byte (0x80-0xBF, 0xF5-0xFF)
		return UTF8DecodeResult{
			codepoint: 0xFFFD
			consumed: true
		}
	}

	// Continuation byte expected (10xxxxxx)
	if byte & 0xC0 == 0x80 {
		self.acc = (self.acc << 6) | u32(byte & 0x3F)
		self.state -= 1
		if self.state == 0 {
			cp := self.acc
			// Reject overlong encodings, surrogates, and out-of-range
			if cp < self.min_val || (cp >= 0xD800 && cp <= 0xDFFF) || cp > 0x10FFFF {
				return UTF8DecodeResult{
					codepoint: 0xFFFD
					consumed: true
				}
			}
			return UTF8DecodeResult{
				codepoint: cp
				consumed: true
			}
		}
		return UTF8DecodeResult{ consumed: true }
	}

	// Not a valid continuation byte - sequence is broken.
	// Emit replacement character and signal that the byte was NOT consumed,
	// so the caller can retry with this byte as a potential start byte.
	self.state = 0
	return UTF8DecodeResult{
		codepoint: 0xFFFD
		consumed: false
	}
}
