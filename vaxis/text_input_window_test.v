module vaxis

fn test_text_input_draws_into_window_and_positions_cursor() {
	mut screen := Screen.new(Winsize{
		cols: 5
		rows: 1
	})
	win := Window.new(&screen)
	mut input := TextInput.new()
	input.insert_slice_at_cursor('ab')
	input.draw_in_window_with_style(win, Style{
		bold: true
	})
	first := screen.read_cell(0, 0) or { panic('missing cell') }
	second := screen.read_cell(1, 0) or { panic('missing cell') }
	assert first.char_.grapheme == 'a'
	assert first.char_.width == 1
	assert first.style.bold
	assert second.char_.grapheme == 'b'
	assert screen.cursor_vis
	assert screen.cursor_col == 2
	input.deinit()
	screen.deinit()
}
