module osc

fn test_osc777_show_desktop_notification_with_title() {
	mut p := Parser.init(unsafe { nil })
	input := '777;notify;Title;Body'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .show_desktop_notification
	assert cmd.str_value == 'Title'
	assert cmd.str_value2 == 'Body'
}
