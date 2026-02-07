module terminal

// SGR (Select Graphic Rendition) attribute parsing.
//
// Source: terminal/sgr.zig
//
// This implements the full SGR parser with colon-separator support.
// Types SgrAttribute and SgrAttributeKind are defined in types.v.
// SepList is defined in parser.v.

// SgrParser parses the attributes from a list of SGR parameters.
// Full version with colon-separator support.
pub struct SgrParser {
pub mut:
	params     []u16
	params_sep SepList
	idx        int
}

// next returns the next attribute or none if there are no more attributes.
pub fn (mut self SgrParser) next() ?SgrAttribute {
	if self.idx >= self.params.len {
		// Add one to ensure we don't loop on unset.
		defer {
			self.idx += 1
		}
		// If we're at index zero it means we must have an empty list
		// and an empty list implicitly means unset, otherwise we're
		// done and return none.
		if self.idx == 0 {
			return SgrAttribute{
				kind: .unset
			}
		}
		return none
	}

	slice := self.params[self.idx..]
	// Check if current separator is a colon.
	colon := self.params_sep.is_set(self.idx)
	self.idx += 1

	// Our last one will have an idx be the last value.
	if slice.len == 0 {
		return none
	}

	// If we have a colon separator then we need to ensure we're
	// parsing a value that allows it.
	if colon {
		match slice[0] {
			4, 38, 48, 58 {}
			else {
				// Consume all the colon separated
				// values and return them as unknown.
				for self.params_sep.is_set(self.idx) {
					self.idx += 1
				}
				self.idx += 1
				return SgrAttribute{
					kind: .unknown
				}
			}
		}
	}

	p := int(slice[0])

	if p == 0 {
		return SgrAttribute{ kind: .unset }
	} else if p == 1 {
		return SgrAttribute{ kind: .bold }
	} else if p == 2 {
		return SgrAttribute{ kind: .faint }
	} else if p == 3 {
		return SgrAttribute{ kind: .italic }
	} else if p == 4 {
		// Underline
		if colon {
			if slice.len >= 2 && !self.is_colon() {
				self.idx += 1
				ul := match slice[1] {
					0 { UnderlineStyle.none }
					1 { UnderlineStyle.single }
					2 { UnderlineStyle.double }
					3 { UnderlineStyle.curly }
					4 { UnderlineStyle.dotted }
					5 { UnderlineStyle.dashed }
					// For unknown underline styles, just render a single underline.
					else { UnderlineStyle.single }
				}
				return SgrAttribute{
					kind: .underline_set
					underline: ul
				}
			}
			if slice.len >= 2 && self.is_colon() {
				self.consume_unknown_colon()
			}
			// Fall through to unknown return at end
		} else {
			return SgrAttribute{
				kind: .underline_set
				underline: .single
			}
		}
	} else if p == 5 || p == 6 {
		return SgrAttribute{ kind: .blink }
	} else if p == 7 {
		return SgrAttribute{ kind: .inverse }
	} else if p == 8 {
		return SgrAttribute{ kind: .invisible }
	} else if p == 9 {
		return SgrAttribute{ kind: .strikethrough }
	} else if p == 21 {
		return SgrAttribute{ kind: .underline_set, underline: .double }
	} else if p == 22 {
		return SgrAttribute{ kind: .reset_bold }
	} else if p == 23 {
		return SgrAttribute{ kind: .reset_italic }
	} else if p == 24 {
		return SgrAttribute{ kind: .underline_set, underline: .none }
	} else if p == 25 {
		return SgrAttribute{ kind: .reset_blink }
	} else if p == 27 {
		return SgrAttribute{ kind: .reset_inverse }
	} else if p == 28 {
		return SgrAttribute{ kind: .reset_invisible }
	} else if p == 29 {
		return SgrAttribute{ kind: .reset_strikethrough }
	} else if p >= 30 && p <= 37 {
		// 8-color foreground
		return SgrAttribute{
			kind: .fg_8
			index: u8(p - 30)
		}
	} else if p == 38 {
		if slice.len >= 2 {
			if slice[1] == 2 {
				// Direct-color (r, g, b).
				if v := self.parse_direct_color(.direct_color_fg, slice, colon) {
					return v
				}
			} else if slice[1] == 5 {
				// Indexed color.
				if slice.len >= 3 {
					self.idx += 2
					return SgrAttribute{
						kind: .fg_256
						index: u8(slice[2])
					}
				}
			}
		}
	} else if p == 39 {
		return SgrAttribute{ kind: .reset_fg }
	} else if p >= 40 && p <= 47 {
		// 8-color background
		return SgrAttribute{
			kind: .bg_8
			index: u8(p - 40)
		}
	} else if p == 48 {
		if slice.len >= 2 {
			if slice[1] == 2 {
				if v := self.parse_direct_color(.direct_color_bg, slice, colon) {
					return v
				}
			} else if slice[1] == 5 {
				if slice.len >= 3 {
					self.idx += 2
					return SgrAttribute{
						kind: .bg_256
						index: u8(slice[2])
					}
				}
			}
		}
	} else if p == 49 {
		return SgrAttribute{ kind: .reset_bg }
	} else if p == 53 {
		return SgrAttribute{ kind: .overline }
	} else if p == 55 {
		return SgrAttribute{ kind: .reset_overline }
	} else if p == 58 {
		if slice.len >= 2 {
			if slice[1] == 2 {
				if v := self.parse_direct_color(.underline_color, slice, colon) {
					return v
				}
			} else if slice[1] == 5 {
				if slice.len >= 3 {
					self.idx += 2
					return SgrAttribute{
						kind: .underline_color_256
						index: u8(slice[2])
					}
				}
			}
		}
	} else if p == 59 {
		return SgrAttribute{ kind: .reset_underline_color }
	} else if p >= 90 && p <= 97 {
		// 8-color bright foreground
		return SgrAttribute{
			kind: .bright_fg_8
			index: u8(p - 90)
		}
	} else if p >= 100 && p <= 107 {
		// 8-color bright background
		return SgrAttribute{
			kind: .bright_bg_8
			index: u8(p - 100)
		}
	}

	return SgrAttribute{
		kind: .unknown
	}
}

fn (mut self SgrParser) parse_direct_color(kind SgrAttributeKind, slice []u16, colon bool) ?SgrAttribute {
	// Any direct color style must have at least 5 values.
	if slice.len < 5 {
		return none
	}

	// Only used for direct color sets (38, 48, 58) and subparam 2.

	// Note: We use truncation because the value should be 0 to 255. If
	// it isn't, the behavior is undefined so we just truncate it.

	// If we don't have a colon, then we expect exactly 3 semicolon
	// separated values.
	if !colon {
		self.idx += 4
		return SgrAttribute{
			kind: kind
			r: u8(slice[2])
			g: u8(slice[3])
			b: u8(slice[4])
		}
	}

	// We have a colon, we might have either 5 or 6 values depending
	// on if the colorspace is present.
	count := self.count_colon()
	if count == 3 {
		// This is the much more common case in the wild.
		self.idx += 4
		return SgrAttribute{
			kind: kind
			r: u8(slice[2])
			g: u8(slice[3])
			b: u8(slice[4])
		}
	} else if count == 4 {
		self.idx += 5
		return SgrAttribute{
			kind: kind
			r: u8(slice[3])
			g: u8(slice[4])
			b: u8(slice[5])
		}
	} else {
		self.consume_unknown_colon()
		return none
	}
}

// Returns true if the present position has a colon separator.
// This always returns false for the last value since it has no
// separator.
fn (self &SgrParser) is_colon() bool {
	return self.params_sep.is_set(self.idx)
}

fn (self &SgrParser) count_colon() int {
	mut count := 0
	mut idx := self.idx
	for idx < self.params.len - 1 && self.params_sep.is_set(idx) {
		count += 1
		idx += 1
	}
	return count
}

// Consumes all the remaining parameters separated by a colon and
// returns an unknown attribute.
fn (mut self SgrParser) consume_unknown_colon() {
	count := self.count_colon()
	self.idx += count + 1
}
