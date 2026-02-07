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
