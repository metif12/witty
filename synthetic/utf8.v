module synthetic

import rand
import io

pub enum Utf8Len as u8 {
	one   = 1
	two   = 2
	three = 3
	four  = 4
}

// Utf8 generates valid UTF-8 with configurable relative encoding-length
// weights. It does not generate multi-codepoint graphemes, matching Ghostty.
pub struct Utf8 {
pub mut:
	rng      &rand.PRNG = unsafe { nil }
	min_len  usize      = 1
	max_len  usize      = ~usize(0)
	p_length [4]f64     = [f64(1), 1, 1, 1]!
}

pub fn Utf8.init(rng &rand.PRNG) Utf8 {
	return Utf8{
		rng: unsafe { rng }
	}
}

pub fn (mut self Utf8) generator() Generator {
	return self
}

pub fn (mut self Utf8) next(max_len usize) ![]u8 {
	mut writer := CollectingWriter{}
	self.next_writer(mut writer, max_len)!
	return writer.data
}

// src/synthetic/Utf8.zig next. A surrogate retries without writing or reducing
// remaining length; the next random operation remains in the same order.
pub fn (mut self Utf8) next_writer(mut writer io.Writer, max_len usize) ! {
	len := synthetic_min_usize(usize(source_range_biased(mut self.rng, u64(self.min_len),
		u64(self.max_len), int(sizeof(usize) * 8))), max_len)
	mut remaining := len
	for remaining > 0 {
		mut utf8_len := self.choose_length()!
		for usize(utf8_len) > remaining {
			utf8_len = unsafe { Utf8Len(int(utf8_len) - 1) }
		}
		cp := match utf8_len {
			.one { source_range_biased(mut self.rng, 0, 0x7f, 21) }
			.two { source_range_biased(mut self.rng, 0x80, 0x7ff, 21) }
			.three { source_range_biased(mut self.rng, 0x800, 0xffff, 21) }
			.four { source_range_biased(mut self.rng, 0x10000, 0x10ffff, 21) }
		}

		if cp >= 0xd800 && cp <= 0xdfff { continue
		 }
		encoded := rune(cp).str().bytes()
		assert encoded.len == int(utf8_len)
		source_write_all(mut writer, encoded)!
		remaining -= usize(encoded.len)
	}
}

fn (mut self Utf8) choose_length() !Utf8Len {
	return unsafe { Utf8Len(source_weighted_index(mut self.rng, self.p_length[..]) + 1) }
}
