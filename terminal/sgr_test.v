module terminal

// Tests for SGR (Select Graphic Rendition) parsing.

// Helper: parse SGR params with semicolon separators.
fn sgr_parse(params []u16) SgrAttribute {
	mut p := SgrParser{ params: params }
	return p.next() or { SgrAttribute{ kind: .unknown } }
}

// Helper: parse SGR params with colon separators (all params except last
// are marked as having a colon separator after them).
fn sgr_parse_colon(params []u16) SgrAttribute {
	mut sep := SepList.init_empty()
	for i in 0 .. params.len - 1 {
		sep.set(i)
	}
	mut p := SgrParser{ params: params, params_sep: sep }
	return p.next() or { SgrAttribute{ kind: .unknown } }
}

fn test_sgr_parser_basic() {
	assert sgr_parse([]).kind == .unset
	assert sgr_parse([u16(0)]).kind == .unset

	v1 := sgr_parse([u16(38), 2, 40, 44, 52])
	assert v1.kind == .direct_color_fg
	assert v1.r == 40
	assert v1.g == 44
	assert v1.b == 52

	assert sgr_parse([u16(38), 2, 44, 52]).kind == .unknown

	v2 := sgr_parse([u16(48), 2, 40, 44, 52])
	assert v2.kind == .direct_color_bg
	assert v2.r == 40
	assert v2.g == 44
	assert v2.b == 52

	assert sgr_parse([u16(48), 2, 44, 52]).kind == .unknown
}

fn test_sgr_parser_multiple() {
	mut p := SgrParser{ params: [u16(0), 38, 2, 40, 44, 52] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.kind == .unset
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .direct_color_fg
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
	assert v1.kind == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bold
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
	assert v1.kind == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bold
	assert p.next() == none
}

fn test_sgr_bold() {
	assert sgr_parse([u16(1)]).kind == .bold
	assert sgr_parse([u16(22)]).kind == .reset_bold
}

fn test_sgr_italic() {
	assert sgr_parse([u16(3)]).kind == .italic
	assert sgr_parse([u16(23)]).kind == .reset_italic
}

fn test_sgr_underline() {
	v1 := sgr_parse([u16(4)])
	assert v1.kind == .underline_set

	v2 := sgr_parse([u16(24)])
	assert v2.kind == .underline_set
	assert v2.underline == .none
}

fn test_sgr_underline_styles() {
	v1 := sgr_parse_colon([u16(4), 2])
	assert v1.kind == .underline_set
	assert v1.underline == .double

	v2 := sgr_parse_colon([u16(4), 0])
	assert v2.kind == .underline_set
	assert v2.underline == .none

	v3 := sgr_parse_colon([u16(4), 1])
	assert v3.kind == .underline_set
	assert v3.underline == .single

	v4 := sgr_parse_colon([u16(4), 3])
	assert v4.kind == .underline_set
	assert v4.underline == .curly

	v5 := sgr_parse_colon([u16(4), 4])
	assert v5.kind == .underline_set
	assert v5.underline == .dotted

	v6 := sgr_parse_colon([u16(4), 5])
	assert v6.kind == .underline_set
	assert v6.underline == .dashed
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
	assert v1.kind == .underline_set
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bold
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
	assert v1.kind == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bold
	assert p.next() == none
}

fn test_sgr_blink() {
	assert sgr_parse([u16(5)]).kind == .blink
	assert sgr_parse([u16(6)]).kind == .blink
	assert sgr_parse([u16(25)]).kind == .reset_blink
}

fn test_sgr_inverse() {
	assert sgr_parse([u16(7)]).kind == .inverse
	assert sgr_parse([u16(27)]).kind == .reset_inverse
}

fn test_sgr_strikethrough() {
	assert sgr_parse([u16(9)]).kind == .strikethrough
	assert sgr_parse([u16(29)]).kind == .reset_strikethrough
}

fn test_sgr_8_color() {
	mut p := SgrParser{ params: [u16(31), 43, 90, 103] }

	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.kind == .fg_8
	assert v1.index == 1 // red

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bg_8
	assert v2.index == 3 // yellow

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.kind == .bright_fg_8
	assert v3.index == 0 // bright_black (90-90)

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.kind == .bright_bg_8
	assert v4.index == 3 // bright_yellow (103-100)
}

fn test_sgr_256_color() {
	mut p := SgrParser{ params: [u16(38), 5, 161, 48, 5, 236] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.kind == .fg_256
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bg_256
	assert p.next() == none
}

fn test_sgr_256_color_underline() {
	mut p := SgrParser{ params: [u16(58), 5, 9] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.kind == .underline_color_256
	assert p.next() == none
}

fn test_sgr_24bit_bg_color() {
	v := sgr_parse_colon([u16(48), 2, 1, 2, 3])
	assert v.kind == .direct_color_bg
	assert v.r == 1
	assert v.g == 2
	assert v.b == 3
}

fn test_sgr_underline_color() {
	v1 := sgr_parse_colon([u16(58), 2, 1, 2, 3])
	assert v1.kind == .underline_color
	assert v1.r == 1
	assert v1.g == 2
	assert v1.b == 3

	v2 := sgr_parse_colon([u16(58), 2, 0, 1, 2, 3])
	assert v2.kind == .underline_color
	assert v2.r == 1
	assert v2.g == 2
	assert v2.b == 3
}

fn test_sgr_reset_underline_color() {
	mut p := SgrParser{ params: [u16(59)] }
	v := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v.kind == .reset_underline_color
}

fn test_sgr_invisible() {
	mut p := SgrParser{ params: [u16(8), 28] }
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.kind == .invisible
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .reset_invisible
}

fn test_sgr_underline_bg_and_fg() {
	mut p := SgrParser{
		params: [u16(4), 38, 2, 255, 247, 219, 48, 2, 242, 93, 147, 4]
	}
	v1 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v1.kind == .underline_set
	assert v1.underline == .single

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .direct_color_fg
	assert v2.r == 255
	assert v2.g == 247
	assert v2.b == 219

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.kind == .direct_color_bg
	assert v3.r == 242
	assert v3.g == 93
	assert v3.b == 147

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.kind == .underline_set
	assert v4.underline == .single
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
	assert v1.kind == .direct_color_fg
	assert v1.r == 1
	assert v1.g == 2
	assert v1.b == 3

	// 4 8 : 2 : Pi : Pr : Pg : Pb
	v2 := sgr_parse_colon([u16(48), 2, 0, 1, 2, 3])
	assert v2.kind == .direct_color_bg
	assert v2.r == 1
	assert v2.g == 2
	assert v2.b == 3

	// 5 8 : 2 : Pi : Pr : Pg : Pb
	v3 := sgr_parse_colon([u16(58), 2, 0, 1, 2, 3])
	assert v3.kind == .underline_color
	assert v3.r == 1
	assert v3.g == 2
	assert v3.b == 3

	// Semicolon version should not parse optional color space identifier
	// 3 8 ; 2 ; Pr ; Pg ; Pb
	v4 := sgr_parse([u16(38), 2, 0, 1, 2, 3])
	assert v4.kind == .direct_color_fg
	assert v4.r == 0
	assert v4.g == 1
	assert v4.b == 2

	// 4 8 ; 2 ; Pr ; Pg ; Pb
	v5 := sgr_parse([u16(48), 2, 0, 1, 2, 3])
	assert v5.kind == .direct_color_bg
	assert v5.r == 0
	assert v5.g == 1
	assert v5.b == 2

	// 5 8 ; 2 ; Pr ; Pg ; Pb
	v6 := sgr_parse([u16(58), 2, 0, 1, 2, 3])
	assert v6.kind == .underline_color
	assert v6.r == 0
	assert v6.g == 1
	assert v6.b == 2
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
	assert v1.kind == .unknown
	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bold
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
	assert v1.kind == .direct_color_fg
	assert v1.r == 1
	assert v1.g == 2
	assert v1.b == 3

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bold
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
	assert v1.kind == .direct_color_fg
	assert v1.r == 1
	assert v1.g == 2
	assert v1.b == 3

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .bold
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
	assert v1.kind == .unset

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .underline_set
	assert v2.underline == .curly

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.kind == .direct_color_fg
	assert v3.r == 175
	assert v3.g == 175
	assert v3.b == 215

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.kind == .underline_color
	assert v4.r == 190
	assert v4.g == 80
	assert v4.b == 70
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
	assert v1.kind == .underline_set
	assert v1.underline == .curly

	v2 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v2.kind == .direct_color_fg
	assert v2.r == 51
	assert v2.g == 51
	assert v2.b == 51

	v3 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v3.kind == .direct_color_bg
	assert v3.r == 170
	assert v3.g == 170
	assert v3.b == 170

	v4 := p.next() or {
		assert false, 'expected value'
		return
	}
	assert v4.kind == .underline_color
	assert v4.r == 255
	assert v4.g == 97
	assert v4.b == 136

	assert p.next() == none
}
