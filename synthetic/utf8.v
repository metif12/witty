module synthetic

import rand

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
	return Utf8{ rng: unsafe { rng } }
}

pub fn (mut self Utf8) generator() Generator {
	return self
}

pub fn (mut self Utf8) next(max_len usize) ![]u8 {
	if isnil(self.rng) {
		return error('random generator is not initialized')
	}
	if self.max_len < self.min_len {
		return error('invalid UTF-8 length range')
	}
	random_len := synthetic_random_inclusive(mut self.rng, self.min_len, self.max_len)!
	len := synthetic_min_usize(random_len, max_len)
	if len > usize(2147483647) {
		return error('UTF-8 length exceeds V array capacity')
	}
	mut result := []u8{cap: int(len)}
	for usize(result.len) < len {
		remaining := len - usize(result.len)
		mut utf8_len := self.choose_length()!
		for usize(utf8_len) > remaining {
			utf8_len = unsafe { Utf8Len(int(utf8_len) - 1) }
		}

		cp := match utf8_len {
			.one { synthetic_random_inclusive(mut self.rng, 0x00, 0x7f)! }
			.two { synthetic_random_inclusive(mut self.rng, 0x80, 0x7ff)! }
			.three { synthetic_random_inclusive(mut self.rng, 0x800, 0xffff)! }
			.four { synthetic_random_inclusive(mut self.rng, 0x10000, 0x10ffff)! }
		}
		if cp >= 0xd800 && cp <= 0xdfff {
			continue
		}
		result << rune(cp).str().bytes()
	}
	return result
}

fn (mut self Utf8) choose_length() !Utf8Len {
	mut total := f64(0)
	for weight in self.p_length {
		if weight < 0 {
			return error('UTF-8 length weights must be non-negative')
		}
		total += weight
	}
	if total <= 0 {
		return error('at least one UTF-8 length weight must be positive')
	}
	pick := self.rng.f64() * total
	mut cumulative := f64(0)
	for i, weight in self.p_length {
		cumulative += weight
		if pick < cumulative {
			return unsafe { Utf8Len(i + 1) }
		}
	}
	return .four
}
