module vaxis

fn test_internal_screen_retains_source_defaults_and_comparison() {
	mut screen := InternalScreen.new(2, 2)
	assert screen.buf.len == 4
	assert screen.buf[0].char_ == ' '
	assert screen.buf[0].default_
	assert screen.buf[0].eql(Cell{
		default_: true
		char_:    CellCharacter{
			grapheme: 'x'
		}
	})
	assert !screen.buf[0].eql(Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	cell := Cell{
		char_:    CellCharacter{
			grapheme: '界'
		}
		link:     CellHyperlink{
			uri:    'https://example.com'
			params: 'id=1'
		}
		default_: false
	}
	screen.write_cell(1, 1, cell)
	assert screen.buf[3].eql(cell)
	read := screen.read_cell(1, 1) or { panic('missing internal cell') }
	assert read.char_.grapheme == '界'
	assert read.link.uri == 'https://example.com'
	assert read.link.params == 'id=1'
	assert screen.read_cell(3, 0) == none
	screen.deinit()
	assert screen.buf.len == 0
}
