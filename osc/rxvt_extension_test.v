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
	assert cmd is DesktopNotification
	assert (cmd as DesktopNotification).title == 'Title'
	assert (cmd as DesktopNotification).body == 'Body'
}
