module search

// Tests for SlidingWindow.
//
// Source: terminal/search/sliding_window.zig (tests section, lines 635-1677)
//
// Most tests from the Zig source require Screen/Terminal instances with
// PageList (linked list model). Since the V Screen uses the simpler Pages
// model, and SlidingWindow.append() is XTODO (needs PageFormatter point_map),
// those tests are stubbed here with XTODO markers.
//
// Basic tests for the CircBuf data structures and search helpers are
// included and functional.

import highlight

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

// ============================================================
// Original Zig test stubs (XTODO)
// ============================================================

// XTODO: Requires Screen/Terminal with PageList and SlidingWindow.append().
// Original test: "SlidingWindow single append"
// Tests finding two matches in a single page after append.
fn test_sliding_window_single_append() {
	// XTODO: Needs SlidingWindow.append() which requires PageFormatter point_map.
}

// XTODO: Original test: "SlidingWindow single append case insensitive ASCII"
fn test_sliding_window_single_append_case_insensitive() {
	// XTODO: Needs SlidingWindow.append() which requires PageFormatter point_map.
}

// XTODO: Original test: "SlidingWindow single append single char"
fn test_sliding_window_single_append_single_char() {
	// XTODO: Needs SlidingWindow.append() which requires PageFormatter point_map.
}

// XTODO: Original test: "SlidingWindow single append no match"
fn test_sliding_window_single_append_no_match() {
	// XTODO: Needs SlidingWindow.append() which requires PageFormatter point_map.
}

// XTODO: Original test: "SlidingWindow two pages"
fn test_sliding_window_two_pages() {
	// XTODO: Needs SlidingWindow.append() and multi-page Screen setup.
}

// XTODO: Original test: "SlidingWindow two pages single char"
fn test_sliding_window_two_pages_single_char() {
	// XTODO: Needs SlidingWindow.append() and multi-page Screen setup.
}

// XTODO: Original test: "SlidingWindow two pages match across boundary"
fn test_sliding_window_two_pages_match_across_boundary() {
	// XTODO: Needs SlidingWindow.append() and multi-page Screen setup.
}

// XTODO: Original test: "SlidingWindow two pages no match across boundary with newline"
fn test_sliding_window_two_pages_no_match_boundary_newline() {
	// XTODO: Needs SlidingWindow.append() and multi-page Screen setup.
}

// XTODO: Original test: "SlidingWindow two pages no match across boundary with newline reverse"
fn test_sliding_window_two_pages_no_match_boundary_newline_reverse() {
	// XTODO: Needs SlidingWindow.append() and reverse multi-page setup.
}

// XTODO: Original test: "SlidingWindow two pages no match prunes first page"
fn test_sliding_window_two_pages_no_match_prunes_first() {
	// XTODO: Needs SlidingWindow.append() and multi-page Screen setup.
}

// XTODO: Original test: "SlidingWindow two pages no match keeps both pages"
fn test_sliding_window_two_pages_no_match_keeps_both() {
	// XTODO: Needs SlidingWindow.append() and large needle setup.
}

// XTODO: Original test: "SlidingWindow single append across circular buffer boundary"
fn test_sliding_window_circ_buf_boundary() {
	// XTODO: Needs SlidingWindow.append() to fill and wrap the circular buffer.
}

// XTODO: Original test: "SlidingWindow single append match on boundary"
fn test_sliding_window_match_on_boundary() {
	// XTODO: Needs SlidingWindow.append() with soft-wrapped rows.
}

// XTODO: Original test: "SlidingWindow single append reversed"
fn test_sliding_window_single_append_reversed() {
	// XTODO: Needs SlidingWindow.append() with reverse direction.
}

// XTODO: Original test: "SlidingWindow single append no match reversed"
fn test_sliding_window_single_append_no_match_reversed() {
	// XTODO: Needs SlidingWindow.append() with reverse direction.
}

// XTODO: Original test: "SlidingWindow two pages reversed"
fn test_sliding_window_two_pages_reversed() {
	// XTODO: Needs SlidingWindow.append() and reverse multi-page setup.
}

// XTODO: Original test: "SlidingWindow two pages match across boundary reversed"
fn test_sliding_window_two_pages_match_boundary_reversed() {
	// XTODO: Needs SlidingWindow.append() and reverse multi-page setup.
}

// XTODO: Original test: "SlidingWindow two pages no match prunes first page reversed"
fn test_sliding_window_two_pages_no_match_prunes_reversed() {
	// XTODO: Needs SlidingWindow.append() and reverse multi-page setup.
}

// XTODO: Original test: "SlidingWindow two pages no match keeps both pages reversed"
fn test_sliding_window_two_pages_no_match_keeps_both_reversed() {
	// XTODO: Needs SlidingWindow.append() and reverse large needle setup.
}

// XTODO: Original test: "SlidingWindow single append across circular buffer boundary reversed"
fn test_sliding_window_circ_buf_boundary_reversed() {
	// XTODO: Needs SlidingWindow.append() and reverse circular buffer wrapping.
}

// XTODO: Original test: "SlidingWindow single append match on boundary reversed"
fn test_sliding_window_match_on_boundary_reversed() {
	// XTODO: Needs SlidingWindow.append() with reverse and soft-wrapped rows.
}

// XTODO: Original test: "SlidingWindow single append soft wrapped"
fn test_sliding_window_soft_wrapped() {
	// XTODO: Needs Terminal with VT stream processing and SlidingWindow.append().
}

// XTODO: Original test: "SlidingWindow single append reversed soft wrapped"
fn test_sliding_window_soft_wrapped_reversed() {
	// XTODO: Needs Terminal with VT stream processing and SlidingWindow.append().
}

// XTODO: Original test: "SlidingWindow append whitespace only node"
fn test_sliding_window_whitespace_only_node() {
	// XTODO: Tests a real bug where a whitespace-only page encoding
	// to zero bytes would crash. Needs Screen setup.
}
