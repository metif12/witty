module vaxis

// Draw the already translated TextInput cell sequence into a Window, using
// the window's negotiated width method as pinned TextInput.drawWithStyle does.
pub fn (mut input TextInput) draw_in_window_with_style(win Window, style Style) {
	result := input.draw_with_style_method(int(win.width), style, win.screen.width_method)
	if win.width == 0 {
		return
	}
	for cell in result.cells {
		width := text_input_gwidth(cell.text, win.screen.width_method)
		win.write_cell(cell.col, 0, Cell{
			char_: CellCharacter{
				grapheme: cell.text
				width:    u8(width)
			}
			style: style
		})
	}
	win.show_cursor(result.cursor_col, 0)
}

pub fn (mut input TextInput) draw_in_window(win Window) {
	input.draw_in_window_with_style(win, Style{})
}
