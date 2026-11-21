module vaxis

fn test_text_input_inserts_clusters_with_source_gap_geometry() {
	mut input := TextInput.new()
	input.insert_slice_at_cursor('abc')
	assert input.get_text() == 'abc'
	assert input.buf.buffer.len == 513
	assert input.buf.cursor == 3
	assert input.buf.gap_size == 510
	input.cursor_left()
	input.insert_slice_at_cursor('é👩‍🚀')
	assert input.get_text() == 'abé👩‍🚀c'
	assert input.slice_to_cursor() == 'abé👩‍🚀'
	assert input.buf.buffer.len == 513
	input.deinit()
}

fn test_text_input_gap_movement_preserves_inserted_suffix() {
	mut buffer := TextInputBuffer.new()
	buffer.insert_slice_at_cursor('abcdef')
	buffer.move_gap_left(4)
	buffer.move_gap_right(3)
	assert buffer.first_half().bytestr() == 'abcde'
	assert buffer.second_half().bytestr() == 'f'
	buffer.insert_slice_at_cursor('!')
	assert buffer.string() == 'abcde!f'
	buffer.deinit()
}

fn test_text_input_left_gap_growth_adds_full_amount_before_saturating_cursor() {
	mut buffer := TextInputBuffer.new()
	buffer.insert_slice_at_cursor('abc')
	previous_gap := buffer.gap_size
	buffer.grow_gap_left(5)
	assert buffer.cursor == 0
	assert buffer.gap_size == previous_gap + 5
	// The source deliberately leaves this state larger than the allocation.
	buffer.deinit()
}

fn test_text_input_zero_width_draw_updates_scroll_without_screen_writes() {
	mut screen := Screen.new(Winsize{ cols: 8, rows: 1 })
	mut input := TextInput.new()
	input.insert_slice_at_cursor('abcdef')
	input.draw_in_window(Window.new(&screen).child(WindowChildOptions{ width: 3 }))
	assert input.draw_offset == 4
	input.update(Key{ codepoint: home })
	before := screen.buf.clone()
	previous_col := input.prev_cursor_col
	previous_idx := input.prev_cursor_idx
	input.draw_in_window_with_style(Window.new(&screen).child(WindowChildOptions{ width: 0 }), Style{
		bold: true
	})
	assert input.draw_offset == 0
	assert input.prev_cursor_col == previous_col
	assert input.prev_cursor_idx == previous_idx
	assert screen.buf == before
	assert screen.cursor_col == 2
	input.deinit()
	screen.deinit()
}

fn test_text_input_edits_and_draws_malformed_bytes_with_source_consumption() {
	mut input := TextInput.new()
	input.insert_slice_at_cursor([u8(0xff), `a`].bytestr())
	assert input.graphemes_before_cursor() == 2
	mut screen := Screen.new(Winsize{ cols: 5, rows: 1 })
	screen.width_method = .unicode
	input.draw_in_window(Window.new(&screen))
	first := screen.read_cell(0, 0) or { panic('missing cell') }
	assert first.char_.grapheme.bytes() == [u8(0xff)]
	assert first.char_.width == 1
	assert screen.cursor_col == 2
	input.cursor_left()
	assert input.byte_offset_to_cursor() == 1
	input.delete_before_cursor()
	assert input.get_text() == 'a'
	assert input.byte_offset_to_cursor() == 0
	input.cursor_right()
	assert input.byte_offset_to_cursor() == 1
	input.clear_retaining_capacity()
	input.insert_slice_at_cursor([u8(0xf0), 0x9f].bytestr())
	input.update(Key{ codepoint: home })
	input.delete_after_cursor()
	assert input.get_text() == ''
	input.deinit()
	screen.deinit()
}

fn test_text_input_preserves_last_returning_grapheme_count() {
	mut input := TextInput.new()
	input.buf.insert_slice_at_cursor('a'.repeat(65535))
	assert input.graphemes_before_cursor() == 65535
	input.draw_offset = 65534
	assert input.width_to_cursor() == 1
	input.deinit()
}

fn test_text_input_caller_buffer_keeps_tail_and_borrows_returned_prefix() {
	mut input := TextInput.new()
	input.insert_slice_at_cursor('ab界c')
	input.cursor_left()
	mut bytes := []u8{len: 9, init: 0xa5}
	mut prefix := input.slice_to_cursor_into(mut bytes)
	assert prefix.bytestr() == 'ab界'
	assert uint(prefix.data) == uint(bytes.data)
	assert bytes[5..] == [u8(0xa5), 0xa5, 0xa5, 0xa5]
	prefix[0] = `X`
	assert bytes[0] == `X` && input.get_text() == 'ab界c'
	input.buf.move_gap_left(input.buf.cursor)
	assert input.slice_to_cursor_into(mut bytes).len == 0
	assert bytes[0] == `X`
	input.deinit()
}
