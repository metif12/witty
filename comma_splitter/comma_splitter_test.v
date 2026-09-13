module comma_splitter

fn test_parser_state_source_layouts_and_ordinals() {
	assert sizeof(State) == 1
	assert [State.normal, .quoted, .escape, .hexescape, .unicodeescape].map(u8(it)) == [
		u8(0),
		1,
		2,
		3,
		4,
	]
	assert sizeof(UnicodeEscapeState) == 1
	assert [UnicodeEscapeState.start, .digits].map(u8(it)) == [u8(0), 1]
}

fn test_splitter_simple() {
	mut s := CommaSplitter.init('a,b,c')
	assert s.next()? == 'a'
	assert s.next()? == 'b'
	assert s.next()? == 'c'
	assert s.next() == none
}

fn test_splitter_empty() {
	mut s := CommaSplitter.init('')
	assert s.next() == none
}

fn test_splitter_single() {
	mut s := CommaSplitter.init('a')
	assert s.next()? == 'a'
	assert s.next() == none
}

fn test_splitter_hex_escape() {
	mut s := CommaSplitter.init('\\x5a')
	assert s.next()? == '\\x5a'
	assert s.next() == none
}

fn test_splitter_single_quotes_not_special() {
	// Single quotes are not special, they do not begin a quoted block.
	mut s := CommaSplitter.init("'a',b")
	assert s.next()? == "'a'"
	assert s.next()? == 'b'
	assert s.next() == none
}

fn test_splitter_single_quotes_with_comma() {
	// Single quotes don't protect commas.
	mut s := CommaSplitter.init("'a,b',c")
	assert s.next()? == "'a"
	assert s.next()? == "b'"
	assert s.next()? == 'c'
	assert s.next() == none
}

fn test_splitter_double_quotes() {
	// Double quotes protect commas.
	mut s := CommaSplitter.init('"a,b",c')
	assert s.next()? == '"a,b"'
	assert s.next()? == 'c'
	assert s.next() == none
}

fn test_splitter_whitespace_preserved() {
	mut s := CommaSplitter.init(' a , b ')
	assert s.next()? == ' a '
	assert s.next()? == ' b '
	assert s.next() == none
}

fn test_splitter_unfinished_hex_escape() {
	mut s := CommaSplitter.init('\\x')
	assert s.next() == none
	assert s.last_error == 'unfinished escape'
}

fn test_splitter_partial_hex_escape() {
	mut s := CommaSplitter.init('\\x5')
	assert s.next() == none
	assert s.last_error == 'unfinished escape'
}

fn test_splitter_unfinished_unicode_escape() {
	mut s := CommaSplitter.init('\\u')
	assert s.next() == none
	assert s.last_error == 'unfinished escape'
}

fn test_splitter_unicode_escape_unclosed_brace() {
	mut s := CommaSplitter.init('\\u{')
	assert s.next() == none
	assert s.last_error == 'unfinished escape'
}

fn test_splitter_unicode_escape_empty_braces() {
	mut s := CommaSplitter.init('\\u{}')
	assert s.next() == none
	assert s.last_error == 'illegal escape'
}

fn test_splitter_unicode_escape_invalid_digit() {
	mut s := CommaSplitter.init('\\u{h1}')
	assert s.next() == none
	assert s.last_error == 'illegal escape'
}

fn test_splitter_unicode_escape_max_valid() {
	mut s := CommaSplitter.init('\\u{10ffff}')
	assert s.next()? == '\\u{10ffff}'
	assert s.next() == none
}

fn test_splitter_unicode_escape_overflow() {
	mut s := CommaSplitter.init('\\u{110000}')
	assert s.next() == none
	assert s.last_error == 'illegal escape'
}

fn test_splitter_illegal_escape_char() {
	mut s := CommaSplitter.init('\\d')
	assert s.next() == none
	assert s.last_error == 'illegal escape'
}

fn test_splitter_valid_escapes() {
	mut s := CommaSplitter.init('\\n\\r\\t\\"\\\'\\\\' + '')
	assert s.next()? == '\\n\\r\\t\\"\\\'\\\\'
	assert s.next() == none
}

fn test_splitter_quotes_with_single_quotes_inside() {
	mut s := CommaSplitter.init('"abc\'def\'ghi"')
	assert s.next()? == '"abc\'def\'ghi"'
	assert s.next() == none
}

fn test_splitter_quoted_comma() {
	mut s := CommaSplitter.init('",",abc')
	assert s.next()? == '","'
	assert s.next()? == 'abc'
	assert s.next() == none
}

fn test_splitter_single_quotes_list() {
	mut s := CommaSplitter.init("'a','b', 'c'")
	assert s.next()? == "'a'"
	assert s.next()? == "'b'"
	assert s.next()? == " 'c'"
	assert s.next() == none
}

fn test_splitter_unclosed_quote() {
	mut s := CommaSplitter.init('abc"def')
	assert s.next() == none
	assert s.last_error == 'unclosed quote'
}

fn test_splitter_complex_quoted_fields() {
	mut s := CommaSplitter.init('title:"Focus Split: Up",description:"Focus the split above, if it exists.",action:goto_split:up')
	assert s.next()? == 'title:"Focus Split: Up"'
	assert s.next()? == 'description:"Focus the split above, if it exists."'
	assert s.next()? == 'action:goto_split:up'
	assert s.next() == none
}

fn test_splitter_rest() {
	mut s := CommaSplitter.init('a,b,c,def')
	assert s.next()? == 'a'
	assert s.next()? == 'b'
	assert s.rest()? == 'c,def'
	assert s.next() == none
}

fn test_splitter_unicode_escape_with_comma() {
	mut s := CommaSplitter.init('a,\\u{10,df}')
	assert s.next()? == 'a'
	assert s.next() == none
	assert s.last_error == 'illegal escape'
}

fn test_splitter_unicode_escape_range_uses_source_accumulator() {
	mut lowercase := CommaSplitter.init('\\u{1aaaaa}')
	assert lowercase.next()? == '\\u{1aaaaa}'
	assert lowercase.next() == none

	mut uppercase := CommaSplitter.init('\\u{1AAAAA}')
	assert uppercase.next()? == '\\u{1AAAAA}'
	assert uppercase.next() == none
}
