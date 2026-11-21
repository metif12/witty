module vxfw

import vaxis

fn test_text_line_adapter_keeps_borrowed_views_and_usize_state() {
	mut data := 'a\r\nb\nc'.bytes()
	input := unsafe { tos(data.data, data.len) }
	mut iter := LineIterator{
		buf: input
	}
	first := iter.next() or { panic('first line') }
	assert first == 'a'
	assert uint(first.str) == uint(data.data)
	assert iter.index == 3
	data[0] = `x`
	data[3] = `y`
	assert first == 'x'
	second := iter.next() or { panic('second line') }
	assert second == 'y'
	assert uint(second.str) == uint(data.data) + 3
	assert iter.next() or { panic('third line') } == 'c'
	assert iter.next() == none
	assert iter.next() == none
	iter.index = ~uint(0)
	assert iter.next() == none
}

fn test_text_softwrap_adapter_borrows_trimmed_words_and_public_state() {
	DrawContext.init(.unicode)
	mut data := 'ab cd\t '.bytes()
	input := unsafe { tos(data.data, data.len) }
	ctx := DrawContext{
		min:       Size{}
		max:       MaxSize{
			width: 3
		}
		cell_size: Size{}
	}
	mut iter := SoftwrapIterator.new(input, ctx)
	assert uint(iter.hard_iter.buf.str) == uint(data.data)
	first := iter.next() or { panic('first line') }
	assert first == WrappedLine{
		width: 2
		bytes: 'ab'
	}
	assert uint(first.bytes.str) == uint(data.data)
	assert iter.index == 3
	assert iter.line == 'ab cd'
	data[0] = `x`
	data[3] = `y`
	assert first.bytes == 'xb'
	second := iter.next() or { panic('second line') }
	assert second == WrappedLine{
		width: 2
		bytes: 'yd'
	}
	assert uint(second.bytes.str) == uint(data.data) + 3
	assert iter.next() == none
	assert iter.next() == none
}

fn test_text_public_draw_keeps_cell_graphemes_borrowed() {
	DrawContext.init(.unicode)
	mut data := 'ab cd'.bytes()
	input := unsafe { tos(data.data, data.len) }
	text := Text{
		text:  input
		style: vaxis.Style{
			bold: true
		}
	}
	ctx := DrawContext{
		min:       Size{}
		max:       MaxSize{
			width:  3
			height: 3
		}
		cell_size: Size{}
	}
	surface := text.widget().draw(ctx)!
	assert surface.size == Size{
		width:  2
		height: 2
	}
	assert surface.widget.eql(text.widget())
	assert uint(surface.read_cell(0, 0).char_.grapheme.str) == uint(data.data)
	assert uint(surface.read_cell(0, 1).char_.grapheme.str) == uint(data.data) + 3
	data[0] = `x`
	data[3] = `y`
	assert surface.read_cell(0, 0).char_.grapheme == 'x'
	assert surface.read_cell(0, 1).char_.grapheme == 'y'
	assert surface.read_cell(0, 0).char_.width == 1
	assert surface.read_cell(0, 0).style.bold
}

fn test_text_preserves_oversize_cluster_nonprogress_and_bounded_draw() {
	DrawContext.init(.unicode)
	ctx := DrawContext{
		min:       Size{}
		max:       MaxSize{
			width:  1
			height: 2
		}
		cell_size: Size{}
	}
	mut iter := SoftwrapIterator.new('漢', ctx)
	for _ in 0 .. 3 {
		line := iter.next() or { panic('oversize cluster stays pending') }
		assert line.width == 0
		assert line.bytes == ''
		assert iter.index == 0
	}
	surface := Text{
		text: '漢'
	}.draw(ctx)!
	assert surface.size == Size{
		width:  0
		height: 2
	}
	assert surface.buffer.len == 0
}

fn test_text_zero_maximum_returns_before_decode_and_parent_assertion() {
	DrawContext.init(.unicode)
	input := [u8(0xff), 0xcc, 0x81].bytestr()
	surface := Text{
		text:        input
		width_basis: .parent
	}.draw(DrawContext{
		min:       Size{
			width:  65535
			height: 2
		}
		max:       MaxSize{
			width: 0
		}
		cell_size: Size{}
	})!
	assert surface.size == Size{
		width:  65535
		height: 2
	}
	assert surface.buffer.len == 0
}
