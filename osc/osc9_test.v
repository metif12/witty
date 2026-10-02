module osc

fn test_osc_source_tag_layouts_and_ordinals() {
	assert sizeof(ProgressState) == 4
	assert [ProgressState.remove, .set, .err_state, .indeterminate, .pause].map(i32(it)) == [
		i32(0),
		1,
		2,
		3,
		4,
	]

	assert sizeof(CommandType) == 4
	mut command_count := 0
	$for enum_value in CommandType.values {
		assert i32(enum_value.value) == i32(command_count)
		command_count++
	}
	assert command_count == 23
	assert i32(CommandType.invalid) == 0
	assert i32(CommandType.kitty_text_sizing) == 22

	assert sizeof(OscWriter) == 1
	assert [OscWriter.none, .fixed, .allocating].map(u8(it)) == [u8(0), 1, 2]
}

// Helper to feed input string to parser and return the command
fn parse_osc_input(input string) Command {
	mut p := Parser.init(unsafe { nil })
	for ch in input {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command from osc parser') }
	return cmd
}

fn test_osc9_show_desktop_notification() {
	cmd := parse_osc_input('9;Hello world')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).title == ''
	assert (cmd as DesktopNotification).body == 'Hello world'
}

fn test_osc9_show_single_character_desktop_notification() {
	cmd := parse_osc_input('9;H')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).title == ''
	assert (cmd as DesktopNotification).body == 'H'
}

fn test_osc9_notification_exactly_at_buffer_length_has_no_sentinel_space() {
	mut p := Parser.init(unsafe { nil })
	for ch in ('9;' + 'a'.repeat(max_buf)).bytes() {
		p.next(ch)
	}
	assert p.end(none) == none
}

fn test_osc9_non_string_command_does_not_require_sentinel_space() {
	mut p := Parser.init(unsafe { nil })
	for ch in ('9;5' + 'a'.repeat(max_buf - 1)).bytes() {
		p.next(ch)
	}
	cmd := p.end(none) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ConEmuWaitInput
}

fn test_osc9_conemu_sleep() {
	cmd := parse_osc_input('9;1;420')
	assert cmd is ConEmuSleep
	assert (cmd as ConEmuSleep).duration_ms == 420
}

fn test_osc9_conemu_sleep_no_value_default_100() {
	cmd := parse_osc_input('9;1;')
	assert cmd is ConEmuSleep
	assert (cmd as ConEmuSleep).duration_ms == 100
}

fn test_osc9_conemu_sleep_cannot_exceed_10000() {
	cmd := parse_osc_input('9;1;12345')
	assert cmd is ConEmuSleep
	assert (cmd as ConEmuSleep).duration_ms == 10000
}

fn test_osc9_conemu_sleep_invalid_input() {
	cmd := parse_osc_input('9;1;foo')
	assert cmd is ConEmuSleep
	assert (cmd as ConEmuSleep).duration_ms == 100
}

fn test_osc9_conemu_sleep_matches_zig_unsigned_parsing() {
	assert parse_osc_input('9;1;1__2').duration_ms == 12
	assert parse_osc_input('9;1;+12').duration_ms == 100
	assert parse_osc_input('9;1;65536').duration_ms == 100
}

fn test_osc9_conemu_sleep_desktop_notification_1() {
	// "9;1" without semicolon -> desktop notification
	cmd := parse_osc_input('9;1')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '1'
}

fn test_osc9_conemu_sleep_desktop_notification_2() {
	cmd := parse_osc_input('9;1a')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '1a'
}

fn test_osc9_conemu_message_box() {
	cmd := parse_osc_input('9;2;hello world')
	assert cmd is ConEmuShowMessageBox
	assert (cmd as ConEmuShowMessageBox).value == 'hello world'
}

fn test_osc9_conemu_message_box_invalid_input() {
	cmd := parse_osc_input('9;2')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '2'
}

fn test_osc9_conemu_message_box_empty() {
	cmd := parse_osc_input('9;2;')
	assert cmd is ConEmuShowMessageBox
	assert (cmd as ConEmuShowMessageBox).value == ''
}

fn test_osc9_conemu_message_box_spaces() {
	cmd := parse_osc_input('9;2;   ')
	assert cmd is ConEmuShowMessageBox
	assert (cmd as ConEmuShowMessageBox).value == '   '
}

fn test_osc9_message_box_desktop_notification_1() {
	cmd := parse_osc_input('9;2')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '2'
}

fn test_osc9_message_box_desktop_notification_2() {
	cmd := parse_osc_input('9;2a')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '2a'
}

fn test_osc9_conemu_change_tab_title() {
	cmd := parse_osc_input('9;3;foo bar')
	assert cmd is ConEmuChangeTabTitle
	assert (cmd as ConEmuChangeTabTitle).title is string
	assert ((cmd as ConEmuChangeTabTitle).title as string) == 'foo bar'
}

fn test_osc9_conemu_change_tab_title_reset() {
	cmd := parse_osc_input('9;3;')
	assert cmd is ConEmuChangeTabTitle
	assert (cmd as ConEmuChangeTabTitle).title is ConEmuTabTitleReset
}

fn test_osc9_conemu_change_tab_title_spaces() {
	cmd := parse_osc_input('9;3;   ')
	assert cmd is ConEmuChangeTabTitle
	assert (cmd as ConEmuChangeTabTitle).title is string
	assert ((cmd as ConEmuChangeTabTitle).title as string) == '   '
}

fn test_osc9_change_tab_title_desktop_notification_1() {
	cmd := parse_osc_input('9;3')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '3'
}

fn test_osc9_change_tab_title_desktop_notification_2() {
	cmd := parse_osc_input('9;3a')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '3a'
}

fn test_osc9_conemu_progress_set() {
	cmd := parse_osc_input('9;4;1;100')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .set
	assert (cmd as ProgressReport).progress? == 100
}

fn test_osc9_conemu_progress_set_overflow() {
	cmd := parse_osc_input('9;4;1;900')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .set
	assert (cmd as ProgressReport).progress? == 100
}

fn test_progress_report_cval() {
	assert ProgressReport{ state: .pause, progress: u8(250) }.cval() == ProgressReportC{
		state: int(ProgressState.pause)
		progress: 100
	}
	assert ProgressReport{ state: .remove }.cval().progress == -1
}

fn test_osc9_conemu_progress_set_single_digit() {
	cmd := parse_osc_input('9;4;1;9')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .set
	assert (cmd as ProgressReport).progress? == 9
}

fn test_osc9_conemu_progress_set_double_digit() {
	cmd := parse_osc_input('9;4;1;94')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .set
	assert (cmd as ProgressReport).progress? == 94
}

fn test_osc9_conemu_progress_matches_zig_unsigned_parsing() {
	assert parse_osc_input('9;4;1;1__0').progress? == 10
	assert parse_osc_input('9;4;1;+10').progress == none
	assert parse_osc_input('9;4;1;18446744073709551616').progress == none
}

fn test_osc9_conemu_progress_remove_no_progress() {
	cmd := parse_osc_input('9;4;0;')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .remove
	assert (cmd as ProgressReport).progress == none
}

fn test_osc9_conemu_progress_remove_double_semicolon() {
	cmd := parse_osc_input('9;4;0;;')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .remove
	assert (cmd as ProgressReport).progress == none
}

fn test_osc9_conemu_progress_remove_ignores_progress() {
	cmd := parse_osc_input('9;4;0;100')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .remove
	assert (cmd as ProgressReport).progress == none
}

fn test_osc9_conemu_progress_remove_extra_semicolon() {
	cmd := parse_osc_input('9;4;0;100;')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .remove
}

fn test_osc9_conemu_progress_error() {
	cmd := parse_osc_input('9;4;2')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .err_state
	assert (cmd as ProgressReport).progress == none
}

fn test_osc9_conemu_progress_error_with_progress() {
	cmd := parse_osc_input('9;4;2;100')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .err_state
	assert (cmd as ProgressReport).progress? == 100
}

fn test_osc9_progress_pause() {
	cmd := parse_osc_input('9;4;4')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .pause
	assert (cmd as ProgressReport).progress == none
}

fn test_osc9_conemu_progress_pause_with_progress() {
	cmd := parse_osc_input('9;4;4;100')
	assert cmd is ProgressReport
	assert (cmd as ProgressReport).state == .pause
	assert (cmd as ProgressReport).progress? == 100
}

fn test_osc9_progress_desktop_notification_1() {
	cmd := parse_osc_input('9;4')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '4'
}

fn test_osc9_progress_desktop_notification_2() {
	cmd := parse_osc_input('9;4;')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '4;'
}

fn test_osc9_progress_desktop_notification_3() {
	cmd := parse_osc_input('9;4;5')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '4;5'
}

fn test_osc9_progress_desktop_notification_4() {
	cmd := parse_osc_input('9;4;5a')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '4;5a'
}

fn test_osc9_conemu_wait_input() {
	cmd := parse_osc_input('9;5')
	assert cmd is ConEmuWaitInput
}

fn test_osc9_conemu_wait_ignores_trailing() {
	cmd := parse_osc_input('9;5;foo')
	assert cmd is ConEmuWaitInput
}

fn test_osc9_conemu_guimacro_1() {
	cmd := parse_osc_input('9;6;a')
	assert cmd is ConEmuGuiMacro
	assert (cmd as ConEmuGuiMacro).value == 'a'
}

fn test_osc9_conemu_guimacro_2() {
	cmd := parse_osc_input('9;6;ab')
	assert cmd is ConEmuGuiMacro
	assert (cmd as ConEmuGuiMacro).value == 'ab'
}

fn test_osc9_conemu_guimacro_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;6')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '6'
}

fn test_osc9_conemu_run_process_1() {
	cmd := parse_osc_input('9;7;ab')
	assert cmd is ConEmuRunProcess
	assert (cmd as ConEmuRunProcess).value == 'ab'
}

fn test_osc9_conemu_run_process_2() {
	cmd := parse_osc_input('9;7;')
	assert cmd is ConEmuRunProcess
	assert (cmd as ConEmuRunProcess).value == ''
}

fn test_osc9_conemu_run_process_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;7')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '7'
}

fn test_osc9_conemu_output_env_var_1() {
	cmd := parse_osc_input('9;8;ab')
	assert cmd is ConEmuOutputEnvironmentVariable
	assert (cmd as ConEmuOutputEnvironmentVariable).value == 'ab'
}

fn test_osc9_conemu_output_env_var_2() {
	cmd := parse_osc_input('9;8;')
	assert cmd is ConEmuOutputEnvironmentVariable
	assert (cmd as ConEmuOutputEnvironmentVariable).value == ''
}

fn test_osc9_conemu_output_env_var_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;8')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '8'
}

fn test_osc9_conemu_set_cwd() {
	cmd := parse_osc_input('9;9;ab')
	assert cmd is ReportPwd
	assert (cmd as ReportPwd).value == 'ab'
}

fn test_osc9_conemu_set_cwd_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;9')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '9'
}

fn test_osc9_conemu_xterm_emulation_1() {
	cmd := parse_osc_input('9;10')
	assert cmd is ConEmuXtermEmulation
	assert (cmd as ConEmuXtermEmulation).keyboard? == true
	assert (cmd as ConEmuXtermEmulation).output? == true
}

fn test_osc9_conemu_xterm_emulation_2() {
	cmd := parse_osc_input('9;10;0')
	assert cmd is ConEmuXtermEmulation
	assert (cmd as ConEmuXtermEmulation).keyboard? == false
	assert (cmd as ConEmuXtermEmulation).output? == false
}

fn test_osc9_conemu_xterm_emulation_3() {
	cmd := parse_osc_input('9;10;1')
	assert cmd is ConEmuXtermEmulation
	assert (cmd as ConEmuXtermEmulation).keyboard? == true
	assert (cmd as ConEmuXtermEmulation).output? == true
}

fn test_osc9_conemu_xterm_emulation_4() {
	cmd := parse_osc_input('9;10;2')
	assert cmd is ConEmuXtermEmulation
	assert (cmd as ConEmuXtermEmulation).keyboard == none
	assert (cmd as ConEmuXtermEmulation).output? == false
}

fn test_osc9_conemu_xterm_emulation_5() {
	cmd := parse_osc_input('9;10;3')
	assert cmd is ConEmuXtermEmulation
	assert (cmd as ConEmuXtermEmulation).keyboard == none
	assert (cmd as ConEmuXtermEmulation).output? == true
}

fn test_osc9_conemu_xterm_emulation_6() {
	cmd := parse_osc_input('9;10;4')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '10;4'
}

fn test_osc9_conemu_xterm_emulation_7() {
	cmd := parse_osc_input('9;10;')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '10;'
}

fn test_osc9_conemu_xterm_emulation_8() {
	cmd := parse_osc_input('9;10;abc')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '10;abc'
}

fn test_osc9_conemu_comment() {
	cmd := parse_osc_input('9;11;ab')
	assert cmd is ConEmuComment
	assert (cmd as ConEmuComment).value == 'ab'
}

fn test_osc9_conemu_comment_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;11')
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).body == '11'
}

fn test_osc9_conemu_mark_prompt_start_1() {
	cmd := parse_osc_input('9;12')
	assert cmd is SemanticPrompt
	// ghostty emits semantic_prompt with action fresh_line_new_prompt.
	assert (cmd as SemanticPrompt).action == .fresh_line_new_prompt
}

fn test_osc9_conemu_mark_prompt_start_2() {
	cmd := parse_osc_input('9;12;abc')
	assert cmd is SemanticPrompt
	assert (cmd as SemanticPrompt).action == .fresh_line_new_prompt
}

fn test_progress_defaults_only_when_value_is_absent() {
	assert parse_osc_input('9;4;1').progress? == 0
	assert parse_osc_input('9;4;1x').progress? == 0
	for input in ['9;4;1;', '9;4;1;bad', '9;4;1;+10', '9;4;1;18446744073709551616'] {
		assert parse_osc_input(input).progress == none
	}
}
