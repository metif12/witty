module global_state

import os

fn test_resources_dir_detects_env() {
	old := os.getenv_opt('GHOSTTY_RESOURCES_DIR')
	os.setenv('GHOSTTY_RESOURCES_DIR', '/tmp/witty-resources-env', true)
	defer {
		if v := old {
			os.setenv('GHOSTTY_RESOURCES_DIR', v, true)
		} else {
			os.unsetenv('GHOSTTY_RESOURCES_DIR')
		}
	}

	res := ResourcesDir.detect()
	assert res.app() == '/tmp/witty-resources-env'
	assert res.host() == '/tmp/witty-resources-env'
}

fn test_resources_dir_detects_share_layout() {
	tmp := os.join_path(os.temp_dir(), 'witty-resources-test-${os.getpid()}')
	defer {
		os.rmdir_all(tmp) or {}
	}
	sentinel_dir := os.join_path(tmp, 'share', 'terminfo', 'g')
	os.mkdir_all(sentinel_dir) or { panic(err) }
	os.write_file(os.join_path(sentinel_dir, 'ghostty'), '') or { panic(err) }

	res := resources_dir_from_exe(os.join_path(tmp, 'bin', 'witty'))
	assert res.app() == os.join_path(tmp, 'share', 'ghostty')
}
