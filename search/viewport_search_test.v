module search

import terminal

fn write_page_list_text(mut list terminal.PageList, tag terminal.PointTag, x u16, y u16, text string) {
	for i, ch in text.runes() {
		pin := list.pin(terminal.Point.new(tag, terminal.Coordinate{
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

fn test_viewport_simple_search() ! {
	mut list := terminal.PageList.init(10, 10, usize(0x7fffffffffffffff))!
	defer { list.deinit() }
	write_page_list_text(mut list, .active, 0, 0, 'Fizz')
	write_page_list_text(mut list, .active, 0, 2, 'Fizz')

	mut finder := ViewportSearch.init('Fizz'.bytes())
	defer { finder.deinit() }
	assert finder.update(&list)
	// The viewport covers mutable active content, so without dirty tracking
	// an unchanged fingerprint still requires a new search.
	assert finder.update(&list)

	first := finder.next() or {
		assert false, 'missing first match'
		return
	}
	assert first.start_pin().x == 0
	assert first.start_pin().y == 0
	assert first.end_pin().x == 3
	second := finder.next() or {
		assert false, 'missing second match'
		return
	}
	assert second.start_pin().y == 2
	assert finder.next() == none
}

fn test_viewport_dirty_tracking() ! {
	mut list := terminal.PageList.init(10, 10, usize(0x7fffffffffffffff))!
	defer { list.deinit() }
	write_page_list_text(mut list, .active, 0, 0, 'Fizz')

	mut finder := ViewportSearch.init('Fizz'.bytes())
	defer { finder.deinit() }
	finder.active_dirty = false
	assert finder.update(&list)
	assert !finder.update(&list)

	write_page_list_text(mut list, .active, 0, 0, 'Buzz')
	assert !finder.update(&list)
	finder.active_dirty = true
	assert finder.update(&list)
	assert finder.next() == none
}

fn test_viewport_history_does_not_research_unchanged_pages() ! {
	mut list := terminal.PageList.init(10, 2, usize(100_000_000))!
	defer { list.deinit() }
	write_page_list_text(mut list, .screen, 0, 0, 'Fizz')
	initial_node := list.pages.first or {
		assert false, 'missing initial page'
		return
	}
	list.grow_rows(usize(initial_node.data.capacity.rows))
	list.scroll(terminal.PageScrollTop{})
	assert list.viewport == .top

	mut finder := ViewportSearch.init('Fizz'.bytes())
	defer { finder.deinit() }
	assert finder.update(&list)
	match_ := finder.next() or {
		assert false, 'missing history match'
		return
	}
	assert match_.start_pin().x == 0
	assert match_.start_pin().y == 0
	assert !finder.update(&list)
}
