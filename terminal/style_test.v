module terminal

fn test_style_equality_ignores_inactive_color_storage() {
	base := CellStyle{}
	stale := CellStyle{
		fg_r: 1
		fg_g: 2
		fg_b: 3
		fg_palette: 4
		bg_r: 5
		bg_g: 6
		bg_b: 7
		bg_palette: 8
		underline_r: 9
		underline_g: 10
		underline_b: 11
		underline_palette: 12
	}
	assert base.eql(&stale)
	assert base.hash() == stale.hash()
}

fn test_style_equality_uses_only_active_color_payload() {
	palette_a := CellStyle{ fg_color: .palette, fg_palette: 3, fg_r: 10 }
	palette_b := CellStyle{ fg_color: .palette, fg_palette: 3, fg_r: 20 }
	palette_c := CellStyle{ fg_color: .palette, fg_palette: 4, fg_r: 10 }
	assert palette_a.eql(&palette_b)
	assert palette_a.hash() == palette_b.hash()
	assert !palette_a.eql(&palette_c)

	rgb_a := CellStyle{
		underline_color: .rgb
		underline_r: 1
		underline_g: 2
		underline_b: 3
		underline_palette: 4
	}
	rgb_b := CellStyle{
		underline_color: .rgb
		underline_r: 1
		underline_g: 2
		underline_b: 3
		underline_palette: 9
	}
	rgb_c := CellStyle{
		underline_color: .rgb
		underline_r: 1
		underline_g: 2
		underline_b: 4
		underline_palette: 4
	}
	assert rgb_a.eql(&rgb_b)
	assert rgb_a.hash() == rgb_b.hash()
	assert !rgb_a.eql(&rgb_c)
}

fn test_style_hash_matches_zig_source() {
	assert CellStyle{}.hash() == 0
	assert CellStyle{
		flags: StyleFlags{ bold: true }
	}.hash() == 0xd0fc3c4cfdcbcf4e
	assert CellStyle{
		fg_color: .palette
		fg_palette: 7
		bg_color: .rgb
		bg_r: 1
		bg_g: 2
		bg_b: 3
		underline_color: .palette
		underline_palette: 9
		flags: StyleFlags{
			bold: true
			italic: true
			underline: .curly
		}
	}.hash() == 0x50c324342b82c60f
}

// Tests for Style VT and HTML formatting.
// Source: style.zig tests

fn test_style_vt_formatting_empty() {
	style := CellStyle{}
	result := style.format_vt()
	assert result == '\x1b[0m'
}

fn test_style_vt_formatting_bold() {
	style := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m'
}

fn test_style_vt_formatting_faint() {
	style := CellStyle{
		flags: StyleFlags{
			faint: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[2m'
}

fn test_style_vt_formatting_italic() {
	style := CellStyle{
		flags: StyleFlags{
			italic: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[3m'
}

fn test_style_vt_formatting_blink() {
	style := CellStyle{
		flags: StyleFlags{
			blink: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[5m'
}

fn test_style_vt_formatting_inverse() {
	style := CellStyle{
		flags: StyleFlags{
			inverse: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[7m'
}

fn test_style_vt_formatting_invisible() {
	style := CellStyle{
		flags: StyleFlags{
			invisible: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[8m'
}

fn test_style_vt_formatting_strikethrough() {
	style := CellStyle{
		flags: StyleFlags{
			strikethrough: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[9m'
}

fn test_style_vt_formatting_overline() {
	style := CellStyle{
		flags: StyleFlags{
			overline: true
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[53m'
}

fn test_style_vt_formatting_underline_single() {
	style := CellStyle{
		flags: StyleFlags{
			underline: .single
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4m'
}

fn test_style_vt_formatting_underline_double() {
	style := CellStyle{
		flags: StyleFlags{
			underline: .double
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4:2m'
}

fn test_style_vt_formatting_underline_curly() {
	style := CellStyle{
		flags: StyleFlags{
			underline: .curly
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4:3m'
}

fn test_style_vt_formatting_underline_dotted() {
	style := CellStyle{
		flags: StyleFlags{
			underline: .dotted
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4:4m'
}

fn test_style_vt_formatting_underline_dashed() {
	style := CellStyle{
		flags: StyleFlags{
			underline: .dashed
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4:5m'
}

fn test_style_vt_formatting_fg_palette() {
	style := CellStyle{
		fg_color: .palette
		fg_palette: 42
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[38;5;42m'
}

fn test_style_vt_formatting_fg_rgb() {
	style := CellStyle{
		fg_color: .rgb
		fg_r: 255
		fg_g: 128
		fg_b: 64
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[38;2;255;128;64m'
}

fn test_style_vt_formatting_bg_palette() {
	style := CellStyle{
		bg_color: .palette
		bg_palette: 7
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[48;5;7m'
}

fn test_style_vt_formatting_bg_rgb() {
	style := CellStyle{
		bg_color: .rgb
		bg_r: 32
		bg_g: 64
		bg_b: 96
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[48;2;32;64;96m'
}

fn test_style_vt_formatting_multiple_flags() {
	style := CellStyle{
		flags: StyleFlags{
			bold: true
			italic: true
			underline: .single
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m\x1b[3m\x1b[4m'
}

fn test_style_vt_formatting_all_flags() {
	style := CellStyle{
		flags: StyleFlags{
			bold: true
			faint: true
			italic: true
			blink: true
			inverse: true
			invisible: true
			strikethrough: true
			overline: true
			underline: .curly
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m\x1b[2m\x1b[3m\x1b[4:3m\x1b[5m\x1b[7m\x1b[8m\x1b[9m\x1b[53m'
}

fn test_style_vt_formatting_combined_colors_and_flags() {
	style := CellStyle{
		fg_color: .rgb
		fg_r: 255
		fg_g: 0
		fg_b: 0
		bg_color: .palette
		bg_palette: 8
		flags: StyleFlags{
			bold: true
			italic: true
			underline: .double
		}
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m\x1b[3m\x1b[4:2m\x1b[38;2;255;0;0m\x1b[48;5;8m'
}

fn test_style_vt_formatting_all_colors_rgb() {
	style := CellStyle{
		fg_color: .rgb
		fg_r: 10
		fg_g: 20
		fg_b: 30
		bg_color: .rgb
		bg_r: 40
		bg_g: 50
		bg_b: 60
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[38;2;10;20;30m\x1b[48;2;40;50;60m'
}

fn test_style_vt_formatting_all_colors_palette() {
	style := CellStyle{
		fg_color: .palette
		fg_palette: 1
		bg_color: .palette
		bg_palette: 2
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[38;5;1m\x1b[48;5;2m'
}

fn test_style_html_formatting_basic_bold() {
	style := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	result := style.format_html()
	assert result == 'font-weight: bold;'
}

fn test_style_html_formatting_fg_color_rgb() {
	style := CellStyle{
		fg_color: .rgb
		fg_r: 255
		fg_g: 128
		fg_b: 64
	}
	result := style.format_html()
	assert result.contains('color: rgb(255, 128, 64);')
}

fn test_style_html_formatting_bg_color_palette() {
	style := CellStyle{
		bg_color: .palette
		bg_palette: 7
	}
	result := style.format_html()
	assert result.contains('background-color: var(--vt-palette-7);')
}

fn test_style_html_formatting_combined_colors_and_flags() {
	style := CellStyle{
		fg_color: .rgb
		fg_r: 255
		fg_g: 0
		fg_b: 0
		bg_color: .rgb
		bg_r: 0
		bg_g: 0
		bg_b: 255
		flags: StyleFlags{
			bold: true
			italic: true
		}
	}
	result := style.format_html()
	assert result.contains('color: rgb(255, 0, 0);')
	assert result.contains('background-color: rgb(0, 0, 255);')
	assert result.contains('font-weight: bold;')
	assert result.contains('font-style: italic;')
}

fn test_style_default() {
	style := CellStyle{}
	assert style.default()
}

fn test_style_not_default() {
	style := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	assert !style.default()
}

fn test_style_eql() {
	s1 := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	s2 := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	assert s1.eql(&s2)
}

fn test_style_not_eql() {
	s1 := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	s2 := CellStyle{
		flags: StyleFlags{
			italic: true
		}
	}
	assert !s1.eql(&s2)
}

fn test_style_hash_different_styles() {
	s1 := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	s2 := CellStyle{
		flags: StyleFlags{
			italic: true
		}
	}
	assert s1.hash() != s2.hash()
}

fn test_style_hash_same_styles() {
	s1 := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	s2 := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	assert s1.hash() == s2.hash()
}

fn test_rgb_eql() {
	a := RGB{
		r: 10
		g: 20
		b: 30
	}
	b := RGB{
		r: 10
		g: 20
		b: 30
	}
	assert a.eql(b)
}

fn test_rgb_not_eql() {
	a := RGB{
		r: 10
		g: 20
		b: 30
	}
	b := RGB{
		r: 10
		g: 20
		b: 31
	}
	assert !a.eql(b)
}

fn test_style_bg_cell_from_style_none() {
	style := CellStyle{}
	result := style.bg_cell_from_style()
	assert result == none
}

fn test_style_bg_cell_from_style_palette() {
	style := CellStyle{
		bg_color: .palette
		bg_palette: 42
	}
	cell := style.bg_cell_from_style() or { panic('expected cell') }
	assert cell.content_tag == .bg_color_palette
	assert cell.color_palette == 42
}

fn test_style_bg_cell_from_style_rgb() {
	style := CellStyle{
		bg_color: .rgb
		bg_r: 10
		bg_g: 20
		bg_b: 30
	}
	cell := style.bg_cell_from_style() or { panic('expected cell') }
	assert cell.content_tag == .bg_color_rgb
	assert cell.color_rgb_r == 10
	assert cell.color_rgb_g == 20
	assert cell.color_rgb_b == 30
}
