module comma_splitter

// Iterator to split a string into fields by commas, taking into account
// quotes and escapes.
//
// Supports the same escapes as in Zig literal strings.
//
// Quotes must begin and end with a double quote (`"`). It is an error to not
// end a quote that was begun. To include a double quote inside a quote (or to
// not have a double quote start a quoted section) escape it with a backslash.
//
// Single quotes (`'`) are not special, they do not begin a quoted block.
//
// Zig multiline string literals are NOT supported.
//
// Quotes and escapes are not stripped or decoded, that must be handled as a
// separate step!

// State of the state machine.
enum State {
	normal
	quoted
	escape
	hexescape
	unicodeescape
}

// Sub-state for parsing unicode escapes.
enum UnicodeEscapeState {
	start
	digits
}

pub struct CommaSplitter {
	// The string that we are splitting.
	str string
pub mut:
	// If an error occurred during parsing, this contains the error message.
	// Empty string means no error. Check this after next() returns none
	// to distinguish between end-of-input and a parse error.
	last_error string
mut:
	// How much of the string has been consumed so far.
	index int
}

// Initialize a splitter with the given string.
pub fn CommaSplitter.init(str string) CommaSplitter {
	return CommaSplitter{
		str: str
	}
}

// Return the next field, none if no more fields.
// If none is returned and last_error is non-empty, a parse error occurred.
// Note: In Zig this returns Error!?[]const u8, but V can't combine ! and ?.
pub fn (mut self CommaSplitter) next() ?string {
	if self.index >= self.str.len {
		return none
	}

	// Where the current field starts.
	start := self.index
	// State of state machine.
	mut state := State.normal
	// Keep track of the state to return to when done processing an escape
	// sequence.
	mut last := State.normal
	// Used to count number of digits seen in a hex escape.
	mut hexescape_digits := 0
	// Sub-state of parsing hex escapes.
	mut unicodeescape_state := UnicodeEscapeState.start
	// Number of digits in a unicode escape seen so far.
	mut unicodeescape_digits := 0
	// Accumulator for value of unicode escape.
	mut unicodeescape_value := u32(0)

	for {
		match state {
			.normal {
				if self.index >= self.str.len {
					return self.str[start..]
				}
				c := self.str[self.index]
				if c == `,` {
					self.index += 1
					return self.str[start..self.index - 1]
				} else if c == `"` {
					self.index += 1
					state = .quoted
				} else if c == `\\` {
					self.index += 1
					last = .normal
					state = .escape
				} else {
					self.index += 1
					// state stays .normal
				}
			}
			.quoted {
				if self.index >= self.str.len {
					self.last_error = 'unclosed quote'
					return none
				}
				c := self.str[self.index]
				if c == `"` {
					self.index += 1
					state = .normal
				} else if c == `\\` {
					self.index += 1
					last = .quoted
					state = .escape
				} else {
					self.index += 1
					// state stays .quoted
				}
			}
			.escape {
				if self.index >= self.str.len {
					self.last_error = 'unfinished escape'
					return none
				}
				c := self.str[self.index]
				if c == `n` || c == `r` || c == `t` || c == `\\` || c == `'`
					|| c == `"` {
					self.index += 1
					state = last
				} else if c == `x` {
					self.index += 1
					hexescape_digits = 0
					state = .hexescape
				} else if c == `u` {
					self.index += 1
					unicodeescape_state = .start
					unicodeescape_digits = 0
					unicodeescape_value = 0
					state = .unicodeescape
				} else {
					self.last_error = 'illegal escape'
					return none
				}
			}
			.hexescape {
				if self.index >= self.str.len {
					self.last_error = 'unfinished escape'
					return none
				}
				c := self.str[self.index]
				if is_hex_digit(c) {
					self.index += 1
					hexescape_digits += 1
					if hexescape_digits == 2 {
						state = last
					}
					// else state stays .hexescape
				} else {
					self.last_error = 'illegal escape'
					return none
				}
			}
			.unicodeescape {
				if self.index >= self.str.len {
					self.last_error = 'unfinished escape'
					return none
				}
				match unicodeescape_state {
					.start {
						if self.str[self.index] == `{` {
							self.index += 1
							unicodeescape_value = 0
							unicodeescape_state = .digits
						} else {
							self.last_error = 'illegal escape'
							return none
						}
					}
					.digits {
						c := self.str[self.index]
						if c == `}` {
							self.index += 1
							if unicodeescape_digits == 0 {
								self.last_error = 'illegal escape'
								return none
							}
							state = last
						} else if c >= `0` && c <= `9` {
							self.index += 1
							unicodeescape_digits += 1
							unicodeescape_value <<= 4
							unicodeescape_value += u32(c - `0`)
						} else if c >= `a` && c <= `f` {
							self.index += 1
							unicodeescape_digits += 1
							unicodeescape_value <<= 4
							unicodeescape_value += u32(c - `a`)
						} else if c >= `A` && c <= `F` {
							self.index += 1
							unicodeescape_digits += 1
							unicodeescape_value <<= 4
							unicodeescape_value += u32(c - `A`)
						} else {
							self.last_error = 'illegal escape'
							return none
						}
						if unicodeescape_value > 0x10ffff {
							self.last_error = 'illegal escape'
							return none
						}
					}
				}
			}
		}
	}
	// unreachable
	return none
}

// Return any remaining string data, whether it has a comma or not.
pub fn (mut self CommaSplitter) rest() ?string {
	if self.index >= self.str.len {
		return none
	}
	result := self.str[self.index..]
	self.index = self.str.len
	return result
}

// Helper: check if a byte is a hex digit.
fn is_hex_digit(c u8) bool {
	return (c >= `0` && c <= `9`) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}
