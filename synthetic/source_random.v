module synthetic

import rand
import buildcfg
import math
import math.bits

// Zig 0.15.2 std/Random/{Xoshiro256,SplitMix64}.zig. Each small integer
// consumes a fill operation, which cuts the unused tail of its 64-bit word.
pub struct Xoshiro256 {
mut:
	s [4]u64
}

pub fn new_source_random(seed u64) &rand.PRNG {
	mut rng := &Xoshiro256{}
	rng.seed_u64(seed)
	return &rand.PRNG(rng)
}

fn (mut rng Xoshiro256) seed_u64(seed u64) {
	mut state := seed
	for i in 0 .. 4 {
		state += u64(0x9e3779b97f4a7c15)
		mut z := state
		z = (z ^ (z >> 30)) * u64(0xbf58476d1ce4e5b9)
		z = (z ^ (z >> 27)) * u64(0x94d049bb133111eb)
		rng.s[i] = z ^ (z >> 31)
	}
}

fn (mut rng Xoshiro256) seed(data []u32) {
	assert data.len == 2
	rng.seed_u64(u64(data[0]) | (u64(data[1]) << 32))
}

fn rotl64(value u64, count u32) u64 {
	return (value << count) | (value >> (64 - count))
}

fn (mut rng Xoshiro256) u64() u64 {
	r := rotl64(rng.s[0] + rng.s[3], 23) + rng.s[0]
	t := rng.s[1] << 17
	rng.s[2] ^= rng.s[0]
	rng.s[3] ^= rng.s[1]
	rng.s[1] ^= rng.s[2]
	rng.s[0] ^= rng.s[3]
	rng.s[2] ^= t
	rng.s[3] = rotl64(rng.s[3], 45)
	return r
}

fn (mut rng Xoshiro256) u8() u8 {
	return u8(rng.u64())
}

fn (mut rng Xoshiro256) u16() u16 {
	return u16(rng.u64())
}

fn (mut rng Xoshiro256) u32() u32 {
	return u32(rng.u64())
}

fn (rng Xoshiro256) block_size() int {
	return 64
}

fn (mut rng Xoshiro256) free() {}

// Random.bytes with Xoshiro256.fill's little-endian complete words and cut tail.
fn source_random_fill(mut rng rand.PRNG, mut buffer []u8) {
	mut offset := 0
	for offset < buffer.len {
		mut value := rng.u64()
		count := if buffer.len - offset < 8 { buffer.len - offset } else { 8 }
		for i in 0 .. count {
			buffer[offset + i] = u8(value)
			value >>= 8
		}
		offset += count
	}
}

fn source_mask(width int) u64 {
	return if width == 64 { ~u64(0) } else { (u64(1) << width) - 1 }
}

fn source_uint(mut rng rand.PRNG, width int) u64 {
	return rng.u64() & source_mask(width)
}

fn source_limit_biased(value u64, limit u64, width int) u64 {
	if width == 64 {
		hi, _ := bits.mul_64(value, limit)
		return hi
	}
	return (value * limit) >> width
}

fn source_at_most_biased(mut rng rand.PRNG, maximum u64, width int) u64 {
	if maximum == source_mask(width) { return source_uint(mut rng, width) }
	return source_limit_biased(source_uint(mut rng, width), maximum + 1, width)
}

fn source_range_biased(mut rng rand.PRNG, minimum u64, maximum u64, width int) u64 {
	assert minimum <= maximum
	return minimum + source_at_most_biased(mut rng, maximum - minimum, width)
}

fn source_less_than(mut rng rand.PRNG, limit u64, width int) u64 {
	assert limit > 0
	mut value := source_uint(mut rng, width)
	mut low := u64(0)
	mut high := u64(0)
	if width == 64 {
		high, low = bits.mul_64(value, limit)
	} else {
		product := value * limit
		high = product >> width
		low = product & source_mask(width)
	}
	if low < limit {
		mut threshold := (u64(0) - limit) & source_mask(width)
		if threshold >= limit {
			threshold -= limit
			if threshold >= limit { threshold %= limit }
		}
		for low < threshold {
			value = source_uint(mut rng, width)
			if width == 64 {
				high, low = bits.mul_64(value, limit)
			} else {
				product := value * limit
				high = product >> width
				low = product & source_mask(width)
			}
		}
	}
	return high
}

fn source_range(mut rng rand.PRNG, minimum u64, maximum u64, width int) u64 {
	assert minimum <= maximum
	span := maximum - minimum
	return minimum + if span == source_mask(width) {
		source_uint(mut rng, width)
	} else {
		source_less_than(mut rng, span + 1, width)
	}
}

fn source_float(mut rng rand.PRNG) f64 {
	value := rng.u64()
	mut leading := u64(bits.leading_zeros_64(value))
	if leading >= 12 {
		leading = 12
		for {
			additional := u64(bits.leading_zeros_64(rng.u64()))
			leading += additional
			if additional != 64 { break
			 }
			if leading >= 1022 {
				leading = 1022
				break
			}
		}
	}
	return math.f64_from_bits(((1022 - leading) << 52) | (value & u64(0xfffffffffffff)))
}

fn source_weighted_index(mut rng rand.PRNG, weights []f64) int {
	mut sum := f64(0)
	for weight in weights {
		sum += weight
	}
	point := math.min(source_float(mut rng) * sum, sum - 2.220446049250313e-16)
	assert point < sum
	mut accumulated := f64(0)
	for i, weight in weights {
		accumulated += weight
		if point < accumulated { return i }
	}
	panic('unreachable weighted index')
}

// Zig checked unsigned subtraction at OSC nominal-limit boundaries.
fn source_sub(value uint, amount uint) uint {
	if buildcfg.runtime_safety && value < amount { panic('integer overflow') }
	return value - amount
}
