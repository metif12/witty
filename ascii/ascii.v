module ascii

// to_lower translates std.ascii.toLower from Zig 0.15.2.
pub fn to_lower(ch u8) u8 {
	return if ch >= `A` && ch <= `Z` { ch | u8(0x20) } else { ch }
}

// eql_ignore_case translates std.ascii.eqlIgnoreCase.
pub fn eql_ignore_case(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		if to_lower(a[i]) != to_lower(b[i]) {
			return false
		}
	}
	return true
}

// order_ignore_case translates std.ascii.orderIgnoreCase. Its result follows
// V's comparison convention: negative, zero, or positive.
pub fn order_ignore_case(lhs string, rhs string) int {
	n := if lhs.len < rhs.len { lhs.len } else { rhs.len }
	for i in 0 .. n {
		left := to_lower(lhs[i])
		right := to_lower(rhs[i])
		if left < right {
			return -1
		}
		if left > right {
			return 1
		}
	}
	if lhs.len < rhs.len {
		return -1
	}
	if lhs.len > rhs.len {
		return 1
	}
	return 0
}

// lower_string applies std.ascii.toLower to every byte without performing
// Unicode case folding.
pub fn lower_string(value string) string {
	mut result := value.bytes()
	for i in 0 .. result.len {
		result[i] = to_lower(result[i])
	}
	return result.bytestr()
}
