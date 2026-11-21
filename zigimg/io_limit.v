module zigimg

// std.Io.Limit's nonexhaustive usize enum, carried as a value in V.
pub struct Limit {
pub:
	value uint
}

pub fn Limit.nothing() Limit {
	return Limit.limited(0)
}

pub fn Limit.unlimited() Limit {
	return Limit.limited(~uint(0))
}

pub fn Limit.limited(count uint) Limit {
	return Limit{
		value: count
	}
}

pub fn Limit.limited64(count u64) Limit {
	return Limit.limited(if count > u64(~uint(0)) { ~uint(0) } else { uint(count) })
}

pub fn Limit.count_vec(data [][]u8) Limit {
	mut total := uint(0)
	for bytes in data {
		if uint(bytes.len) > ~uint(0) - total { panic('integer overflow') }
		total += uint(bytes.len)
	}
	return Limit.limited(total)
}

pub fn (limit Limit) min(other Limit) Limit {
	return Limit.limited(limit.min_int(other.value))
}

pub fn (limit Limit) min_int(count uint) uint {
	return if count < limit.value { count } else { limit.value }
}

pub fn (limit Limit) min_int64(count u64) uint {
	return if count < u64(limit.value) { uint(count) } else { limit.value }
}

pub fn (limit Limit) slice(mut bytes []u8) []u8 {
	return unsafe { bytes[..int(limit.min_int(uint(bytes.len)))] }
}

// V's returned array view cannot enforce Zig's const element qualification.
pub fn (limit Limit) slice_const(bytes []u8) []u8 {
	return unsafe { bytes[..int(limit.min_int(uint(bytes.len)))] }
}

pub fn (limit Limit) to_int() ?uint {
	if limit.value == ~uint(0) { return none }
	return limit.value
}

pub fn (limit Limit) slice1(mut non_empty_buffer []u8) []u8 {
	if non_empty_buffer.len == 0 { panic('reached unreachable code') }
	plus_one := if limit.value == ~uint(0) { limit.value } else { limit.value + 1 }
	len := if plus_one < uint(non_empty_buffer.len) { int(plus_one) } else { non_empty_buffer.len }
	return unsafe { non_empty_buffer[..len] }
}

pub fn (limit Limit) nonzero() bool {
	return limit.value > 0
}

pub fn (limit Limit) subtract(count uint) ?Limit {
	if limit.value == ~uint(0) { return limit }
	if count > limit.value { return none }
	return Limit.limited(limit.value - count)
}
