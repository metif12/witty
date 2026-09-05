module osc

fn test_osc52_get_set_clipboard() {
	mut p := Parser.init(unsafe { nil })
	input := '52;s;?'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .clipboard_contents
	assert cmd.clipboard.kind == `s`
	assert cmd.clipboard.data == '?'
}

fn test_osc52_get_set_clipboard_optional_parameter() {
	mut p := Parser.init(unsafe { nil })
	input := '52;;?'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .clipboard_contents
	assert cmd.clipboard.kind == `c`
	assert cmd.clipboard.data == '?'
}

fn test_osc52_clear_clipboard() {
	mut p := Parser.init(unsafe { nil })
	input := '52;;'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .clipboard_contents
	assert cmd.clipboard.kind == `c`
	assert cmd.clipboard.data == ''
}
