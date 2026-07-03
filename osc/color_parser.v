module osc

// --- Original Ghostty Comments Start: src/terminal/osc/parsers/color.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/osc/parsers/color.zig
//
// The possible operations we support for colors.
// Parse OSCs 4, 5, 10-19, 104, 110-119
// If we've collected any extra data parse that, otherwise use an empty
// string.
// Check and make sure that we're parsing the correct OSCs
// Parse any color operation string. This should NOT include the operation
// itself, but only the body of the operation. e.g. for "4;a;b;c" the body
// should be "a;b;c" and the operation should be set accordingly.
//
// Color parsing is fairly complicated so we pull this out to a specialized
// function rather than go through our OSC parsing state machine. This is
// much slower and requires more memory (since we need to buffer the full
// request) but grants us an easier to understand and testable implementation.
//
// If color changing ends up being a bottleneck we can optimize this later.
// OSC 4/5
// Note: in ANY error scenario below we return the accumulated results.
// This matches the xterm behavior (see misc.c ChangeAnsiColorRequest)
// We expect a `c; spec` pair. If either doesn't exist then
// we return the results up to this point.
// Color must be numeric. u9 because that'll fit our palette + special
// Parse the color.
// OSC5 maps directly to the Special enum.
// OSC4 maps 0-255 to palette, 256-259 to special offset
// by the palette count.
// "?" always results in a query.
// OSC 104/105: Reset ANSI Colors
// Note: xterm stops parsing the reset list on any error, but we're
// more flexible and try the next value. This matches the behavior of
// Kitty and I don't see a downside to being more flexible here. Hopefully
// no one depends on the exact behavior of xterm.
// If no parameters are given, we reset the full table.
// Empty color strings are ignored, not treated as an error.
// Color must be numeric. u9 because that'll fit our palette + special
// Parse the color.
// OSC105 maps directly to the Special enum.
// OSC104 maps 0-255 to palette, 256-259 to special offset
// by the palette count.
// OSC 10-19: Get/Set Dynamic Colors
// Note: in ANY error scenario below we return the accumulated results.
// This matches the xterm behavior (see misc.c ChangeColorsRequest)
// Each successive value uses the next color so long as it exists.
// OSC 110-119: Reset Dynamic Colors
// A segmented list is used to avoid copying when many operations
// are given in a single OSC. In most cases, OSC 4/104/etc. send
// very few so the prealloc is optimized for that.
//
// The exact prealloc value is chosen arbitrarily assuming most
// color ops have very few. If we can get empirical data on more
// typical values we can switch to that.
// A single operation related to the terminal color palette.
// Test every palette index
// Simple color set
// printf '\e]4;0;red\\'
// Simple color query
// printf '\e]4;0;?\\'
// Trailing invalid data produces results up to that point
// printf '\e]4;0;red;\e\\'
// Whitespace doesn't produce a working value in xterm but we
// allow it because Kitty does and it seems harmless.
//
// printf '\e]4;0;red \e\\'
// Test every special color
// Simple color set
// printf '\e]4;256;red\\'
// Test every special color
// Simple color set
// printf '\e]4;256;red\\'
// printf '\e]4;0;red;1;blue\e\\'
// Multiple requests with same index overwrite each other
// printf '\e]4;0;red;0;blue\e\\'
// Test every palette index
// Simple color set
// printf '\e]104;0\\'
// Test every special color
// Simple color set
// printf '\e]104;256\\'
// OSC 10-19: Get/Set Dynamic Colors
// Example script:
// printf '\e]10;red\e\\'
// Example script:
// printf '\e]11;red;blue\e\\'
// OSC 110-119: Reset Dynamic Colors
// Example script:
// printf '\e]110\e\\'
// xterm allows a trailing semicolon. script to verify:
//
// printf '\e]110;\e\\'
// xterm does NOT allow any whitespace
//
// printf '\e]110 \e\\'
//
// --- Original Ghostty Comments End: src/terminal/osc/parsers/color.zig


// OSC color operations to set, reset, or report color settings.
//
// Currently, these OSCs are handled by color operations:
// 4, 5, 10-19, 104, 105, 110-119

// The possible operations we support for colors.
pub enum ColorOperation {
	osc_4
	osc_5
	osc_10
	osc_11
	osc_12
	osc_13
	osc_14
	osc_15
	osc_16
	osc_17
	osc_18
	osc_19
	osc_104
	osc_105
	osc_110
	osc_111
	osc_112
	osc_113
	osc_114
	osc_115
	osc_116
	osc_117
	osc_118
	osc_119
}

// DynamicColor represents the dynamic color targets for OSC 10-19.
pub enum DynamicColor {
	foreground       // 10
	background       // 11
	cursor           // 12
	pointer_foreground // 13
	pointer_background // 14
	tektronix_foreground // 15
	tektronix_background // 16
	highlight_background // 17
	tektronix_cursor // 18
	highlight_foreground // 19
}

// next returns the next DynamicColor in sequence, or none if at end.
pub fn (c DynamicColor) next() ?DynamicColor {
	return match c {
		.foreground { .background }
		.background { .cursor }
		.cursor { .pointer_foreground }
		.pointer_foreground { .pointer_background }
		.pointer_background { .tektronix_foreground }
		.tektronix_foreground { .tektronix_background }
		.tektronix_background { .highlight_background }
		.highlight_background { .tektronix_cursor }
		.tektronix_cursor { .highlight_foreground }
		.highlight_foreground { none }
	}
}

// SpecialColor represents special colors beyond the 256-color palette.
// This mirrors ghostty's `terminal.color.Special` enum(u3).
pub enum SpecialColor {
	bold      // 0
	underline // 1
	blink     // 2
	reverse   // 3
	italic    // 4
}

// RGB represents an RGB color.
pub struct RGB {
pub:
	r u8
	g u8
	b u8
}

// parse_rgb parses an X11 color specification string into an RGB value.
// Supported formats:
//   - rgb:RR/GG/BB (hex, 1-4 digits per channel)
//   - rgbi:R.R/G.G/B.B (float intensity 0.0-1.0)
//   - #RGB, #RRGGBB, #RRRGGGBBB, #RRRRGGGGBBBB
//   - Named X11 colors (a subset)
pub fn parse_rgb(spec string) ?RGB {
	s := spec.trim_space()
	if s.len == 0 {
		return none
	}

	// Try rgb: format
	if s.starts_with('rgb:') {
		return parse_rgb_colon(s[4..])
	}

	// Try rgbi: format (floating point intensity)
	if s.starts_with('rgbi:') {
		return parse_rgbi(s[5..])
	}

	// Try # format
	if s[0] == `#` {
		return parse_rgb_hash(s[1..])
	}

	// Try named colors (case insensitive)
	return parse_named_color(s)
}

// parse_rgb_colon parses "RR/GG/BB" format (1-4 hex digits per channel).
fn parse_rgb_colon(s string) ?RGB {
	parts := s.split('/')
	if parts.len != 3 {
		return none
	}
	r := parse_color_channel(parts[0]) or { return none }
	g := parse_color_channel(parts[1]) or { return none }
	b := parse_color_channel(parts[2]) or { return none }
	return RGB{
		r: r
		g: g
		b: b
	}
}

// parse_color_channel parses a hex color channel value (1-4 digits).
// Scales the value to 8-bit range.
fn parse_color_channel(s string) ?u8 {
	if s.len == 0 || s.len > 4 {
		return none
	}
	val := u32(parse_hex(s) or { return none })
	return match s.len {
		1 { u8(val * 17) } // 0x0 -> 0x00, 0xf -> 0xff
		2 { u8(val) }
		3 { u8(val >> 4) }
		4 { u8(val >> 8) }
		else { none }
	}
}

// parse_hex parses a hex string to an integer.
fn parse_hex(s string) ?u64 {
	if s.len == 0 {
		return none
	}
	mut result := u64(0)
	for c in s {
		result *= 16
		if c >= `0` && c <= `9` {
			result += u64(c - `0`)
		} else if c >= `a` && c <= `f` {
			result += u64(c - `a` + 10)
		} else if c >= `A` && c <= `F` {
			result += u64(c - `A` + 10)
		} else {
			return none
		}
	}
	return result
}

// parse_rgbi parses "R.R/G.G/B.B" format (floating point intensity).
fn parse_rgbi(s string) ?RGB {
	parts := s.split('/')
	if parts.len != 3 {
		return none
	}
	r := parse_float_channel(parts[0]) or { return none }
	g := parse_float_channel(parts[1]) or { return none }
	b := parse_float_channel(parts[2]) or { return none }
	return RGB{
		r: r
		g: g
		b: b
	}
}

// parse_float_channel parses a floating point color channel (0.0-1.0).
fn parse_float_channel(s string) ?u8 {
	val := s.f64()
	if val < 0.0 || val > 1.0 {
		return none
	}
	return u8(val * 255.0 + 0.5)
}

// parse_rgb_hash parses "#RGB", "#RRGGBB", "#RRRGGGBBB", "#RRRRGGGGBBBB".
fn parse_rgb_hash(s string) ?RGB {
	match s.len {
		3 {
			r := parse_hex(s[0..1]) or { return none }
			g := parse_hex(s[1..2]) or { return none }
			b := parse_hex(s[2..3]) or { return none }
			return RGB{
				r: u8(r * 17)
				g: u8(g * 17)
				b: u8(b * 17)
			}
		}
		6 {
			r := parse_hex(s[0..2]) or { return none }
			g := parse_hex(s[2..4]) or { return none }
			b := parse_hex(s[4..6]) or { return none }
			return RGB{
				r: u8(r)
				g: u8(g)
				b: u8(b)
			}
		}
		9 {
			r := parse_hex(s[0..3]) or { return none }
			g := parse_hex(s[3..6]) or { return none }
			b := parse_hex(s[6..9]) or { return none }
			return RGB{
				r: u8(r >> 4)
				g: u8(g >> 4)
				b: u8(b >> 4)
			}
		}
		12 {
			r := parse_hex(s[0..4]) or { return none }
			g := parse_hex(s[4..8]) or { return none }
			b := parse_hex(s[8..12]) or { return none }
			return RGB{
				r: u8(r >> 8)
				g: u8(g >> 8)
				b: u8(b >> 8)
			}
		}
		else {
			return none
		}
	}
}

// parse_named_color parses a limited set of X11 named colors.
fn parse_named_color(name string) ?RGB {
	lower := name.to_lower()
	return match lower {
		'red' { RGB{r: 255, g: 0, b: 0} }
		'green' { RGB{r: 0, g: 128, b: 0} }
		'blue' { RGB{r: 0, g: 0, b: 255} }
		'white' { RGB{r: 255, g: 255, b: 255} }
		'black' { RGB{r: 0, g: 0, b: 0} }
		'yellow' { RGB{r: 255, g: 255, b: 0} }
		'cyan' { RGB{r: 0, g: 255, b: 255} }
		'magenta' { RGB{r: 255, g: 0, b: 255} }
		'orange' { RGB{r: 255, g: 165, b: 0} }
		'aliceblue' { RGB{r: 0xf0, g: 0xf8, b: 0xff} }
		else { none }
	}
}

// ColorTarget identifies what color is being operated on.
pub type ColorTarget = ColorTargetPalette | ColorTargetSpecial | ColorTargetDynamic

pub struct ColorTargetPalette {
pub:
	index u8
}

pub struct ColorTargetSpecial {
pub:
	color SpecialColor
}

pub struct ColorTargetDynamic {
pub:
	color DynamicColor
}

// ColorRequest represents a single color operation request.
pub type ColorRequest = ColorRequestSet | ColorRequestQuery | ColorRequestReset | ColorRequestResetPalette | ColorRequestResetSpecial

pub struct ColorRequestSet {
pub:
	target ColorTarget
	color  RGB
}

pub struct ColorRequestQuery {
pub:
	target ColorTarget
}

pub struct ColorRequestReset {
pub:
	target ColorTarget
}

pub struct ColorRequestResetPalette {}

pub struct ColorRequestResetSpecial {}

// ColoredTarget pairs a color target with an RGB color value.
pub struct ColoredTarget {
pub:
	target ColorTarget
	color  RGB
}

// parse_color_operation parses OSC color commands (4, 5, 10-19, 104, 105, 110-119).
fn parse_color_operation(mut parser Parser, terminator_ch u8) ?Command {
	data := parser.buffered()
	data_str := data.bytestr()

	// Determine the operation from the parser state
	op := match parser.state {
		.s_4 { ColorOperation.osc_4 }
		.s_5 { ColorOperation.osc_5 }
		.s_10 { ColorOperation.osc_10 }
		.s_11 { ColorOperation.osc_11 }
		.s_12 { ColorOperation.osc_12 }
		.s_13 { ColorOperation.osc_13 }
		.s_14 { ColorOperation.osc_14 }
		.s_15 { ColorOperation.osc_15 }
		.s_16 { ColorOperation.osc_16 }
		.s_17 { ColorOperation.osc_17 }
		.s_18 { ColorOperation.osc_18 }
		.s_19 { ColorOperation.osc_19 }
		.s_104 { ColorOperation.osc_104 }
		.s_105 { ColorOperation.osc_105 }
		.s_110 { ColorOperation.osc_110 }
		.s_111 { ColorOperation.osc_111 }
		.s_112 { ColorOperation.osc_112 }
		.s_113 { ColorOperation.osc_113 }
		.s_114 { ColorOperation.osc_114 }
		.s_115 { ColorOperation.osc_115 }
		.s_116 { ColorOperation.osc_116 }
		.s_117 { ColorOperation.osc_117 }
		.s_118 { ColorOperation.osc_118 }
		.s_119 { ColorOperation.osc_119 }
		else {
			parser.state = .invalid
			return none
		}
	}

	// Parse the color data based on operation type. This mirrors Ghostty's
	// parseColor which produces a SegmentedList(Request). Here we produce a
	// []ColorRequest and store it directly on the command.
	requests := parse_color_data(op, data_str)

	// Store the result as a color_operation command. The parsed operation and
	// request list are wired into the dedicated Command fields so downstream
	// consumers can apply the color changes. We keep str_value/str_value2
	// populated with the raw data and operation name for logging/debugging.
	parser.command = Command{
		cmd_type:       .color_operation
		terminator:     init_terminator(terminator_ch)
		str_value:      data_str
		str_value2:     op.str()
		color_op:       op
		color_requests: requests
	}
	return parser.command
}

// parse_color_data parses the color data string based on operation type.
// Returns a list of parsed color requests.
fn parse_color_data(op ColorOperation, data string) []ColorRequest {
	return match op {
		.osc_4 { parse_get_set_ansi_color(.osc_4, data) }
		.osc_5 { parse_get_set_ansi_color(.osc_5, data) }
		.osc_104 { parse_reset_ansi_color(.osc_104, data) }
		.osc_105 { parse_reset_ansi_color(.osc_105, data) }
		.osc_10 { parse_get_set_dynamic_color(.foreground, data) }
		.osc_11 { parse_get_set_dynamic_color(.background, data) }
		.osc_12 { parse_get_set_dynamic_color(.cursor, data) }
		.osc_13 { parse_get_set_dynamic_color(.pointer_foreground, data) }
		.osc_14 { parse_get_set_dynamic_color(.pointer_background, data) }
		.osc_15 { parse_get_set_dynamic_color(.tektronix_foreground, data) }
		.osc_16 { parse_get_set_dynamic_color(.tektronix_background, data) }
		.osc_17 { parse_get_set_dynamic_color(.highlight_background, data) }
		.osc_18 { parse_get_set_dynamic_color(.tektronix_cursor, data) }
		.osc_19 { parse_get_set_dynamic_color(.highlight_foreground, data) }
		.osc_110 { parse_reset_dynamic_color(.foreground, data) }
		.osc_111 { parse_reset_dynamic_color(.background, data) }
		.osc_112 { parse_reset_dynamic_color(.cursor, data) }
		.osc_113 { parse_reset_dynamic_color(.pointer_foreground, data) }
		.osc_114 { parse_reset_dynamic_color(.pointer_background, data) }
		.osc_115 { parse_reset_dynamic_color(.tektronix_foreground, data) }
		.osc_116 { parse_reset_dynamic_color(.tektronix_background, data) }
		.osc_117 { parse_reset_dynamic_color(.highlight_background, data) }
		.osc_118 { parse_reset_dynamic_color(.tektronix_cursor, data) }
		.osc_119 { parse_reset_dynamic_color(.highlight_foreground, data) }
	}
}

// OSC 4/5: Get/Set ANSI colors
fn parse_get_set_ansi_color(op ColorOperation, data string) []ColorRequest {
	// Note: in ANY error scenario below we return the accumulated results.
	// This matches the xterm behavior (see misc.c ChangeAnsiColorRequest)
	mut result := []ColorRequest{}
	mut remaining := data

	for remaining.len > 0 {
		// We expect a `c;spec` pair. If either doesn't exist then
		// we return the results up to this point.
		sep1 := remaining.index_u8(`;`)
		if sep1 < 0 {
			return result
		}
		color_str := remaining[..sep1]
		remaining = remaining[sep1 + 1..]

		sep2 := remaining.index_u8(`;`)
		mut spec_str := ''
		if sep2 >= 0 {
			spec_str = remaining[..sep2]
			remaining = remaining[sep2 + 1..]
		} else {
			spec_str = remaining
			remaining = ''
		}

		// Color must be numeric
		color_idx := color_str.int()
		if color_str.len == 0 || (color_idx == 0 && color_str != '0') {
			return result
		}

		// Parse the target based on operation
		target := match op {
			.osc_5 {
				// OSC5 maps directly to the Special enum (0-4)
				if color_idx < 0 || color_idx > 4 {
					return result
				}
				ColorTarget(ColorTargetSpecial{
					color: unsafe { SpecialColor(color_idx) }
				})
			}
			.osc_4 {
				// OSC4 maps 0-255 to palette, 256-260 to special
				if color_idx >= 0 && color_idx <= 255 {
					ColorTarget(ColorTargetPalette{
						index: u8(color_idx)
					})
				} else if color_idx >= 256 && color_idx <= 260 {
					ColorTarget(ColorTargetSpecial{
						color: unsafe { SpecialColor(color_idx - 256) }
					})
				} else {
					return result
				}
			}
			else {
				return result
			}
		}

		// "?" always results in a query.
		if spec_str == '?' {
			result << ColorRequestQuery{target: target}
			continue
		}

		rgb := parse_rgb(spec_str) or { return result }
		result << ColorRequestSet{
			target: target
			color:  rgb
		}
	}
	return result
}

// OSC 104/105: Reset ANSI Colors
fn parse_reset_ansi_color(op ColorOperation, data string) []ColorRequest {
	mut result := []ColorRequest{}

	if data.len == 0 {
		// If no parameters are given, we reset the full table.
		if op == .osc_104 {
			result << ColorRequestResetPalette{}
		} else {
			result << ColorRequestResetSpecial{}
		}
		return result
	}

	// Split on semicolons and parse each color index
	parts := data.split(';')
	for part in parts {
		trimmed := part.trim_space()
		if trimmed.len == 0 {
			continue
		}

		color_idx := trimmed.int()
		if color_idx == 0 && trimmed != '0' {
			// Invalid number, skip (matches Kitty behavior)
			continue
		}

		target := match op {
			.osc_105 {
				// OSC105 maps directly to the Special enum (0-4)
				if color_idx < 0 || color_idx > 4 {
					continue
				}
				ColorTarget(ColorTargetSpecial{
					color: unsafe { SpecialColor(color_idx) }
				})
			}
			.osc_104 {
				// OSC104 maps 0-255 to palette, 256-260 to special
				if color_idx >= 0 && color_idx <= 255 {
					ColorTarget(ColorTargetPalette{
						index: u8(color_idx)
					})
				} else if color_idx >= 256 && color_idx <= 260 {
					ColorTarget(ColorTargetSpecial{
						color: unsafe { SpecialColor(color_idx - 256) }
					})
				} else {
					continue
				}
			}
			else {
				continue
			}
		}

		result << ColorRequestReset{target: target}
	}

	// If nothing was parsed (all invalid), reset the full table
	if result.len == 0 {
		if op == .osc_104 {
			result << ColorRequestResetPalette{}
		} else {
			result << ColorRequestResetSpecial{}
		}
	}

	return result
}

// OSC 10-19: Get/Set Dynamic Colors
fn parse_get_set_dynamic_color(start DynamicColor, data string) []ColorRequest {
	// Note: in ANY error scenario below we return the accumulated results.
	// This matches the xterm behavior (see misc.c ChangeColorsRequest)
	mut result := []ColorRequest{}
	mut color := start
	mut remaining := data

	for remaining.len > 0 {
		sep := remaining.index_u8(`;`)
		mut spec_str := ''
		if sep >= 0 {
			spec_str = remaining[..sep]
			remaining = remaining[sep + 1..]
		} else {
			spec_str = remaining
			remaining = ''
		}

		target := ColorTarget(ColorTargetDynamic{color: color})

		if spec_str == '?' {
			result << ColorRequestQuery{target: target}
		} else {
			rgb := parse_rgb(spec_str) or { return result }
			result << ColorRequestSet{
				target: target
				color:  rgb
			}
		}

		// Each successive value uses the next color so long as it exists.
		color = color.next() or { return result }
	}
	return result
}

// OSC 110-119: Reset Dynamic Colors
fn parse_reset_dynamic_color(color DynamicColor, data string) []ColorRequest {
	mut result := []ColorRequest{}
	// xterm behavior: only semicolons are ignored (trailing semicolons ok).
	// Any other content (including whitespace) means the command is invalid.
	if data.len > 0 {
		// Check if there are any non-semicolon characters
		for c in data {
			if c != `;` {
				// xterm does NOT allow any whitespace or other chars
				return result
			}
		}
	}
	result << ColorRequestReset{
		target: ColorTargetDynamic{color: color}
	}
	return result
}

// str returns the string representation of a ColorOperation.
fn (op ColorOperation) str() string {
	return match op {
		.osc_4 { 'osc_4' }
		.osc_5 { 'osc_5' }
		.osc_10 { 'osc_10' }
		.osc_11 { 'osc_11' }
		.osc_12 { 'osc_12' }
		.osc_13 { 'osc_13' }
		.osc_14 { 'osc_14' }
		.osc_15 { 'osc_15' }
		.osc_16 { 'osc_16' }
		.osc_17 { 'osc_17' }
		.osc_18 { 'osc_18' }
		.osc_19 { 'osc_19' }
		.osc_104 { 'osc_104' }
		.osc_105 { 'osc_105' }
		.osc_110 { 'osc_110' }
		.osc_111 { 'osc_111' }
		.osc_112 { 'osc_112' }
		.osc_113 { 'osc_113' }
		.osc_114 { 'osc_114' }
		.osc_115 { 'osc_115' }
		.osc_116 { 'osc_116' }
		.osc_117 { 'osc_117' }
		.osc_118 { 'osc_118' }
		.osc_119 { 'osc_119' }
	}
}
