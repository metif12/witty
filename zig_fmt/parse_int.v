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
		if digit >= base || digit > max_value || result > (max_value - digit) / base {
			return error('overflow')
		}
		result = result * base + digit
	}
	return result
}
