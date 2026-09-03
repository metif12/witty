module search

// Tests for SlidingWindow.
//
// Source: terminal/search/sliding_window.zig (tests section, lines 635-1677)
//
// The search cases use PageList nodes directly so they exercise the same
// formatter mapping and node identities as production without depending on
// the older flat Screen facade.

import highlight
import terminal

// ============================================================
// CircBuf / DataBuf tests
// ============================================================

fn test_data_buf_basic() {
	mut buf := DataBuf.new()
	assert buf.len() == 0
	assert buf.capacity() == 0

	buf.ensure_unused_capacity(10)
	assert buf.capacity() >= 10

	buf.append_slice_assume_capacity('hello'.bytes())
	assert buf.len() == 5

	slices := buf.get_ptr_slice(0, 5)
	assert slices.first == 'hello'.bytes()
	assert slices.second.len == 0
}

fn test_data_buf_wrap_around() {
	mut buf := DataBuf.new()
	buf.ensure_unused_capacity(8)

	// Fill near capacity
	buf.append_slice_assume_capacity('abcdef'.bytes())
	assert buf.len() == 6

	// Delete oldest 4
	buf.delete_oldest(4)
	assert buf.len() == 2

	// Append more (should wrap around)
	buf.ensure_unused_capacity(6)
	buf.append_slice_assume_capacity('ghijkl'.bytes())
	assert buf.len() == 8

	// Verify through get_ptr_slice which handles wrapping
	slices := buf.get_ptr_slice(0, 8)
	// Combined data should be "efghijkl"
	mut combined := slices.first.clone()
	combined << slices.second
	assert combined == 'efghijkl'.bytes()
}

fn test_data_buf_delete_oldest() {
	mut buf := DataBuf.new()
	buf.ensure_unused_capacity(5)
	buf.append_slice_assume_capacity('abcde'.bytes())

	buf.delete_oldest(2)
	assert buf.len() == 3

	slices := buf.get_ptr_slice(0, 3)
	mut combined := slices.first.clone()
	combined << slices.second
	assert combined == 'cde'.bytes()
}

fn test_data_buf_empty_slices() {
	buf := DataBuf.new()
	slices := buf.get_ptr_slice(0, 0)
	assert slices.first.len == 0
	assert slices.second.len == 0
}

fn test_meta_buf_basic() {
	mut buf := MetaBuf.new()
	assert buf.len() == 0

	buf.ensure_unused_capacity(2)
	buf.append_assume_capacity(Meta{
		serial: 42
		cell_map: [highlight.Coordinate{ x: 1, y: 2 }]
	})
	assert buf.len() == 1

	m := buf.get(0)
	assert m.serial == 42
	assert m.cell_map.len == 1
	assert m.cell_map[0].x == 1
	assert m.cell_map[0].y == 2
}

fn test_meta_buf_delete_oldest() {
	mut buf := MetaBuf.new()
	buf.ensure_unused_capacity(3)

	buf.append_assume_capacity(Meta{ serial: 1 })
	buf.append_assume_capacity(Meta{ serial: 2 })
	buf.append_assume_capacity(Meta{ serial: 3 })
	assert buf.len() == 3

	buf.delete_oldest(1)
	assert buf.len() == 2
	assert buf.get(0).serial == 2
	assert buf.get(1).serial == 3
}

// ============================================================
// Search helper tests
// ============================================================

fn test_index_of_ignore_case_basic() {
	haystack := 'hello world'.bytes()
	needle := 'world'.bytes()
	idx := index_of_ignore_case(haystack, needle) or {
		assert false, 'expected match'
		return
	}
	assert idx == 6
}

fn test_index_of_ignore_case_case_insensitive() {
	haystack := 'Hello World'.bytes()
	needle := 'hello'.bytes()
	idx := index_of_ignore_case(haystack, needle) or {
		assert false, 'expected match'
		return
	}
	assert idx == 0
}

fn test_index_of_ignore_case_no_match() {
	haystack := 'hello world'.bytes()
	needle := 'xyz'.bytes()
	result := index_of_ignore_case(haystack, needle)
	assert result == none
}

fn test_index_of_ignore_case_empty_needle() {
	haystack := 'hello'.bytes()
	needle := []u8{}
	idx := index_of_ignore_case(haystack, needle) or {
		assert false, 'expected match'
		return
	}
	assert idx == 0
}

fn test_index_of_ignore_case_needle_too_long() {
	haystack := 'hi'.bytes()
	needle := 'hello'.bytes()
	result := index_of_ignore_case(haystack, needle)
	assert result == none
}

fn test_reverse_bytes() {
	mut arr := 'abcde'.bytes()
	reverse_bytes(mut arr)
	assert arr == 'edcba'.bytes()
}

fn test_reverse_bytes_empty() {
	mut arr := []u8{}
	reverse_bytes(mut arr)
	assert arr == []u8{}
}

fn test_reverse_bytes_single() {
	mut arr := [u8(`x`)]
	reverse_bytes(mut arr)
	assert arr == [u8(`x`)]
}

// ============================================================
// SlidingWindow basic tests
// ============================================================

fn test_sliding_window_empty_on_init() {
	mut w := SlidingWindow.init(.forward, 'boo!'.bytes())
	defer {
		w.deinit()
	}
	assert w.data.len() == 0
	assert w.meta.len() == 0
}

fn test_sliding_window_init_reverse_needle() {
	mut w := SlidingWindow.init(.reverse, 'abc'.bytes())
	defer {
		w.deinit()
	}
	// Needle should be reversed for reverse search.
	assert w.needle == 'cba'.bytes()
}

fn test_sliding_window_clear_and_retain_capacity() {
	mut w := SlidingWindow.init(.forward, 'test'.bytes())
	defer {
		w.deinit()
	}

	// Manually populate some data for testing.
	w.data.ensure_unused_capacity(5)
	w.data.append_slice_assume_capacity('hello'.bytes())
	w.meta.ensure_unused_capacity(1)
	w.meta.append_assume_capacity(Meta{
		serial: 1
		cell_map: []highlight.Coordinate{len: 5}
	})

	w.clear_and_retain_capacity()
	assert w.data.len() == 0
	assert w.meta.len() == 0
	assert w.data_offset == 0
}

fn test_sliding_window_next_no_data() {
	mut w := SlidingWindow.init(.forward, 'test'.bytes())
	defer {
		w.deinit()
	}
	// No data, should return none.
	assert w.next() == none
	assert w.next() == none
}

fn test_sliding_window_next_data_shorter_than_needle() {
	mut w := SlidingWindow.init(.forward, 'long needle'.bytes())
	defer {
		w.deinit()
	}

	// Add data shorter than needle.
	w.data.ensure_unused_capacity(3)
	w.data.append_slice_assume_capacity('hi'.bytes())
	w.meta.ensure_unused_capacity(1)
	w.meta.append_assume_capacity(Meta{
		serial: 1
		cell_map: []highlight.Coordinate{len: 2}
	})

	assert w.next() == none
}

// Build a PageList node directly. This keeps these tests focused on the
// sliding-window/formatter contract while preserving the same Page data and
// linked-node identities used by the production search path.
fn sliding_test_node(lines []string, wraps []bool, cols u16, serial u64) &terminal.PageNode {
	mut page := terminal.Page.init(terminal.PageCapacity{
		cols: cols
		rows: u16(lines.len)
	})
	page.size.rows = u16(lines.len)
	for y, line in lines {
		for x, cp in line.runes() {
			if x >= int(cols) {
				break
			}
			page.rows[y].cells[x] = terminal.CellData.init(u32(cp))
		}
		if y < wraps.len {
			page.rows[y].wrap = wraps[y]
			page.rows[y].wrap_continuation = y > 0 && wraps[y - 1]
		}
	}
	return &terminal.PageNode{
		data: page
		serial: serial
	}
}

fn sliding_assert_match(mut window SlidingWindow, start_x u16, start_y u16, end_x u16, end_y u16) {
	h := window.next() or {
		assert false, 'expected a search match'
		return
	}
	assert h.top_x == start_x
	assert h.chunks[0].start == start_y
	assert h.bot_x == end_x
	assert h.chunks[h.chunks.len - 1].end - 1 == end_y
}

fn test_sliding_window_single_append() {
	mut node := sliding_test_node(['hello. boo! hello. boo!'], [false], 80, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(.forward, 'boo!'.bytes())
	w.append(node)
	sliding_assert_match(mut w, 7, 0, 10, 0)
	sliding_assert_match(mut w, 19, 0, 22, 0)
	assert w.next() == none
}

fn test_sliding_window_single_append_case_insensitive() {
	mut node := sliding_test_node(['hello. boo!'], [false], 80, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(.forward, 'Boo!'.bytes())
	w.append(node)
	sliding_assert_match(mut w, 7, 0, 10, 0)
}

fn test_sliding_window_single_append_single_char() {
	mut node := sliding_test_node(['aba'], [false], 8, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(.forward, 'a'.bytes())
	w.append(node)
	sliding_assert_match(mut w, 0, 0, 0, 0)
	sliding_assert_match(mut w, 2, 0, 2, 0)
	assert w.next() == none
}

fn test_sliding_window_single_append_no_match() {
	mut node := sliding_test_node(['hello. boo!'], [false], 80, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(.forward, 'nope!'.bytes())
	w.append(node)
	assert w.next() == none
	assert w.meta.len() == 1
}

fn test_sliding_window_two_pages() {
	mut first := sliding_test_node(['first boo!'], [false], 20, 1)
	mut second := sliding_test_node(['second boo!'], [false], 20, 2)
	defer {
		first.data.deinit()
		second.data.deinit()
	}
	mut w := SlidingWindow.init(.forward, 'boo!'.bytes())
	w.append(first)
	w.append(second)
	sliding_assert_match(mut w, 6, 0, 9, 0)
	sliding_assert_match(mut w, 7, 0, 10, 0)
}

fn test_sliding_window_two_pages_single_char() {
	mut first := sliding_test_node(['abc'], [false], 8, 1)
	mut second := sliding_test_node(['cab'], [false], 8, 2)
	defer {
		first.data.deinit()
		second.data.deinit()
	}
	mut w := SlidingWindow.init(.forward, 'b'.bytes())
	w.append(first)
	w.append(second)
	sliding_assert_match(mut w, 1, 0, 1, 0)
	sliding_assert_match(mut w, 2, 0, 2, 0)
}

fn test_sliding_window_two_pages_match_across_boundary() {
	mut first := sliding_test_node(['hello'], [true], 8, 1)
	mut second := sliding_test_node([', world!'], [false], 8, 2)
	defer {
		first.data.deinit()
		second.data.deinit()
	}
	mut w := SlidingWindow.init(.forward, 'hello, world'.bytes())
	w.append(first)
	w.append(second)
	sliding_assert_match(mut w, 0, 0, 6, 0)
}

fn test_sliding_window_two_pages_no_match_boundary_newline() {
	sliding_test_boundary_newline(.forward)
}

fn test_sliding_window_two_pages_no_match_boundary_newline_reverse() {
	sliding_test_boundary_newline(.reverse)
}

fn sliding_test_boundary_newline(direction Direction) {
	mut first := sliding_test_node(['hello'], [false], 8, 1)
	mut second := sliding_test_node([', world!'], [false], 8, 2)
	defer {
		first.data.deinit()
		second.data.deinit()
	}
	mut w := SlidingWindow.init(direction, 'hello, world'.bytes())
	if direction == .forward {
		w.append(first)
		w.append(second)
	} else {
		w.append(second)
		w.append(first)
	}
	assert w.next() == none
}

fn test_sliding_window_two_pages_no_match_prunes_first() {
	sliding_test_pruning(.forward, false)
}

fn test_sliding_window_two_pages_no_match_keeps_both() {
	sliding_test_pruning(.forward, true)
}

fn sliding_test_pruning(direction Direction, long_needle bool) {
	mut first := sliding_test_node(['abcdefgh'], [false], 12, 1)
	mut second := sliding_test_node(['ijklmnop'], [false], 12, 2)
	defer {
		first.data.deinit()
		second.data.deinit()
	}
	needle := if long_needle { 'xxxxxxxxxxxxxxxxxxxxxxxx'.bytes() } else { 'nope!'.bytes() }
	mut w := SlidingWindow.init(direction, needle)
	if direction == .forward {
		w.append(first)
		w.append(second)
	} else {
		w.append(second)
		w.append(first)
	}
	assert w.next() == none
	assert w.meta.len() == if long_needle { 2 } else { 1 }
}

fn test_sliding_window_circ_buf_boundary() {
	sliding_test_circular_boundary(.forward)
}

fn sliding_test_circular_boundary(direction Direction) {
	mut node := sliding_test_node(['XXXXXXXXXXXXXXXXXXXboo!XXXXX'], [true], 32, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(direction, 'abc'.bytes())
	w.append(node)
	w.append(node)
	assert w.next() == none
	assert w.meta.len() == 1
	w.test_change_needle(if direction == .forward { 'boo'.bytes() } else { 'oob'.bytes() })
	w.append(node)
	slices := w.data.get_ptr_slice(0, w.data.len())
	assert slices.first.len > 0
	assert slices.second.len > 0
	sliding_assert_match(mut w, 19, 0, 21, 0)
}

fn test_sliding_window_match_on_boundary() {
	sliding_test_match_on_boundary(.forward)
}

fn sliding_test_match_on_boundary(direction Direction) {
	mut node := sliding_test_node(['o!XXXXXXXXXXXXXXXXXXXbo'], [true], 28, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(direction, 'abcd'.bytes())
	w.append(node)
	w.append(node)
	assert w.next() == none
	w.test_change_needle(if direction == .forward { 'boo!'.bytes() } else { '!oob'.bytes() })
	w.append(node)
	sliding_assert_match(mut w, 21, 0, 1, 0)
}

fn test_sliding_window_single_append_reversed() {
	mut node := sliding_test_node(['hello. boo! hello. boo!'], [false], 80, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(.reverse, 'boo!'.bytes())
	w.append(node)
	sliding_assert_match(mut w, 19, 0, 22, 0)
	sliding_assert_match(mut w, 7, 0, 10, 0)
}

fn test_sliding_window_single_append_no_match_reversed() {
	mut node := sliding_test_node(['hello. boo!'], [false], 80, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(.reverse, 'nope!'.bytes())
	w.append(node)
	assert w.next() == none
	assert w.meta.len() == 1
}

fn test_sliding_window_two_pages_reversed() {
	mut first := sliding_test_node(['first boo!'], [false], 20, 1)
	mut second := sliding_test_node(['second boo!'], [false], 20, 2)
	defer {
		first.data.deinit()
		second.data.deinit()
	}
	mut w := SlidingWindow.init(.reverse, 'boo!'.bytes())
	w.append(second)
	w.append(first)
	sliding_assert_match(mut w, 7, 0, 10, 0)
	sliding_assert_match(mut w, 6, 0, 9, 0)
}

fn test_sliding_window_two_pages_match_boundary_reversed() {
	mut first := sliding_test_node(['hello'], [true], 8, 1)
	mut second := sliding_test_node([', world!'], [false], 8, 2)
	defer {
		first.data.deinit()
		second.data.deinit()
	}
	mut w := SlidingWindow.init(.reverse, 'hello, world'.bytes())
	w.append(second)
	w.append(first)
	sliding_assert_match(mut w, 0, 0, 6, 0)
}

fn test_sliding_window_two_pages_no_match_prunes_reversed() {
	sliding_test_pruning(.reverse, false)
}

fn test_sliding_window_two_pages_no_match_keeps_both_reversed() {
	sliding_test_pruning(.reverse, true)
}

fn test_sliding_window_circ_buf_boundary_reversed() {
	sliding_test_circular_boundary(.reverse)
}

fn test_sliding_window_match_on_boundary_reversed() {
	sliding_test_match_on_boundary(.reverse)
}

fn test_sliding_window_soft_wrapped() {
	sliding_test_soft_wrap(.forward)
}

fn test_sliding_window_soft_wrapped_reversed() {
	sliding_test_soft_wrap(.reverse)
}

fn sliding_test_soft_wrap(direction Direction) {
	mut node := sliding_test_node(['A', 'xxbo', 'o!', 'C'], [false, true, false, false], 4, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(direction, 'boo!'.bytes())
	w.append(node)
	sliding_assert_match(mut w, 2, 1, 1, 2)
}

fn test_sliding_window_whitespace_only_node() {
	mut node := sliding_test_node([''], [true], 80, 1)
	defer { node.data.deinit() }
	mut w := SlidingWindow.init(.forward, 'x'.bytes())
	assert w.append(node) == 0
	assert w.meta.len() == 0
	assert w.next() == none
}
