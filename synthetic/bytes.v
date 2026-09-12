module synthetic

import rand

// Bytes generates arbitrary byte strings from an optional alphabet.
pub struct Bytes {
pub mut:
	rng      &rand.PRNG = unsafe { nil }
	min_len  usize = 1
	max_len  usize = ~usize(0)
	alphabet ?[]u8
}

pub fn Bytes.init(rng &rand.PRNG) Bytes {
	return Bytes{ rng: unsafe { rng } }
}

pub fn (mut self Bytes) generator() Generator {
	return self
}

// new_alphabet returns a copy that draws bytes from the supplied alphabet.
// Duplicate alphabet entries intentionally increase their probability.
pub fn (self &Bytes) new_alphabet(alphabet ?[]u8) Bytes {
	return Bytes{
		rng: self.rng
		min_len: self.min_len
		max_len: self.max_len
		alphabet: alphabet
	}
}

pub fn (self &Bytes) at_least(new_min_len usize) Bytes {
	return Bytes{
		rng: self.rng
		min_len: synthetic_min_usize(self.max_len, new_min_len)
		max_len: self.max_len
		alphabet: self.alphabet
	}
}

pub fn (self &Bytes) at_most(new_max_len usize) Bytes {
	max_len := synthetic_min_usize(self.max_len, new_max_len)
	return Bytes{
		rng: self.rng
		min_len: synthetic_min_usize(self.min_len, max_len)
		max_len: max_len
		alphabet: self.alphabet
	}
}

pub fn (mut self Bytes) next(max_len usize) ![]u8 {
	mut bounded := self.at_most(max_len)
	return bounded.write()
}

// write generates one random value and returns the bytes written by the Zig
// writer-based implementation.
pub fn (mut self Bytes) write() ![]u8 {
	if isnil(self.rng) {
		return error('random generator is not initialized')
	}
	if self.min_len < 1 || self.max_len < self.min_len {
		return error('invalid byte length range')
	}
	len := synthetic_random_inclusive(mut self.rng, self.min_len, self.max_len)!
	if len > usize(2147483647) {
		return error('byte length exceeds V array capacity')
	}
	mut result := self.rng.bytes(int(len))!
	if alphabet := self.alphabet {
		for i, byte in result {
			result[i] = alphabet[int(byte) % alphabet.len]
		}
	}
	return result
}

fn synthetic_random_inclusive(mut rng rand.PRNG, min_value usize, max_value usize) !usize {
	if min_value == max_value {
		return min_value
	}
	if min_value == 0 && max_value == ~usize(0) {
		return usize(rng.u64())
	}
	span := max_value - min_value + 1
	return min_value + usize(rng.u64n(u64(span))!)
}

fn synthetic_min_usize(a usize, b usize) usize {
	return if a < b { a } else { b }
}
