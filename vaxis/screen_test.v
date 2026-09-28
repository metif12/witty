module vaxis

fn test_cell_scale_retains_pinned_packed_fields() {
	assert sizeof(CellScale) == 2
	default_scale := CellScale{}
	assert default_scale.scale() == 1
	assert default_scale.numerator() == 1
	assert default_scale.denominator() == 1
	assert default_scale.vertical_alignment() == .top
	assert default_scale.eql(CellScale.init(1, 1, 1, .top))
	assert !default_scale.eql(CellScale.init(2, 1, 1, .top))
	centered := CellScale.init(7, 3, 4, .center)
	assert centered.scale() == 7
	assert centered.numerator() == 3
	assert centered.denominator() == 4
	assert centered.vertical_alignment() == .center
}

fn test_screen_source_cell_and_bounds_contract() {
	mut screen := Screen.new(Winsize{ cols: 3, rows: 2, x_pixel: 30, y_pixel: 40 })
	assert screen.width == 3
	assert screen.height == 2
	assert screen.width_pix == 30
	assert screen.height_pix == 40
	assert screen.buf.len == 6
	assert screen.width_method == .wcwidth
	assert (screen.read_cell(0, 0) or { panic('cell missing') }).char_.grapheme == ' '
	assert screen.read_cell(3, 0) == none
	assert screen.read_cell(0, 2) == none

	marked := Cell{
		char_:   CellCharacter{
			grapheme: '界'
			width:    2
		}
		wrapped: true
	}
	screen.write_cell(2, 1, marked)
	screen.write_cell(3, 1, marked)
	assert (screen.read_cell(2, 1) or { panic('cell missing') }).char_.grapheme == '界'
	assert (screen.read_cell(2, 1) or { panic('cell missing') }).wrapped
	screen.clear()
	assert (screen.read_cell(2, 1) or { panic('cell missing') }).char_.grapheme == ' '
	screen.deinit()
	assert screen.buf.len == 0
}
