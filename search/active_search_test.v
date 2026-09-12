module search

import terminal

fn write_active_search_text(mut list terminal.PageList, x u16, y u16, text string) {
	for i, ch in text.runes() {
		pin := list.pin(terminal.Point.new(.active, terminal.Coordinate{
			x: x + u16(i)
			y: y
		})) or { continue }
		mut row := &pin.node.data.rows[int(pin.y)]
		row.cells[int(pin.x)] = terminal.CellData{
			content_tag: .codepoint
			codepoint: u32(ch)
		}
	}
}

fn test_active_search_finds_matches() {
	mut list := terminal.PageList.init(10, 10, usize(0x7fffffffffffffff))
	defer { list.deinit() }
	write_active_search_text(mut list, 0, 0, 'Fizz')
	write_active_search_text(mut list, 0, 2, 'Fizz')

	mut finder := ActiveSearch.init('Fizz'.bytes())
	defer { finder.deinit() }
	first_active := finder.update(&list) or {
		assert false, 'active list unexpectedly empty'
		return
	}
	assert voidptr(first_active) == voidptr(list.get_top_left(.active).node)

	first := finder.next() or {
		assert false, 'missing first match'
		return
	}
	assert first.start_pin().y == 0
	assert first.end_pin().x == 3
	second := finder.next() or {
		assert false, 'missing second match'
		return
	}
	assert second.start_pin().y == 2
	assert finder.next() == none
}
