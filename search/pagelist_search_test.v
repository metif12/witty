module search

import terminal

fn write_pagelist_search_text(node &terminal.PageNode, x int, y int, text string) {
	unsafe {
		mut mutable_node := node
		for i, ch in text.runes() {
			mutable_node.data.rows[y].cells[x + i] = terminal.CellData{
				content_tag: .codepoint
				codepoint:   u32(ch)
			}
		}
	}
}

fn test_pagelist_search_initial_page_and_feed() ! {
	mut list := terminal.PageList.init(80, 24, usize(100_000_000))!
	defer { list.deinit() }
	initial_node := list.pages.first or {
		assert false, 'missing initial page'
		return
	}
	list.grow_rows(usize(initial_node.data.capacity.rows))!
	first_node := list.pages.first or {
		assert false, 'missing first page'
		return
	}
	last_node := list.pages.last or {
		assert false, 'missing last page'
		return
	}
	assert voidptr(first_node) != voidptr(last_node)
	write_pagelist_search_text(first_node, 0, 0, 'Fizz')
	write_pagelist_search_text(last_node, 0, 0, 'Fizz')

	mut finder := PageListSearch.init('Fizz'.bytes(), &list, last_node)!
	defer { finder.deinit() }
	start_y := finder.pin.y
	start_x := finder.pin.x
	assert finder.next() != none
	assert finder.next() == none
	assert finder.feed()
	assert finder.pin.y == start_y
	assert finder.pin.x == start_x
	assert finder.next() != none
	for finder.feed() {
	}
	assert !finder.feed()
}
