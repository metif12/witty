module osc

fn test_osc1337_key_case_folding_is_ascii_only() {
	assert iterm2_key_from_str('FILE') == .file
	assert iterm2_key_from_str('Fİle') == .unknown
}

fn test_osc1337_valid_unimplemented_key_no_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;SetBadgeFormat'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_valid_unimplemented_key_empty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;SetBadgeFormat='
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_valid_unimplemented_key_nonempty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;SetBadgeFormat=abc123'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_valid_key_lowercase_no_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;setbadgeformat'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_valid_key_lowercase_empty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;setbadgeformat='
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_valid_key_lowercase_nonempty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;setbadgeformat=abc123'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_invalid_key_no_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;BobrKurwa'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_invalid_key_empty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;BobrKurwa='
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_invalid_key_nonempty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;BobrKurwa=abc123'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_copy_no_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;Copy'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_copy_empty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;Copy='
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_copy_only_prefix_colon() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;Copy=:'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_copy_question_mark() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;Copy=:?'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_copy_valid_base64_no_colon_prefix() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;Copy=YWJjMTIz'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_copy_valid_base64() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;Copy=:YWJjMTIz'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .clipboard_contents
	assert cmd.clipboard.kind == `c`
	assert cmd.clipboard.data == 'YWJjMTIz'
}

fn test_osc1337_currentdir_no_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;CurrentDir'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_currentdir_empty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;CurrentDir='
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc1337_currentdir_nonempty_value() {
	mut p := Parser.init(unsafe { nil })
	input := '1337;CurrentDir=abc123'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .report_pwd
	assert cmd.str_value == 'abc123'
}
