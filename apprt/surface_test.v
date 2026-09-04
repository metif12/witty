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
