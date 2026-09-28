module vaxis

fn test_pretty_print_primary_screen_and_default_cells() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols: 3
		rows: 1
	})
	vx.screen.write_cell(0, 0, Cell{
		char_: CellCharacter{
			grapheme: 'a'
		}
	})
	vx.screen.write_cell(1, 0, Cell{
		default_: true
	})
	vx.screen.write_cell(2, 0, Cell{
		char_: CellCharacter{
			grapheme: 'b'
		}
	})
	assert vx.pretty_print()! == '\x1b[?25l\x1b[?2026h\x1b[ma\x1b[1Cb\r\n\x1b[m\x1b[?2026l'
	assert vx.screen_last.buf[0].default_
	vx.enter_alt_screen()
	blocked := vx.pretty_print() or {
		assert err.msg() == 'NotInPrimaryScreen'
		''
	}
	assert blocked == ''
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_pretty_print_style_and_link() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols: 1
		rows: 1
	})
	vx.screen.write_cell(0, 0, Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
		style: Style{
			fg:     ColorIndex{
				index: 2
			}
			italic: true
		}
		link:  CellHyperlink{
			uri: 'https://example.com'
		}
	})
	assert vx.pretty_print()! == '\x1b[?25l\x1b[?2026h\x1b[m\x1b[32m\x1b[3m' +
		'\x1b]8;;https://example.com\x1b\\x\r\n\x1b[m\x1b[?2026l'
	vx.screen.deinit()
	vx.screen_last.deinit()
}
