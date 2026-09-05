module apprt

import os

fn test_resources_dir_forwards_internal_os_detection() {
	old := os.getenv_opt('GHOSTTY_RESOURCES_DIR')
	os.setenv('GHOSTTY_RESOURCES_DIR', '/tmp/witty-apprt-resources', true)
	defer {
		if value := old {
			os.setenv('GHOSTTY_RESOURCES_DIR', value, true)
		} else {
			os.unsetenv('GHOSTTY_RESOURCES_DIR')
		}
	}

	result := resources_dir()
	assert result.app() == '/tmp/witty-apprt-resources'
	assert result.host() == '/tmp/witty-apprt-resources'
}
