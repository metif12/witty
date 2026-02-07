module osc

fn test_osc0_change_window_title() {
	mut p := Parser.init(unsafe { nil })
	p.next(`0`)
	p.next(`;`)
	p.next(`a`)
	p.next(`b`)
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .change_window_title
	assert cmd.str_value == 'ab'
}

fn test_osc2_change_window_title() {
	mut p := Parser.init(unsafe { nil })
	p.next(`2`)
	p.next(`;`)
	p.next(`a`)
	p.next(`b`)
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .change_window_title
	assert cmd.str_value == 'ab'
}

fn test_osc2_change_window_title_with_utf8() {
	mut p := Parser.init(unsafe { nil })
	p.next(`2`)
	p.next(`;`)
	// EM DASH U+2014 (E2 80 94)
	p.next(0xE2)
	p.next(0x80)
	p.next(0x94)
	p.next(` `)
	// HYPHEN U+2010 (E2 80 90)
	// Intentionally chosen to conflict with the 0x90 C1 control
	p.next(0xE2)
	p.next(0x80)
	p.next(0x90)
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .change_window_title
	// The raw bytes should be preserved
	assert cmd.str_value.len == 7
}

fn test_osc2_change_window_title_empty() {
	mut p := Parser.init(unsafe { nil })
	p.next(`2`)
	p.next(`;`)
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .change_window_title
	assert cmd.str_value == ''
}

fn test_osc0_change_window_title_longer_than_buffer() {
	mut p := Parser.init(unsafe { nil })
	p.next(`0`)
	p.next(`;`)
	// Feed more than max_buf characters
	for _ in 0 .. max_buf + 2 {
		p.next(`a`)
	}
	// Should still work since we use a dynamic buffer
	// but contents may be truncated
	_ = p.end(0)
}
