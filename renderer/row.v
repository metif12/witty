module renderer

import terminal

// Returns true if the row of this pin should never have its background
// color extended for filling padding space in the renderer. This is
// a set of heuristics that help making our padding look better.
pub fn never_extend_bg(row terminal.RowData, cells []terminal.CellData, styles []terminal.CellStyle, default_background terminal.RGB) bool {
	// Any semantic prompts should not have their background extended
	// because prompts often contain special formatting (such as
	// powerline) that looks bad when extended.
	match row.semantic_prompt {
		.prompt, .prompt_continuation { return true }
		else {}
	}

	for x, cell in cells {
		match cell.content_tag {
			// If it is a background color cell, we check the color.
			.bg_color_palette, .bg_color_rgb {
				s := if cell.style_id != 0 && x < styles.len {
					styles[x]
				} else {
					terminal.CellStyle{}
				}
				// No bg color means default background
				if s.bg_color == .none {
					return true
				}
				if s.bg_color == .rgb {
					if s.bg_r == default_background.r && s.bg_g == default_background.g
						&& s.bg_b == default_background.b {
						return true
					}
				}
			}
			// If its a codepoint cell we can check the style.
			.codepoint, .codepoint_grapheme {
				// For codepoint containing, we also never extend bg
				// if any cell has a powerline glyph because these are
				// perfect-fit.
				cp := cell.codepoint
				if cp >= 0xE0B0 && cp <= 0xE0C8 {
					return true
				}
				if cp == 0xE0CA {
					return true
				}
				if cp >= 0xE0CC && cp <= 0xE0D2 {
					return true
				}
				if cp == 0xE0D4 {
					return true
				}

				// Never extend a cell that has a default background.
				// A default background is applied if there is no background
				// on the style or the explicitly set background
				// matches our default background.
				s := if cell.style_id != 0 && x < styles.len {
					styles[x]
				} else {
					terminal.CellStyle{}
				}
				if s.bg_color == .none {
					return true
				}
				if s.bg_color == .rgb {
					if s.bg_r == default_background.r && s.bg_g == default_background.g
						&& s.bg_b == default_background.b {
						return true
					}
				}
			}
		}
	}

	return false
}
