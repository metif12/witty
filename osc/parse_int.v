module osc

import zig_fmt

// V form of std.fmt.parseInt for an unsigned integer and base 10. Signs are
// accepted, but a negative unsigned result can only be zero.
fn parse_int_unsigned_decimal(value string, max_value u64) ?u64 {
	return zig_fmt.parse_int_unsigned_max(value, max_value, 10) or { return none }
}

// V form of std.fmt.parseUnsigned for base 10. Unlike parseInt, this does not
// consume a sign.
fn parse_unsigned_decimal(value string, max_value u64) ?u64 {
	return zig_fmt.parse_unsigned(value, max_value, 10) or { return none }
}

// V form of std.fmt.parseInt for a signed integer and base 10.
fn parse_int_signed_decimal(value string, positive_max u64, negative_max u64) ?i64 {
	return zig_fmt.parse_int_signed_limits(value, positive_max, negative_max, 10) or {
		return none
	}
}
