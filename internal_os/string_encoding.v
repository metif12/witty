module internal_os

// printf_q_decode decodes the subset of shell escaping produced by Bash's
// `printf %q`. The Zig implementation mutates a sentinel buffer in place;
// V strings are immutable, so the translated API returns the decoded copy.
pub fn printf_q_decode(value string) !string {
	mut data := value
	if data.starts_with("\$'") {
		if data.len < 3 || !data.ends_with("'") {
			return error('DecodeError')
		}
		data = data[2..data.len - 1]
	} else if data.starts_with("'") {
		if data.len < 2 || !data.ends_with("'") {
			return error('DecodeError')
		}
		data = data[1..data.len - 1]
	}

	mut result := []u8{cap: data.len}
	mut i := 0
	for i < data.len {
		if data[i] != `\\` {
			result << data[i]
			i++
			continue
		}
		if i + 1 >= data.len {
			return error('DecodeError')
		}
		escaped := data[i + 1]
		match escaped {
			` `, `\\`, `"`, `'`, `$` { result << escaped }
			`e` { result << u8(0x1b) }
			`n` { result << `\n` }
			`r` { result << `\r` }
			`t` { result << `\t` }
			`v` { result << u8(0x0b) }
			else {
				return error('DecodeError')
			}
		}
		i += 2
	}
	return result.bytestr()
}

// url_percent_decode decodes every percent triplet and rejects truncated or
// non-hexadecimal escapes. As in the source, plus signs are ordinary bytes.
pub fn url_percent_decode(value string) !string {
	mut result := []u8{cap: value.len}
	mut i := 0
	for i < value.len {
		if value[i] != `%` {
			result << value[i]
			i++
			continue
		}
		if i + 2 >= value.len {
			return error('DecodeError')
		}
		hi := string_encoding_hex(value[i + 1]) or { return error('DecodeError') }
		lo := string_encoding_hex(value[i + 2]) or { return error('DecodeError') }
		result << u8((hi << 4) | lo)
		i += 3
	}
	return result.bytestr()
}

// url_percent_encode applies Ghostty's OSC-safe URI component alphabet.
// Printable ASCII is retained except for space, semicolon, and equals.
pub fn url_percent_encode(data []u8) string {
	hex := '0123456789ABCDEF'
	mut result := []u8{cap: data.len}
	for byte in data {
		if byte >= 0x20 && byte <= 0x7e && byte !in [` `, `;`, `=`] {
			result << byte
		} else {
			result << `%`
			result << hex[int(byte >> 4)]
			result << hex[int(byte & 0x0f)]
		}
	}
	return result.bytestr()
}

fn string_encoding_hex(value u8) ?u8 {
	return match value {
		`0`...`9` { value - `0` }
		`a`...`f` { value - `a` + 10 }
		`A`...`F` { value - `A` + 10 }
		else { none }
	}
}
