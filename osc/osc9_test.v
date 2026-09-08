module osc

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
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.title == ''
	assert cmd.desktop_notification.body == 'Hello world'
}

fn test_osc9_show_single_character_desktop_notification() {
	cmd := parse_osc_input('9;H')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.title == ''
	assert cmd.desktop_notification.body == 'H'
}

fn test_osc9_conemu_sleep() {
	cmd := parse_osc_input('9;1;420')
	assert cmd.cmd_type == .conemu_sleep
	assert cmd.duration_ms == 420
}

fn test_osc9_conemu_sleep_no_value_default_100() {
	cmd := parse_osc_input('9;1;')
	assert cmd.cmd_type == .conemu_sleep
	assert cmd.duration_ms == 100
}

fn test_osc9_conemu_sleep_cannot_exceed_10000() {
	cmd := parse_osc_input('9;1;12345')
	assert cmd.cmd_type == .conemu_sleep
	assert cmd.duration_ms == 10000
}

fn test_osc9_conemu_sleep_invalid_input() {
	cmd := parse_osc_input('9;1;foo')
	assert cmd.cmd_type == .conemu_sleep
	assert cmd.duration_ms == 100
}

fn test_osc9_conemu_sleep_matches_zig_unsigned_parsing() {
	assert parse_osc_input('9;1;1__2').duration_ms == 12
	assert parse_osc_input('9;1;+12').duration_ms == 100
	assert parse_osc_input('9;1;65536').duration_ms == 100
}

fn test_osc9_conemu_sleep_desktop_notification_1() {
	// "9;1" without semicolon -> desktop notification
	cmd := parse_osc_input('9;1')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '1'
}

fn test_osc9_conemu_sleep_desktop_notification_2() {
	cmd := parse_osc_input('9;1a')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '1a'
}

fn test_osc9_conemu_message_box() {
	cmd := parse_osc_input('9;2;hello world')
	assert cmd.cmd_type == .conemu_show_message_box
	assert cmd.str_value == 'hello world'
}

fn test_osc9_conemu_message_box_invalid_input() {
	cmd := parse_osc_input('9;2')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '2'
}

fn test_osc9_conemu_message_box_empty() {
	cmd := parse_osc_input('9;2;')
	assert cmd.cmd_type == .conemu_show_message_box
	assert cmd.str_value == ''
}

fn test_osc9_conemu_message_box_spaces() {
	cmd := parse_osc_input('9;2;   ')
	assert cmd.cmd_type == .conemu_show_message_box
	assert cmd.str_value == '   '
}

fn test_osc9_message_box_desktop_notification_1() {
	cmd := parse_osc_input('9;2')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '2'
}

fn test_osc9_message_box_desktop_notification_2() {
	cmd := parse_osc_input('9;2a')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '2a'
}

fn test_osc9_conemu_change_tab_title() {
	cmd := parse_osc_input('9;3;foo bar')
	assert cmd.cmd_type == .conemu_change_tab_title
	assert cmd.tab_title.kind == .value
	assert cmd.tab_title.value == 'foo bar'
}

fn test_osc9_conemu_change_tab_title_reset() {
	cmd := parse_osc_input('9;3;')
	assert cmd.cmd_type == .conemu_change_tab_title
	assert cmd.tab_title.kind == .reset
}

fn test_osc9_conemu_change_tab_title_spaces() {
	cmd := parse_osc_input('9;3;   ')
	assert cmd.cmd_type == .conemu_change_tab_title
	assert cmd.tab_title.kind == .value
	assert cmd.tab_title.value == '   '
}

fn test_osc9_change_tab_title_desktop_notification_1() {
	cmd := parse_osc_input('9;3')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '3'
}

fn test_osc9_change_tab_title_desktop_notification_2() {
	cmd := parse_osc_input('9;3a')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '3a'
}

fn test_osc9_conemu_progress_set() {
	cmd := parse_osc_input('9;4;1;100')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .set
	assert cmd.progress? == 100
}

fn test_osc9_conemu_progress_set_overflow() {
	cmd := parse_osc_input('9;4;1;900')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .set
	assert cmd.progress? == 100
}

fn test_osc9_conemu_progress_set_single_digit() {
	cmd := parse_osc_input('9;4;1;9')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .set
	assert cmd.progress? == 9
}

fn test_osc9_conemu_progress_set_double_digit() {
	cmd := parse_osc_input('9;4;1;94')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .set
	assert cmd.progress? == 94
}

fn test_osc9_conemu_progress_matches_zig_unsigned_parsing() {
	assert parse_osc_input('9;4;1;1__0').progress? == 10
	assert parse_osc_input('9;4;1;+10').progress? == 0
	assert parse_osc_input('9;4;1;18446744073709551616').progress? == 0
}

fn test_osc9_conemu_progress_remove_no_progress() {
	cmd := parse_osc_input('9;4;0;')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .remove
	assert cmd.progress == none
}

fn test_osc9_conemu_progress_remove_double_semicolon() {
	cmd := parse_osc_input('9;4;0;;')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .remove
	assert cmd.progress == none
}

fn test_osc9_conemu_progress_remove_ignores_progress() {
	cmd := parse_osc_input('9;4;0;100')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .remove
	assert cmd.progress == none
}

fn test_osc9_conemu_progress_remove_extra_semicolon() {
	cmd := parse_osc_input('9;4;0;100;')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .remove
}

fn test_osc9_conemu_progress_error() {
	cmd := parse_osc_input('9;4;2')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .err_state
	assert cmd.progress == none
}

fn test_osc9_conemu_progress_error_with_progress() {
	cmd := parse_osc_input('9;4;2;100')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .err_state
	assert cmd.progress? == 100
}

fn test_osc9_progress_pause() {
	cmd := parse_osc_input('9;4;4')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .pause
	assert cmd.progress == none
}

fn test_osc9_conemu_progress_pause_with_progress() {
	cmd := parse_osc_input('9;4;4;100')
	assert cmd.cmd_type == .conemu_progress_report
	assert cmd.progress_state == .pause
	assert cmd.progress? == 100
}

fn test_osc9_progress_desktop_notification_1() {
	cmd := parse_osc_input('9;4')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '4'
}

fn test_osc9_progress_desktop_notification_2() {
	cmd := parse_osc_input('9;4;')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '4;'
}

fn test_osc9_progress_desktop_notification_3() {
	cmd := parse_osc_input('9;4;5')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '4;5'
}

fn test_osc9_progress_desktop_notification_4() {
	cmd := parse_osc_input('9;4;5a')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '4;5a'
}

fn test_osc9_conemu_wait_input() {
	cmd := parse_osc_input('9;5')
	assert cmd.cmd_type == .conemu_wait_input
}

fn test_osc9_conemu_wait_ignores_trailing() {
	cmd := parse_osc_input('9;5;foo')
	assert cmd.cmd_type == .conemu_wait_input
}

fn test_osc9_conemu_guimacro_1() {
	cmd := parse_osc_input('9;6;a')
	assert cmd.cmd_type == .conemu_guimacro
	assert cmd.str_value == 'a'
}

fn test_osc9_conemu_guimacro_2() {
	cmd := parse_osc_input('9;6;ab')
	assert cmd.cmd_type == .conemu_guimacro
	assert cmd.str_value == 'ab'
}

fn test_osc9_conemu_guimacro_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;6')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '6'
}

fn test_osc9_conemu_run_process_1() {
	cmd := parse_osc_input('9;7;ab')
	assert cmd.cmd_type == .conemu_run_process
	assert cmd.str_value == 'ab'
}

fn test_osc9_conemu_run_process_2() {
	cmd := parse_osc_input('9;7;')
	assert cmd.cmd_type == .conemu_run_process
	assert cmd.str_value == ''
}

fn test_osc9_conemu_run_process_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;7')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '7'
}

fn test_osc9_conemu_output_env_var_1() {
	cmd := parse_osc_input('9;8;ab')
	assert cmd.cmd_type == .conemu_output_environment_variable
	assert cmd.str_value == 'ab'
}

fn test_osc9_conemu_output_env_var_2() {
	cmd := parse_osc_input('9;8;')
	assert cmd.cmd_type == .conemu_output_environment_variable
	assert cmd.str_value == ''
}

fn test_osc9_conemu_output_env_var_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;8')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '8'
}

fn test_osc9_conemu_set_cwd() {
	cmd := parse_osc_input('9;9;ab')
	assert cmd.cmd_type == .report_pwd
	assert cmd.str_value == 'ab'
}

fn test_osc9_conemu_set_cwd_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;9')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '9'
}

fn test_osc9_conemu_xterm_emulation_1() {
	cmd := parse_osc_input('9;10')
	assert cmd.cmd_type == .conemu_xterm_emulation
	assert cmd.xterm_keyboard? == true
	assert cmd.xterm_output? == true
}

fn test_osc9_conemu_xterm_emulation_2() {
	cmd := parse_osc_input('9;10;0')
	assert cmd.cmd_type == .conemu_xterm_emulation
	assert cmd.xterm_keyboard? == false
	assert cmd.xterm_output? == false
}

fn test_osc9_conemu_xterm_emulation_3() {
	cmd := parse_osc_input('9;10;1')
	assert cmd.cmd_type == .conemu_xterm_emulation
	assert cmd.xterm_keyboard? == true
	assert cmd.xterm_output? == true
}

fn test_osc9_conemu_xterm_emulation_4() {
	cmd := parse_osc_input('9;10;2')
	assert cmd.cmd_type == .conemu_xterm_emulation
	assert cmd.xterm_keyboard == none
	assert cmd.xterm_output? == false
}

fn test_osc9_conemu_xterm_emulation_5() {
	cmd := parse_osc_input('9;10;3')
	assert cmd.cmd_type == .conemu_xterm_emulation
	assert cmd.xterm_keyboard == none
	assert cmd.xterm_output? == true
}

fn test_osc9_conemu_xterm_emulation_6() {
	cmd := parse_osc_input('9;10;4')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '10;4'
}

fn test_osc9_conemu_xterm_emulation_7() {
	cmd := parse_osc_input('9;10;')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '10;'
}

fn test_osc9_conemu_xterm_emulation_8() {
	cmd := parse_osc_input('9;10;abc')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '10;abc'
}

fn test_osc9_conemu_comment() {
	cmd := parse_osc_input('9;11;ab')
	assert cmd.cmd_type == .conemu_comment
	assert cmd.str_value == 'ab'
}

fn test_osc9_conemu_comment_incomplete_desktop_notification() {
	cmd := parse_osc_input('9;11')
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.desktop_notification.body == '11'
}

fn test_osc9_conemu_mark_prompt_start_1() {
	cmd := parse_osc_input('9;12')
	assert cmd.cmd_type == .semantic_prompt
	// ghostty emits semantic_prompt with action fresh_line_new_prompt.
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
}

fn test_osc9_conemu_mark_prompt_start_2() {
	cmd := parse_osc_input('9;12;abc')
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
}
