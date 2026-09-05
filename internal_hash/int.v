module internal_hash

// int_u64 is Zig 0.15.2's std.hash.int specialization for u64. Ghostty uses
// this mixer for compact integer cache keys.
@[ignore_overflow]
pub fn int_u64(input u64) u64 {
	mut x := input
	multiplier := u64(0xbea225f9eb34556d)
	x = (x ^ (x >> 32)) * multiplier
	x = (x ^ (x >> 29)) * multiplier
	x = (x ^ (x >> 32)) * multiplier
	return x ^ (x >> 29)
}
