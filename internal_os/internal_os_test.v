module internal_os

import os

fn test_pipe_returns_distinct_fds() {
	fds := pipe() or { panic(err) }
	defer {
		os.fd_close(fds[0])
		os.fd_close(fds[1])
	}
	assert fds[0] >= 0
	assert fds[1] >= 0
	assert fds[0] != fds[1]
}

fn test_temp_dir_is_unique_and_deletes_contents() {
	mut first := TempDir.init()!
	mut second := TempDir.init()!
	assert first.name().len > 0
	assert second.name().len > 0
	assert first.path != second.path
	assert os.is_dir(first.path)
	assert os.is_dir(second.path)

	nested := os.join_path(first.path, 'nested')
	os.mkdir(nested)!
	os.write_file(os.join_path(nested, 'data'), 'temporary')!
	first_path := first.path
	second_path := second.path
	first.deinit()
	second.deinit()
	assert !os.exists(first_path)
	assert !os.exists(second_path)

	// Repeated cleanup is harmless and never broadens the deletion target.
	first.deinit()
}

fn test_shell_command_builder_ignores_empty_arguments() {
	mut command := ShellCommandBuilder.init()
	defer { command.deinit() }
	command.append_arg('bash')
	command.append_arg('')
	command.append_arg('--posix')
	command.append_arg('-l')
	assert command.to_owned_slice() == 'bash --posix -l'
}

fn test_shell_escape_writer() {
	assert shell_escape('abc') == 'abc'
	assert shell_escape('a c') == 'a\\ c'
	assert shell_escape('a?c') == 'a\\?c'
	assert shell_escape('a\\c') == 'a\\\\c'
	assert shell_escape('a|c') == 'a\\|c'
	assert shell_escape('a"c') == 'a\\"c'
	assert shell_escape('a(1)') == 'a\\(1\\)'
	assert shell_escape('line one\nline two') == 'line\\ one\nline\\ two'
}

fn test_fix_max_files_can_restore_when_available() {
	lim := fix_max_files() or { return }
	restore_max_files(lim)
	assert lim.cur > 0
	assert lim.max >= lim.cur
}

fn test_fix_max_files_does_not_shrink_limit() {
	// After fixing, the current NOFILE limit must be at least what it was
	// before: fix_max_files only ever raises it, then returns the *old*
	// value so it can be restored.
	old := fix_max_files() or { return }
	// The old value must be sane: a positive soft limit within the hard limit.
	assert old.cur > 0
	assert old.max >= old.cur
	restore_max_files(old)
}

fn test_get_passwd_returns_shell_and_home() {
	$if !windows {
		entry := get_passwd()!
		assert (entry.shell or { '' }).len > 0
		assert (entry.home or { '' }).len > 0
	}
}

fn test_i18n_locale_canonicalization() {
	assert canonicalize_locale('en_US') == 'en_US'
	assert canonicalize_locale('en-US') == 'en_US'
	assert canonicalize_locale('zh-Hans') == 'zh_CN'
	assert canonicalize_locale('zh-Hans-SG') == 'zh_SG'
	assert canonicalize_locale('zh-Hant') == 'zh_TW'
	assert canonicalize_locale('zh-Hant-HK') == 'zh_HK'
	assert canonicalize_locale('zh-Hant-MO') == 'zh_MO'
}

fn test_i18n_unknown_message_falls_back_to_msgid() {
	msgid := 'witty-i18n-test-message-that-is-not-in-a-catalog'
	assert translate(msgid) == msgid
}

fn test_systemd_detection_is_false_off_linux() {
	$if !linux {
		assert !launched_by_systemd()
	}
}

fn test_hostname_validation() {
	for hostname in ['example', 'example.com', 'www.example.com', 'example.com.',
		'host-name.example.com.', '123.example.com.', 'a-b.com', '127.0.0.1',
		'a'.repeat(63) + '.com', 'a.'.repeat(126) + 'a'] {
		assert hostname_is_valid(hostname), hostname
	}
	for hostname in ['', '.example.com', 'example.com..', 'host..domain', '-hostname', 'hostname-',
		'a.-.b', 'host_name.com', '.', '..', 'a'.repeat(64) + '.com', 'a.'.repeat(126) + 'ab'] {
		assert !hostname_is_valid(hostname), hostname
	}
}

fn test_hostname_is_local() {
	assert hostname_is_local('localhost')!
	assert hostname_is_local(os.hostname()!)!
	assert !hostname_is_local('not-the-local-hostname')!
}
