module vaxis

fn parser_key(result ParserResult) Key {
	event := result.event or { panic('expected key') }
	if event is Key { return event }
	panic('expected key press')
}

fn test_parser_has_inline_scratch_and_borrows_ground_text() {
	assert sizeof(Parser) == 128
	mut parser := Parser{}
	mut bytes := 'ax'.bytes()
	result := parser.parse(bytes, false)!
	assert result.n == 1
	key := parser_key(result)
	assert key.codepoint == `a`
	text := key.text or { panic('missing text') }
	assert text.str == bytes.data
	bytes[0] = `z`
	assert text == 'z'
	incomplete := parser.parse('\x1b['.bytes(), false)!
	assert incomplete.n == 0
	assert incomplete.event == none
	unknown := parser.parse('\x1b[999z'.bytes(), false)!
	assert unknown.n == 6
	assert unknown.event == none
}

fn test_parser_csi_text_borrows_scratch_for_press_release_and_shift() {
	mut parser := Parser{}
	key := parser_key(parser.parse('\x1b[97;;97:98u'.bytes(), false)!)
	text := key.text or { panic('missing text') }
	assert text == 'ab'
	assert text.str == &parser.buf[0]
	release := parser.parse('\x1b[97;1:3;120:121u'.bytes(), false)!
	event := release.event or { panic('missing release') }
	assert event is KeyRelease
	if event is KeyRelease {
		assert event.key.text or { '' } == 'xy'
		assert (event.key.text or { '' }).str == &parser.buf[0]
	}
	assert text == 'xy'
	// The source writes earlier codepoints even if a later one invalidates the
	// sequence, so previously borrowed text observes that partial scratch write.
	assert parser.parse('\x1b[97;;122:55296u'.bytes(), false)!.event == none
	assert text == 'zy'
	shifted := parser_key(parser.parse('\x1b[97;2u'.bytes(), false)!)
	assert shifted.text or { '' } == 'A'
	assert (shifted.text or { '' }).str == &parser.buf[0]
	// All source scratch bytes are available, including an exact-size result.
	full := parser_key(parser.parse(('\x1b[97;;' + []string{len: 128, init: '98'}.join(':') + 'u').bytes(),
		false)!)
	assert (full.text or { '' }).len == 128
}

fn test_parser_uses_pinned_utf8_replacement_and_byte_consumption() {
	mut parser := Parser{}
	for bytes in [[u8(0x80)], [u8(0xe2), 0x82], [u8(0xe2), `x`],
		[u8(0xed), 0xa0]] {
		result := parser.parse(bytes, false)!
		assert result.n == uint(bytes.len)
		key := parser_key(result)
		assert key.codepoint == 0xfffd
		assert (key.text or { '' }).bytes() == bytes
	}
	// The decoder rejects the overlong sequence at byte two, then rejects the
	// next continuation bytes separately, as the pinned uucode test specifies.
	mut it := InputUtf8Iterator{
		bytes: [u8(0xf0), 0x80, 0x80, 0xaf]
	}
	assert (it.next() or { u32(0) }) == 0xfffd
	assert it.i == 2
	assert (it.next() or { u32(0) }) == 0xfffd
	assert it.i == 3
	assert (it.next() or { u32(0) }) == 0xfffd
	assert it.next() == none
}

fn test_parser_preserves_unsigned_parameter_contract() {
	mut parser := Parser{}
	key := parser_key(parser.parse('\x1b[97;1u'.bytes(), false)!)
	assert key.codepoint == `a`
	assert parse_input_unsigned('9_7', 10, 21)! == 97
	// '_' is a CSI final byte, so it ends the sequence before parameter parsing.
	assert parser.parse('\x1b[9_7u'.bytes(), false)!.event == none
	assert parser.parse('\x1b[+97u'.bytes(), false)!.event == none
	assert parser.parse('\x1b[65_536~'.bytes(), false)!.event == none
	assert parser.parse('\x1b[97;2_56u'.bytes(), false)!.event == none
	assert parse_input_unsigned('1__2', 10, 8)! == 12
	for invalid in ['', '_1', '1_', '+1', '-1'] {
		parse_input_unsigned(invalid, 10, 8) or {
			assert err.msg() == 'InvalidCharacter'
			continue
		}
		assert false
	}
}

fn test_parser_propagates_osc_color_and_clipboard_errors() {
	mut parser := Parser{}
	for invalid in ['\x1b]11;bad\x07', '\x1b]4;2;rgb:aaaa/bbbb/short\x1b\\'] {
		parser.parse(invalid.bytes(), false) or {
			assert err.msg() == 'InvalidColorSpec'
			continue
		}
		assert false
	}
	parser.parse('\x1b]10;rgb:aaZZ/bbbb/cccc\x07'.bytes(), false) or {
		assert err.msg() == 'InvalidCharacter'
		return
	}
	assert false
}

fn test_parser_clipboard_standard_base64_validation() {
	mut parser := Parser{}
	for encoded, expected in {
		'':     ''
		'YQ==': 'a'
		'YWI=': 'ab'
		'YWJj': 'abc'
	} {
		result := parser.parse(('\x1b]52;c;' + encoded + '\x07').bytes(), true)!
		event := result.event or { panic('missing paste') }
		assert event is Paste
		if event is Paste { assert event.text == expected
		 }
	}
	for encoded, expected in {
		'A':     'InvalidPadding'
		'AA':    'InvalidPadding'
		'AAA':   'InvalidPadding'
		'A..A':  'InvalidCharacter'
		'AA=A':  'InvalidPadding'
		'AA/=':  'InvalidPadding'
		'A/==':  'InvalidPadding'
		'A===':  'InvalidPadding'
		'====':  'InvalidPadding'
		'YWJ_':  'InvalidCharacter'
		'YWJ\n': 'InvalidCharacter'
	} {
		parser.parse(('\x1b]52;c;' + encoded + '\x07').bytes(), true) or {
			assert err.msg() == expected
			continue
		}
		assert false
	}
}
