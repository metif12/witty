module osc

fn test_rgb_parse_named_red() {
	rgb := parse_rgb('red') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 255
	assert rgb.g == 0
	assert rgb.b == 0
}

fn test_rgb_parse_named_blue() {
	rgb := parse_rgb('blue') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0
	assert rgb.g == 0
	assert rgb.b == 255
}

fn test_rgb_parse_complete_x11_named_colors() {
	assert parse_rgb('medium spring green')? == RGB{
		r: 0
		g: 250
		b: 154
	}
	assert parse_rgb('FoReStGReEn')? == RGB{
		r: 34
		g: 139
		b: 34
	}
	assert parse_rgb('lawngreen')? == RGB{
		r: 124
		g: 252
		b: 0
	}
}

fn test_rgb_parse_hash_6() {
	rgb := parse_rgb('#aabbcc') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xaa
	assert rgb.g == 0xbb
	assert rgb.b == 0xcc
}

fn test_rgb_parse_hash_3() {
	rgb := parse_rgb('#abc') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xaa
	assert rgb.g == 0xbb
	assert rgb.b == 0xcc
}

fn test_rgb_parse_rgb_colon() {
	rgb := parse_rgb('rgb:f0/f8/ff') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xf0
	assert rgb.g == 0xf8
	assert rgb.b == 0xff
}

fn test_rgb_parse_rgb_colon_matches_zig_unsigned_grammar() {
	assert parse_rgb('rgb:f__f/0/0')? == RGB{
		r: 0
	}
	assert parse_rgb('rgb:_ff/0/0') == none
	assert parse_rgb('rgb:ff_/0/0') == none
}

fn test_rgb_parse_rgbi() {
	rgb := parse_rgb('rgbi:1.0/1.0/1.0') or {
		assert false, 'expected rgb'
		return
	}
	assert rgb.r == 0xff
	assert rgb.g == 0xff
	assert rgb.b == 0xff
	assert parse_rgb('rgbi:0x1p0/0_0.0/0')? == RGB{
		r: 255
	}
}

fn test_rgb_parse_invalid() {
	assert parse_rgb('#xxxyyzz') == none
	assert parse_rgb('') == none
	assert parse_rgb('notacolor') == none
	assert parse_rgb('rgbi:a/a/a') == none
	assert parse_rgb('rgbi: 1/0/0') == none
}

// Translated from ghostty color.zig test "RGB.parse". Verifies the 8-bit
// channel scaling (color * 255 / max) for hex specs of 1-4 digits, the
// intensity (rgbi) truncation, and named-color values.
fn test_rgb_parse_ghostty() {
	// rgbi intensity truncates: 1.0 -> 255, others -> 0.
	assert parse_rgb('rgbi:1.0/0/0')? == RGB{
		r: 255
		g: 0
		b: 0
	}
	// Mixed digit widths: 7f (2-digit) = 127, a0a0 (4-digit) scaled = 160.
	assert parse_rgb('rgb:7f/a0a0/0')? == RGB{
		r: 127
		g: 160
		b: 0
	}
	// 1/2/3-digit hex all max out to 255.
	assert parse_rgb('rgb:f/ff/fff')? == RGB{
		r: 255
		g: 255
		b: 255
	}
	assert parse_rgb('#ffffff')? == RGB{
		r: 255
		g: 255
		b: 255
	}
	assert parse_rgb('#fff')? == RGB{
		r: 255
		g: 255
		b: 255
	}
	// #rrrgggbbb (3-digit channels).
	assert parse_rgb('#fffffffff')? == RGB{
		r: 255
		g: 255
		b: 255
	}
	// #rrrrggggbbbb (4-digit channels).
	assert parse_rgb('#ffffffffffff')? == RGB{
		r: 255
		g: 255
		b: 255
	}
	assert parse_rgb('#ff0010')? == RGB{
		r: 255
		g: 0
		b: 16
	}

	// Named colors.
	assert parse_rgb('black')? == RGB{
		r: 0
		g: 0
		b: 0
	}
	assert parse_rgb('red')? == RGB{
		r: 255
		g: 0
		b: 0
	}
	// X11 green is (0, 255, 0), not (0, 128, 0).
	assert parse_rgb('green')? == RGB{
		r: 0
		g: 255
		b: 0
	}
	assert parse_rgb('blue')? == RGB{
		r: 0
		g: 0
		b: 255
	}
	assert parse_rgb('white')? == RGB{
		r: 255
		g: 255
		b: 255
	}

	// Invalid formats.
	assert parse_rgb('#') == none
	assert parse_rgb('#ff') == none
	assert parse_rgb('#ffff') == none
	assert parse_rgb('#fffff') == none
	assert parse_rgb('#gggggg') == none
}

fn test_osc4_set_palette_color() {
	result := parse_get_set_ansi_color(.osc_4, '0;red')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestSet {
		if req.target is ColorTargetPalette {
			assert req.target.index == 0
		} else {
			assert false, 'expected palette target'
		}
		assert req.color.r == 255
		assert req.color.g == 0
		assert req.color.b == 0
	} else {
		assert false, 'expected set request'
	}
}

fn test_osc4_query_palette_color() {
	result := parse_get_set_ansi_color(.osc_4, '0;?')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestQuery {
		if req.target is ColorTargetPalette {
			assert req.target.index == 0
		} else {
			assert false, 'expected palette target'
		}
	} else {
		assert false, 'expected query request'
	}
}

fn test_osc4_multiple_requests() {
	result := parse_get_set_ansi_color(.osc_4, '0;red;1;blue')
	assert result.len == 2

	req0 := result[0]
	if req0 is ColorRequestSet {
		if req0.target is ColorTargetPalette {
			assert req0.target.index == 0
		}
		assert req0.color.r == 255
		assert req0.color.g == 0
		assert req0.color.b == 0
	}

	req1 := result[1]
	if req1 is ColorRequestSet {
		if req1.target is ColorTargetPalette {
			assert req1.target.index == 1
		}
		assert req1.color.r == 0
		assert req1.color.g == 0
		assert req1.color.b == 255
	}
}

fn test_osc104_reset_palette() {
	result := parse_reset_ansi_color(.osc_104, '')
	assert result.len == 1
	req := result[0]
	assert req is ColorRequestResetPalette
}

fn test_osc104_reset_specific() {
	result := parse_reset_ansi_color(.osc_104, '0')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestReset {
		if req.target is ColorTargetPalette {
			assert req.target.index == 0
		} else {
			assert false, 'expected palette target'
		}
	} else {
		assert false, 'expected reset request'
	}
}

fn test_osc104_reset_multiple() {
	result := parse_reset_ansi_color(.osc_104, '0;;1')
	assert result.len == 2
}

fn test_osc104_reset_invalid_index() {
	result := parse_reset_ansi_color(.osc_104, 'ffff;1')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestReset {
		if req.target is ColorTargetPalette {
			assert req.target.index == 1
		}
	}
}

fn test_osc105_reset_all() {
	result := parse_reset_ansi_color(.osc_105, '')
	assert result.len == 1
	req := result[0]
	assert req is ColorRequestResetSpecial
}

fn test_osc10_set_dynamic_color() {
	result := parse_get_set_dynamic_color(.foreground, 'red')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestSet {
		if req.target is ColorTargetDynamic {
			assert req.target.color == .foreground
		} else {
			assert false, 'expected dynamic target'
		}
		assert req.color.r == 255
		assert req.color.g == 0
		assert req.color.b == 0
	} else {
		assert false, 'expected set request'
	}
}

fn test_osc11_set_dynamic_multiple() {
	result := parse_get_set_dynamic_color(.background, 'red;blue')
	assert result.len == 2
	req0 := result[0]
	if req0 is ColorRequestSet {
		if req0.target is ColorTargetDynamic {
			assert req0.target.color == .background
		}
		assert req0.color.r == 255
	}
	req1 := result[1]
	if req1 is ColorRequestSet {
		if req1.target is ColorTargetDynamic {
			assert req1.target.color == .cursor
		}
		assert req1.color.b == 255
	}
}

fn test_osc110_reset_dynamic() {
	result := parse_reset_dynamic_color(.foreground, '')
	assert result.len == 1
	req := result[0]
	if req is ColorRequestReset {
		if req.target is ColorTargetDynamic {
			assert req.target.color == .foreground
		}
	}
}

fn test_osc110_reset_trailing_semicolon() {
	result := parse_reset_dynamic_color(.foreground, ';')
	assert result.len == 1
}

fn test_osc110_reset_whitespace() {
	result := parse_reset_dynamic_color(.foreground, ' ')
	assert result.len == 0
}

fn test_osc4_empty_param() {
	// Empty param should return no results
	mut p := Parser.init(unsafe { nil })
	input := '4;;'
	for ch in input.bytes() {
		p.next(ch)
	}
	// This should either return none or an empty color operation
	_ = p.end(0x1b)
}

// Translated from ghostty test "OSC 4:" - exhaustive palette + special coverage.
fn test_osc4_full() {
	// Test every palette index (0..254 to match ghostty's maxInt(u8) exclusive)
	for idx := 0; idx < 255; idx++ {
		// Simple color set: "{idx};red"
		{
			list := parse_get_set_ansi_color(.osc_4, '${idx};red')
			assert list.len == 1
			req := list[0]
			assert req is ColorRequestSet
			if req is ColorRequestSet {
				assert req.target is ColorTargetPalette
				if req.target is ColorTargetPalette {
					assert req.target.index == u8(idx)
				}
				assert req.color.r == 255
				assert req.color.g == 0
				assert req.color.b == 0
			}
		}

		// Simple color query: "{idx};?"
		{
			list := parse_get_set_ansi_color(.osc_4, '${idx};?')
			assert list.len == 1
			req := list[0]
			assert req is ColorRequestQuery
			if req is ColorRequestQuery {
				assert req.target is ColorTargetPalette
				if req.target is ColorTargetPalette {
					assert req.target.index == u8(idx)
				}
			}
		}

		// Trailing invalid data produces results up to that point: "{idx};red;"
		{
			list := parse_get_set_ansi_color(.osc_4, '${idx};red;')
			assert list.len == 1
			req := list[0]
			assert req is ColorRequestSet
			if req is ColorRequestSet {
				assert req.target is ColorTargetPalette
				if req.target is ColorTargetPalette {
					assert req.target.index == u8(idx)
				}
				assert req.color.r == 255
				assert req.color.g == 0
				assert req.color.b == 0
			}
		}

		// Whitespace still parses (Kitty compat): "{idx};red "
		{
			list := parse_get_set_ansi_color(.osc_4, '${idx};red ')
			assert list.len == 1
			req := list[0]
			assert req is ColorRequestSet
			if req is ColorRequestSet {
				assert req.target is ColorTargetPalette
				if req.target is ColorTargetPalette {
					assert req.target.index == u8(idx)
				}
				assert req.color.r == 255
			}
		}
	}

	// Test every special color: "{256+i};red"
	specials := [SpecialColor.bold, .underline, .blink, .reverse, .italic]
	for i, special in specials {
		list := parse_get_set_ansi_color(.osc_4, '${256 + i};red')
		assert list.len == 1
		req := list[0]
		assert req is ColorRequestSet
		if req is ColorRequestSet {
			assert req.target is ColorTargetSpecial
			if req.target is ColorTargetSpecial {
				assert req.target.color == special
			}
			assert req.color.r == 255
			assert req.color.g == 0
			assert req.color.b == 0
		}
	}
}

// Translated from ghostty test "OSC 5:" - special colors mapped directly.
fn test_osc5_full() {
	specials := [SpecialColor.bold, .underline, .blink, .reverse, .italic]
	for i, special in specials {
		list := parse_get_set_ansi_color(.osc_5, '${i};red')
		assert list.len == 1
		req := list[0]
		assert req is ColorRequestSet
		if req is ColorRequestSet {
			assert req.target is ColorTargetSpecial
			if req.target is ColorTargetSpecial {
				assert req.target.color == special
			}
			assert req.color.r == 255
			assert req.color.g == 0
			assert req.color.b == 0
		}
	}
}

// Translated from ghostty test "OSC 4: multiple requests".
fn test_osc4_multiple_requests_full() {
	// Two distinct indices: "0;red;1;blue"
	{
		list := parse_get_set_ansi_color(.osc_4, '0;red;1;blue')
		assert list.len == 2
		req0 := list[0]
		assert req0 is ColorRequestSet
		if req0 is ColorRequestSet {
			assert req0.target is ColorTargetPalette
			if req0.target is ColorTargetPalette {
				assert req0.target.index == 0
			}
			assert req0.color.r == 255
			assert req0.color.g == 0
			assert req0.color.b == 0
		}
		req1 := list[1]
		assert req1 is ColorRequestSet
		if req1 is ColorRequestSet {
			assert req1.target is ColorTargetPalette
			if req1.target is ColorTargetPalette {
				assert req1.target.index == 1
			}
			assert req1.color.r == 0
			assert req1.color.g == 0
			assert req1.color.b == 255
		}
	}

	// Same index twice, both preserved: "0;red;0;blue"
	{
		list := parse_get_set_ansi_color(.osc_4, '0;red;0;blue')
		assert list.len == 2
		req0 := list[0]
		if req0 is ColorRequestSet {
			if req0.target is ColorTargetPalette {
				assert req0.target.index == 0
			}
			assert req0.color.r == 255
			assert req0.color.b == 0
		}
		req1 := list[1]
		if req1 is ColorRequestSet {
			if req1.target is ColorTargetPalette {
				assert req1.target.index == 0
			}
			assert req1.color.r == 0
			assert req1.color.b == 255
		}
	}
}

// Translated from ghostty test "OSC 104:" - exhaustive palette + special reset.
fn test_osc104_full() {
	for idx := 0; idx < 255; idx++ {
		list := parse_reset_ansi_color(.osc_104, '${idx}')
		assert list.len == 1
		req := list[0]
		assert req is ColorRequestReset
		if req is ColorRequestReset {
			assert req.target is ColorTargetPalette
			if req.target is ColorTargetPalette {
				assert req.target.index == u8(idx)
			}
		}
	}

	specials := [SpecialColor.bold, .underline, .blink, .reverse, .italic]
	for i, special in specials {
		list := parse_reset_ansi_color(.osc_104, '${256 + i}')
		assert list.len == 1
		req := list[0]
		assert req is ColorRequestReset
		if req is ColorRequestReset {
			assert req.target is ColorTargetSpecial
			if req.target is ColorTargetSpecial {
				assert req.target.color == special
			}
		}
	}
}

// Translated from ghostty test "OSC 10..19: dynamic".
fn test_osc_dynamic_full() {
	dynamics := [DynamicColor.foreground, .background, .cursor, .pointer_foreground,
		.pointer_background, .tektronix_foreground, .tektronix_background, .highlight_background,
		.tektronix_cursor, .highlight_foreground]
	for color in dynamics {
		list := parse_get_set_dynamic_color(color, 'red')
		assert list.len == 1
		req := list[0]
		assert req is ColorRequestSet
		if req is ColorRequestSet {
			assert req.target is ColorTargetDynamic
			if req.target is ColorTargetDynamic {
				assert req.target.color == color
			}
			assert req.color.r == 255
			assert req.color.g == 0
			assert req.color.b == 0
		}
	}
}

// Translated from ghostty test "OSC 110..119: reset dynamic".
fn test_osc_reset_dynamic_full() {
	dynamics := [DynamicColor.foreground, .background, .cursor, .pointer_foreground,
		.pointer_background, .tektronix_foreground, .tektronix_background, .highlight_background,
		.tektronix_cursor, .highlight_foreground]
	for color in dynamics {
		// Bare reset: ""
		{
			list := parse_reset_dynamic_color(color, '')
			assert list.len == 1
			req := list[0]
			assert req is ColorRequestReset
			if req is ColorRequestReset {
				assert req.target is ColorTargetDynamic
				if req.target is ColorTargetDynamic {
					assert req.target.color == color
				}
			}
		}

		// Trailing semicolon allowed: ";"
		{
			list := parse_reset_dynamic_color(color, ';')
			assert list.len == 1
			req := list[0]
			assert req is ColorRequestReset
			if req is ColorRequestReset {
				assert req.target is ColorTargetDynamic
				if req.target is ColorTargetDynamic {
					assert req.target.color == color
				}
			}
		}

		// Whitespace is not allowed: " "
		{
			list := parse_reset_dynamic_color(color, ' ')
			assert list.len == 0
		}
	}
}

fn test_ansi_color_indices_match_zig_u9_parsing() {
	for input in ['+1;red', '-0;red', '1__0;red'] {
		list := parse_get_set_ansi_color(.osc_4, input)
		assert list.len == 1
		assert list[0] is ColorRequestSet
	}
	assert parse_get_set_ansi_color(.osc_4, '1junk;red').len == 0
	assert parse_get_set_ansi_color(.osc_4, '512;red').len == 0
	assert parse_get_set_ansi_color(.osc_4, '_1;red').len == 0
	assert parse_get_set_ansi_color(.osc_4, '1_;red').len == 0
}

fn test_color_parser_skips_empty_tokens_like_zig() {
	ansi := parse_get_set_ansi_color(.osc_4, ';;1;;red;;')
	assert ansi.len == 1
	req := ansi[0]
	assert req is ColorRequestSet
	if req is ColorRequestSet {
		assert req.target is ColorTargetPalette
		if req.target is ColorTargetPalette {
			assert req.target.index == 1
		}
	}

	dynamic := parse_get_set_dynamic_color(.foreground, ';red;;blue;')
	assert dynamic.len == 2
	assert dynamic[0] is ColorRequestSet
	assert dynamic[1] is ColorRequestSet
}

fn test_reset_color_does_not_trim_whitespace() {
	list := parse_reset_ansi_color(.osc_104, ' 1 ')
	assert list.len == 1
	assert list[0] is ColorRequestResetPalette
}

fn test_osc105_is_not_a_live_parser_state() {
	mut p := Parser.init(unsafe { nil })
	for ch in '105;'.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}
