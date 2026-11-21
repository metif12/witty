module tmux

// Tmux layout parsing.
//
// Source: terminal/tmux/layout.zig
//
// A tmux layout is a tree structure describing the arrangement of
// panes within a window. Panes can be arranged horizontally (left-right)
// or vertically (top-bottom), with arbitrary nesting.

// ============================================================
// Layout - a tmux layout tree node
// ============================================================

// A tmux layout.
//
// This is a tree structure so by definition it pretty much needs to be
// allocated. We use V's garbage collection for memory management.
pub struct Layout {
pub:
	// Width, height of the node.
	width  uint
	height uint

	// X and Y offset from the top-left corner of the window.
	x uint
	y uint

	// The content of this node, either a pane (leaf) or more nodes
	// (split) horizontally or vertically.
	content Content
}

pub type Content = ContentPane | ContentHorizontal | ContentVertical

pub struct ContentPane {
pub:
	pane_id uint
}

pub struct ContentHorizontal {
pub:
	children []Layout
}

pub struct ContentVertical {
pub:
	children []Layout
}

// ============================================================
// Layout parsing
// ============================================================

// Parse a layout string that includes a 4-character checksum prefix.
//
// The expected format is: `XXXX,layout_string` where XXXX is the
// 4-character hexadecimal checksum and the layout string follows
// after the comma. For example: `f8f9,80x24,0,0{40x24,0,0,1,40x24,40,0,2}`.
//
// Returns an error if the checksum doesn't match the layout or
// if the format is invalid.
pub fn Layout.parse_with_checksum(str string) !Layout {
	// If the string is less than 5 characters, it can't possibly
	// be correct. 4-char checksum + comma. In practice it should
	// be even longer, but that'll fail parse later.
	if str.len < 5 {
		return error('SyntaxError: string too short for checksum')
	}
	if str[4] != `,` {
		return error('SyntaxError: expected comma after checksum')
	}

	// The layout string should start with a 4-character checksum.
	checksum := Checksum.calculate(str[5..])
	checksum_str := checksum.as_string()
	if str[..4] != checksum_str {
		return error('ChecksumMismatch')
	}

	// Checksum matches, parse the rest.
	return Layout.parse(str[5..])
}

// Parse a layout string into a Layout structure.
//
// The layout string must be fully provided as a single string.
// Layouts are generally small so this should not be a problem.
//
// Tmux layout strings have the following format:
//
// - WxH,X,Y,ID Leaf pane: width x height, x-offset, y-offset, pane ID
// - WxH,X,Y{...} Horizontal split (left-right), children comma-separated
// - WxH,X,Y[...] Vertical split (top-bottom), children comma-separated
pub fn Layout.parse(str string) !Layout {
	mut ps := ParseState{}
	root := parse_next(str, mut ps)!
	if ps.offset != uint(str.len) {
		return error('SyntaxError: trailing data')
	}
	return root
}

// ParseState wraps the mutable offset used during recursive parsing.
// V does not allow mutable primitive parameters, so we use a struct.
struct ParseState {
mut:
	offset uint
}

fn parse_next(str string, mut ps ParseState) !Layout {
	// Find the first `x` to grab the width.
	x_idx := str[ps.offset..].index_u8(`x`)
	if x_idx < 0 {
		return error('SyntaxError: missing width separator')
	}
	width := parse_usize(str[ps.offset..ps.offset + uint(x_idx)]) or {
		return error('SyntaxError: invalid width')
	}
	ps.offset += uint(x_idx + 1) // Consume `x`

	// Find the height, up to a comma.
	comma_idx := str[ps.offset..].index_u8(`,`)
	if comma_idx < 0 {
		return error('SyntaxError: missing height separator')
	}
	height := parse_usize(str[ps.offset..ps.offset + uint(comma_idx)]) or {
		return error('SyntaxError: invalid height')
	}
	ps.offset += uint(comma_idx + 1) // Consume `,`

	// Find X.
	comma_idx2 := str[ps.offset..].index_u8(`,`)
	if comma_idx2 < 0 {
		return error('SyntaxError: missing x separator')
	}
	x := parse_usize(str[ps.offset..ps.offset + uint(comma_idx2)]) or {
		return error('SyntaxError: invalid x')
	}
	ps.offset += uint(comma_idx2 + 1) // Consume `,`

	// Find Y, which can end in any of `,{,[`
	mut y_end := -1
	for i := ps.offset; i < uint(str.len); i++ {
		if str[i] == `,` || str[i] == `{` || str[i] == `[` {
			y_end = int(i - ps.offset)
			break
		}
	}
	if y_end < 0 {
		return error('SyntaxError: missing y delimiter')
	}
	y := parse_usize(str[ps.offset..ps.offset + uint(y_end)]) or {
		return error('SyntaxError: invalid y')
	}
	ps.offset += uint(y_end) // Don't consume the delimiter!

	// Determine our child node based on the delimiter character.
	delimiter := str[ps.offset]

	mut content := Content(ContentPane{ pane_id: 0 })

	if delimiter == `,` {
		// Consume the delimiter.
		ps.offset += 1

		// Leaf pane. Read up to `,}]` because we may be in
		// a set of nodes. If none exist, end of string is fine.
		mut pane_end := uint(str.len) - ps.offset
		for i := ps.offset; i < uint(str.len); i++ {
			if str[i] == `,` || str[i] == `}` || str[i] == `]` {
				pane_end = i - ps.offset
				break
			}
		}

		pane_str := str[ps.offset..ps.offset + pane_end]
		if pane_end == 0 {
			return error('SyntaxError: empty pane ID')
		}
		pane_id := parse_usize(pane_str) or { return error('SyntaxError: invalid pane ID') }
		ps.offset += pane_end // Consume the pane ID, not the delimiter

		content = Content(ContentPane{ pane_id: pane_id })
	} else if delimiter == `{` || delimiter == `[` {
		opening := delimiter

		// Move beyond our opening.
		ps.offset += 1

		mut nodes := []Layout{}

		for {
			nodes << parse_next(str, mut ps)!

			// We should not reach the end of string here because
			// we expect a closing bracket.
			if ps.offset >= uint(str.len) {
				return error('SyntaxError: unexpected end of string')
			}

			// If it is a comma, we expect another node.
			if str[ps.offset] == `,` {
				ps.offset += 1 // Consume
				continue
			}

			// We expect a closing bracket now.
			if opening == `{` {
				if str[ps.offset] != `}` {
					return error('SyntaxError: expected closing }')
				}
			} else if opening == `[` {
				if str[ps.offset] != `]` {
					return error('SyntaxError: expected closing ]')
				}
			}

			// Successfully parsed all children.
			ps.offset += 1 // Consume closing bracket

			if opening == `{` {
				content = Content(ContentHorizontal{ children: nodes })
			} else {
				content = Content(ContentVertical{ children: nodes })
			}
			break
		}
	} else {
		return error('SyntaxError: unexpected character after y')
	}

	return Layout{
		width: width
		height: height
		x: x
		y: y
		content: content
	}
}

// ============================================================
// Checksum
// ============================================================

// Checksum for tmux layout strings.
pub struct Checksum {
pub:
	value u16
}

// Calculate the checksum of a tmux layout string.
// The algorithm rotates the checksum right by 1 bit (with wraparound)
// and adds the ASCII value of each character.
pub fn Checksum.calculate(str string) Checksum {
	mut result := u16(0)
	for c in str.bytes() {
		// Rotate right by 1: (result >> 1) + ((result & 1) << 15)
		result = (result >> 1) | ((result & 1) << 15)
		result += u16(c)
	}
	return Checksum{ value: result }
}

// Convert the checksum to a 4-character hexadecimal string. This
// is always zero-padded to match the tmux implementation
// (in layout-custom.c).
pub fn (self Checksum) as_string() string {
	charset := '0123456789abcdef'
	return '${charset[(self.value >> 12) & 0xf].ascii_str()}${charset[(self.value >> 8) & 0xf].ascii_str()}${charset[(self.value >> 4) & 0xf].ascii_str()}${charset[self.value & 0xf].ascii_str()}'
}
