module vaxis

// Pinned Parser owns the scratch storage for CSI text-as-codepoints. Ground
// key text borrows the input; CSI text borrows buf until the next parse call.
pub struct Parser {
pub mut:
	buf [128]u8
}

pub struct ParserResult {
pub mut:
	event ?InputEvent @[required]
	n     uint       @[required]
}

// clipboard represents the source's optional paste allocator. Allocation
// itself uses V ownership, but an OSC 52 reply still requires it to be enabled.
pub fn (mut parser Parser) parse(input []u8, clipboard bool) !ParserResult {
	if input.len == 0 { panic('Assertion failed: input.len > 0') }
	parsed := if input.len > 1 && input[0] == 27 && input[1] == `]` {
		parse_osc(input, clipboard)!
	} else {
		decode_input(input, mut parser, true) or { ParsedInput{} }
	}
	return ParserResult{
		event: parsed.event
		n:     uint(parsed.consumed)
	}
}

fn (mut parser Parser) parse_codepoint_text(raw string) ?string {
	mut total := 0
	for part in raw.split(':') {
		cp := parse_param_u21(part) or { return none }
		if cp > 0x10ffff { return none }
		// utf8Encode checks the output capacity before rejecting surrogate halves.
		length := if cp < 0x80 {
			1
		} else if cp < 0x800 {
			2
		} else if cp < 0x10000 {
			3
		} else {
			4
		}
		if length > parser.buf.len - total { panic('Assertion failed: out.len >= length') }
		if cp >= 0xd800 && cp <= 0xdfff { return none }
		encoded := rune(cp).str()
		for i in 0 .. encoded.len {
			parser.buf[total + i] = encoded[i]
		}
		total += encoded.len
	}
	return unsafe { tos(&parser.buf[0], total) }
}

// Keep the source's checked slice boundaries in production builds as well.
fn input_parser_slice(input []u8, start int, end int) []u8 {
	if start > end { panic('start index is larger than end index') }
	if start < 0 || end > input.len { panic('index out of bounds') }
	return input[start..end]
}

fn input_parser_sub32(value u8) u16 {
	if value < 32 { panic('integer overflow') }
	return u16(value - 32)
}

// std.fmt.parseUnsigned's fixed-base path, including embedded underscores,
// rejection of signs, and its distinct character/overflow errors.
fn parse_input_unsigned(raw string, base u8, bits u8) !u64 {
	if raw.len == 0 || raw[0] == `_` || raw[raw.len - 1] == `_` {
		return error('InvalidCharacter')
	}
	limit := (u64(1) << bits) - 1
	mut value := u64(0)
	for c in raw {
		if c == `_` { continue
		 }
		digit := match c {
			`0`...`9` { c - `0` }
			`a`...`z` { c - `a` + 10 }
			`A`...`Z` { c - `A` + 10 }
			else { return error('InvalidCharacter') }
		}

		if digit >= base { return error('InvalidCharacter') }
		if value > limit / base { return error('Overflow') }
		value *= base
		if u64(digit) > limit - value { return error('Overflow') }
		value += u64(digit)
	}
	return value
}

// std.base64.standard.Decoder: do not accept the URL alphabet, whitespace,
// missing padding, or nonzero trailing bits as V's permissive decoder does.
fn decode_clipboard_base64(source []u8) !string {
	if source.len % 4 != 0 { return error('InvalidPadding') }
	mut result := []u8{cap: source.len / 4 * 3}
	mut acc := u32(0)
	mut acc_len := u8(0)
	mut leftover := source.len
	for i, c in source {
		digit := match c {
			`A`...`Z` { c - `A` }
			`a`...`z` { c - `a` + 26 }
			`0`...`9` { c - `0` + 52 }
			`+` { u8(62) }
			`/` { u8(63) }
			else { u8(255) }
		}

		if digit == 255 {
			if c != `=` { return error('InvalidCharacter') }
			leftover = i
			break
		}
		acc = (acc << 6) + u32(digit)
		acc_len += 6
		if acc_len >= 8 {
			acc_len -= 8
			result << u8(acc >> acc_len)
		}
	}
	if acc_len > 4 || (acc & ((u32(1) << acc_len) - 1)) != 0 {
		return error('InvalidPadding')
	}
	if leftover < source.len {
		for c in source[leftover..] {
			if c != `=` {
				// Preserve the source decoder's check on the raw byte here.
				return error(if c == 255 { 'InvalidCharacter' } else { 'InvalidPadding' })
			}
		}
		if source.len - leftover != int(acc_len / 2) { return error('InvalidPadding') }
	}
	return result.bytestr()
}
