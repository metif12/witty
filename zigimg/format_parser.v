module zigimg

// std.fmt.Parser and ArgState in the pinned Zig 0.15.2 library.
pub struct FormatNone {}

pub struct FormatNumber {
pub mut:
	value usize @[required]
}

pub struct FormatNamed {
pub mut:
	bytes []u8 @[required]
}

pub type FormatSpecifier = FormatNamed | FormatNone | FormatNumber

// bytes and named/until results borrow their caller's storage.
pub struct FormatParser {
pub mut:
	bytes []u8  @[required]
	i     usize @[required]
}

pub fn (parser FormatParser) peek(offset usize) ?u8 {
	if offset > ~usize(0) - parser.i { panic('integer overflow') }
	index := parser.i + offset
	if index >= usize(parser.bytes.len) { return none }
	return parser.bytes[int(index)]
}

pub fn (mut parser FormatParser) number() ?usize {
	mut result := ?usize(none)
	for {
		byte := parser.peek(0) or { break }
		if byte < `0` || byte > `9` { break
		 }
		mut value := result or { usize(0) }
		if value > ~usize(0) / 10 { panic('integer overflow') }
		value *= 10
		digit := usize(byte - `0`)
		if value > ~usize(0) - digit { panic('integer overflow') }
		value += digit
		result = value
		parser.i++
	}
	return result
}

pub fn (mut parser FormatParser) until(delimiter u8) []u8 {
	start := parser.i
	mut end := start
	for end < usize(parser.bytes.len) && parser.bytes[int(end)] != delimiter {
		end++
	}
	parser.i = if end < usize(parser.bytes.len) { end } else { usize(parser.bytes.len) }
	if start > parser.i { panic('start index ${start} is larger than end index ${parser.i}') }
	return unsafe { parser.bytes[int(start)..int(parser.i)] }
}

pub fn (mut parser FormatParser) char() ?u8 {
	index := parser.i
	if index > usize(parser.bytes.len) { panic('integer overflow') }
	if usize(parser.bytes.len) - index == 0 { return none }
	parser.i = index + 1
	return parser.bytes[int(index)]
}

pub fn (mut parser FormatParser) maybe(byte u8) bool {
	if next := parser.peek(0) {
		if next == byte {
			parser.i++
			return true
		}
	}
	return false
}

pub fn (mut parser FormatParser) specifier() !FormatSpecifier {
	if parser.maybe(`[`) {
		name := parser.until(`]`)
		if !parser.maybe(`]`) { return error('Expected closing ]') }
		return FormatNamed{
			bytes: unsafe { name }
		}
	}
	if value := parser.number() { return FormatNumber{
			value: value
		} }
	return FormatNone{}
}

pub struct FormatArgState {
pub mut:
	next_arg  usize
	used_args u32
	args_len  usize @[required]
}

pub fn (state FormatArgState) has_unused_args() bool {
	mut bits := state.used_args
	mut count := usize(0)
	for bits != 0 {
		count += usize(bits & 1)
		bits >>= 1
	}
	return count != state.args_len
}

pub fn (mut state FormatArgState) next_arg(arg_index ?usize) ?usize {
	mut index := usize(0)
	if explicit := arg_index {
		index = explicit
	} else {
		index = state.next_arg
		if state.next_arg == ~usize(0) { panic('integer overflow') }
		state.next_arg++
	}
	if index >= state.args_len { return none }
	if index >= 32 { panic('integer does not fit in destination type') }
	state.used_args |= u32(1) << u32(index)
	return index
}
