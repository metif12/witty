module vxfw

import vaxis

fn test_pinned_line_iterator_breaks_and_terminal_empty_line() {
	for text in ['Hello,\nworld', 'Hello,\rworld', 'Hello,\r\nworld'] {
		mut iter := LineIterator{
			buf: text
		}
		assert iter.next() or { panic('first') } == 'Hello,'
		assert iter.next() or { panic('second') } == 'world'
		assert iter.next() == none
	}
	mut iter := LineIterator{
		buf: 'a\r\n\r\nb\n'
	}
	assert iter.next() or { panic('first') } == 'a'
	assert iter.next() or { panic('blank') } == ''
	assert iter.next() or { panic('last') } == 'b'
	assert iter.next() == none
}

fn test_pinned_softwrap_words_leading_spaces_and_long_words() {
	DrawContext.init(.unicode)
	for pair in [
		['Hello, \n world', 'Hello,| world'],
		['Hello, world', 'Hello,|world'],
		['abcdefghijk', 'abcdefg|hijk'],
		['Hello,        \n world', 'Hello,| world'],
	] {
		mut iter := SoftwrapIterator.new(pair[0], DrawContext{
			min:       Size{}
			cell_size: Size{}
			max:       MaxSize{
				width: 7
			}
		})
		mut lines := []string{}
		for {
			line := iter.next() or { break }
			assert line.width == DrawContext{
				min:       Size{}
				max:       MaxSize{}
				cell_size: Size{}
			}.string_width(line.bytes)
			lines << line.bytes
		}
		assert lines.join('|') == pair[1]
	}
}

fn test_text_styles_tabs_alignment_and_ellipsis() {
	DrawContext.init(.unicode)
	style := vaxis.Style{
		bold:    true
		reverse: true
		fg:      vaxis.ColorIndex{
			index: 4
		}
	}
	text := Text{
		text:       'abc'
		style:      style
		text_align: .center
	}
	ctx := DrawContext{
		cell_size: Size{}
		min:       Size{
			width:  7
			height: 2
		}
		max:       MaxSize{
			width:  7
			height: 2
		}
	}
	surface := text.draw(ctx)!
	assert surface.size == Size{
		width:  7
		height: 2
	}
	assert surface.read_cell(2, 0).char_.grapheme == 'a'
	assert surface.read_cell(2, 0).style.bold
	assert !surface.read_cell(0, 0).style.bold
	assert surface.read_cell(0, 0).style.reverse
	clipped := Text{
		text:     'abcdefg'
		softwrap: false
	}.draw(DrawContext{
		min:       Size{}
		cell_size: Size{}
		max:       MaxSize{
			width: 4
		}
	})!
	assert clipped.buffer.map(it.char_.grapheme).join('') == 'abc…'
	tabs := Text{
		text: 'a\tb'
	}.draw(DrawContext{
		min:       Size{}
		cell_size: Size{}
		max:       MaxSize{
			width: 20
		}
	})!
	assert tabs.size.width == 2 // Unicode width treats the tab as zero before draw expands it.
	assert tabs.read_cell(0, 0).char_.grapheme == 'a'
	assert tabs.read_cell(1, 0).char_.grapheme == ' '
	zero := text.draw(DrawContext{
		cell_size: Size{}
		min:       Size{
			height: 2
		}
		max:       MaxSize{
			width: 0
		}
	})!
	assert zero.size == Size{
		height: 2
	}
	assert zero.buffer.len == 0
}

fn test_rich_text_preserves_span_styles_links_and_expands_tabs() {
	DrawContext.init(.unicode)
	text := RichText{
		text: [
			TextSpan{
				text: 'Hello, '
			},
			TextSpan{
				text:  'World'
				style: vaxis.Style{
					bold: true
				}
				link:  vaxis.CellHyperlink{
					uri: 'https://example.org'
				}
			},
		]
	}
	surface := text.draw(DrawContext{
		min:       Size{}
		cell_size: Size{}
		max:       MaxSize{
			width:  8
			height: 8
		}
	})!
	assert surface.size == Size{
		width:  6
		height: 2
	}
	assert surface.read_cell(0, 0).char_.grapheme == 'H'
	assert !surface.read_cell(0, 0).style.bold
	assert surface.read_cell(0, 1).char_.grapheme == 'W'
	assert surface.read_cell(0, 1).style.bold
	assert surface.read_cell(0, 1).link.uri == 'https://example.org'
	tabs := RichText{
		text: [TextSpan{ text: 'a\tb' }]
	}.draw(DrawContext{
		min:       Size{}
		max:       MaxSize{}
		cell_size: Size{}
	})!
	assert tabs.size.width == 10
	assert tabs.buffer.map(it.char_.grapheme).join('') == 'a        b'
}
