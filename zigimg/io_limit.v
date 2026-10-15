module zigimg

// std.Io.Limit's nonexhaustive usize enum, carried as a value in V.
pub struct Limit {
pub:
	value usize
}

pub fn Limit.nothing() Limit {
	return Limit.limited(0)
}

pub fn Limit.unlimited() Limit {
	return Limit.limited(~usize(0))
}

pub fn Limit.limited(count usize) Limit {
	return Limit{
		value: count
	}
}

pub fn Limit.limited64(count u64) Limit {
	return Limit.limited(if count > u64(~usize(0)) { ~usize(0) } else { usize(count) })
}

pub fn Limit.count_vec(data [][]u8) Limit {
	mut total := usize(0)
	for bytes in data {
		if usize(bytes.len) > ~usize(0) - total { panic('integer overflow') }
		total += usize(bytes.len)
	}
	return Limit.limited(total)
}

pub fn (limit Limit) min(other Limit) Limit {
	return Limit.limited(limit.min_int(other.value))
}

pub fn (limit Limit) min_int(count usize) usize {
	return if count < limit.value { count } else { limit.value }
}

pub fn (limit Limit) min_int64(count u64) usize {
	return if count < u64(limit.value) { usize(count) } else { limit.value }
}

pub fn (limit Limit) slice(mut bytes []u8) []u8 {
	return unsafe { bytes[..int(limit.min_int(usize(bytes.len)))] }
}

// V's returned array view cannot enforce Zig's const element qualification.
pub fn (limit Limit) slice_const(bytes []u8) []u8 {
	return unsafe { bytes[..int(limit.min_int(usize(bytes.len)))] }
}

pub fn (limit Limit) to_int() ?usize {
	if limit.value == ~usize(0) { return none }
	return limit.value
}

pub fn (limit Limit) slice1(mut non_empty_buffer []u8) []u8 {
	if non_empty_buffer.len == 0 { panic('reached unreachable code') }
	plus_one := if limit.value == ~usize(0) { limit.value } else { limit.value + 1 }
	len := if plus_one < usize(non_empty_buffer.len) { int(plus_one) } else { non_empty_buffer.len }
	return unsafe { non_empty_buffer[..len] }
}

pub fn (limit Limit) nonzero() bool {
	return limit.value > 0
}

pub fn (limit Limit) subtract(count usize) ?Limit {
	if limit.value == ~usize(0) { return limit }
	if count > limit.value { return none }
	return Limit.limited(limit.value - count)
}
