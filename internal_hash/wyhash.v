module internal_hash

import math.bits

// Zig 0.15.2's std.hash.Wyhash constants. This is the exact algorithm used by
// the Ghostty revision Witty translates; V's standard `hash` module currently
// exposes a different Wyhash revision and therefore produces different hashes.
const wyhash_secret = [u64(0xa0761d6478bd642f), 0xe7037ed1a0b428db, 0x8ebc6af09c88c6e3,
	0x589965cc75374cc3]

// wyhash returns Zig 0.15.2 std.hash.Wyhash.hash(seed, input).
pub fn wyhash(input []u8, seed u64) u64 {
	mut state := [3]u64{}
	state[0] = seed ^ wyhash_mix(seed ^ wyhash_secret[0], wyhash_secret[1])
	state[1] = state[0]
	state[2] = state[0]

	mut a := u64(0)
	mut b := u64(0)
	if input.len <= 16 {
		if input.len >= 4 {
			end := input.len - 4
			quarter := (input.len / 8) * 4
			a = (wyhash_read(input, 0, 4) << 32) | wyhash_read(input, quarter, 4)
			b = (wyhash_read(input, end, 4) << 32) | wyhash_read(input, end - quarter, 4)
		} else if input.len > 0 {
			a = (u64(input[0]) << 16) | (u64(input[input.len >> 1]) << 8) | u64(input[input.len - 1])
		}
	} else {
		mut offset := 0
		if input.len >= 48 {
			for offset + 48 < input.len {
				for lane in 0 .. 3 {
					left := wyhash_read(input, offset + 16 * lane, 8)
					right := wyhash_read(input, offset + 16 * lane + 8, 8)
					state[lane] = wyhash_mix(left ^ wyhash_secret[lane + 1], right ^ state[lane])
				}
				offset += 48
			}
			state[0] ^= state[1] ^ state[2]
		}

		for offset + 16 < input.len {
			state[0] = wyhash_mix(wyhash_read(input, offset, 8) ^ wyhash_secret[1], wyhash_read(input, offset + 8, 8) ^ state[0])
			offset += 16
		}
		a = wyhash_read(input, input.len - 16, 8)
		b = wyhash_read(input, input.len - 8, 8)
	}

	low, high := wyhash_mum(a ^ wyhash_secret[1], b ^ state[0])
	return wyhash_mix(low ^ wyhash_secret[0] ^ u64(input.len), high ^ wyhash_secret[1])
}

@[direct_array_access; inline]
fn wyhash_read(input []u8, offset int, count int) u64 {
	mut result := u64(0)
	for index in 0 .. count {
		result |= u64(input[offset + index]) << u32(index * 8)
	}
	return result
}

@[inline]
fn wyhash_mum(a u64, b u64) (u64, u64) {
	high, low := bits.mul_64(a, b)
	return low, high
}

@[inline]
fn wyhash_mix(a u64, b u64) u64 {
	low, high := wyhash_mum(a, b)
	return low ^ high
}

// auto_hash_u64 is Zig 0.15.2's std.hash_map.AutoContext(u64).hash. u64 has
// a unique representation, so AutoContext hashes its eight little-endian
// bytes directly with Wyhash.
pub fn auto_hash_u64(value u64) u64 {
	data := [u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24), u8(value >> 32),
		u8(value >> 40), u8(value >> 48), u8(value >> 56)]
	return wyhash(data, 0)
}
