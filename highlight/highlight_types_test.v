module highlight

import terminal

fn test_flattened_highlight_init_spans_pages() {
	mut list := terminal.PageList.init(80, 24, usize(100_000_000))
	defer { list.deinit() }
	start_node := list.pages.first or {
		assert false, 'missing first page'
		return
	}
	// Grow one row beyond the first page. The standard page capacity can
	// change as Page's translated layout evolves, so don't hard-code it.
	rows_to_next_page := usize(start_node.data.capacity.rows - start_node.data.size.rows) + 1
	list.grow_rows(rows_to_next_page)
	end_node := list.pages.last or {
		assert false, 'missing last page'
		return
	}
	assert voidptr(start_node) != voidptr(end_node)

	result := FlattenedHighlight.init(terminal.PagePin{
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

fn test_untracked_highlight_track_uses_tracked_init() {
	mut list := terminal.PageList.init(10, 2, usize(0))
	defer { list.deinit() }
	start := list.get_top_left(.active)
	end := list.get_bottom_right(.active) or { panic('missing active bottom-right pin') }
	initial_tracked := list.count_tracked_pins()
	mut tracked := (UntrackedHighlight{
		start: start
		end: end
	}).track(mut list)
	assert list.count_tracked_pins() == initial_tracked + 2
	tracked.deinit(mut list)
	assert list.count_tracked_pins() == initial_tracked
}

fn test_tracked_highlight_init_assume_preserves_pins() {
	mut list := terminal.PageList.init(10, 2, usize(0))
	defer { list.deinit() }
	start := list.get_top_left(.active)
	end := list.get_bottom_right(.active) or { panic('missing active bottom-right pin') }
	tracked := TrackedHighlight.init_assume(&start, &end)
	assert voidptr(tracked.start) == voidptr(&start)
	assert voidptr(tracked.end) == voidptr(&end)
}
