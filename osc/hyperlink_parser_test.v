module osc

fn test_osc8_hyperlink() {
	mut p := Parser.init(unsafe { nil })
	input := '8;;http://example.com'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_start
	assert cmd.hyperlink.uri == 'http://example.com'
	assert cmd.hyperlink.id == none
}

fn test_osc8_hyperlink_with_id() {
	mut p := Parser.init(unsafe { nil })
	input := '8;id=foo;http://example.com'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_start
	assert cmd.hyperlink.id? == 'foo'
	assert cmd.hyperlink.uri == 'http://example.com'
}

fn test_osc8_hyperlink_with_empty_id() {
	mut p := Parser.init(unsafe { nil })
	input := '8;id=;http://example.com'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_start
	// Empty id is treated as no id
	assert cmd.hyperlink.id == none
	assert cmd.hyperlink.uri == 'http://example.com'
}

fn test_osc8_hyperlink_with_incomplete_key() {
	mut p := Parser.init(unsafe { nil })
	input := '8;id;http://example.com'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_start
	assert cmd.hyperlink.id == none
	assert cmd.hyperlink.uri == 'http://example.com'
}

fn test_osc8_hyperlink_stops_options_at_incomplete_key() {
	mut p := Parser.init(unsafe { nil })
	input := '8;broken:id=ignored;http://example.com'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_start
	assert cmd.hyperlink.id == none
	assert cmd.hyperlink.uri == 'http://example.com'
}

fn test_osc8_hyperlink_with_empty_key() {
	mut p := Parser.init(unsafe { nil })
	input := '8;=value;http://example.com'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_start
	assert cmd.hyperlink.id == none
	assert cmd.hyperlink.uri == 'http://example.com'
}

fn test_osc8_hyperlink_with_empty_key_and_id() {
	mut p := Parser.init(unsafe { nil })
	input := '8;=value:id=foo;http://example.com'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_start
	assert cmd.hyperlink.id? == 'foo'
	assert cmd.hyperlink.uri == 'http://example.com'
}

fn test_osc8_hyperlink_with_empty_uri_and_id() {
	// Having an id with empty URI is invalid
	mut p := Parser.init(unsafe { nil })
	input := '8;id=foo;'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b)
	assert cmd == none
}

fn test_osc8_hyperlink_end() {
	mut p := Parser.init(unsafe { nil })
	input := '8;;'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .hyperlink_end
}
