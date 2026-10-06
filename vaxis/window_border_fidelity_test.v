module vaxis

fn test_window_border_custom_glyphs_borrow_bytes_and_force_one_cell_width() {
	mut bytes := 'ABCDEFGH'.bytes()
	glyphs := [
		unsafe { tos(bytes.data, 1) },
		unsafe { tos(&bytes[1], 2) },
		unsafe { tos(&bytes[3], 1) },
		unsafe { tos(&bytes[4], 2) },
		unsafe { tos(&bytes[6], 1) },
		unsafe { tos(&bytes[7], 1) },
	]!
	mut screen := Screen.new(Winsize{ cols: 3, rows: 3 })
	style := Style{
		bold:     true
		ul_style: .curly
		fg:       ColorIndex{
			index: 9
		}
	}
	child := Window.new(&screen).child(WindowChildOptions{
		border: WindowBorderOptions{
			where_: BorderAll{}
			glyphs: BorderCustom{
				glyphs: glyphs
			}
			style:  style
		}
	})
	assert child.width == 1 && child.height == 1 && child.x_off == 1 && child.y_off == 1
	assert screen.buf[1].char_.grapheme == 'BC'
	assert screen.buf[3].char_.grapheme == 'EF'
	assert screen.buf[1].char_.width == 1 && screen.buf[3].char_.width == 1
	assert screen.buf[1].char_.grapheme.str == unsafe { &bytes[1] }
	assert screen.buf[3].char_.grapheme.str == unsafe { &bytes[4] }
	assert screen.buf[1].style.eql(style)
	bytes[1] = `Z`
	bytes[4] = `Q`
	assert screen.buf[1].char_.grapheme == 'ZC'
	assert screen.buf[3].char_.grapheme == 'QF'
}

fn test_window_border_degenerate_corners_keep_last_source_write_and_defaults() {
	mut screen := Screen{
		width:  1
		height: 1
		buf:    [
			Cell{
				char_:    CellCharacter{
					grapheme: 'old'
					width:    3
				}
				link:     CellHyperlink{
					uri:    'old'
					params: 'id=old'
				}
				wrapped:  true
				default_: true
				scale:    CellScale.init(2, 3, 4, .bottom)
			},
		]
	}
	child := Window.new(&screen).child(WindowChildOptions{
		border: WindowBorderOptions{
			where_: BorderAll{}
			glyphs: BorderCustom{
				glyphs: ['A', 'H', 'B', 'V', 'C', 'D']!
			}
		}
	})
	assert child.width == 0 && child.height == 0 && child.x_off == 1 && child.y_off == 1
	assert screen.buf[0].char_.grapheme == 'C'
	assert screen.buf[0].char_.width == 1
	assert screen.buf[0].link.uri == '' && screen.buf[0].link.params == ''
	assert !screen.buf[0].wrapped && !screen.buf[0].default_
	assert screen.buf[0].scale.eql(CellScale{})
}

fn test_window_border_preserves_negative_parent_clipping_for_inner_writes() {
	mut screen := Screen.new(Winsize{ cols: 2, rows: 3 })
	child := Window.new(&screen).child(WindowChildOptions{
		x_off:  -1
		border: WindowBorderOptions{
			where_: BorderAll{}
			glyphs: BorderCustom{
				glyphs: ['A', 'H', 'B', 'V', 'C', 'D']!
			}
		}
	})
	assert child.width == 1 && child.height == 1
	assert child.x_off == 0 && child.y_off == 1
	assert child.parent_x_off == 0 && child.parent_y_off == 0
	assert screen.buf[0].char_.grapheme == 'H' && screen.buf[1].char_.grapheme == 'B'
	assert screen.buf[4].char_.grapheme == 'H' && screen.buf[5].char_.grapheme == 'C'
	child.write_cell(0, 0, Cell{
		char_: CellCharacter{
			grapheme: 'x'
		}
	})
	assert screen.buf[2].char_.grapheme == 'x' && screen.buf[3].char_.grapheme == 'V'
}

fn test_window_border_saturates_empty_dimensions_and_keeps_maximum_loop_counter() {
	mut screen := Screen{}
	for dimensions in [[u16(65535), 0]!, [u16(0), 65535]!, [u16(0), 0]!] {
		child := Window{
			width:        dimensions[0]
			height:       dimensions[1]
			x_off:        0
			y_off:        0
			parent_x_off: 0
			parent_y_off: 0
			screen:       &screen
		}.child(WindowChildOptions{
			border: WindowBorderOptions{
				where_: BorderAll{}
			}
		})
		assert child.width == u16(max_int(int(dimensions[0]) - 2, 0))
		assert child.height == u16(max_int(int(dimensions[1]) - 2, 0))
		assert child.x_off == 1 && child.y_off == 1
		assert screen.buf.len == 0
	}
}

fn test_window_border_empty_locations_keep_screen_and_child_geometry() {
	mut screen := Screen.new(Winsize{ cols: 4, rows: 3 })
	parent := Window.new(&screen)
	without := parent.child(WindowChildOptions{ x_off: 1, y_off: 1, width: 2, height: 1 })
	other := parent.child(WindowChildOptions{
		x_off:  1
		y_off:  1
		width:  2
		height: 1
		border: WindowBorderOptions{
			where_: BorderLocations{}
		}
	})
	assert without == other
	assert other.width == 2 && other.height == 1 && other.x_off == 1 && other.y_off == 1
	assert screen.buf.all(it.char_.grapheme == ' ')
}
