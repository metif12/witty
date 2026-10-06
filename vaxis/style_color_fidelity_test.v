module vaxis

fn test_style_public_mutation_and_independent_field_replacement() {
	mut style := Style{}
	default_copy := style
	style.fg = ColorRgb{
		rgb: [u8(1), 2, 3]!
	}
	style.bg = ColorIndex{
		index: 42
	}
	style.ul = ColorRgb{
		rgb: [u8(4), 5, 6]!
	}
	style.ul_style = .dashed
	style.bold = true
	style.dim = true
	style.italic = true
	style.blink = true
	style.reverse = true
	style.invisible = true
	style.strikethrough = true
	assert default_copy.eql(Style{})
	assert !style.eql(default_copy)
	mut copy_ := style
	copy_.fg = ColorDefault{}
	copy_.bold = false
	assert style.fg.eql(ColorRgb{ rgb: [u8(1), 2, 3]! })
	assert style.bold
	assert !style.eql(copy_)
}

fn test_color_spec_validates_every_length_before_hex_digits() {
	for invalid in ['rgb:00ZZ/bad/cccc', 'rgb:00ff/00ZZ/bad', 'rgb:00ZZ/00ff/bad', 'rgb:00ZZ/00ff',
		'rgb:00ff/00ZZ'] {
		color_rgb_from_spec(invalid) or {
			assert err.msg() == 'InvalidColorSpec'
			continue
		}
		assert false
	}
	color_rgb_from_spec('rgb:00ZZ/00ff/00ff') or {
		assert err.msg() == 'InvalidCharacter'
		return
	}
	assert false
}

fn test_color_source_ignored_prefix_bytes_and_trailing_components() {
	assert color_rgb_from_spec('rgb:zz12/?*34/\x00\xff56/ignored:tail')!.eql(color_rgb_from_uint(0x123456))
	assert color_rgb_from_uint(0).eql(ColorRgb{ rgb: [u8(0), 0, 0]! })
	assert color_rgb_from_uint(0xffffff).eql(ColorRgb{ rgb: [u8(255), 255, 255]! })
	assert !Color(ColorDefault{}).eql(ColorIndex{ index: 0 })
	assert !Color(ColorIndex{
		index: 0
	}).eql(ColorRgb{ rgb: [u8(0), 0, 0]! })
}

fn test_color_array_constructor_copies_input_bytes() {
	mut bytes := [u8(1), 2, 3]!
	color := Color(ColorRgb{
		rgb: bytes
	})
	bytes[0] = 9
	assert color.eql(ColorRgb{ rgb: [u8(1), 2, 3]! })
}

fn test_style_equality_compares_each_public_field_independently() {
	style := Style{
		fg:            ColorRgb{
			rgb: [u8(1), 2, 3]!
		}
		bg:            ColorIndex{
			index: 42
		}
		ul:            ColorRgb{
			rgb: [u8(4), 5, 6]!
		}
		ul_style:      .curly
		bold:          true
		dim:           true
		italic:        true
		blink:         true
		reverse:       true
		invisible:     true
		strikethrough: true
	}
	copied := style
	assert style.eql(copied)
	for field in 0 .. 11 {
		mut changed := style
		match field {
			0 { changed.fg = ColorDefault{} }
			1 { changed.bg = ColorDefault{} }
			2 { changed.ul = ColorDefault{} }
			3 { changed.ul_style = .dotted }
			4 { changed.bold = false }
			5 { changed.dim = false }
			6 { changed.italic = false }
			7 { changed.blink = false }
			8 { changed.reverse = false }
			9 { changed.invisible = false }
			10 { changed.strikethrough = false }
			else { panic('test field') }
		}

		assert !style.eql(changed)
		assert !changed.eql(style)
	}
}
