module xev

// Translations of the Zig 0.15.2 std.math helpers and integer operators that
// libxev's backends use: overflow-checked add/mul/cast (returning `none` where
// Zig returns error.Overflow or null) and the saturating `+|` / `-|`.

// Zig `a -| b` on usize.
@[inline]
fn sat_sub(a uint, b uint) uint {
	return if a > b { a - b } else { 0 }
}

// Zig `a -| b` on u64.
@[inline]
fn sat_sub_u64(a u64, b u64) u64 {
	return if a > b { a - b } else { 0 }
}

// Zig `a +| b` on i64.
@[inline]
fn sat_add_i64(a i64, b i64) i64 {
	if b > 0 && a > max_i64 - b {
		return max_i64
	}
	if b < 0 && a < min_i64 - b {
		return min_i64
	}
	return a + b
}

// std.math.add(i64, a, b)
fn add_i64(a i64, b i64) ?i64 {
	if b > 0 && a > max_i64 - b {
		return none
	}
	if b < 0 && a < min_i64 - b {
		return none
	}
	return a + b
}

// std.math.mul(i64, a, b)
fn mul_i64(a i64, b i64) ?i64 {
	if a == 0 || b == 0 {
		return 0
	}
	result := a * b
	if result / b != a || (a == -1 && b == min_i64) || (b == -1 && a == min_i64) {
		return none
	}
	return result
}

// std.math.add(u64, a, b)
fn add_u64(a u64, b u64) ?u64 {
	if a > max_u64 - b {
		return none
	}
	return a + b
}

// std.math.mul(u64, a, b)
fn mul_u64(a u64, b u64) ?u64 {
	if a != 0 && b > max_u64 / a {
		return none
	}
	return a * b
}

// std.math.cast(i64, v)
fn cast_i64(v u64) ?i64 {
	if v > u64(max_i64) {
		return none
	}
	return i64(v)
}

// std.math.cast(c_int, v)
fn cast_c_int(v uint) ?int {
	if v > uint(max_i32) {
		return none
	}
	return int(v)
}

// @divFloor(a, b) for i64.
fn floor_div_i64(a i64, b i64) i64 {
	q := a / b
	if (a % b != 0) && ((a < 0) != (b < 0)) {
		return q - 1
	}
	return q
}
