module kitty

import osc

fn test_color_source_tag_layouts_and_shared_terminator() {
	assert sizeof(Special) == 1
	assert u8(Special.foreground) == 0
	assert u8(Special.background) == 1
	assert u8(Special.selection_foreground) == 2
	assert u8(Special.selection_background) == 3
	assert u8(Special.cursor) == 4
	assert u8(Special.cursor_text) == 5
	assert u8(Special.visual_bell) == 6
	assert u8(Special.second_transparent_background) == 7
	assert sizeof(Terminator) == 1
	assert Terminator.st == osc.Terminator.st
	assert Terminator.bel == osc.Terminator.bel
}

// Tests for Kitty color protocol types.
//
// Source: kitty/color.zig (tests)

fn test_kind_special_format() {
	k := Kind(KindSpecial{ special: .foreground })
	assert k.str() == 'foreground'
}

fn test_kind_palette_format() {
	k := Kind(KindPalette{ index: 42 })
	assert k.str() == '42'
}

fn test_kind_parse_special() {
	k := Kind.parse('foreground') or {
		assert false, 'expected parse to succeed'
		return
	}
	if k is KindSpecial {
		assert k.special == .foreground
	} else {
		assert false, 'expected KindSpecial'
	}
}

fn test_kind_parse_palette() {
	k := Kind.parse('42') or {
		assert false, 'expected parse to succeed'
		return
	}
	if k is KindPalette {
		assert k.index == 42
	} else {
		assert false, 'expected KindPalette'
	}
}

fn test_kind_parse_zero() {
	k := Kind.parse('0') or {
		assert false, 'expected parse to succeed'
		return
	}
	if k is KindPalette {
		assert k.index == 0
	} else {
		assert false, 'expected KindPalette'
	}
}

fn test_kind_parse_rejects_out_of_range_palette() {
	assert Kind.parse('256') == none
	assert Kind.parse('257') == none
	assert Kind.parse('-1') == none
	assert Kind.parse('+1') == none
	assert Kind.parse('_12') == none
	assert Kind.parse('12_') == none
}

fn test_kind_parse_matches_zig_digit_separator_rules() {
	for spelling in ['1_2', '1__2'] {
		kind := Kind.parse(spelling) or {
			assert false, 'expected ${spelling} to parse'
			return
		}
		if kind is KindPalette {
			assert kind.index == 12
		} else {
			assert false, 'expected KindPalette'
		}
	}
}

fn test_color_osc_void_c_projection() {
	ColorOSC{}.cval()
}
