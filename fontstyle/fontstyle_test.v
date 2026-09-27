module fontstyle

fn test_font_style_layout_ordinals_and_behavior() {
	assert sizeof(Kind) == 1
	assert [Kind.default_, .false_, .name].map(u8(it)) == [u8(0), 1, 2]

	mut style := FontStyle(FontStyleDefault{})
	style.parse_cli('Regular')!
	assert style.tag() == .name
	assert style.name_value()? == 'Regular'
	assert style.clone() == style
	assert style.format_entry() == 'Regular'
	default_style := FontStyle.parse('default')!
	assert default_style is FontStyleDefault
	assert default_style.format_entry() == 'default'
	false_style := FontStyle.parse('false')!
	assert false_style is FontStyleFalse
	assert false_style.is_false()
	assert false_style.format_entry() == 'false'
	FontStyle.parse(none) or {
		assert err.code() == 1
		return
	}
	assert false, 'expected missing font style to fail'
}
