module terminal

// Style methods for CellStyle.
//
// Source: style.zig
//
// These methods complement the CellStyle struct defined in types.v,
// adding color resolution, equality checks, and hashing functionality.
// The VT and HTML formatting is handled by formatter.v.

// ============================================================
// Style ID
// ============================================================

// The unique identifier for a style. This is at most the number of cells
// that can fit into a terminal page.
// Note: default_style_id is defined in types.v as u32(0).

// ============================================================
// FgOpts - options for foreground color resolution
// ============================================================

// FgOpts provides the configuration needed to resolve a foreground color
// from a style, accounting for bold/bright behavior and palette lookup.
pub struct FgOpts {
pub:
	// The default color to use if the style doesn't specify a
	// foreground color and no configuration options override it.
	default_color RGB
	// The current color palette. Required to map palette indices to
	// real color values.
	palette [256]RGB
	// If specified, the color to use for bold text.
	bold_color ?BoldColor
}

// ============================================================
// CellStyle color resolution methods
// ============================================================

// Returns true if the style is equal to another style.
pub fn (self &CellStyle) eql(other &CellStyle) bool {
	return self.flags.bold == other.flags.bold && self.flags.faint == other.flags.faint
		&& self.flags.italic == other.flags.italic
		&& self.flags.underline == other.flags.underline
		&& self.flags.overline == other.flags.overline && self.flags.blink == other.flags.blink
		&& self.flags.inverse == other.flags.inverse
		&& self.flags.invisible == other.flags.invisible
		&& self.flags.strikethrough == other.flags.strikethrough
		&& self.fg_color == other.fg_color && self.bg_color == other.bg_color
		&& self.underline_color == other.underline_color && self.fg_r == other.fg_r
		&& self.fg_g == other.fg_g && self.fg_b == other.fg_b && self.bg_r == other.bg_r
		&& self.bg_g == other.bg_g && self.bg_b == other.bg_b
		&& self.fg_palette == other.fg_palette && self.bg_palette == other.bg_palette
}

// Returns the bg color for a cell with this style given the cell
// that has this style and the palette to use.
//
// Note that generally if a cell is a color-only cell, it SHOULD
// only have the default style, but this is meant to work with the
// default style as well.
pub fn (self &CellStyle) bg_rgb(cell &CellData, palette [256]RGB) ?RGB {
	return match cell.content_tag {
		.bg_color_palette {
			palette[int(cell.color_palette)]
		}
		.bg_color_rgb {
			RGB{
				r: cell.color_rgb_r
				g: cell.color_rgb_g
				b: cell.color_rgb_b
			}
		}
		else {
			match self.bg_color {
				.none { none }
				.palette { palette[int(self.bg_palette)] }
				.rgb {
					RGB{
						r: self.bg_r
						g: self.bg_g
						b: self.bg_b
					}
				}
			}
		}
	}
}

// Returns the fg color for a cell with this style given the palette
// and various configuration options.
pub fn (self &CellStyle) fg_rgb(opts FgOpts) RGB {
	// Note we don't pull the bold check to the top-level here because
	// we don't want to duplicate the conditional multiple times since
	// certain colors require more checks (e.g. `bold_is_bright`).

	match self.fg_color {
		.none {
			if self.flags.bold {
				if bold := opts.bold_color {
					if bold.bright {
						// bright mode: no special color, use default
					} else {
						// color mode: XTODO - use bold color
						return opts.default_color
					}
				}
			}
			return opts.default_color
		}
		.palette {
			idx := self.fg_palette
			if self.flags.bold {
				if _ := opts.bold_color {
					// bold_is_bright: if idx < 8, use bright variant
					bright_offset := u8(8) // bright_black offset
					if idx < bright_offset {
						return opts.palette[int(idx) + int(bright_offset)]
					}
				}
			}
			return opts.palette[int(idx)]
		}
		.rgb {
			rgb := RGB{
				r: self.fg_r
				g: self.fg_g
				b: self.fg_b
			}
			if self.flags.bold && rgb.r == opts.default_color.r && rgb.g == opts.default_color.g
				&& rgb.b == opts.default_color.b {
				if bold := opts.bold_color {
					if !bold.bright {
						// color mode: XTODO - use bold color
					}
				}
			}
			return rgb
		}
	}
}

// Returns the underline color for this style.
pub fn (self &CellStyle) underline_color_rgb(palette [256]RGB) ?RGB {
	return match self.underline_color {
		.none { none }
		.palette { palette[int(self.fg_palette)] }
		.rgb {
			RGB{
				r: self.fg_r
				g: self.fg_g
				b: self.fg_b
			}
		}
	}
}

// Returns a bg-color only cell from this style, if it exists.
pub fn (self &CellStyle) bg_cell_from_style() ?CellData {
	return match self.bg_color {
		.none { none }
		.palette {
			CellData{
				content_tag: .bg_color_palette
				color_palette: self.bg_palette
			}
		}
		.rgb {
			CellData{
				content_tag: .bg_color_rgb
				color_rgb_r: self.bg_r
				color_rgb_g: self.bg_g
				color_rgb_b: self.bg_b
			}
		}
	}
}

// ============================================================
// Style hashing
// ============================================================

// Hash the style for use in hash maps.
// We combine all fields into a single hash value.
pub fn (self &CellStyle) hash() u64 {
	mut h := u64(0)

	// Mix in flags
	if self.flags.bold {
		h ^= 0x01
	}
	if self.flags.italic {
		h ^= 0x02
	}
	if self.flags.faint {
		h ^= 0x04
	}
	if self.flags.blink {
		h ^= 0x08
	}
	if self.flags.inverse {
		h ^= 0x10
	}
	if self.flags.invisible {
		h ^= 0x20
	}
	if self.flags.strikethrough {
		h ^= 0x40
	}
	if self.flags.overline {
		h ^= 0x80
	}
	h |= u64(int(self.flags.underline)) << 8

	// Mix in color types
	h |= u64(int(self.fg_color)) << 16
	h |= u64(int(self.bg_color)) << 18
	h |= u64(int(self.underline_color)) << 20

	// Mix in color values
	h ^= u64(self.fg_r) << 24
	h ^= u64(self.fg_g) << 32
	h ^= u64(self.fg_b) << 40
	h ^= u64(self.bg_r) << 28
	h ^= u64(self.bg_g) << 36
	h ^= u64(self.bg_b) << 44
	h ^= u64(self.fg_palette) << 48
	h ^= u64(self.bg_palette) << 56

	// Use integer hash to make it sufficiently uniform
	h ^= h >> 33
	h *= 0xff51afd7ed558ccd
	h ^= h >> 33
	h *= 0xc4ceb9fe1a85ec53
	h ^= h >> 33

	return h
}

// ============================================================
// Style VT formatting
// ============================================================

// Returns the VT (SGR) sequence string for this style.
// This always resets the style first with \x1b[0m since a style
// is meant to be fully self-contained.
//
// For individual styles, this always emits multiple SGR sequences
// (i.e. an individual \x1b[<stuff>m for each attribute) rather than
// trying to combine them into a single sequence. We do this because
// terminals have varying levels of support for combined sequences
// especially with mixed separators (e.g. : vs ;).
pub fn (self &CellStyle) format_vt() string {
	return format_style_vt(*self)
}

// Returns the VT sequence string with palette resolution.
pub fn (self &CellStyle) format_vt_with_palette(palette []RGB) string {
	return format_style_vt_with_palette(*self, palette)
}

// Returns the inline CSS properties string for this style.
// The output is a valid CSS style string suitable for use in a style
// attribute (e.g., "color: rgb(255, 0, 0); font-weight: bold;").
//
// Palette colors are emitted as CSS variables like var(--vt-palette-N).
pub fn (self &CellStyle) format_html() string {
	return format_style_html_with_palette(*self, none)
}

// Returns the inline CSS with palette resolution.
pub fn (self &CellStyle) format_html_with_palette(palette []RGB) string {
	return format_style_html_with_palette(*self, palette)
}

// ============================================================
// RGB equality helper
// ============================================================

// Returns true if two RGB colors are equal.
pub fn (self RGB) eql(other RGB) bool {
	return self.r == other.r && self.g == other.g && self.b == other.b
}

// ============================================================
// Set (XTODO)
// ============================================================

// XTODO: RefCountedSet for styles
// The Set type manages a deduplicated, ref-counted collection of styles.
// It is backed by a hash map and provides add/get/release operations.
// This requires the full RefCountedSet implementation which is not yet
// translated.
