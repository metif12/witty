module osc

fn test_osc7_report_pwd() {
	mut p := Parser.init(unsafe { nil })
	input := '7;file:///tmp/example'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(none) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .report_pwd
	assert cmd.str_value == 'file:///tmp/example'
}

fn test_osc7_report_pwd_empty() {
	mut p := Parser.init(unsafe { nil })
	input := '7;'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .report_pwd
	assert cmd.str_value == ''
}
