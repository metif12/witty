module apprt

import configpkg

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
