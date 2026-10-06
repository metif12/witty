module vxfw

import vaxis

fn rich_test_context(width ?u16, height ?u16) DrawContext {
	return DrawContext{
		min:       Size{}
		max:       MaxSize{
			width:  width
			height: height
		}
		cell_size: Size{}
	}
}

fn test_rich_iterator_expands_tabs_retains_styles_and_reset_state() {
	DrawContext.init(.unicode)
	mut iter := RichSoftwrapIterator.new([
		TextSpan{
			text:  'a\tb \n\n c \t'
			style: vaxis.Style{
				bold: true
			}
			link:  vaxis.CellHyperlink{
				uri: 'file:///a'
			}
		},
	], rich_test_context(u16(3), none))
	mut lines := []string{}
	for {
		line := iter.next() or { break }
		assert line.width <= 3
		lines << line.cells.map(it.char_.grapheme).join('')
		for cell in line.cells {
			assert cell.style.bold && cell.link.uri == 'file:///a'
		}
	}
	assert lines.join('|') == 'a|b|| c'
	assert iter.hard_index == usize(iter.text.len)
	iter.reset()
	assert iter.index == 0 && iter.hard_index == 0 && iter.line.len == 0
	assert (iter.next() or { panic('first') }).cells.map(it.char_.grapheme).join('') == 'a'
}

fn test_rich_hard_iterator_keeps_crlf_grapheme_and_borrows_cell_slice() {
	DrawContext.init(.unicode)
	mut iter := RichSoftwrapIterator.new([TextSpan{ text: 'a\r\nb\n' }],
		rich_test_context(none, none))
	mut line := iter.next_hard_break() or { panic('first') }
	assert line.len == 3 && line[1].char_.grapheme == '\r\n'
	assert line[1].char_.width == 0
	line[0].char_.width = 7
	assert iter.text[0].char_.width == 7
	assert iter.next_hard_break() == none
}

fn test_rich_soft_iterator_keeps_nonadvancing_wide_glyph_state() {
	DrawContext.init(.unicode)
	mut iter := RichSoftwrapIterator.new([TextSpan{ text: '界' }], rich_test_context(u16(1),
		u16(3)))
	for _ in 0 .. 3 {
		line := iter.next() or { panic('line') }
		assert line.width == 0 && line.cells.len == 0
		assert iter.index == 0 && iter.hard_index == 1
	}
	surface := RichText{
		text: [TextSpan{ text: '界' }]
	}.draw(rich_test_context(u16(1), u16(3)))!
	assert surface.size == Size{
		width:  0
		height: 3
	}
	assert surface.buffer.len == 0
}

fn test_rich_draw_borrows_input_bytes_but_copies_span_style() {
	DrawContext.init(.unicode)
	mut bytes := [u8(`a`), `b`, 0]
	value := unsafe { tos(&bytes[0], 2) }
	mut spans := [TextSpan{
		text:  value
		style: vaxis.Style{
			bold: true
		}
	}]
	rich := RichText{
		text: spans
	}
	surface := rich.widget().draw(rich_test_context(none, none))!
	bytes[0] = `Z`
	spans[0].style = vaxis.Style{
		italic: true
	}
	assert surface.buffer[0].char_.grapheme == 'Z'
	assert surface.buffer[0].style.bold && !surface.buffer[0].style.italic
	assert surface.widget.userdata == rich.widget().userdata
}

fn test_rich_draw_ellipsis_drops_link_retains_cell_style_and_full_base_style() {
	DrawContext.init(.unicode)
	rich := RichText{
		text:       [
			TextSpan{
				text:  'abcdef'
				style: vaxis.Style{
					italic: true
				}
				link:  vaxis.CellHyperlink{
					uri: 'https://a'
				}
			},
		]
		base_style: vaxis.Style{
			bold:    true
			dim:     true
			reverse: true
		}
		softwrap:   false
	}
	surface := rich.draw(DrawContext{
		min:       Size{
			width:  4
			height: 2
		}
		max:       MaxSize{
			width:  4
			height: 2
		}
		cell_size: Size{}
	})!
	assert surface.buffer[..4].map(it.char_.grapheme).join('') == 'abc…'
	assert surface.buffer[3].style.italic && surface.buffer[3].link.uri == ''
	assert surface.buffer[4].style.bold && surface.buffer[4].style.dim
		&& surface.buffer[4].style.reverse
}

fn test_rich_zero_width_returns_minimum_without_parsing_or_parent_assertion() {
	DrawContext.init(.unicode)
	rich := RichText{
		text:        [TextSpan{ text: '\r' }]
		width_basis: .parent
	}
	surface := rich.draw(DrawContext{
		min:       Size{
			width:  7
			height: 2
		}
		max:       MaxSize{
			width: 0
		}
		cell_size: Size{}
	})!
	assert surface.size == Size{
		width:  7
		height: 2
	}
	assert surface.buffer.len == 0 && surface.children.len == 0
}

fn test_rich_public_iterator_payload_uses_usize_state_and_borrowed_arrays() {
	mut cells := [
		vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: 'x'
				width:    1
			}
		},
	]
	mut iter := RichSoftwrapIterator{
		ctx:        rich_test_context(none, none)
		text:       cells
		line:       cells
		index:      0
		hard_index: 1
	}
	line := iter.next() or { panic('line') }
	assert line.width == 1 && iter.index == 1
	cells[0].char_.width = 2
	assert line.cells[0].char_.width == 2 && iter.text[0].char_.width == 2
	iter.hard_index = ~usize(0)
	assert iter.next_hard_break() == none
}
