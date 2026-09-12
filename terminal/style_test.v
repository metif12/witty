module terminal

fn test_style_color_tag_source_layout() {
	assert sizeof(ColorType) == 1
	assert u8(ColorType.none) == 0
	assert u8(ColorType.palette) == 1
	assert u8(ColorType.rgb) == 2
}

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
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
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
		flags: StyleFlags.init(true, true, false, false, false, false, false, false, .curly)
	}.hash() == 0x50c324342b82c60f
}

fn test_style_flags_retain_source_packed_layout() {
	assert sizeof(StyleFlags) == 2
	mut flags := StyleFlags.init(true, true, true, true, true, true, true, true, .dashed)
	assert flags.int() == 0x05ff
	flags.set_bold(false)
	flags.set_underline(.curly)
	assert flags.int() == 0x03fe
	assert !flags.bold()
	assert flags.italic()
	assert flags.faint()
	assert flags.blink()
	assert flags.inverse()
	assert flags.invisible()
	assert flags.strikethrough()
	assert flags.overline()
	assert flags.underline() == .curly
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
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m'
}

fn test_style_vt_formatting_faint() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, true, false, false, false, false, false, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[2m'
}

fn test_style_vt_formatting_italic() {
	style := CellStyle{
		flags: StyleFlags.init(false, true, false, false, false, false, false, false, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[3m'
}

fn test_style_vt_formatting_blink() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, true, false, false, false, false, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[5m'
}

fn test_style_vt_formatting_inverse() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, true, false, false, false, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[7m'
}

fn test_style_vt_formatting_invisible() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, true, false, false, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[8m'
}

fn test_style_vt_formatting_strikethrough() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, true, false, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[9m'
}

fn test_style_vt_formatting_overline() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, false, true, .none)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[53m'
}

fn test_style_vt_formatting_underline_single() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, false, false, .single)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4m'
}

fn test_style_vt_formatting_underline_double() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, false, false, .double)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4:2m'
}

fn test_style_vt_formatting_underline_curly() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, false, false, .curly)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4:3m'
}

fn test_style_vt_formatting_underline_dotted() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, false, false, .dotted)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[4:4m'
}

fn test_style_vt_formatting_underline_dashed() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, false, false, .dashed)
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

fn test_style_vt_formatting_underline_color_palette() {
	style := CellStyle{
		underline_color: .palette
		underline_palette: 15
	}
	assert style.format_vt() == '\x1b[0m\x1b[58;5;15m'
}

fn test_style_vt_formatting_underline_color_rgb() {
	style := CellStyle{
		underline_color: .rgb
		underline_r: 200
		underline_g: 100
		underline_b: 50
	}
	assert style.format_vt() == '\x1b[0m\x1b[58;2;200;100;50m'
}

fn test_style_vt_formatting_multiple_flags() {
	style := CellStyle{
		flags: StyleFlags.init(true, true, false, false, false, false, false, false, .single)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m\x1b[3m\x1b[4m'
}

fn test_style_vt_formatting_all_flags() {
	style := CellStyle{
		flags: StyleFlags.init(true, true, true, true, true, true, true, true, .curly)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m\x1b[2m\x1b[3m\x1b[5m\x1b[7m\x1b[8m\x1b[9m\x1b[53m\x1b[4:3m'
}

fn test_style_vt_formatting_combined_colors_and_flags() {
	style := CellStyle{
		fg_color: .rgb
		fg_r: 255
		fg_g: 0
		fg_b: 0
		bg_color: .palette
		bg_palette: 8
		underline_color: .rgb
		underline_g: 255
		flags: StyleFlags.init(true, true, false, false, false, false, false, false, .double)
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[1m\x1b[3m\x1b[4:2m\x1b[38;2;255;0;0m\x1b[48;5;8m\x1b[58;2;0;255;0m'
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
		underline_color: .rgb
		underline_r: 70
		underline_g: 80
		underline_b: 90
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[38;2;10;20;30m\x1b[48;2;40;50;60m\x1b[58;2;70;80;90m'
}

fn test_style_vt_formatting_all_colors_palette() {
	style := CellStyle{
		fg_color: .palette
		fg_palette: 1
		bg_color: .palette
		bg_palette: 2
		underline_color: .palette
		underline_palette: 3
	}
	result := style.format_vt()
	assert result == '\x1b[0m\x1b[38;5;1m\x1b[48;5;2m\x1b[58;5;3m'
}

fn test_style_vt_formatting_palette_with_palette_set_emits_rgb() {
	style := CellStyle{
		fg_color: .palette
		fg_palette: 1
	}
	assert style.format_vt_with_palette(default_palette[..]) == '\x1b[0m\x1b[38;2;204;102;102m'
}

fn test_style_vt_formatting_all_palette_colors_with_palette_set() {
	style := CellStyle{
		fg_color: .palette
		fg_palette: 1
		bg_color: .palette
		bg_palette: 2
		underline_color: .palette
		underline_palette: 3
	}
	assert style.format_vt_with_palette(default_palette[..]) == '\x1b[0m\x1b[38;2;204;102;102m\x1b[48;2;181;189;104m\x1b[58;2;240;198;116m'
}

fn test_style_html_formatting_basic_bold() {
	style := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
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
		flags: StyleFlags.init(true, true, false, false, false, false, false, false, .none)
	}
	result := style.format_html()
	assert result.contains('color: rgb(255, 0, 0);')
	assert result.contains('background-color: rgb(0, 0, 255);')
	assert result.contains('font-weight: bold;')
	assert result.contains('font-style: italic;')
}

fn test_style_html_formatting_single_decoration_line() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, false, false, .single)
	}
	result := style.format_html()
	assert result.contains('text-decoration-line: underline;')
	assert result.contains('text-decoration-style: solid;')
}

fn test_style_html_formatting_multiple_decoration_lines() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, false, false, false, false, true, true, .curly)
	}
	result := style.format_html()
	assert result.contains('text-decoration-line: underline line-through overline;')
	assert result.contains('text-decoration-style: wavy;')
}

fn test_style_html_formatting_palette_with_palette_set_emits_rgb() {
	style := CellStyle{
		bg_color: .palette
		bg_palette: 7
	}
	assert style.format_html_with_palette(default_palette[..]) == 'background-color: rgb(197, 200, 198);'
}

fn test_style_html_formatting_all_palette_colors_with_palette_set() {
	style := CellStyle{
		fg_color: .palette
		fg_palette: 1
		bg_color: .palette
		bg_palette: 2
		underline_color: .palette
		underline_palette: 3
	}
	assert style.format_html_with_palette(default_palette[..]) == 'color: rgb(204, 102, 102);background-color: rgb(181, 189, 104);text-decoration-color: rgb(240, 198, 116);'
}

fn test_style_html_formatting_remaining_flags() {
	style := CellStyle{
		flags: StyleFlags.init(false, false, true, true, true, true, false, false, .none)
	}
	assert style.format_html() == 'text-decoration-line: blink;opacity: 0.5;visibility: hidden;filter: invert(100%);'
}

fn test_style_default() {
	style := CellStyle{}
	assert style.default()
}

fn test_style_not_default() {
	style := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	assert !style.default()
}

fn test_style_eql() {
	s1 := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	s2 := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	assert s1.eql(&s2)
}

fn test_style_not_eql() {
	s1 := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	s2 := CellStyle{
		flags: StyleFlags.init(false, true, false, false, false, false, false, false, .none)
	}
	assert !s1.eql(&s2)
}

fn test_style_hash_different_styles() {
	s1 := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	s2 := CellStyle{
		flags: StyleFlags.init(false, true, false, false, false, false, false, false, .none)
	}
	assert s1.hash() != s2.hash()
}

fn test_style_hash_same_styles() {
	s1 := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
	}
	s2 := CellStyle{
		flags: StyleFlags.init(true, false, false, false, false, false, false, false, .none)
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

fn test_style_bg_cell_none() {
	style := CellStyle{}
	result := style.bg_cell()
	assert result == none
}

fn test_style_bg_cell_palette() {
	style := CellStyle{
		bg_color: .palette
		bg_palette: 42
	}
	cell := style.bg_cell() or { panic('expected cell') }
	assert cell.content_tag == .bg_color_palette
	assert cell.color_palette == 42
}

fn test_style_bg_cell_rgb() {
	style := CellStyle{
		bg_color: .rgb
		bg_r: 10
		bg_g: 20
		bg_b: 30
	}
	cell := style.bg_cell() or { panic('expected cell') }
	assert cell.content_tag == .bg_color_rgb
	assert cell.color_rgb_r == 10
	assert cell.color_rgb_g == 20
	assert cell.color_rgb_b == 30
}
