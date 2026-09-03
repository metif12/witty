module highlight

import terminal

fn test_flattened_highlight_from_pins_spans_pages() {
	mut list := terminal.PageList.init(80, 24, usize(100_000_000))
	defer { list.deinit() }
	list.grow_rows(300)
	start_node := list.pages.first or {
		assert false, 'missing first page'
		return
	}
	end_node := list.pages.last or {
		assert false, 'missing last page'
		return
	}
	assert voidptr(start_node) != voidptr(end_node)

	result := FlattenedHighlight.from_pins(terminal.PagePin{
		node: start_node
		x: 3
		y: 2
	}, terminal.PagePin{
		node: end_node
		x: 5
		y: 1
	})
	assert result.chunks.len >= 2
	assert result.chunks[0].serial == start_node.serial
	assert result.chunks[0].start == 2
	assert result.chunks[result.chunks.len - 1].serial == end_node.serial
	assert result.chunks[result.chunks.len - 1].end == 2
	assert result.start_pin().x == 3
	assert result.end_pin().x == 5
}
