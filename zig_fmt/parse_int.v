module zig_fmt

// parse_unsigned matches Zig's std.fmt.parseUnsigned scanner. A zero base
// enables b/o/x prefix detection; underscores are ignored only when they are
// not the first or last character of the digit spelling.
pub fn parse_unsigned(raw string, max_value u64, requested_base u8) !u64 {
	if raw.len == 0 || (requested_base != 0 && (requested_base < 2 || requested_base > 36)) {
		return error('invalid character')
	}

	mut base := if requested_base == 0 { u64(10) } else { u64(requested_base) }
	mut start := 0
	if requested_base == 0 && raw.len > 2 && raw[0] == `0` {
		match raw[1] {
			`b`, `B` {
				base = 2
				start = 2
			}
			`o`, `O` {
				base = 8
				start = 2
			}
			`x`, `X` {
				base = 16
				start = 2
			}
			else {}
		}
	}
	if raw[start] == `_` || raw[raw.len - 1] == `_` {
		return error('invalid character')
	}

	mut result := u64(0)
	for ch in raw[start..] {
		if ch == `_` {
			continue
		}
		digit := match ch {
			`0`...`9` { u64(ch - `0`) }
			`a`...`z` { u64(ch - `a`) + 10 }
			`A`...`Z` { u64(ch - `A`) + 10 }
			else { return error('invalid character') }
		}
		if digit >= base {
			return error('invalid character')
		}
		if digit > max_value || result > (max_value - digit) / base {
			return error('overflow')
		}
		result = result * base + digit
	}
	return result
}

// parse_int_unsigned matches std.fmt.parseInt for an unsigned integer type.
// Unlike parseUnsigned, parseInt consumes a leading sign; a negative unsigned
// spelling is valid only when its value is zero.
pub fn parse_int_unsigned(raw string, bits int, base u8) !u64 {
	if bits < 1 || bits > 64 {
		return error('invalid character')
	}
	max_value := if bits == 64 { max_u64 } else { (u64(1) << u32(bits)) - 1 }
	return parse_int_unsigned_max(raw, max_value, base)
}

// parse_int_unsigned_max is parseInt for an unsigned integer whose maximum
// value is supplied directly. This supports translated non-byte-aligned Zig
// types such as u9 and u21.
pub fn parse_int_unsigned_max(raw string, max_value u64, base u8) !u64 {
	if raw.len == 0 {
		return error('invalid character')
	}
	negative := raw[0] == `-`
	start := if negative || raw[0] == `+` { 1 } else { 0 }
	if start == raw.len {
		return error('invalid character')
	}
	result := parse_unsigned(raw[start..], max_value, base)!
	if negative && result != 0 {
		return error('overflow')
	}
	return result
}

// parse_int_signed matches std.fmt.parseInt for a signed integer type.
pub fn parse_int_signed(raw string, bits int, base u8) !i64 {
	if bits < 1 || bits > 64 {
		return error('invalid character')
	}
	max_positive := if bits == 64 { u64(max_i64) } else { (u64(1) << u32(bits - 1)) - 1 }
	return parse_int_signed_limits(raw, max_positive, max_positive + 1, base)
}

// parse_int_signed_limits is parseInt for a signed integer whose positive and
// negative magnitudes are supplied directly.
pub fn parse_int_signed_limits(raw string, positive_max u64, negative_max u64, base u8) !i64 {
	if raw.len == 0 || positive_max > u64(max_i64) || negative_max > u64(1) << 63 {
		return error('invalid character')
	}
	negative := raw[0] == `-`
	start := if negative || raw[0] == `+` { 1 } else { 0 }
	if start == raw.len {
		return error('invalid character')
	}
	limit := if negative { negative_max } else { positive_max }
	result := parse_unsigned(raw[start..], limit, base)!
	if negative {
		if result == u64(1) << 63 {
			return min_i64
		}
		return -i64(result)
	}
	return i64(result)
}
