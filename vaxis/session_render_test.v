module vaxis

fn test_session_render_retains_cells_and_only_draws_changes() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols: 2
		rows: 1
	})
	vx.enter_alt_screen()
	assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m\x1b[?2026l'
	assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m\x1b[?2026l'
	vx.screen.write_cell(1, 0, Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m\x1b[1;2Hx\x1b[?2026l'
	vx.queue_refresh()
	assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m x\x1b[?2026l'
	assert !vx.refresh
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_session_render_style_link_and_explicit_width() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols: 3
		rows: 1
	})
	vx.enter_alt_screen()
	vx.caps.explicit_width = true
	vx.screen.write_cell(0, 0, Cell{
		char_: CellCharacter{
			grapheme: '界'
			width:    2
		}
		style: Style{
			fg:   ColorIndex{
				index: 9
			}
			bold: true
		}
		link:  CellHyperlink{
			uri:    'https://example.com'
			params: 'id=one'
		}
	})
	vx.screen.write_cell(2, 0, Cell{
		char_: CellCharacter{
			grapheme: 'z'
		}
	})
	assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m\x1b[91m\x1b[1m' +
		'\x1b]8;id=one;https://example.com\x1b\\\x1b]66;w=2;界\x1b\\' +
		'\x1b[39m\x1b[22m\x1b]8;;\x1b\\z\x1b[?2026l'
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_session_render_cursor_and_mouse_shape() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols: 1
		rows: 1
	})
	vx.enter_alt_screen()
	vx.screen.cursor_vis = true
	vx.screen.mouse_shape = .pointer
	vx.screen.cursor_shape = .beam
	assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m\x1b[1;1H\x1b[?25h' +
		'\x1b]22;pointer\x1b\\\x1b[6 q\x1b[?2026l'
	assert vx.screen_last.mouse_shape == .pointer
	assert vx.screen_last.cursor_shape == .beam
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_session_render_scaled_text_and_image_placement() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols: 2
		rows: 2
	})
	vx.enter_alt_screen()
	vx.caps.scaled_text = true
	vx.screen.write_cell(0, 0, Cell{
		char_: CellCharacter{
			grapheme: 'X'
		}
		scale: CellScale.init(2, 1, 1, .top)
		image: ImagePlacement{
			img_id:  7
			options: ImageDrawOptions{
				pixel_offset: ImagePixelOffset{
					x: 3
					y: 4
				}
				z_index:      2
			}
		}
	})
	assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m' +
		'\x1b_Ga=p,i=7,X=3,Y=4,z=2,C=1\x1b\\\x1b]66;s=2:w=1;X\x1b\\' +
		'\x1b[?2026l'
	assert vx.screen_last.buf[1].skip
	assert vx.screen_last.buf[2].skip
	assert vx.screen_last.buf[3].skip
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_session_render_sgr_deltas_match_pinned_sequences() {
	before := Style{
		bold: true
		dim:  true
	}
	after := Style{
		fg:       ColorRgb{
			rgb: [u8(1), 2, 3]!
		}
		ul:       ColorRgb{
			rgb: [u8(4), 5, 6]!
		}
		ul_style: .double_
		dim:      true
	}
	assert render_style_delta(before, after, .standard, true) == '\x1b[38:2:1:2:3m' +
		'\x1b[58:2::4:5:6m\x1b[4:2m\x1b[22m\x1b[2m'
	assert render_style_delta(Style{}, after, .legacy, false) == '\x1b[38;2;1;2;3m' +
		'\x1b[58;2;4;5;6m\x1b[4:2m\x1b[2m'
}
