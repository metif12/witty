module kitty

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
