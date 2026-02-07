module terminal

// Tests for SGR (Select Graphic Rendition) parsing.

// Helper: parse SGR params with semicolon separators.
fn sgr_parse(params []u16) SgrAttribute {
	mut p := SgrParser{ params: params }
	return p.next() or { SgrAttribute{ tag: .unknown } }
}

// Helper: parse SGR params with colon separators (all params except last
// are marked as having a colon separator after them).
fn sgr_parse_colon(params []u16) SgrAttribute {
	mut sep := SepList.init_empty()
	for i in 0 .. params.len - 1 {
		sep.set(i)
	}
	mut p := SgrParser{ params: params, params_sep: sep }
	return p.next() or { SgrAttribute{ tag: .unknown } }
}

fn test_sgr_parser_basic() {
	assert sgr_parse([]).tag == .unset
	assert sgr_parse([u16(0)]).tag == .unset

	v1 := sgr_parse([u16(38), 2, 40, 44, 52])
	assert v1.tag == .direct_color_fg
	assert v1.rgb.r == 40
	assert v1.rgb.g == 44
	assert v1.rgb.b == 52

	assert sgr_parse([u16(38), 2, 44, 52]).tag == .unknown

	v2 := sgr_parse([u16(48), 2, 40, 44, 52])
	assert v2.tag == .direct_color_bg
	assert v2.rgb.r == 40
	assert v2.rgb.g == 44
	assert v2.rgb.b == 52

	assert sgr_parse([u16(48), 2, 44, 52]).tag == .unknown
}

fn test_sgr_parser_multiple() {
	mut p := SgrParser{ params: [u16(0), 38, 2, 40, 44, 52] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .unset
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .direct_color_fg
	assert p.next() == none
	assert p.next() == none
}

fn test_sgr_unsupported_with_colon() {
	mut p := SgrParser{
		params: [u16(0), 4, 1]
		params_sep: SepList{ bits: u64(1) << 0 } // colon after param 0
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .bold
	assert p.next() == none
}

fn test_sgr_unsupported_with_multiple_colon() {
	mut p := SgrParser{
		params: [u16(0), 4, 2, 1]
		params_sep: SepList{ bits: (u64(1) << 0) | (u64(1) << 1) } // colon after 0 and 1
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .bold
	assert p.next() == none
}

fn test_sgr_bold() {
	assert sgr_parse([u16(1)]).tag == .bold
	assert sgr_parse([u16(22)]).tag == .reset_bold
}

fn test_sgr_italic() {
	assert sgr_parse([u16(3)]).tag == .italic
	assert sgr_parse([u16(23)]).tag == .reset_italic
}

fn test_sgr_underline() {
	v1 := sgr_parse([u16(4)])
	assert v1.tag == .underline

	v2 := sgr_parse([u16(24)])
	assert v2.tag == .underline
	assert v2.underline_kind == .none
}

fn test_sgr_underline_styles() {
	v1 := sgr_parse_colon([u16(4), 2])
	assert v1.tag == .underline
	assert v1.underline_kind == .double

	v2 := sgr_parse_colon([u16(4), 0])
	assert v2.tag == .underline
	assert v2.underline_kind == .none

	v3 := sgr_parse_colon([u16(4), 1])
	assert v3.tag == .underline
	assert v3.underline_kind == .single

	v4 := sgr_parse_colon([u16(4), 3])
	assert v4.tag == .underline
	assert v4.underline_kind == .curly

	v5 := sgr_parse_colon([u16(4), 4])
	assert v5.tag == .underline
	assert v5.underline_kind == .dotted

	v6 := sgr_parse_colon([u16(4), 5])
	assert v6.tag == .underline
	assert v6.underline_kind == .dashed
}

fn test_sgr_underline_style_with_more() {
	mut p := SgrParser{
		params: [u16(4), 2, 1]
		params_sep: SepList{ bits: u64(1) << 0 } // colon after param 0
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .underline
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .bold
	assert p.next() == none
}

fn test_sgr_underline_style_with_too_many_colons() {
	mut p := SgrParser{
		params: [u16(4), 2, 3, 1]
		params_sep: SepList{ bits: (u64(1) << 0) | (u64(1) << 1) }
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .bold
	assert p.next() == none
}

fn test_sgr_blink() {
	assert sgr_parse([u16(5)]).tag == .blink
	assert sgr_parse([u16(6)]).tag == .blink
	assert sgr_parse([u16(25)]).tag == .reset_blink
}

fn test_sgr_inverse() {
	assert sgr_parse([u16(7)]).tag == .inverse
	assert sgr_parse([u16(27)]).tag == .reset_inverse
}

fn test_sgr_strikethrough() {
	assert sgr_parse([u16(9)]).tag == .strikethrough
	assert sgr_parse([u16(29)]).tag == .reset_strikethrough
}

fn test_sgr_8_color() {
	mut p := SgrParser{ params: [u16(31), 43, 90, 103] }

	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .color_8_fg
	assert v1.color_name == .red

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .color_8_bg
	assert v2.color_name == .yellow

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.tag == .color_8_bright_fg
	assert v3.color_name == .bright_black

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.tag == .color_8_bright_bg
	assert v4.color_name == .bright_yellow
}

fn test_sgr_256_color() {
	mut p := SgrParser{ params: [u16(38), 5, 161, 48, 5, 236] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .color_256_fg
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .color_256_bg
	assert p.next() == none
}

fn test_sgr_256_color_underline() {
	mut p := SgrParser{ params: [u16(58), 5, 9] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .color_256_underline
	assert p.next() == none
}

fn test_sgr_24bit_bg_color() {
	v := sgr_parse_colon([u16(48), 2, 1, 2, 3])
	assert v.tag == .direct_color_bg
	assert v.rgb.r == 1
	assert v.rgb.g == 2
	assert v.rgb.b == 3
}

fn test_sgr_underline_color() {
	v1 := sgr_parse_colon([u16(58), 2, 1, 2, 3])
	assert v1.tag == .underline_color
	assert v1.rgb.r == 1
	assert v1.rgb.g == 2
	assert v1.rgb.b == 3

	v2 := sgr_parse_colon([u16(58), 2, 0, 1, 2, 3])
	assert v2.tag == .underline_color
	assert v2.rgb.r == 1
	assert v2.rgb.g == 2
	assert v2.rgb.b == 3
}

fn test_sgr_reset_underline_color() {
	mut p := SgrParser{ params: [u16(59)] }
	v := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v.tag == .reset_underline_color
}

fn test_sgr_invisible() {
	mut p := SgrParser{ params: [u16(8), 28] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .invisible
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .reset_invisible
}

fn test_sgr_underline_bg_and_fg() {
	mut p := SgrParser{
		params: [u16(4), 38, 2, 255, 247, 219, 48, 2, 242, 93, 147, 4]
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .underline
	assert v1.underline_kind == .single

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .direct_color_fg
	assert v2.rgb.r == 255
	assert v2.rgb.g == 247
	assert v2.rgb.b == 219

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.tag == .direct_color_bg
	assert v3.rgb.r == 242
	assert v3.rgb.g == 93
	assert v3.rgb.b == 147

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.tag == .underline
	assert v4.underline_kind == .single
}

fn test_sgr_direct_color_fg_missing_color() {
	// This used to crash
	mut p := SgrParser{ params: [u16(38), 5] }
	for {
		p.next() or { break }
	}
}

fn test_sgr_direct_color_bg_missing_color() {
	// This used to crash
	mut p := SgrParser{ params: [u16(48), 5] }
	for {
		p.next() or { break }
	}
}

fn test_sgr_direct_fg_bg_underline_ignore_optional_color_space() {
	// These behaviors have been verified against xterm.

	// Colon version should skip the optional color space identifier
	// 3 8 : 2 : Pi : Pr : Pg : Pb
	v1 := sgr_parse_colon([u16(38), 2, 0, 1, 2, 3])
	assert v1.tag == .direct_color_fg
	assert v1.rgb.r == 1
	assert v1.rgb.g == 2
	assert v1.rgb.b == 3

	// 4 8 : 2 : Pi : Pr : Pg : Pb
	v2 := sgr_parse_colon([u16(48), 2, 0, 1, 2, 3])
	assert v2.tag == .direct_color_bg
	assert v2.rgb.r == 1
	assert v2.rgb.g == 2
	assert v2.rgb.b == 3

	// 5 8 : 2 : Pi : Pr : Pg : Pb
	v3 := sgr_parse_colon([u16(58), 2, 0, 1, 2, 3])
	assert v3.tag == .underline_color
	assert v3.rgb.r == 1
	assert v3.rgb.g == 2
	assert v3.rgb.b == 3

	// Semicolon version should not parse optional color space identifier
	// 3 8 ; 2 ; Pr ; Pg ; Pb
	v4 := sgr_parse([u16(38), 2, 0, 1, 2, 3])
	assert v4.tag == .direct_color_fg
	assert v4.rgb.r == 0
	assert v4.rgb.g == 1
	assert v4.rgb.b == 2

	// 4 8 ; 2 ; Pr ; Pg ; Pb
	v5 := sgr_parse([u16(48), 2, 0, 1, 2, 3])
	assert v5.tag == .direct_color_bg
	assert v5.rgb.r == 0
	assert v5.rgb.g == 1
	assert v5.rgb.b == 2

	// 5 8 ; 2 ; Pr ; Pg ; Pb
	v6 := sgr_parse([u16(58), 2, 0, 1, 2, 3])
	assert v6.tag == .underline_color
	assert v6.rgb.r == 0
	assert v6.rgb.g == 1
	assert v6.rgb.b == 2
}

fn test_sgr_direct_fg_colon_with_too_many_colons() {
	mut sep := SepList.init_empty()
	for idx in 0 .. 6 {
		sep.set(idx)
	}
	mut p := SgrParser{
		params: [u16(38), 2, 0, 1, 2, 3, 4, 1]
		params_sep: sep
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .bold
	assert p.next() == none
}

fn test_sgr_direct_fg_colon_with_colorspace_and_extra_param() {
	mut sep := SepList.init_empty()
	for idx in 0 .. 5 {
		sep.set(idx)
	}
	mut p := SgrParser{
		params: [u16(38), 2, 0, 1, 2, 3, 1]
		params_sep: sep
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .direct_color_fg
	assert v1.rgb.r == 1
	assert v1.rgb.g == 2
	assert v1.rgb.b == 3

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .bold
	assert p.next() == none
}

fn test_sgr_direct_fg_colon_no_colorspace_and_extra_param() {
	mut sep := SepList.init_empty()
	for idx in 0 .. 4 {
		sep.set(idx)
	}
	mut p := SgrParser{
		params: [u16(38), 2, 1, 2, 3, 1]
		params_sep: sep
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .direct_color_fg
	assert v1.rgb.r == 1
	assert v1.rgb.g == 2
	assert v1.rgb.b == 3

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .bold
	assert p.next() == none
}

// Kakoune sent this complex SGR sequence that caused invalid behavior.
fn test_sgr_kakoune_input() {
	// This used to crash
	mut sep := SepList.init_empty()
	sep.set(1)
	sep.set(8)
	sep.set(9)
	sep.set(10)
	sep.set(11)
	sep.set(12)
	mut p := SgrParser{
		params: [u16(0), 4, 3, 38, 2, 175, 175, 215, 58, 2, 0, 190, 80, 70]
		params_sep: sep
	}

	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .unset

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .underline
	assert v2.underline_kind == .curly

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.tag == .direct_color_fg
	assert v3.rgb.r == 175
	assert v3.rgb.g == 175
	assert v3.rgb.b == 215

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.tag == .underline_color
	assert v4.rgb.r == 190
	assert v4.rgb.g == 80
	assert v4.rgb.b == 70
}

// Discussion #5930, another input sent by kakoune
fn test_sgr_kakoune_input_issue_underline_fg_and_bg() {
	// echo -e "\033[4:3;38;2;51;51;51;48;2;170;170;170;58;2;255;97;136mset everything in one sequence, broken\033[m"

	// This used to crash
	mut sep := SepList.init_empty()
	sep.set(0)
	mut p := SgrParser{
		params: [u16(4), 3, 38, 2, 51, 51, 51, 48, 2, 170, 170, 170, 58, 2, 255, 97, 136]
		params_sep: sep
	}

	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.tag == .underline
	assert v1.underline_kind == .curly

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.tag == .direct_color_fg
	assert v2.rgb.r == 51
	assert v2.rgb.g == 51
	assert v2.rgb.b == 51

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.tag == .direct_color_bg
	assert v3.rgb.r == 170
	assert v3.rgb.g == 170
	assert v3.rgb.b == 170

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.tag == .underline_color
	assert v4.rgb.r == 255
	assert v4.rgb.g == 97
	assert v4.rgb.b == 136

	assert p.next() == none
}
