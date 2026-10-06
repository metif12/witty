module vaxis

fn parser_fidelity_key(result ParserResult) Key {
	event := result.event or { panic('missing key') }
	if event is Key { return event }
	panic('expected key')
}

fn test_parser_public_inline_buffer_and_mutable_result_copy() {
	mut parser := Parser{
		buf: [128]u8{init: 17}
	}
	mut copied := parser
	parser.buf[0] = 42
	copied.buf[1] = 99
	assert copied.buf[0] == 17
	assert parser.buf[1] == 17
	mut result := ParserResult{
		event: none
		n:     7
	}
	mut old := result
	result.n = 9
	old.event = none
	assert old.n == 7
	assert result.n == 9
}

fn test_parser_exact_scratch_capacity_and_unicode_error_order() {
	mut parser := Parser{
		buf: [128]u8{init: 17}
	}
	full := '\x1b[97;;' + []string{len: 32, init: '65536'}.join(':') + 'u'
	key := parser_fidelity_key(parser.parse(full.bytes(), false)!)
	assert (key.text or { panic('missing text') }).len == 128
	assert parser.buf[0] == 0xf0
	assert parser.buf[127] == 0x80
	// CodepointTooLarge is returned before utf8Encode checks capacity.
	invalid := '\x1b[97;;' + '97:'.repeat(128) + '1114112u'
	assert parser.parse(invalid.bytes(), false)!.event == none
	for byte in parser.buf {
		assert byte == `a`
	}
	// A surrogate with enough capacity returns no event after prior writes.
	assert parser.parse('\x1b[97;;120:55296u'.bytes(), false)!.event == none
	assert parser.buf[0] == `x`
	assert parser.buf[1] == `a`
}

fn test_parser_raw_apc_da1_and_mouse_success_boundaries() {
	mut parser := Parser{}
	assert parser.parse('\x1b_G\x1bQtail'.bytes(), false)!.n == 5
	assert parser.parse('\x1bPdiscard\x1b'.bytes(), false)!.n == 0
	da1 := parser.parse('\x1b[?c'.bytes(), false)!.event or { panic('missing DA1') }
	assert da1 is CapabilityEvent
	assert parser.parse('\x1b[1c'.bytes(), false)!.event == none
	for mask in [0, 3, 64, 128, 131, 256, 448] {
		result := parser.parse('\x1b[<${mask};0;65535M'.bytes(), false)!
		event := result.event or { panic('missing mouse') }
		if mask >= 256 {
			assert event is MouseLeave
		} else {
			assert event is Mouse
			if event is Mouse {
				assert event.col == 0
				assert event.row == 65534
			}
		}
	}
	legacy := parser.parse([u8(27), `[`, `M`, 32, 32, 255], false)!.event or {
		panic('missing legacy mouse')
	}

	assert legacy is Mouse
	if legacy is Mouse {
		assert legacy.col == 0
		assert legacy.row == 222
	}
}

fn test_parser_public_scratch_mutation_reaches_borrowed_text() {
	mut parser := Parser{
		buf: [128]u8{init: 17}
	}
	key := parser_fidelity_key(parser.parse('\x1b[97;;97:98u'.bytes(), false)!)
	text := key.text or { panic('missing text') }
	parser.buf[0] = `Q`
	assert text == 'Qb'
	assert parser.parse('\x1b[97;;120:55296u'.bytes(), false)!.event == none
	assert text == 'xb'
}
