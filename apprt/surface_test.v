module apprt

import configpkg

fn test_surface_source_tag_layouts_and_ordinals() {
	assert sizeof(SurfaceMessageKind) == 1
	mut message_count := 0
	$for enum_value in SurfaceMessageKind.values {
		assert u8(enum_value.value) == u8(message_count)
		message_count++
	}
	assert message_count == 22
	assert u8(SurfaceMessageKind.set_title) == 0
	assert u8(SurfaceMessageKind.search_selected) == 21

	assert sizeof(ReportTitleStyle) == 1
	assert u8(ReportTitleStyle.csi_21_t) == 0

	assert sizeof(NewSurfaceContext) == 4
	assert [NewSurfaceContext.window, .tab, .split].map(i32(it)) == [i32(0), 1, 2]
}

fn test_should_inherit_working_directory_uses_context_setting() {
	mut config := configpkg.Config.default_config()
	config.window_inherit_working_directory = false
	config.tab_inherit_working_directory = true
	config.split_inherit_working_directory = false

	assert !should_inherit_working_directory(.window, &config)
	assert should_inherit_working_directory(.tab, &config)
	assert !should_inherit_working_directory(.split, &config)
}

fn test_new_config_is_independent_when_no_surface_is_focused() {
	mut config := configpkg.Config.default_config()
	config.working_directory = '/original'
	config.env.entries << configpkg.StringMapEntry{
		key: 'ORIGINAL'
		value: 'one'
	}
	app := CoreApp{}

	mut copy := new_config(&app, &config, .tab)
	copy.working_directory = '/copy'
	copy.env.entries << configpkg.StringMapEntry{
		key: 'COPY'
		value: 'two'
	}

	assert config.working_directory? == '/original'
	assert config.env.entries.len == 1
	assert copy.working_directory? == '/copy'
	assert copy.env.entries.len == 2
}
