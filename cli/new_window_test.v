module cli

fn test_new_window_options_parse_class_and_command() {
	opts := parse_new_window_options(['--font-size=14', '--class=com.example.Ghostty', '-e', 'bash',
		'-c', 'echo hello'])!
	assert opts.class or { '' } == 'com.example.Ghostty'
	assert opts.arguments or { []string{} } == ['bash', '-c', 'echo hello']
}

fn test_new_window_options_empty_class_resets_to_detect() {
	opts := parse_new_window_options(['--class=custom', '--class='])!
	assert opts.class == none
}

fn test_new_window_rejects_empty_command() {
	result := new_window_result(['-e'])!
	assert result.code == 1
	assert result.errors == 'The -e flag was specified on the command line, but no other arguments were found.\n'
}

fn test_new_window_requires_class_value() {
	result := new_window_result(['--class'])!
	assert result.code == 1
	assert result.errors.contains('value required for --class')
}

$if !linux {
	fn test_new_window_reports_unsupported_platform() {
		result := new_window_result([])!
		assert result.code == 1
		assert result.errors == '+new-window is not supported on this platform.\n'
	}
}
