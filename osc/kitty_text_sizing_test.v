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
	assert cmd.kitty_text_sizing.text == 'bobr'
	assert cmd.kitty_text_sizing.scale == 1
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
	assert cmd.kitty_text_sizing.text == 'kurwa'
	assert cmd.kitty_text_sizing.scale == 2
}

fn test_osc66_multiple_parameters() {
	mut p := Parser.init(unsafe { nil })
	input := '66;s=2:w=7:n=13:d=15:v=1:h=2;long'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd.cmd_type == .kitty_text_sizing
	assert cmd.kitty_text_sizing.scale == 2
	assert cmd.kitty_text_sizing.width == 7
	assert cmd.kitty_text_sizing.numerator == 13
	assert cmd.kitty_text_sizing.denominator == 15
	assert cmd.kitty_text_sizing.valign == .bottom
	assert cmd.kitty_text_sizing.halign == .center
	assert cmd.kitty_text_sizing.text == 'long'
}

fn test_osc66_ignores_fields_after_second_equals() {
	mut p := Parser.init(unsafe { nil })
	for ch in '66;s=2=ignored;payload'.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd.cmd_type == .kitty_text_sizing
	assert cmd.kitty_text_sizing.scale == 2
	assert cmd.kitty_text_sizing.text == 'payload'
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
	assert cmd.kitty_text_sizing.scale == 1
}

fn test_osc66_invalid_parameters_keep_defaults() {
	mut p := Parser.init(unsafe { nil })
	for ch in '66;w=8:v=3:n=16;'.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd.cmd_type == .kitty_text_sizing
	assert cmd.kitty_text_sizing.width == 0
	assert cmd.kitty_text_sizing.valign == .top
	assert cmd.kitty_text_sizing.numerator == 0
}

fn test_osc66_zero_with_leading_zero_is_valid() {
	mut p := Parser.init(unsafe { nil })
	for ch in '66;w=3:w=00;reset'.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd.kitty_text_sizing.width == 0
}

fn test_osc66_numeric_fields_use_zig_parse_int_grammar() {
	mut p := Parser.init(unsafe { nil })
	for ch in '66;s=+2:w=-0:n=1__5;payload'.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd.kitty_text_sizing.scale == 2
	assert cmd.kitty_text_sizing.width == 0
	assert cmd.kitty_text_sizing.numerator == 15
}

fn test_osc66_utf8() {
	mut p := Parser.init(unsafe { nil })
	input := '66;;👻魑魅魍魉ゴースッティ'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd.cmd_type == .kitty_text_sizing
	assert cmd.kitty_text_sizing.text == '👻魑魅魍魉ゴースッティ'
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
