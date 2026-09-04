module internal_os

fn test_printf_q_decode() {
	assert printf_q_decode('bobr\\ kurwa')! == 'bobr kurwa'
	assert printf_q_decode('bobr\\nkurwa')! == 'bobr\nkurwa'
	assert printf_q_decode("\$'bobr kurwa'")! == 'bobr kurwa'
	assert printf_q_decode("'bobr kurwa'")! == 'bobr kurwa'
	assert printf_q_decode('\\e\\r\\t\\v\\\\\\"\\\'\\\$')! == '\x1b\r\t\v\\"\'\$'

	for invalid in ['bobr\\dkurwa', 'bobr kurwa\\', "\$'bobr kurwa", "\$'", "'bobr kurwa", "'"] {
		printf_q_decode(invalid) or {
			assert err.msg() == 'DecodeError'
			continue
		}
		assert false, 'expected invalid printf %q input: ${invalid}'
	}
}

fn test_url_percent_decode_all_byte_values() {
	hex_lower := '0123456789abcdef'
	hex_upper := '0123456789ABCDEF'
	for value in 0 .. 256 {
		lower := '%${hex_lower[value >> 4].ascii_str()}${hex_lower[value & 15].ascii_str()}'
		upper := '%${hex_upper[value >> 4].ascii_str()}${hex_upper[value & 15].ascii_str()}'
		assert url_percent_decode(lower)!.bytes() == [u8(value)]
		assert url_percent_decode(upper)!.bytes() == [u8(value)]
	}
}

fn test_url_percent_decode() {
	assert url_percent_decode('bobr%20kurwa')! == 'bobr kurwa'
	assert url_percent_decode('bobr%20kurwa%20')! == 'bobr kurwa '
	assert url_percent_decode('plus+sign')! == 'plus+sign'
	for invalid in ['bobr%2kurwa', 'bobr%kurwa', 'bobr%%kurwa', 'bobr%20kurwa%2', 'bobr%20kurwa%'] {
		url_percent_decode(invalid) or {
			assert err.msg() == 'DecodeError'
			continue
		}
		assert false, 'expected invalid percent encoding: ${invalid}'
	}
}

fn test_url_percent_encode_uses_osc_safe_alphabet() {
	assert url_percent_encode('hello world;key=value'.bytes()) == 'hello%20world%3Bkey%3Dvalue'
	assert url_percent_encode([u8(0), 0x1b, 0x7f, 0xff]) == '%00%1B%7F%FF'
	assert url_percent_encode('%+-._~'.bytes()) == '%+-._~'
	assert url_percent_decode(url_percent_encode('a b;c=d\x00'.bytes()))!.bytes() == 'a b;c=d\x00'.bytes()
}
