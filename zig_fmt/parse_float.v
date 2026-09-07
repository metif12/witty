module zig_fmt

import ascii
import math

#include "@VMODROOT/zig_fmt/parse_float.h"

fn C.witty_zig_strtod(&char, &&char, &f64) int
fn C.witty_zig_strtof(&char, &&char, &f32) int

fn is_digit_for_base(ch u8, base int) bool {
	if ch >= `0` && ch <= `9` {
		return int(ch - `0`) < base
	}
	if base == 16 && ch >= `a` && ch <= `f` {
		return true
	}
	return base == 16 && ch >= `A` && ch <= `F`
}

// normalize_float translates the lexical scanner used by Zig 0.15.2's
// std.fmt.parseFloat. The returned spelling has valid digit separators removed
// so libc can perform the correctly-rounded binary conversion.
fn normalize_float(raw string) !string {
	if raw.len == 0 {
		return error('invalid character')
	}
	mut i := 0
	if raw[i] == `+` || raw[i] == `-` {
		i++
	}
	if i == raw.len {
		return error('invalid character')
	}

	mut base := 10
	mut exponent := `e`
	if i + 1 < raw.len && raw[i] == `0` && (raw[i + 1] == `x` || raw[i + 1] == `X`) {
		base = 16
		exponent = `p`
		i += 2
	}
	body_start := i
	for j := body_start; j < raw.len; j++ {
		if raw[j] != `_` {
			continue
		}
		if j == body_start || j + 1 == raw.len || !is_digit_for_base(raw[j - 1], base)
			|| !is_digit_for_base(raw[j + 1], base) {
			return error('invalid character')
		}
	}

	mut digits := 0
	for i < raw.len && (is_digit_for_base(raw[i], base) || raw[i] == `_`) {
		if raw[i] != `_` {
			digits++
		}
		i++
	}
	if i < raw.len && raw[i] == `.` {
		i++
		for i < raw.len && (is_digit_for_base(raw[i], base) || raw[i] == `_`) {
			if raw[i] != `_` {
				digits++
			}
			i++
		}
	}
	if digits == 0 {
		return error('invalid character')
	}

	if i < raw.len && (raw[i] | 0x20) == exponent {
		i++
		if i < raw.len && (raw[i] == `+` || raw[i] == `-`) {
			i++
		}
		// Zig requires the exponent to begin with a decimal digit before its
		// digit scanner may consume any separators.
		if i == raw.len || raw[i] < `0` || raw[i] > `9` {
			return error('invalid character')
		}
		for i < raw.len && ((raw[i] >= `0` && raw[i] <= `9`) || raw[i] == `_`) {
			i++
		}
	}
	if i != raw.len {
		return error('invalid character')
	}

	if !raw.contains('_') {
		return raw
	}
	mut normalized := []u8{cap: raw.len}
	for ch in raw.bytes() {
		if ch != `_` {
			normalized << ch
		}
	}
	return normalized.bytestr()
}

fn special_float(raw string) ?f64 {
	if raw.len == 0 {
		return none
	}
	negative := raw[0] == `-`
	start := if negative || raw[0] == `+` { 1 } else { 0 }
	if start == raw.len {
		return none
	}
	value := raw[start..]
	if ascii.eql_ignore_case(value, 'nan') {
		// Zig returns its canonical NaN even when the spelling had a minus.
		return math.nan()
	}
	if ascii.eql_ignore_case(value, 'inf') || ascii.eql_ignore_case(value, 'infinity') {
		return math.inf(if negative { -1 } else { 1 })
	}
	return none
}

// parse_f64 is the V equivalent of std.fmt.parseFloat(f64, raw).
pub fn parse_f64(raw string) !f64 {
	if special := special_float(raw) {
		return special
	}
	normalized := normalize_float(raw)!
	mut end := unsafe { &char(nil) }
	mut value := f64(0)
	if C.witty_zig_strtod(normalized.str, &end, &value) == 0 {
		return error('invalid character')
	}
	if usize(end) != usize(normalized.str) + usize(normalized.len) {
		return error('invalid character')
	}
	return value
}

// parse_f32 is the V equivalent of std.fmt.parseFloat(f32, raw). Calling
// strtof directly avoids a possible f64-to-f32 double rounding.
pub fn parse_f32(raw string) !f32 {
	if special := special_float(raw) {
		return f32(special)
	}
	normalized := normalize_float(raw)!
	mut end := unsafe { &char(nil) }
	mut value := f32(0)
	if C.witty_zig_strtof(normalized.str, &end, &value) == 0 {
		return error('invalid character')
	}
	if usize(end) != usize(normalized.str) + usize(normalized.len) {
		return error('invalid character')
	}
	return value
}
