module configpkg

fn test_c_get_nullable_strings_write_null_and_succeed() {
	mut config := Config.default_config()
	config.class = none
	config.title = none
	config.window_title_font_family = none
	for key in ['class', 'title', 'window-title-font-family'] {
		mut output := unsafe { &char(usize(0x1234)) }
		assert config.c_get(key, voidptr(&output))
		assert isnil(output)
	}
	config.title = 'borrowed title'
	mut title := unsafe { &char(nil) }
	assert config.c_get('title', voidptr(&title))
	assert unsafe { cstring_to_vstring(title) } == 'borrowed title'
	mut scalar := f64(17)
	config.background_opacity = 0.5
	assert config.c_get('background-opacity', voidptr(&scalar))
	assert scalar == 0.5
}
