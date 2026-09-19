module cli_args

fn test_comma_splitter_basics() {
	mut splitter := CommaSplitter.init('a,b,c')
	a := splitter.next()!
	b := splitter.next()!
	c := splitter.next()!
	assert a == 'a'
	assert b == 'b'
	assert c == 'c'
	assert !splitter.has_next()
}

fn test_comma_splitter_quoted_and_escaped_values() {
	mut splitter := CommaSplitter.init('"a,b",c\\x2ed')
	a := splitter.next()!
	b := splitter.next()!
	assert a == '"a,b"'
	assert b == 'c\\x2ed'
	assert !splitter.has_next()
}

fn test_comma_splitter_rest() {
	mut splitter := CommaSplitter.init('a,b,c')
	a := splitter.next()!
	assert a == 'a'
	assert splitter.rest() or { '' } == 'b,c'
	assert splitter.rest() == none
}

fn test_comma_splitter_errors() {
	mut unfinished := CommaSplitter.init('\\x5')
	if _ := unfinished.next() {
		assert false, 'expected unfinished escape'
	} else {
		assert err.msg() == 'unfinished escape'
	}

	mut illegal := CommaSplitter.init('\\q')
	if _ := illegal.next() {
		assert false, 'expected illegal escape'
	} else {
		assert err.msg() == 'illegal escape'
	}

	mut unclosed := CommaSplitter.init('"abc')
	if _ := unclosed.next() {
		assert false, 'expected unclosed quote'
	} else {
		assert err.msg() == 'unclosed quote'
	}
}
