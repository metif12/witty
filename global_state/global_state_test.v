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

fn test_resources_dir_returns_empty_when_not_found() {
	old := os.getenv_opt('GHOSTTY_RESOURCES_DIR')
	os.unsetenv('GHOSTTY_RESOURCES_DIR')
	defer {
		if v := old {
			os.setenv('GHOSTTY_RESOURCES_DIR', v, true)
		}
	}

	tmp := os.join_path(os.temp_dir(), 'witty-resources-empty-${os.getpid()}')
	defer {
		os.rmdir_all(tmp) or {}
	}
	os.mkdir_all(os.join_path(tmp, 'bin')) or { panic(err) }

	// No terminfo bundle exists anywhere in the tree, so detection fails
	// and both app() and host() return empty strings.
	res := resources_dir_from_exe(os.join_path(tmp, 'bin', 'witty'))
	assert res.app() == ''
	assert res.host() == ''
}

fn test_resources_dir_host_falls_back_to_app() {
	// In a non-sandboxed environment host() should equal app() when
	// host_path is not explicitly set. This mirrors ghostty's ResourcesDir.host().
	res := ResourcesDir{
		app_path: '/some/app/path'
	}
	assert res.host() == '/some/app/path'

	// When host_path is set explicitly, host() returns it.
	res2 := ResourcesDir{
		app_path:  '/some/app/path'
		host_path: '/some/host/path'
	}
	assert res2.host() == '/some/host/path'
}
