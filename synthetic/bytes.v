module synthetic

import rand
import io

// Bytes generates arbitrary byte strings from an optional alphabet.
pub struct Bytes {
pub mut:
	rng      &rand.PRNG = unsafe { nil }
	min_len  usize      = 1
	max_len  usize      = ~usize(0)
	alphabet ?[]u8
}

pub fn Bytes.init(rng &rand.PRNG) Bytes {
	return Bytes{
		rng: unsafe { rng }
	}
}

// generate_alphabet returns every byte for which check is true, in ascending
// byte order. This is the V equivalent of Ghostty's comptime helper.
pub fn generate_alphabet(check fn (u8) bool) []u8 {
	mut alphabet := []u8{cap: 256}
	for value in 0 .. 256 {
		byte := u8(value)
		if check(byte) {
			alphabet << byte
		}
	}
	return alphabet
}

pub fn (mut self Bytes) generator() Generator {
	return self
}

// new_alphabet returns a copy that draws bytes from the supplied alphabet.
// Duplicate alphabet entries intentionally increase their probability.
pub fn (self &Bytes) new_alphabet(alphabet ?[]u8) Bytes {
	return Bytes{
		rng:      self.rng
		min_len:  self.min_len
		max_len:  self.max_len
		alphabet: alphabet
	}
}

pub fn (self &Bytes) at_least(new_min_len usize) Bytes {
	return Bytes{
		rng:      self.rng
		min_len:  synthetic_min_usize(self.max_len, new_min_len)
		max_len:  self.max_len
		alphabet: self.alphabet
	}
}

pub fn (self &Bytes) at_most(new_max_len usize) Bytes {
	max_len := synthetic_min_usize(self.max_len, new_max_len)
	return Bytes{
		rng:      self.rng
		min_len:  synthetic_min_usize(self.min_len, max_len)
		max_len:  max_len
		alphabet: self.alphabet
	}
}

// Owned-slice compatibility entry points delegate to the source writer API.
pub fn (mut self Bytes) next(max_len usize) ![]u8 {
	mut writer := CollectingWriter{}
	self.next_writer(mut writer, max_len)!
	return writer.data
}

pub fn (mut self Bytes) next_writer(mut writer io.Writer, max_len usize) ! {
	mut bounded := self.at_most(max_len)
	bounded.write_writer(mut writer)!
}

pub fn (mut self Bytes) format() ![]u8 {
	return self.write()
}

pub fn (mut self Bytes) format_writer(mut writer io.Writer) ! {
	self.write_writer(mut writer)!
}

pub fn (mut self Bytes) write() ![]u8 {
	mut writer := CollectingWriter{}
	self.write_writer(mut writer)!
	return writer.data
}

// src/synthetic/Bytes.zig write: choose biased length even for equal endpoints,
// fill exactly eight-byte chunks, map the alphabet, and write before continuing.
pub fn (mut self Bytes) write_writer(mut writer io.Writer) !usize {
	assert self.min_len >= 1
	assert self.max_len >= self.min_len
	len := usize(source_range_biased(mut self.rng, u64(self.min_len), u64(self.max_len),
		int(sizeof(usize) * 8)))
	mut buffer := []u8{len: 8}
	mut remaining := len
	for remaining > 0 {
		count := int(synthetic_min_usize(remaining, usize(buffer.len)))
		mut data := unsafe { buffer[..count] }
		source_random_fill(mut self.rng, mut data)
		if alphabet := self.alphabet {
			for i, byte in data {
				data[i] = alphabet[int(byte) % alphabet.len]
			}
		}
		source_write_all(mut writer, data)!
		remaining -= usize(count)
	}
	return len
}

fn synthetic_random_inclusive(mut rng rand.PRNG, min_value usize, max_value usize) !usize {
	return usize(source_range_biased(mut rng, u64(min_value), u64(max_value),
		int(sizeof(usize) * 8)))
}

fn synthetic_min_usize(a usize, b usize) usize {
	return if a < b { a } else { b }
}
