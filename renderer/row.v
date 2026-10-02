module renderer

import terminal

// Returns true if the row of this pin should never have its background
// color extended for filling padding space in the renderer. This is
// a set of heuristics that help making our padding look better.
pub fn never_extend_bg(row terminal.RowData, cells []terminal.CellData, styles []terminal.CellStyle, palette [256]terminal.RGB, default_background terminal.RGB) bool {
	// Any semantic prompts should not have their background extended
	// because prompts often contain special formatting (such as
	// powerline) that looks bad when extended.
	match row.header.semantic_prompt {
		.prompt, .prompt_continuation { return true }
		else {}
	}

	for x, cell in cells {
		// For codepoint cells we also never extend bg if any cell has a
		// powerline glyph because these are perfect-fit.
		if cell.content_tag == .codepoint || cell.content_tag == .codepoint_grapheme {
			cp := cell.codepoint
			if (cp >= 0xE0B0 && cp <= 0xE0C8) || cp == 0xE0CA
				|| (cp >= 0xE0CC && cp <= 0xE0D2) || cp == 0xE0D4 {
				return true
			}
		}

		// If any cell has a default background color then we don't extend
		// because the default background probably looks good enough as an
		// extension. Resolve the cell's background (mirrors ghostty
		// Style.bg): bg-color cells carry the color on the cell, otherwise
		// it comes from the style; a nil result means the default bg.
		s := if cell.style_id != 0 && x < styles.len {
			styles[x]
		} else {
			terminal.CellStyle{}
		}
		bg := resolve_bg(cell, s, palette) or { return true }
		if bg.r == default_background.r && bg.g == default_background.g
			&& bg.b == default_background.b {
			return true
		}
	}

	return false
}

// resolve_bg returns the background RGB for a cell, or none if there is no
// explicit background (meaning the default background applies). Faithful to
// ghostty's Style.bg(cell, palette).
fn resolve_bg(cell terminal.CellData, s terminal.CellStyle, palette [256]terminal.RGB) ?terminal.RGB {
	match cell.content_tag {
		.bg_color_palette {
			return palette[cell.color_palette()]
		}
		.bg_color_rgb {
			return terminal.RGB{
				r: cell.color_rgb_r()
				g: cell.color_rgb_g()
				b: cell.color_rgb_b()
			}
		}
		.codepoint, .codepoint_grapheme {
			match s.bg_color {
				terminal.StyleColorNone { return none }
				terminal.StyleColorPalette {
					return palette[(s.bg_color as terminal.StyleColorPalette).index]
				}
				terminal.StyleColorRgb {
					return (s.bg_color as terminal.StyleColorRgb).rgb
				}
			}
		}
	}
}
