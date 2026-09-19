module cli_args

// CommaSplitter splits a value on commas while preserving commas inside
// double-quoted strings. Escape sequences are validated but left in the
// returned slice; decoding is the caller's responsibility.
pub struct CommaSplitter {
	value string
mut:
	index int
}

pub fn CommaSplitter.init(value string) CommaSplitter {
	return CommaSplitter{
		value: value
	}
}

// Compatibility alias for callers written against the earlier translation.
pub fn CommaSplitter.new(value string) CommaSplitter {
	return CommaSplitter.init(value)
}

pub fn (s &CommaSplitter) has_next() bool {
	return s.index < s.value.len
}

pub fn (mut s CommaSplitter) next() !string {
	if s.index >= s.value.len {
		return error('end of iterator')
	}
	start := s.index
	mut quoted := false
	for s.index < s.value.len {
		ch := s.value[s.index]
		if ch == `,` && !quoted {
			result := s.value[start..s.index].clone()
			s.index++
			return result
		}
		if ch == `"` {
			quoted = !quoted
			s.index++
			continue
		}
		if ch != `\\` {
			s.index++
			continue
		}

		// Escapes are legal both inside and outside quoted sections, exactly
		// as in Ghostty's splitter.
		s.index++
		if s.index >= s.value.len {
			return error('unfinished escape')
		}
		match s.value[s.index] {
			`n`, `r`, `t`, `\\`, `'`, `"` {
				s.index++
			}
			`x` {
				s.index++
				for _ in 0 .. 2 {
					if s.index >= s.value.len {
						return error('unfinished escape')
					}
					if !is_hex_digit(s.value[s.index]) {
						return error('illegal escape')
					}
					s.index++
				}
			}
			`u` {
				s.index++
				if s.index >= s.value.len {
					return error('unfinished escape')
				}
				if s.value[s.index] != `{` {
					return error('illegal escape')
				}
				s.index++
				mut digits := 0
				mut codepoint := u32(0)
				for {
					if s.index >= s.value.len {
						return error('unfinished escape')
					}
					if s.value[s.index] == `}` {
						if digits == 0 {
							return error('illegal escape')
						}
						s.index++
						break
					}
					nibble := hex_value(s.value[s.index]) or { return error('illegal escape') }
					codepoint = (codepoint << 4) | nibble
					if codepoint > 0x10ffff {
						return error('illegal escape')
					}
					digits++
					s.index++
				}
			}
			else {
				return error('illegal escape')
			}
		}
	}
	if quoted {
		return error('unclosed quote')
	}
	return s.value[start..]
}

// rest returns all remaining input without parsing it.
pub fn (mut s CommaSplitter) rest() ?string {
	if s.index >= s.value.len {
		return none
	}
	result := s.value[s.index..].clone()
	s.index = s.value.len
	return result
}

fn is_hex_digit(ch u8) bool {
	return (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `f`) || (ch >= `A` && ch <= `F`)
}

fn hex_value(ch u8) ?u32 {
	if ch >= `0` && ch <= `9` {
		return u32(ch - `0`)
	}
	if ch >= `a` && ch <= `f` {
		return u32(ch - `a` + 10)
	}
	if ch >= `A` && ch <= `F` {
		return u32(ch - `A` + 10)
	}
	return none
}
