module terminal

// --- Original Ghostty Comments Start: src/terminal/sgr.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/sgr.zig
//
// SGR (Select Graphic Rendition) attrinvbute parsing and types.
// Attribute type for SGR
// Unset all attributes
// Unknown attribute, the raw CSI command parameters are here.
// Bold the text.
// Italic text.
// Faint/dim text.
// Note: reset faint is the same SGR code as reset bold
// Underline the text
// Overline the text
// Blink the text
// Invert fg/bg colors.
// Invisible
// Strikethrough the text.
// Set foreground color as RGB values.
// Set background color as RGB values.
// Set the background/foreground as a named color attribute.
// Reset the fg/bg to their default values.
// Set the background/foreground as a named bright color attribute.
// Set background color as 256-color palette.
// Set foreground color as 256-color palette.
// Full is the full SGR input.
// Partial is the remaining, where we got hung up.
// C ABI functions.
// Padding size for C ABI compatibility.
// Largest variant is Unknown.C: 2 pointers + 2 usize = 32 bytes on 64-bit.
// We use [8]u64 (64 bytes) to allow room for future expansion while
// maintaining ABI compatibility.
// Parser parses the attributes from a list of SGR parameters.
// Empty state parser.
// Next returns the next attribute or null if there are no more attributes.
// We're more likely to not be done than to be done.
// Add one to ensure we don't loop on unset
// If we're at index zero it means we must have an empty list
// and an empty list implicitly means unset, otherwise we're
// done and return null.
// Call inlined for performance reasons.
// Our last one will have an idx be the last value.
// If we have a colon separator then we need to ensure we're
// parsing a value that allows it.
// Colons are fairly rare in the wild.
// In real world use it's very rare
// that we receive an invalid sequence.
// Consume all the colon separated
// values and return them as unknown.
// Colons are fairly rare in the wild.
// Invalid/unknown SGRs are just not very likely.
// For unknown underline styles,
// just render a single underline.
// This is quite a rare condition.
// We are very likely to have enough parameters.
// `2` indicates direct-color (r, g, b).
// We need at least 3 more params for this to make sense.
// `5` indicates indexed color.
// We are very likely to have enough parameters.
// We are very likely to have enough parameters.
// `2` indicates direct-color (r, g, b).
// We need at least 3 more params for this to make sense.
// `5` indicates indexed color.
// We are very likely to have enough parameters.
// We are very likely to have enough parameters.
// `2` indicates direct-color (r, g, b).
// We need at least 3 more params for this to make sense.
// `5` indicates indexed color.
// We are very likely to have enough parameters.
// 82 instead of 90 to offset to "bright" colors
// Any direct color style must have at least 5 values.
// Only used for direct color sets (38, 48, 58) and subparam 2.
// Note: We use @truncate because the value should be 0 to 255. If
// it isn't, the behavior is undefined so we just... truncate it.
// If we don't have a colon, then we expect exactly 3 semicolon
// separated values.
// Semicolons are much more common than colons.
// We have a colon, we might have either 5 or 6 values depending
// on if the colorspace is present.
// This is the much more common case in the wild.
// Invalid/unknown SGRs just don't happen very often at all.
// Returns true if the present position has a colon separator.
// This always returns false for the last value since it has no
// separator.
// Call inlined for performance reasons.
// Consumes all the remaining parameters separated by a colon and
// returns an unknown attribute.
// Mark all parameters except the last as having a colon after.
// This used to crash
// This used to crash
// These behaviors have been verified against xterm.
// Colon version should skip the optional color space identifier
// 3 8 : 2 : Pi : Pr : Pg : Pb
// 4 8 : 2 : Pi : Pr : Pg : Pb
// 5 8 : 2 : Pi : Pr : Pg : Pb
// Semicolon version should not parse optional color space identifier
// 3 8 ; 2 ; Pr ; Pg ; Pb
// 4 8 ; 2 ; Pr ; Pg ; Pb
// 5 8 ; 2 ; Pr ; Pg ; Pb
// Kakoune sent this complex SGR sequence that caused invalid behavior.
// This used to crash
// try testing.expect(p.next() == null);
// Discussion #5930, another input sent by kakoune
// echo -e "\033[4:3;38;2;51;51;51;48;2;170;170;170;58;2;255;97;136mset everything in one sequence, broken\033[m"
// This used to crash
//
// --- Original Ghostty Comments End: src/terminal/sgr.zig

// SGR (Select Graphic Rendition) attribute parsing.
//
// Source: terminal/sgr.zig
//
// This implements the full SGR parser with colon-separator support.
// SepList is defined in parser.v.

// Attribute type for SGR: the source's tagged union. Variants without a
// payload are empty structs.
pub type SgrAttribute = SgrBg256
	| SgrBg8
	| SgrBlink
	| SgrBold
	| SgrBrightBg8
	| SgrBrightFg8
	| SgrDirectColorBg
	| SgrDirectColorFg
	| SgrFaint
	| SgrFg256
	| SgrFg8
	| SgrInverse
	| SgrInvisible
	| SgrItalic
	| SgrOverline
	| SgrResetBg
	| SgrResetBlink
	| SgrResetBold
	| SgrResetFg
	| SgrResetInverse
	| SgrResetInvisible
	| SgrResetItalic
	| SgrResetOverline
	| SgrResetStrikethrough
	| SgrResetUnderlineColor
	| SgrStrikethrough
	| SgrUnderline
	| SgrUnderlineColor
	| SgrUnderlineColor256
	| SgrUnknown
	| SgrUnset

// Unset all attributes
pub struct SgrUnset {}

// Unknown attribute, the raw CSI command parameters are here.
pub struct SgrUnknown {
pub:
	// Full is the full SGR input.
	full []u16
	// Partial is the remaining, where we got hung up.
	partial []u16
}

// Bold the text.
pub struct SgrBold {}

pub struct SgrResetBold {}

// Italic text.
pub struct SgrItalic {}

pub struct SgrResetItalic {}

// Faint/dim text.
// Note: reset faint is the same SGR code as reset bold
pub struct SgrFaint {}

// Underline the text
pub struct SgrUnderline {
pub:
	style UnderlineStyle
}

pub struct SgrUnderlineColor {
pub:
	rgb RGB
}

pub struct SgrUnderlineColor256 {
pub:
	idx u8
}

pub struct SgrResetUnderlineColor {}

// Overline the text
pub struct SgrOverline {}

pub struct SgrResetOverline {}

// Blink the text
pub struct SgrBlink {}

pub struct SgrResetBlink {}

// Invert fg/bg colors.
pub struct SgrInverse {}

pub struct SgrResetInverse {}

// Invisible
pub struct SgrInvisible {}

pub struct SgrResetInvisible {}

// Strikethrough the text.
pub struct SgrStrikethrough {}

pub struct SgrResetStrikethrough {}

// Set foreground color as RGB values.
pub struct SgrDirectColorFg {
pub:
	rgb RGB
}

// Set background color as RGB values.
pub struct SgrDirectColorBg {
pub:
	rgb RGB
}

// Set the background/foreground as a named color attribute.
pub struct SgrBg8 {
pub:
	name Name
}

pub struct SgrFg8 {
pub:
	name Name
}

// Reset the fg/bg to their default values.
pub struct SgrResetFg {}

pub struct SgrResetBg {}

// Set the background/foreground as a named bright color attribute.
pub struct SgrBrightBg8 {
pub:
	name Name
}

pub struct SgrBrightFg8 {
pub:
	name Name
}

// Set background color as 256-color palette.
pub struct SgrBg256 {
pub:
	idx u8
}

// Set foreground color as 256-color palette.
pub struct SgrFg256 {
pub:
	idx u8
}

// SgrAttributeTag is the attribute's tag, with the source's C ABI values.
pub enum SgrAttributeTag as i32 {
	unset
	unknown
	bold
	reset_bold
	italic
	reset_italic
	faint
	underline
	underline_color
	underline_color_256
	reset_underline_color
	overline
	reset_overline
	blink
	reset_blink
	inverse
	reset_inverse
	invisible
	reset_invisible
	strikethrough
	reset_strikethrough
	direct_color_fg
	direct_color_bg
	bg_8
	fg_8
	reset_fg
	reset_bg
	bright_bg_8
	bright_fg_8
	bg_256
	fg_256
}

// The tag of the active attribute variant.
pub fn (self SgrAttribute) tag() SgrAttributeTag {
	return match self {
		SgrUnset { .unset }
		SgrUnknown { .unknown }
		SgrBold { .bold }
		SgrResetBold { .reset_bold }
		SgrItalic { .italic }
		SgrResetItalic { .reset_italic }
		SgrFaint { .faint }
		SgrUnderline { .underline }
		SgrUnderlineColor { .underline_color }
		SgrUnderlineColor256 { .underline_color_256 }
		SgrResetUnderlineColor { .reset_underline_color }
		SgrOverline { .overline }
		SgrResetOverline { .reset_overline }
		SgrBlink { .blink }
		SgrResetBlink { .reset_blink }
		SgrInverse { .inverse }
		SgrResetInverse { .reset_inverse }
		SgrInvisible { .invisible }
		SgrResetInvisible { .reset_invisible }
		SgrStrikethrough { .strikethrough }
		SgrResetStrikethrough { .reset_strikethrough }
		SgrDirectColorFg { .direct_color_fg }
		SgrDirectColorBg { .direct_color_bg }
		SgrBg8 { .bg_8 }
		SgrFg8 { .fg_8 }
		SgrResetFg { .reset_fg }
		SgrResetBg { .reset_bg }
		SgrBrightBg8 { .bright_bg_8 }
		SgrBrightFg8 { .bright_fg_8 }
		SgrBg256 { .bg_256 }
		SgrFg256 { .fg_256 }
	}
}

// SgrParser parses the attributes from a list of SGR parameters.
pub struct SgrParser {
pub mut:
	params     []u16
	params_sep SepList
	idx        uint
}

// next returns the next attribute or none if there are no more attributes.
pub fn (mut self SgrParser) next() ?SgrAttribute {
	if self.idx >= uint(self.params.len) {
		// Add one to ensure we don't loop on unset
		defer {
			self.idx += 1
		}

		// If we're at index zero it means we must have an empty list
		// and an empty list implicitly means unset, otherwise we're
		// done and return none.
		if self.idx == 0 {
			return SgrUnset{}
		}
		return none
	}

	slice := self.params[int(self.idx)..]
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
				partial_len := if self.idx - start + 1 < uint(slice.len) {
					self.idx - start + 1
				} else {
					uint(slice.len)
				}
				return SgrUnknown{
					full:    self.params
					partial: slice[..int(partial_len)]
				}
			}
		}
	}

	match slice[0] {
		0 {
			return SgrUnset{}
		}
		1 {
			return SgrBold{}
		}
		2 {
			return SgrFaint{}
		}
		3 {
			return SgrItalic{}
		}
		4 {
			if colon {
				assert slice.len >= 2, 'colon underline requires a style parameter'
				if self.is_colon() {
					// Invalid/unknown SGRs are just not very likely.
					self.consume_unknown_colon()
				} else {
					self.idx += 1
					return SgrUnderline{
						style: match slice[1] {
							0 { UnderlineStyle.none }
							1 { UnderlineStyle.single }
							2 { UnderlineStyle.double }
							3 { UnderlineStyle.curly }
							4 { UnderlineStyle.dotted }
							5 { UnderlineStyle.dashed }
							// For unknown underline styles,
							// just render a single underline.
							else { UnderlineStyle.single }
						}
					}
				}
			} else {
				return SgrUnderline{
					style: .single
				}
			}
		}
		5 {
			return SgrBlink{}
		}
		6 {
			return SgrBlink{}
		}
		7 {
			return SgrInverse{}
		}
		8 {
			return SgrInvisible{}
		}
		9 {
			return SgrStrikethrough{}
		}
		21 {
			return SgrUnderline{
				style: .double
			}
		}
		22 {
			return SgrResetBold{}
		}
		23 {
			return SgrResetItalic{}
		}
		24 {
			return SgrUnderline{
				style: .none
			}
		}
		25 {
			return SgrResetBlink{}
		}
		27 {
			return SgrResetInverse{}
		}
		28 {
			return SgrResetInvisible{}
		}
		29 {
			return SgrResetStrikethrough{}
		}
		30...37 {
			return SgrFg8{
				name: unsafe { Name(u8(slice[0] - 30)) }
			}
		}
		38 {
			if slice.len >= 2 {
				match slice[1] {
					// `2` indicates direct-color (r, g, b).
					// We need at least 3 more params for this to make sense.
					2 {
						if v := self.parse_direct_color(.direct_color_fg, slice, colon) {
							return v
						}
					}
					// `5` indicates indexed color.
					5 {
						if slice.len >= 3 {
							self.idx += 2
							return SgrFg256{
								idx: u8(slice[2])
							}
						}
					}
					else {}
				}
			}
		}
		39 {
			return SgrResetFg{}
		}
		40...47 {
			return SgrBg8{
				name: unsafe { Name(u8(slice[0] - 40)) }
			}
		}
		48 {
			if slice.len >= 2 {
				match slice[1] {
					// `2` indicates direct-color (r, g, b).
					// We need at least 3 more params for this to make sense.
					2 {
						if v := self.parse_direct_color(.direct_color_bg, slice, colon) {
							return v
						}
					}
					// `5` indicates indexed color.
					5 {
						if slice.len >= 3 {
							self.idx += 2
							return SgrBg256{
								idx: u8(slice[2])
							}
						}
					}
					else {}
				}
			}
		}
		49 {
			return SgrResetBg{}
		}
		53 {
			return SgrOverline{}
		}
		55 {
			return SgrResetOverline{}
		}
		58 {
			if slice.len >= 2 {
				match slice[1] {
					// `2` indicates direct-color (r, g, b).
					// We need at least 3 more params for this to make sense.
					2 {
						if v := self.parse_direct_color(.underline_color, slice, colon) {
							return v
						}
					}
					// `5` indicates indexed color.
					5 {
						if slice.len >= 3 {
							self.idx += 2
							return SgrUnderlineColor256{
								idx: u8(slice[2])
							}
						}
					}
					else {}
				}
			}
		}
		59 {
			return SgrResetUnderlineColor{}
		}
		90...97 {
			// 82 instead of 90 to offset to "bright" colors
			return SgrBrightFg8{
				name: unsafe { Name(u8(slice[0] - 82)) }
			}
		}
		100...107 {
			return SgrBrightBg8{
				name: unsafe { Name(u8(slice[0] - 92)) }
			}
		}
		else {}
	}

	return SgrUnknown{
		full:    self.params
		partial: slice
	}
}

fn (mut self SgrParser) parse_direct_color(tag SgrAttributeTag, slice []u16, colon bool) ?SgrAttribute {
	// Any direct color style must have at least 5 values.
	if slice.len < 5 {
		return none
	}

	// Only used for direct color sets (38, 48, 58) and subparam 2.
	assert slice[1] == 2, 'direct color parser requires subparameter 2'

	// Note: We use truncation because the value should be 0 to 255. If
	// it isn't, the behavior is undefined so we just truncate it.

	// If we don't have a colon, then we expect exactly 3 semicolon
	// separated values.
	if !colon {
		self.idx += 4
		return sgr_direct_color(tag, RGB{
			r: u8(slice[2])
			g: u8(slice[3])
			b: u8(slice[4])
		})
	}

	// We have a colon, we might have either 5 or 6 values depending
	// on if the colorspace is present.
	count := self.count_colon()
	match count {
		3 {
			// This is the much more common case in the wild.
			self.idx += 4
			return sgr_direct_color(tag, RGB{
				r: u8(slice[2])
				g: u8(slice[3])
				b: u8(slice[4])
			})
		}
		4 {
			self.idx += 5
			return sgr_direct_color(tag, RGB{
				r: u8(slice[3])
				g: u8(slice[4])
				b: u8(slice[5])
			})
		}
		else {
			self.consume_unknown_colon()
			return none
		}
	}
}

// sgr_direct_color builds the RGB variant named by tag, standing in for the
// source's comptime `@unionInit`.
fn sgr_direct_color(tag SgrAttributeTag, rgb RGB) SgrAttribute {
	return match tag {
		.direct_color_fg { SgrDirectColorFg{ rgb: rgb } }
		.direct_color_bg { SgrDirectColorBg{ rgb: rgb } }
		.underline_color { SgrUnderlineColor{ rgb: rgb } }
		else { panic('sgr_direct_color: ${tag} is not a direct color attribute') }
	}
}

// Returns true if the present position has a colon separator.
// This always returns false for the last value since it has no
// separator.
fn (self &SgrParser) is_colon() bool {
	return self.params_sep.is_set(self.idx)
}

fn (self &SgrParser) count_colon() uint {
	mut count := uint(0)
	mut idx := self.idx
	for idx < uint(self.params.len - 1) && self.params_sep.is_set(idx) {
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
