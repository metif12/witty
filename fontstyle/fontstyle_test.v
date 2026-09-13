module fontstyle

fn test_font_style_layout_ordinals_and_behavior() {
	assert sizeof(Kind) == 1
	assert [Kind.default_, .false_, .name].map(u8(it)) == [u8(0), 1, 2]

	mut style := FontStyle{}
	style.parse_cli('Regular')!
	assert style.kind == .name
	assert style.name_value()? == 'Regular'
	assert style.clone() == style
	assert style.format_entry() == 'Regular'
	assert FontStyle.parse('default')!.format_entry() == 'default'
	assert FontStyle.parse('false')!.format_entry() == 'false'
	FontStyle.parse(none) or {
		assert err.code() == 1
		return
	}
	assert false, 'expected missing font style to fail'
}
