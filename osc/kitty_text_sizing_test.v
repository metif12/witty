module osc

fn test_osc66_empty_parameters() {
	mut p := Parser.init(unsafe { nil })
	input := '66;;bobr'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .kitty_text_sizing
	assert cmd.str_value == 'bobr'
}

fn test_osc66_single_parameter() {
	mut p := Parser.init(unsafe { nil })
	input := '66;s=2;kurwa'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .kitty_text_sizing
	assert cmd.str_value == 'kurwa'
	// scale=2 should be encoded in str_value2
	assert cmd.str_value2.starts_with('2,')
}

fn test_osc66_scale_is_zero() {
	mut p := Parser.init(unsafe { nil })
	input := '66;s=0;nope'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .kitty_text_sizing
	// scale=0 is invalid, should remain default (1)
	assert cmd.str_value2.starts_with('1,')
}

fn test_osc66_unsafe_utf8() {
	mut p := Parser.init(unsafe { nil })
	input := '66;;\n'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc66_overlong_utf8() {
	mut p := Parser.init(unsafe { nil })
	// Start with the prefix
	for ch in '66;;'.bytes() {
		p.next(ch)
	}
	// Feed more than max_payload characters
	for _ in 0 .. kitty_text_sizing_max_payload + 10 {
		p.next(`b`)
	}
	assert p.end(0x1b) == none
}
