module osc

// parse_decimal_digits is the common digit loop from Zig's
// std.fmt.parseInt/parseUnsigned. Zig ignores interior underscores while
// rejecting them at either edge and checks every multiply/add for overflow.
fn parse_decimal_digits(value string, max_value u64) ?u64 {
	if value.len == 0 || value[0] == `_` || value[value.len - 1] == `_` {
		return none
	}
	mut result := u64(0)
	for c in value {
		if c == `_` {
			continue
		}
		if c < `0` || c > `9` {
			return none
		}
		digit := u64(c - `0`)
		if digit > max_value || result > (max_value - digit) / 10 {
			return none
		}
		result = result * 10 + digit
	}
	return result
}

// V form of std.fmt.parseInt for an unsigned integer and base 10. Signs are
// accepted, but a negative unsigned result can only be zero.
fn parse_int_unsigned_decimal(value string, max_value u64) ?u64 {
	if value.len == 0 {
		return none
	}
	negative := value[0] == `-`
	offset := if negative || value[0] == `+` { 1 } else { 0 }
	result := parse_decimal_digits(value[offset..], max_value) or { return none }
	if negative && result != 0 {
		return none
	}
	return result
}

// V form of std.fmt.parseUnsigned for base 10. Unlike parseInt, this does not
// consume a sign.
fn parse_unsigned_decimal(value string, max_value u64) ?u64 {
	return parse_decimal_digits(value, max_value)
}

// V form of std.fmt.parseInt for a signed integer and base 10.
fn parse_int_signed_decimal(value string, positive_max u64, negative_max u64) ?i64 {
	if value.len == 0 {
		return none
	}
	negative := value[0] == `-`
	offset := if negative || value[0] == `+` { 1 } else { 0 }
	limit := if negative { negative_max } else { positive_max }
	result := parse_decimal_digits(value[offset..], limit) or { return none }
	if !negative {
		return i64(result)
	}
	if result == u64(1) << 63 {
		return min_i64
	}
	return -i64(result)
}
