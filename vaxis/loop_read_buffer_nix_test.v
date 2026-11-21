module vaxis

fn read_buffer_test_key(result ParserResult) Key {
	event := result.event or { panic('expected key') }
	if event is Key { return event }
	panic('expected key press')
}

fn test_loop_read_buffer_handles_one_read_without_tty_pending_storage() {
	mut reader := LoopReadBuffer{}
	mut parser := Parser{}
	mut bytes := reader.read_buffer()
	assert bytes.len == 1024
	assert bytes.data == &reader.buf[0]
	input := 'a\x1b[5n\x1b[A'.bytes()
	copy(mut bytes, input)
	reader.begin_read(uint(input.len))
	first := reader.parse_next(mut parser, false)!
	assert first.n == 1
	assert read_buffer_test_key(first).codepoint == `a`
	ignored := reader.parse_next(mut parser, false)!
	assert ignored.event == none
	assert ignored.n == 4
	last := reader.parse_next(mut parser, false)!
	assert read_buffer_test_key(last).codepoint == up
	assert !reader.has_next()
	assert reader.read_start == 0
}

fn test_loop_read_buffer_preserves_pinned_incomplete_offset_and_read_count() {
	mut reader := LoopReadBuffer{}
	mut parser := Parser{}
	mut bytes := reader.read_buffer()
	copy(mut bytes, 'a\x1b['.bytes())
	reader.begin_read(3)
	assert read_buffer_test_key(reader.parse_next(mut parser, false)!).codepoint == `a`
	incomplete := reader.parse_next(mut parser, false)!
	assert incomplete.n == 0
	assert !reader.has_next()
	assert reader.read_start == 3 // Source preserves length + 1, including a gap.
	assert reader.buf[..3] == [u8(27), `[`, `[`]
	bytes = reader.read_buffer()
	assert bytes.len == 1021
	assert bytes.data == unsafe { &reader.buf[0] + 3 }
	copy(mut bytes, 'Axyz'.bytes())
	reader.begin_read(4) // Source counts only this read, omitting the prefix size.
	unknown := reader.parse_next(mut parser, false)!
	assert unknown.n == 3
	assert unknown.event == none
	assert read_buffer_test_key(reader.parse_next(mut parser, false)!).codepoint == `A`
	assert !reader.has_next() // x, y, z lie beyond the pinned read boundary.
	assert reader.read_start == 0
}

fn test_loop_read_buffer_error_propagation_and_zero_read() {
	mut reader := LoopReadBuffer{}
	mut parser := Parser{}
	reader.read_start = 4
	reader.begin_read(0)
	assert !reader.has_next()
	assert reader.read_start == 4
	reader.read_start = 0
	mut bytes := reader.read_buffer()
	input := '\x1b]11;invalid\x07'.bytes()
	copy(mut bytes, input)
	reader.begin_read(uint(input.len))
	reader.parse_next(mut parser, false) or {
		assert err.msg() == 'InvalidColorSpec'
		return
	}
	assert false
}
