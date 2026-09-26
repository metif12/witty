module osc

fn test_osc_parser_state_source_layout_and_ordinals() {
	assert sizeof(OscParserState) == 1
	states := [OscParserState.start, .invalid, .s_0, .s_1, .s_2, .s_4, .s_5, .s_6,
		.s_7, .s_8, .s_9, .s_10, .s_11, .s_12, .s_13, .s_14, .s_15, .s_16, .s_17,
		.s_18, .s_19, .s_21, .s_22, .s_52, .s_66, .s_77, .s_104, .s_110, .s_111,
		.s_112, .s_113, .s_114, .s_115, .s_116, .s_117, .s_118, .s_119, .s_133,
		.s_777, .s_1337]
	for idx, state in states {
		assert u8(state) == u8(idx)
	}
}

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
	assert cmd is ChangeWindowTitle
	assert (cmd as ChangeWindowTitle).value == 'ab'
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
	assert cmd is ChangeWindowTitle
	assert (cmd as ChangeWindowTitle).value == 'ab'
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
	assert cmd is ChangeWindowTitle
	// The raw bytes should be preserved
	assert (cmd as ChangeWindowTitle).value.len == 7
}

fn test_osc2_change_window_title_empty() {
	mut p := Parser.init(unsafe { nil })
	p.next(`2`)
	p.next(`;`)
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ChangeWindowTitle
	assert (cmd as ChangeWindowTitle).value == ''
}

fn test_osc0_change_window_title_longer_than_buffer() {
	mut p := Parser.init(unsafe { nil })
	p.next(`0`)
	p.next(`;`)
	for _ in 0 .. max_buf + 2 {
		p.next(`a`)
	}
	assert p.end(none) == none
}

fn test_osc0_change_window_title_one_shorter_than_buffer_length() {
	mut p := Parser.init(unsafe { nil })
	p.next(`0`)
	p.next(`;`)
	for _ in 0 .. max_buf - 1 {
		p.next(`a`)
	}
	cmd := p.end(none) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ChangeWindowTitle
	assert (cmd as ChangeWindowTitle).value == 'a'.repeat(max_buf - 1)
}

fn test_osc0_change_window_title_exactly_at_buffer_length() {
	mut p := Parser.init(unsafe { nil })
	p.next(`0`)
	p.next(`;`)
	for _ in 0 .. max_buf {
		p.next(`a`)
	}
	// The source parser reserves one byte for the sentinel terminator.
	assert p.end(none) == none
}

fn test_osc_terminator_defaults_to_st_when_final_byte_is_absent() {
	assert Terminator.init(none) == .st
	assert Terminator.st.string() == '\x1b\\'
	assert Terminator.bel.string() == '\x07'
}
