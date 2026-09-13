module global_state

import os

fn test_logging_defaults_follow_runtime_and_darwin_target() {
	logging := Logging{}
	$if linux || freebsd {
		assert logging.stderr()
	} $else {
		assert !logging.stderr()
	}
	$if macos || ios {
		assert logging.macos()
	} $else {
		assert !logging.macos()
	}
	assert sizeof(Logging) == 1
	assert logging.int() == default_logging_bits
}

fn test_detect_action_direct_match() {
	assert detect_action(['--font-size=12', '+list-themes'])!.action? == .list_themes
}

fn test_detect_action_version_is_immediate() {
	assert detect_action(['+help', '--version', '+list-fonts'])!.action? == .version
}

fn test_detect_action_help_is_fallback() {
	assert detect_action(['--help'])!.action? == .help
	assert detect_action(['--help', '+list-fonts'])!.action? == .list_fonts
}

fn test_detect_action_exec_aborts_before_action() {
	assert detect_action(['-e', '+help'])!.action == none
	assert detect_action(['+help', '-e'])!.action? == .help
}

fn test_cli_action_layout_and_source_ordinals() {
	assert sizeof(Action) == 1
	mut action_count := 0
	$for enum_value in Action.values {
		assert u8(enum_value.value) == u8(action_count)
		action_count++
	}
	assert action_count == 15
	assert u8(Action.version) == 0
	assert u8(Action.new_window) == 14
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
	parsed := parse_logging(os.getenv('GHOSTTY_LOG'))!
	assert parsed.stderr()
	assert !parsed.macos()
	assert parse_logging('true')!.int() == 0b11
	assert parse_logging('false')!.int() == 0
	if _ := parse_logging('unknown') {
		assert false, 'unknown logging field must fail'
	} else {
		assert err.msg() == 'invalid value'
	}
}
