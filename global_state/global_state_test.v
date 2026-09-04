module global_state

import os
import cli_args

fn test_detect_action_direct_match() {
	assert detect_action(['--font-size=12', '+list-themes'])! == .list_themes
}

fn test_detect_action_version_is_immediate() {
	assert detect_action(['+help', '--version', '+list-fonts'])! == .version
}

fn test_detect_action_help_is_fallback() {
	assert detect_action(['--help'])! == .help
	assert detect_action(['--help', '+list-fonts'])! == .list_fonts
}

fn test_detect_action_exec_aborts_before_action() {
	assert detect_action(['-e', '+help'])! == .none
	assert detect_action(['+help', '-e'])! == .help
}

fn test_detect_action_rejects_invalid_and_multiple_actions() {
	if _ := detect_action(['+invalid']) {
		assert false, 'invalid action must fail'
	} else {
		assert err.msg().contains('invalid action')
	}
	if _ := detect_action(['+help', '+version']) {
		assert false, 'multiple actions must fail'
	} else {
		assert err.msg() == 'multiple actions'
	}
}

fn test_logging_env_uses_packed_boolean_parser() {
	old := os.getenv_opt('GHOSTTY_LOG')
	os.setenv('GHOSTTY_LOG', 'stderr,no-macos', true)
	defer {
		if value := old {
			os.setenv('GHOSTTY_LOG', value, true)
		} else {
			os.unsetenv('GHOSTTY_LOG')
		}
	}
	parsed := cli_args.parse_packed_struct[Logging](os.getenv('GHOSTTY_LOG'))!
	assert parsed.stderr
	assert !parsed.macos
}

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
	sentinel := $if macos { 'terminfo/78/xterm-ghostty' } $else $if freebsd { 'site-terminfo/g/ghostty' } $else $if windows { 'terminfo/ghostty.terminfo' } $else { 'terminfo/g/ghostty' }
	sentinel_path := os.join_path(tmp, 'share', sentinel)
	sentinel_dir := os.dir(sentinel_path)
	os.mkdir_all(sentinel_dir) or { panic(err) }
	os.write_file(sentinel_path, '') or { panic(err) }

	res := resources_dir_from_exe(os.join_path(tmp, 'bin', 'witty'))
	assert res.app() == os.join_path(tmp, 'share', 'ghostty')
}

fn test_resources_maybe_dir_returns_verified_parent() {
	tmp := os.join_path(os.temp_dir(), 'witty-resources-maybe-${os.getpid()}')
	defer { os.rmdir_all(tmp) or {} }
	sentinel := os.join_path(tmp, 'share', 'terminfo', 'g', 'ghostty')
	os.mkdir_all(os.dir(sentinel))!
	os.write_file(sentinel, '')!
	assert (maybe_dir(tmp, 'share', 'terminfo/g/ghostty') or { '' }) == os.join_path(tmp, 'share')
	assert maybe_dir(tmp, 'share', 'terminfo/x/missing') == none
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
		app_path: '/some/app/path'
		host_path: '/some/host/path'
	}
	assert res2.host() == '/some/host/path'
}
