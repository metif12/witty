module vaxis

fn test_session_control_sequences_and_state() {
	mut vx := Vaxis.new(VaxisOptions{})
	assert vx.notify(none, 'body') == '\x1b]9;body\x1b\\'
	assert vx.notify('title', 'body') == '\x1b]777;notify;title;body\x1b\\'
	assert vx.set_title('hello') == '\x1b]2;hello\x1b\\'
	assert vx.copy_to_system_clipboard('hello') == '\x1b]52;c;aGVsbG8=\x1b\\'
	request := vx.request_system_clipboard() or {
		assert err.msg() == 'NoClipboardAllocator'
		''
	}
	assert request == ''
	rgb := [u8(0x12), 0x34, 0xab]!
	assert vx.set_terminal_foreground_color(rgb) == '\x1b]10;rgb:1212/3434/abab\x1b\\'
	assert vx.set_terminal_background_color(rgb) == '\x1b]11;rgb:1212/3434/abab\x1b\\'
	assert vx.set_terminal_cursor_color(rgb) == '\x1b]12;rgb:1212/3434/abab\x1b\\'
	assert vx.state.changed_default_fg
	assert vx.state.changed_default_bg
	assert vx.state.changed_cursor_color
	assert vx.query_color(ColorReportKind(ColorReportFg{})) == '\x1b]10;?\x1b\\'
	assert vx.query_color(ColorReportKind(ColorReportIndex{
		index: 7
	})) == '\x1b]4;7;?\x1b\\'
	assert vx.subscribe_to_color_scheme_updates() == '\x1b[?996n\x1b[?2031h'
	assert vx.state.color_scheme_updates
	assert vx.device_status_report() == '\x1b[5n'
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_session_control_clipboard_request_with_allocator() {
	mut vx := Vaxis.new(VaxisOptions{
		system_clipboard: true
	})
	assert vx.request_system_clipboard()! == '\x1b]52;c;?\x1b\\'
	vx.screen.deinit()
	vx.screen_last.deinit()
}
