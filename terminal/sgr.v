module terminal

// SGR (Select Graphic Rendition) attribute parsing and types.

// Color name for 8-color and bright 8-color palette.
pub enum ColorName as u8 {
	black          = 0
	red            = 1
	green          = 2
	yellow         = 3
	blue           = 4
	magenta        = 5
	cyan           = 6
	white          = 7
	bright_black   = 8
	bright_red     = 9
	bright_green   = 10
	bright_yellow  = 11
	bright_blue    = 12
	bright_magenta = 13
	bright_cyan    = 14
	bright_white   = 15
}

// Tag for SgrAttribute identifying which variant is active.
pub enum SgrTag {
	// Unset all attributes
	unset
	// Unknown attribute, the raw CSI command parameters are here.
	unknown
	// Bold the text.
	bold
	reset_bold
	// Italic text.
	italic
	reset_italic
	// Faint/dim text.
	// Note: reset faint is the same SGR code as reset bold.
	faint
	// Underline the text.
	underline
	underline_color
	color_256_underline
	reset_underline_color
	// Overline the text.
	overline
	reset_overline
	// Blink the text.
	blink
	reset_blink
	// Invert fg/bg colors.
	inverse
	reset_inverse
	// Invisible.
	invisible
	reset_invisible
	// Strikethrough the text.
	strikethrough
	reset_strikethrough
	// Set foreground color as RGB values.
	direct_color_fg
	// Set background color as RGB values.
	direct_color_bg
	// Set the background/foreground as a named color attribute.
	color_8_bg
	color_8_fg
	// Reset the fg/bg to their default values.
	reset_fg
	reset_bg
	// Set the background/foreground as a named bright color attribute.
	color_8_bright_bg
	color_8_bright_fg
	// Set background color as 256-color palette.
	color_256_bg
	// Set foreground color as 256-color palette.
	color_256_fg
}

// Unknown SGR attribute data.
pub struct SgrUnknown {
pub:
	// Full is the full SGR input.
	full []u16
	// Partial is the remaining, where we got hung up.
	partial []u16
}

// Attribute type for SGR.
pub struct SgrAttribute {
pub:
	tag SgrTag
	// Data fields - which one is valid depends on tag.
	rgb            RGB            // for direct_color_fg, direct_color_bg, underline_color
	underline_kind UnderlineStyle // for underline
	color_name     ColorName      // for color_8_fg, color_8_bg, color_8_bright_fg, color_8_bright_bg
	palette        u8             // for color_256_fg, color_256_bg, color_256_underline
	unknown        SgrUnknown     // for unknown
}

// SepList is defined in parser.v (shared between parser and SGR).

// Parser parses the attributes from a list of SGR parameters.
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
				tag: .unset
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
				start := self.idx
				for self.params_sep.is_set(self.idx) {
					self.idx += 1
				}
				self.idx += 1
				end_idx := if self.idx - start + 1 < slice.len {
					self.idx - start + 1
				} else {
					slice.len
				}
				return SgrAttribute{
					tag: .unknown
					unknown: SgrUnknown{
						full: self.params
						partial: slice[..end_idx]
					}
				}
			}
		}
	}

	p := int(slice[0])

	if p == 0 {
		return SgrAttribute{ tag: .unset }
	} else if p == 1 {
		return SgrAttribute{ tag: .bold }
	} else if p == 2 {
		return SgrAttribute{ tag: .faint }
	} else if p == 3 {
		return SgrAttribute{ tag: .italic }
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
					tag: .underline
					underline_kind: ul
				}
			}
			if slice.len >= 2 && self.is_colon() {
				self.consume_unknown_colon()
			}
			// Fall through to unknown return at end
		} else {
			return SgrAttribute{
				tag: .underline
				underline_kind: .single
			}
		}
	} else if p == 5 || p == 6 {
		return SgrAttribute{ tag: .blink }
	} else if p == 7 {
		return SgrAttribute{ tag: .inverse }
	} else if p == 8 {
		return SgrAttribute{ tag: .invisible }
	} else if p == 9 {
		return SgrAttribute{ tag: .strikethrough }
	} else if p == 21 {
		return SgrAttribute{ tag: .underline, underline_kind: .double }
	} else if p == 22 {
		return SgrAttribute{ tag: .reset_bold }
	} else if p == 23 {
		return SgrAttribute{ tag: .reset_italic }
	} else if p == 24 {
		return SgrAttribute{ tag: .underline, underline_kind: .none }
	} else if p == 25 {
		return SgrAttribute{ tag: .reset_blink }
	} else if p == 27 {
		return SgrAttribute{ tag: .reset_inverse }
	} else if p == 28 {
		return SgrAttribute{ tag: .reset_invisible }
	} else if p == 29 {
		return SgrAttribute{ tag: .reset_strikethrough }
	} else if p >= 30 && p <= 37 {
		// 8-color foreground
		return SgrAttribute{
			tag: .color_8_fg
			color_name: unsafe { ColorName(u8(p - 30)) }
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
						tag: .color_256_fg
						palette: u8(slice[2])
					}
				}
			}
		}
	} else if p == 39 {
		return SgrAttribute{ tag: .reset_fg }
	} else if p >= 40 && p <= 47 {
		// 8-color background
		return SgrAttribute{
			tag: .color_8_bg
			color_name: unsafe { ColorName(u8(p - 40)) }
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
						tag: .color_256_bg
						palette: u8(slice[2])
					}
				}
			}
		}
	} else if p == 49 {
		return SgrAttribute{ tag: .reset_bg }
	} else if p == 53 {
		return SgrAttribute{ tag: .overline }
	} else if p == 55 {
		return SgrAttribute{ tag: .reset_overline }
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
						tag: .color_256_underline
						palette: u8(slice[2])
					}
				}
			}
		}
	} else if p == 59 {
		return SgrAttribute{ tag: .reset_underline_color }
	} else if p >= 90 && p <= 97 {
		// 8-color bright foreground
		// 82 instead of 90 to offset to "bright" colors
		return SgrAttribute{
			tag: .color_8_bright_fg
			color_name: unsafe { ColorName(u8(p - 82)) }
		}
	} else if p >= 100 && p <= 107 {
		// 8-color bright background
		return SgrAttribute{
			tag: .color_8_bright_bg
			color_name: unsafe { ColorName(u8(p - 92)) }
		}
	}

	return SgrAttribute{
		tag: .unknown
		unknown: SgrUnknown{
			full: self.params
			partial: slice
		}
	}
}

fn (mut self SgrParser) parse_direct_color(tag SgrTag, slice []u16, colon bool) ?SgrAttribute {
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
			tag: tag
			rgb: RGB{
				r: u8(slice[2])
				g: u8(slice[3])
				b: u8(slice[4])
			}
		}
	}

	// We have a colon, we might have either 5 or 6 values depending
	// on if the colorspace is present.
	count := self.count_colon()
	if count == 3 {
		// This is the much more common case in the wild.
		self.idx += 4
		return SgrAttribute{
			tag: tag
			rgb: RGB{
				r: u8(slice[2])
				g: u8(slice[3])
				b: u8(slice[4])
			}
		}
	} else if count == 4 {
		self.idx += 5
		return SgrAttribute{
			tag: tag
			rgb: RGB{
				r: u8(slice[3])
				g: u8(slice[4])
				b: u8(slice[5])
			}
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
