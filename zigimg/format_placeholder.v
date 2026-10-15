module zigimg

// The grammar and record of std.fmt.Placeholder; V parsing runs at runtime.
pub struct FormatPlaceholder {
pub mut:
	specifier_arg []u8            @[required]
	fill          u8              @[required]
	alignment     Alignment       @[required]
	arg           FormatSpecifier @[required]
	width         FormatSpecifier @[required]
	precision     FormatSpecifier @[required]
}

pub fn FormatPlaceholder.parse(bytes []u8) !FormatPlaceholder {
	// Source retains immutable compile-time storage. Own the V result's storage.
	owned := bytes.clone()
	mut parser := FormatParser{
		bytes: unsafe { owned }
		i:     0
	}
	arg := parser.specifier()!
	specifier_arg := parser.until(`:`).clone()
	if byte := parser.char() {
		if byte != `:` { return error('expected : or }, found ' + "'" + [byte].bytestr() + "'") }
	}
	mut fill := ?u8(none)
	if byte := parser.peek(1) {
		if byte in [`<`, `^`, `>`] { fill = parser.char() }
	}
	mut alignment := ?Alignment(none)
	if byte := parser.peek(0) {
		if byte in [`<`, `^`, `>`] {
			parser.char()
			alignment = match byte {
				`<` { Alignment.left }
				`^` { Alignment.center }
				else { Alignment.right }
			}
		}
	}
	if fill == none && alignment == none {
		if byte := parser.peek(0) {
			if byte == `0` { fill = byte }
		}
	}
	width := parser.specifier()!
	if byte := parser.char() {
		if byte != `.` { return error('expected . or }, found ' + "'" + [byte].bytestr() + "'") }
	}
	precision := parser.specifier()!
	if byte := parser.char() {
		return error('extraneous trailing character ' + "'" + [byte].bytestr() + "'")
	}
	return FormatPlaceholder{
		specifier_arg: specifier_arg
		fill:          fill or { u8(` `) }
		alignment:     alignment or { Alignment.right }
		arg:           arg
		width:         width
		precision:     precision
	}
}
