module terminal

import internal_hash

// --- Original Ghostty Comments Start: src/terminal/style.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/style.zig
//
// The unique identifier for a style. This is at most the number of cells
// that can fit into a terminal page.
// The Id to use for default styling.
// The style attributes for a cell.
// Various colors, all self-explanatory.
// On/off attributes that don't require much bit width so we use
// a packed struct to make this take up significantly less space.
// The color for an SGR attribute. A color can come from multiple
// sources so we use this to track the source plus color value so that
// we can properly react to things like palette changes.
// True if the color is equal to another color.
// Formatting to make debug logs easier to read
// by only including non-default attributes.
// True if the style is the default style.
// True if the style is equal to another style.
// Returns the bg color for a cell with this style given the cell
// that has this style and the palette to use.
//
// Note that generally if a cell is a color-only cell, it SHOULD
// only have the default style, but this is meant to work with the
// default style as well.
// The default color to use if the style doesn't specify a
// foreground color and no configuration options override
// it.
// The current color palette. Required to map palette indices to
// real color values.
// If specified, the color to use for bold text.
// Returns the fg color for a cell with this style given the palette
// and various configuration options.
// Note we don't pull the bold check to the top-level here because
// we don't want to duplicate the conditional multiple times since
// certain colors require more checks (e.g. `bold_is_bright`).
// Returns the underline color for this style.
// Returns a bg-color only cell from this style, if it exists.
// Formatting to make debug logs easier to read
// by only including non-default attributes.
// Returns a formatter that renders this style as VT sequences,
// to be used with `{f}`. This always resets the style first `\x1b[0m`
// since a style is meant to be fully self-contained.
//
// For individual styles, this always emits multiple SGR sequences
// (i.e. an individual `\x1b[<stuff>m` for each attribute) rather than
// trying to combine them into a single sequence. We do this because
// terminals have varying levels of support for combined sequences
// especially with mixed separators (e.g. `:` vs `;`).
// Returns a formatter that renders this style as inline CSS properties,
// to be used with `{f}`. The output is a valid CSS style string suitable
// for use in a `style` attribute (e.g., "color: rgb(255, 0, 0); font-weight: bold;").
//
// Palette colors are emitted as CSS variables like `var(--vt-palette-N)`.
// If set, palette colors will be emitted as RGB values instead of
// palette indices. This is useful when you want to capture the
// exact colors at formatting time rather than relying on the
// terminal's palette.
// Always reset the style. Styles are fully self-contained.
// Even if this style is empty, then that means we want to go
// back to the default.
// Our flags
// Various RGB colors.
// If set, palette colors will be emitted as RGB values instead of
// CSS variables. This is useful when you want to capture the exact
// colors at formatting time rather than relying on CSS variables.
// Colors
// Text decoration line
// Text decoration style
// `PackedStyle` represents the same data as `Style` but without padding,
// which is necessary for hashing via re-interpretation of the underlying
// bytes.
//
// `Style` is still preferred for everything else as it has type-safety
// when using the `Color` tagged union.
//
// Empirical testing shows that storing all of the tags first and then the
// data provides a better layout for serializing into and is faster on
// benchmarks.
// After https://github.com/ziglang/zig/issues/19754 is implemented,
// it will be an compiler-error to have packed union fields of
// differing size.
//
// For now we just need to be careful not to accidentally introduce
// padding.
// We pack the style in to 128 bits, fold it to 64 bits,
// then use std.hash.int to make it sufficiently uniform.
// Add style
// Second add should return the same metadata.
// Look it up
// Add a second style
// Look it up
// Ref count
// Release
// We added the first one twice, so
// We want to support at least this many styles without overflowing.
//
// --- Original Ghostty Comments End: src/terminal/style.zig

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
	return self.flags.int() == other.flags.int()
		&& style_color_eql(self.fg_color, self.fg_r, self.fg_g, self.fg_b, self.fg_palette, other.fg_color, other.fg_r, other.fg_g, other.fg_b, other.fg_palette)
		&& style_color_eql(self.bg_color, self.bg_r, self.bg_g, self.bg_b, self.bg_palette, other.bg_color, other.bg_r, other.bg_g, other.bg_b, other.bg_palette)
		&& style_color_eql(self.underline_color, self.underline_r, self.underline_g, self.underline_b, self.underline_palette, other.underline_color, other.underline_r, other.underline_g, other.underline_b, other.underline_palette)
}

fn style_color_eql(tag ColorType, r u8, g u8, b u8, palette u8, other_tag ColorType, other_r u8, other_g u8, other_b u8, other_palette u8) bool {
	if tag != other_tag {
		return false
	}
	return match tag {
		.none { true }
		.palette { palette == other_palette }
		.rgb { r == other_r && g == other_g && b == other_b }
	}
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
			if self.flags.bold() {
				if bold := opts.bold_color {
					if bold.bright {
						// bright mode: no special color, use default
					} else {
						// color mode: use the explicit bold color
						return bold.to_terminal_rgb()
					}
				}
			}
			return opts.default_color
		}
		.palette {
			idx := self.fg_palette
			if self.flags.bold() {
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
			if self.flags.bold() && rgb.r == opts.default_color.r && rgb.g == opts.default_color.g
				&& rgb.b == opts.default_color.b {
				if bold := opts.bold_color {
					if !bold.bright {
						// color mode: use the explicit bold color
						return bold.to_terminal_rgb()
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
		.palette { palette[int(self.underline_palette)] }
		.rgb {
			RGB{
				r: self.underline_r
				g: self.underline_g
				b: self.underline_b
			}
		}
	}
}

// ============================================================
// Style hashing
// ============================================================

// Hash the style for use in hash maps. Ghostty packs the three color tags,
// their active 24-bit payloads, and the flags into a padding-free u128, folds
// its two u64 halves, and applies an integer hash. Constructing those halves
// explicitly preserves the same field layout without relying on V struct
// padding or inactive tagged-union storage.
pub fn (self &CellStyle) hash() u64 {
	fg_data := style_color_data(self.fg_color, self.fg_r, self.fg_g, self.fg_b, self.fg_palette)
	bg_data := style_color_data(self.bg_color, self.bg_r, self.bg_g, self.bg_b, self.bg_palette)
	underline_data := style_color_data(self.underline_color, self.underline_r, self.underline_g, self.underline_b, self.underline_palette)

	low := u64(int(self.fg_color)) | (u64(int(self.bg_color)) << 8) | (u64(int(self.underline_color)) << 16) | (fg_data << 24) | ((bg_data & 0xffff) << 48)
	high := (bg_data >> 16) | (underline_data << 8) | (u64(self.flags.int()) << 32)
	return internal_hash.int_u64(low ^ high)
}

fn style_color_data(tag ColorType, r u8, g u8, b u8, palette u8) u64 {
	return match tag {
		.none { u64(0) }
		.palette { u64(palette) }
		.rgb { u64(r) | (u64(g) << 8) | (u64(b) << 16) }
	}
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

// Ghostty exports its style-specialized RefCountedSet as `style.Set`.
// StyleSet is the V specialization used by Page, so expose the same public
// name without duplicating the implementation.
pub type Set = StyleSet
