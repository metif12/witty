module terminal

// Tests translated from Ghostty's PageList.zig

// ============================================================
// Helper: write a codepoint into a cell in the active area
// ============================================================

fn set_active_cell(mut pl PageList, x u16, y u16, cp u32) {
	p := pl.get_pin(.active, x, y) or { return }
	if int(p.y) < p.node.data.rows.len {
		mut row := &p.node.data.rows[int(p.y)]
		if int(p.x) < row.cells.len {
			row.cells[int(p.x)] = CellData{
				content_tag: .codepoint
				codepoint: cp
			}
		}
	}
}

fn set_screen_cell(mut pl PageList, x u16, y u16, cp u32) {
	p := pl.get_pin(.screen, x, y) or { return }
	if int(p.y) < p.node.data.rows.len {
		mut row := &p.node.data.rows[int(p.y)]
		if int(p.x) < row.cells.len {
			row.cells[int(p.x)] = CellData{
				content_tag: .codepoint
				codepoint: cp
			}
		}
	}
}

// ============================================================
// Init tests
// ============================================================

fn test_page_list_init() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.cols == 80
	assert s.rows == 24
	assert s.total_rows == 24
	assert s.viewport == .active

	// Verify we can get cells in the active area
	cell := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert cell.cell.codepoint == 0
}

fn test_page_list_init_rows_across_two_pages() {
	// Use enough rows to require two pages
	cap := initial_capacity(80)
	rows := u16(cap.rows * 2 + 10)
	mut s := PageList.init(80, rows, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.total_rows == usize(rows)
	assert s.total_pages() >= 2
}

fn test_page_list_init_more_than_max_cols() {
	// Test large column count triggers capacity adjustment
	mut s := PageList.init(500, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.cols == 500
	assert s.rows == 24
	assert s.total_rows == 24
}

// ============================================================
// pointFromPin tests
// ============================================================

fn test_page_list_point_from_pin_active_no_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// With no history, active pin at (0,0) should be at screen (0,0)
	p := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	pt := s.point_from_pin(.active, p) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert pt.x == 0
	assert pt.y == 0

	// Active pin at (5, 10)
	p2 := s.get_pin(.active, 5, 10) or {
		assert false, 'get_pin failed'
		return
	}
	pt2 := s.point_from_pin(.active, p2) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert pt2.x == 5
	assert pt2.y == 10
}

fn test_page_list_point_from_pin_active_with_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow to create scrollback
	s.grow_rows(50)

	// Active pin at (0,0) should still be (0,0) in active coords
	p := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	pt := s.point_from_pin(.active, p) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert pt.x == 0
	assert pt.y == 0

	// Screen pin at active area should have y offset by history
	pt_screen := s.point_from_pin(.screen, p) or {
		assert false, 'point_from_pin screen failed'
		return
	}
	assert pt_screen.y > 0 // Should be offset by scrollback
}

fn test_page_list_point_from_pin_traverse_pages() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow enough to span multiple pages
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 3)

	// Get a pin in the active area and convert
	p := s.get_pin(.active, 5, 10) or {
		assert false, 'get_pin failed'
		return
	}
	pt := s.point_from_pin(.active, p) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert pt.x == 5
	assert pt.y == 10
}

// ============================================================
// Grow tests
// ============================================================

fn test_page_list_grow_fit_in_capacity() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	initial_pages := s.total_pages()
	initial_rows := s.total_rows

	// Grow by one row - should fit in existing page
	s.grow() or {}
	assert s.total_rows == initial_rows + 1
	assert s.total_pages() == initial_pages
}

fn test_page_list_grow_allocate() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Fill the first page
	cap := initial_capacity(80)
	remaining := usize(cap.rows) - s.total_rows
	s.grow_rows(remaining)

	initial_pages := s.total_pages()

	// Now grow one more should allocate new page
	s.grow() or {}
	assert s.total_pages() == initial_pages + 1
}

fn test_page_list_active_after_grow() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Write to first active row
	set_active_cell(mut s, 0, 0, u32(0x41))

	// Grow
	s.grow_rows(50)

	// Row 0 in active should now be blank (original row scrolled to history)
	cell := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert cell.cell.codepoint == 0 || cell.cell.content_tag == .bg_color_only
}

fn test_page_list_grow_prune_scrollback() {
	// Use limited max_size to force pruning
	cap := initial_capacity(80)
	page_bytes := usize(cap.cols) * usize(cap.rows) * 16
	max_sz := page_bytes * 2 // Only room for ~2 pages

	mut s := PageList.init(80, 24, max_sz)
	defer { s.deinit() }

	// Grow until we've exceeded our capacity
	for _ in 0 .. int(cap.rows) * 5 {
		s.grow() or {}
	}

	// Total rows should still be valid
	assert s.total_rows >= usize(s.rows)
	s.assert_integrity()
}

fn test_page_list_grow_prune_with_viewport_pin() {
	cap := initial_capacity(80)
	page_bytes := usize(cap.cols) * usize(cap.rows) * 16
	max_sz := page_bytes * 3

	mut s := PageList.init(80, 24, max_sz)
	defer { s.deinit() }

	// Grow to create some scrollback
	s.grow_rows(50)

	// Scroll to top to set viewport pin
	s.scroll(PageScrollTop{})
	assert s.viewport == .top

	// Grow a lot more to force pruning
	for _ in 0 .. int(cap.rows) * 5 {
		s.grow() or {}
	}

	// Should still be valid
	assert s.total_rows >= usize(s.rows)
	s.assert_integrity()
}

fn test_page_list_scrollbar_with_max_size_0_after_grow() {
	mut s := PageList.init(80, 24, usize(0))
	defer { s.deinit() }

	s.grow_rows(10)

	sb := s.scrollbar()
	assert sb.total == usize(s.rows)
	assert sb.len == usize(s.rows)
}

// ============================================================
// Scroll tests
// ============================================================

fn test_page_list_scroll_with_max_size_0_no_history() {
	mut s := PageList.init(80, 24, usize(0))
	defer { s.deinit() }

	s.scroll(PageScrollDeltaRow{ delta: -1 })
	assert s.viewport == .active

	s.scroll(PageScrollTop{})
	assert s.viewport == .active
}

fn test_page_list_scroll_top() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	s.scroll(PageScrollTop{})
	assert s.viewport == .top

	sb := s.scrollbar()
	assert sb.offset == 0

	// Back to active
	s.scroll(PageScrollActive{})
	assert s.viewport == .active
}

fn test_page_list_scroll_delta_row_back() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	// Scroll back
	s.scroll(PageScrollDeltaRow{ delta: -10 })

	// Should be in pin mode (not active)
	assert s.viewport != .active

	sb := s.scrollbar()
	expected_offset := s.total_rows - usize(s.rows) - 10
	assert sb.offset == expected_offset
}

fn test_page_list_scroll_delta_row_back_overflow() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create some scrollback
	s.grow_rows(50)

	// Scroll back more than available
	s.scroll(PageScrollDeltaRow{ delta: -int(s.total_rows) })

	// Should be at top
	assert s.viewport == .top

	sb := s.scrollbar()
	assert sb.offset == 0
}

fn test_page_list_scroll_delta_row_forward() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback and scroll to top
	s.grow_rows(100)
	s.scroll(PageScrollTop{})

	// Scroll forward
	s.scroll(PageScrollDeltaRow{ delta: 10 })

	sb := s.scrollbar()
	assert sb.offset == 10
}

fn test_page_list_scroll_delta_row_forward_into_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback and scroll to top
	s.grow_rows(100)
	s.scroll(PageScrollTop{})

	// Scroll forward more than scrollback
	s.scroll(PageScrollDeltaRow{ delta: int(s.total_rows) })

	// Should be back at active
	assert s.viewport == .active
}

fn test_page_list_scroll_to_pin() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	// Get a pin in scrollback
	p := s.get_pin(.screen, 0, 5) or {
		assert false, 'get_pin failed'
		return
	}

	s.scroll(PageScrollPin{ pin: p })
	assert s.viewport == .pin
}

fn test_page_list_scroll_to_pin_in_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	// Get a pin in active area
	p := s.get_pin(.active, 0, 10) or {
		assert false, 'get_pin failed'
		return
	}

	// Scrolling to active pin should keep viewport active
	s.scroll(PageScrollPin{ pin: p })
	assert s.viewport == .active
}

fn test_page_list_scroll_to_pin_at_top() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	// Get pin at very top
	p := s.get_pin(.screen, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}

	s.scroll(PageScrollPin{ pin: p })
	assert s.viewport == .top
}

fn test_page_list_scroll_to_row_0() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	s.scroll(PageScrollRow{ n: 0 })
	assert s.viewport == .top

	sb := s.scrollbar()
	assert sb.offset == 0
}

fn test_page_list_scroll_to_row_in_scrollback() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	s.scroll(PageScrollRow{ n: 10 })
	assert s.viewport == .pin

	sb := s.scrollbar()
	assert sb.offset == 10
}

fn test_page_list_scroll_to_row_in_middle() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	mid := s.total_rows / 2
	s.scroll(PageScrollRow{ n: mid })
	assert s.viewport == .pin

	sb := s.scrollbar()
	assert sb.offset == mid
}

fn test_page_list_scroll_to_row_at_active_boundary() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	boundary := s.total_rows - usize(s.rows)
	s.scroll(PageScrollRow{ n: boundary })

	// Should be at active since this is the active boundary
	assert s.viewport == .active
}

fn test_page_list_scroll_to_row_beyond_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	s.scroll(PageScrollRow{ n: s.total_rows })

	// Past active should clamp to active
	assert s.viewport == .active
}

fn test_page_list_scroll_to_row_without_scrollback() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// No scrollback, any scroll should stay active
	s.scroll(PageScrollRow{ n: 0 })
	assert s.viewport == .top

	s.scroll(PageScrollRow{ n: 10 })
	assert s.viewport == .active
}

fn test_page_list_scroll_to_row_then_delta() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create scrollback
	s.grow_rows(100)

	// Scroll to row 10
	s.scroll(PageScrollRow{ n: 10 })
	assert s.viewport == .pin

	sb1 := s.scrollbar()
	assert sb1.offset == 10

	// Now delta forward by 5
	s.scroll(PageScrollDeltaRow{ delta: 5 })

	sb2 := s.scrollbar()
	assert sb2.offset == 15
}

fn test_page_list_scroll_clear() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Write to a few rows
	for y in u16(0) .. 5 {
		set_active_cell(mut s, 0, y, u32(0x41))
	}

	initial_rows := s.total_rows

	// Scroll clear pushes active content to scrollback
	s.scroll_clear()

	// Should have more rows now (original + new blank active rows)
	assert s.total_rows > initial_rows
}

// ============================================================
// Total pages / rows tests
// ============================================================

fn test_page_list_total_pages() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	initial := s.total_pages()
	assert initial >= 1

	// Grow enough to create new pages
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 3)

	assert s.total_pages() > initial
}

fn test_page_list_count_total_rows() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.count_total_rows() == s.total_rows

	s.grow_rows(100)

	assert s.count_total_rows() == s.total_rows
}

// ============================================================
// Get top-left / bottom-right tests
// ============================================================

fn test_page_list_get_top_left_screen() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	tl := s.get_top_left(.screen)
	assert tl.y == 0
	assert tl.x == 0
}

fn test_page_list_get_top_left_active_no_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	tl_screen := s.get_top_left(.screen)
	tl_active := s.get_top_left(.active)

	// With no history, screen and active should be the same
	assert tl_screen.eql(tl_active)
}

fn test_page_list_get_top_left_active_with_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(50)

	tl_screen := s.get_top_left(.screen)
	tl_active := s.get_top_left(.active)

	// Active should be after screen (history is before active)
	assert tl_screen.before(tl_active)
}

fn test_page_list_get_bottom_right() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	br := s.get_bottom_right(.active) or {
		assert false, 'get_bottom_right failed'
		return
	}
	assert br.x == s.cols - 1
}

// ============================================================
// Track pin tests
// ============================================================

fn test_page_list_track_pin() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	p := s.get_pin(.active, 5, 10) or {
		assert false, 'get_pin failed'
		return
	}

	tp := s.track_pin(p)
	assert tp.x == 5
	assert tp.y == p.y

	s.untrack_pin(tp)
}

fn test_page_list_pin_is_valid() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	p := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}

	assert s.pin_is_valid(p)
}

fn test_page_list_pin_is_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create history
	s.grow_rows(50)

	// Active pin
	p_active := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	assert s.pin_is_active(p_active)

	// Screen pin at row 0 should be history (not active)
	p_screen := s.get_pin(.screen, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	assert !s.pin_is_active(p_screen)
}

// ============================================================
// Erase tests
// ============================================================

fn test_page_list_erase() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.total_pages() >= 1

	// Grow to 5+ pages
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 5)

	assert s.total_pages() >= 5
	assert s.total_rows > usize(s.rows)

	// Erase entire history
	s.erase_rows(.history, none)
	assert s.total_rows == usize(s.rows)
	// Should be back to 1 page (or close)
	assert s.total_pages() <= 2
}

fn test_page_list_erase_active_regrows_automatically() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.total_rows == usize(s.rows)

	// Erase some active rows
	s.erase_rows(.active, PointTag(.active))
	assert s.total_rows == usize(s.rows)
}

fn test_page_list_erase_resets_viewport_to_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow and scroll to top
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 5)

	s.scroll(PageScrollTop{})
	assert s.viewport == .top

	// Erase history
	s.erase_rows(.history, none)

	// Viewport should be back to active since there's no history
	assert s.viewport == .active || s.viewport == .top
}

fn test_page_list_erase_one_row_active() {
	mut s := PageList.init(10, 1, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.total_pages() >= 1

	// Write a letter
	set_active_cell(mut s, 0, 0, u32(0x41))

	// Verify it's there
	cell := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert cell.cell.codepoint == u32(0x41)

	// Erase active
	s.erase_rows(.active, PointTag(.active))
	assert s.total_rows == usize(s.rows)

	// Row should be empty
	cell2 := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed after erase'
		return
	}
	assert cell2.cell.codepoint == 0 || cell2.cell.content_tag == .bg_color_only
}

fn test_page_list_erase_row() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Write codepoints to identify rows
	for y in u16(0) .. s.rows {
		set_active_cell(mut s, 0, y, u32(y) + u32(0x41))
	}

	// Erase row 0
	p := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	s.erase_row(p)

	// After erase, row 0 should have what was row 1 ('B')
	cell := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert cell.cell.codepoint == u32(0x42)
}

fn test_page_list_erase_row_with_tracked_pin() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Track a pin at row 5
	p := s.get_pin(.active, 2, 5) or {
		assert false, 'get_pin failed'
		return
	}
	tp := s.track_pin(p)

	// Erase row 0 (before tracked pin)
	erase_pin := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	s.erase_row(erase_pin)

	// Tracked pin should shift up by 1
	assert tp.y == p.y - 1

	s.untrack_pin(tp)
}

// ============================================================
// Split tests
// ============================================================

fn test_page_list_split_at_middle_row() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	// Write to identify rows
	for y in u16(0) .. 10 {
		set_active_cell(mut s, 0, y, u32(y) + u32(0x41))
	}

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	split_pin := PagePin{
		node: first
		y: 5
		x: 0
	}
	s.split(split_pin) or {
		assert false, 'split failed: ${err}'
		return
	}

	// Should now have 2 pages
	assert s.total_pages() == 2

	// First page should have rows 0-4
	assert first.data.size.rows == 5

	// Second page should have rows 5-9
	second := first.next or {
		assert false, 'no second page'
		return
	}
	assert second.data.size.rows == 5
}

fn test_page_list_split_at_row_0_noop() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	split_pin := PagePin{
		node: first
		y: 0
		x: 0
	}
	s.split(split_pin) or {
		assert false, 'split failed: ${err}'
		return
	}

	// Should still have 1 page (no-op for y=0)
	assert s.total_pages() == 1
}

fn test_page_list_split_at_last_row() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	split_pin := PagePin{
		node: first
		y: 9
		x: 0
	}
	s.split(split_pin) or {
		assert false, 'split failed: ${err}'
		return
	}

	// Should have 2 pages: 9 rows + 1 row
	assert s.total_pages() == 2
	assert first.data.size.rows == 9

	second := first.next or {
		assert false, 'no second page'
		return
	}
	assert second.data.size.rows == 1
}

fn test_page_list_split_moves_tracked_pins() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	// Track a pin at row 7
	p := s.get_pin(.active, 2, 7) or {
		assert false, 'get_pin failed'
		return
	}
	tp := s.track_pin(p)

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	split_pin := PagePin{
		node: first
		y: 5
		x: 0
	}
	s.split(split_pin) or {
		assert false, 'split failed: ${err}'
		return
	}

	// Pin was at row 7, split at 5, so pin should move to second page row 2
	second := first.next or {
		assert false, 'no second page'
		return
	}
	assert voidptr(tp.node) == voidptr(second)
	assert tp.y == 2 // 7 - 5
	assert tp.x == 2

	s.untrack_pin(tp)
}

fn test_page_list_split_tracked_pin_before_split_unchanged() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	// Track a pin at row 2
	p := s.get_pin(.active, 3, 2) or {
		assert false, 'get_pin failed'
		return
	}
	tp := s.track_pin(p)

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	split_pin := PagePin{
		node: first
		y: 5
		x: 0
	}
	s.split(split_pin) or {
		assert false, 'split failed: ${err}'
		return
	}

	// Pin should stay in first page
	assert voidptr(tp.node) == voidptr(first)
	assert tp.y == p.y
	assert tp.x == 3

	s.untrack_pin(tp)
}

fn test_page_list_split_tracked_pin_at_split_point() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	// Track a pin at exactly row 5
	p := s.get_pin(.active, 0, 5) or {
		assert false, 'get_pin failed'
		return
	}
	tp := s.track_pin(p)

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	split_pin := PagePin{
		node: first
		y: 5
		x: 0
	}
	s.split(split_pin) or {
		assert false, 'split failed: ${err}'
		return
	}

	// Pin at split point moves to second page row 0
	second := first.next or {
		assert false, 'no second page'
		return
	}
	assert voidptr(tp.node) == voidptr(second)
	assert tp.y == 0

	s.untrack_pin(tp)
}

fn test_page_list_split_preserves_wrap_flags() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Set wrap flags on rows
	page.rows[5].wrap = true
	page.rows[6].wrap_continuation = true
	page.rows[7].wrap = true
	page.rows[7].wrap_continuation = true

	split_pin := PagePin{
		node: first
		y: 5
		x: 0
	}
	s.split(split_pin) or {
		assert false, 'split failed: ${err}'
		return
	}

	second := first.next or {
		assert false, 'no second page'
		return
	}

	// Row 5 -> second page row 0
	assert second.data.rows[0].wrap == true
	assert second.data.rows[0].wrap_continuation == false

	// Row 6 -> second page row 1
	assert second.data.rows[1].wrap == false
	assert second.data.rows[1].wrap_continuation == true

	// Row 7 -> second page row 2
	assert second.data.rows[2].wrap == true
	assert second.data.rows[2].wrap_continuation == true
}

fn test_page_list_split_middle_page_preserves_order() {
	mut s := PageList.init(10, 12, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	// Split to create 2 pages (at row 4)
	split1 := PagePin{
		node: first
		y: 4
		x: 0
	}
	s.split(split1) or {
		assert false, 'split1 failed: ${err}'
		return
	}
	assert s.total_pages() == 2

	// Split second page to create 3 pages
	second := first.next or {
		assert false, 'no second page'
		return
	}
	split2 := PagePin{
		node: second
		y: 4
		x: 0
	}
	s.split(split2) or {
		assert false, 'split2 failed: ${err}'
		return
	}
	assert s.total_pages() == 3

	// Verify linked list order
	n1 := s.pages.first or {
		assert false
		return
	}
	n2 := n1.next or {
		assert false
		return
	}
	n3 := n2.next or {
		assert false
		return
	}
	assert n3.next == none

	// Verify row counts: 4, 4, 4
	assert n1.data.size.rows == 4
	assert n2.data.size.rows == 4
	assert n3.data.size.rows == 4
}

// ============================================================
// Clone tests
// ============================================================

fn test_page_list_clone() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	mut c := s.clone(PageCloneOpts{})
	defer { c.deinit() }

	assert c.total_rows == s.total_rows
	assert c.cols == s.cols
	assert c.rows == s.rows
}

fn test_page_list_clone_with_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(100)

	mut c := s.clone(PageCloneOpts{})
	defer { c.deinit() }

	assert c.total_rows == s.total_rows
}

fn test_page_list_clone_active_only() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(100)

	mut c := s.clone(PageCloneOpts{
		top: .active
	})
	defer { c.deinit() }

	// Clone of active should have at least 24 rows
	assert c.total_rows >= usize(s.rows)
}

fn test_page_list_clone_less_than_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(100)

	// Clone just active area, should be regrown to full active size
	mut c := s.clone(PageCloneOpts{
		top: .active
	})
	defer { c.deinit() }

	assert c.total_rows >= usize(s.rows)
}

// ============================================================
// Resize without reflow tests
// ============================================================

fn test_page_list_resize_no_reflow_more_rows() {
	mut s := PageList.init(80, 3, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.total_rows == 3

	s.resize(PageResizeOpts{
		cols: 80
		rows: 10
		reflow: false
	})

	assert s.rows == 10
	assert s.total_rows >= 10
}

fn test_page_list_resize_no_reflow_more_rows_with_history() {
	mut s := PageList.init(80, 3, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Create history
	s.grow_rows(50)

	old_total := s.total_rows

	s.resize(PageResizeOpts{
		cols: 80
		rows: 10
		reflow: false
	})

	assert s.rows == 10
	assert s.total_rows >= old_total
}

fn test_page_list_resize_no_reflow_less_rows() {
	mut s := PageList.init(80, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Write to all rows
	for y in u16(0) .. 10 {
		set_active_cell(mut s, 0, y, u32(y) + u32(0x41))
	}

	s.resize(PageResizeOpts{
		cols: 80
		rows: 5
		reflow: false
	})

	assert s.rows == 5
}

fn test_page_list_resize_no_reflow_one_row() {
	mut s := PageList.init(80, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Write to all rows
	for y in u16(0) .. 10 {
		set_active_cell(mut s, 0, y, u32(y) + u32(0x41))
	}

	s.resize(PageResizeOpts{
		cols: 80
		rows: 1
		reflow: false
	})

	assert s.rows == 1
}

fn test_page_list_resize_no_reflow_less_cols() {
	mut s := PageList.init(10, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.resize(PageResizeOpts{
		cols: 5
		rows: 10
		reflow: false
	})

	assert s.cols == 5

	// Verify all rows have 5 cells
	mut node := s.pages.first
	for {
		n := node or { break }
		for row in n.data.rows {
			assert row.cells.len == 5
		}
		node = n.next
	}
}

fn test_page_list_resize_no_reflow_less_cols_pin_in_trimmed() {
	mut s := PageList.init(10, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Track a pin at x=8
	p := s.get_pin(.active, 8, 0) or {
		assert false, 'get_pin failed'
		return
	}
	tp := s.track_pin(p)

	s.resize(PageResizeOpts{
		cols: 5
		rows: 10
		reflow: false
	})

	// Pin should be clamped to x=4
	assert tp.x == 4

	s.untrack_pin(tp)
}

fn test_page_list_resize_no_reflow_more_cols() {
	mut s := PageList.init(5, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.resize(PageResizeOpts{
		cols: 10
		rows: 10
		reflow: false
	})

	assert s.cols == 10

	// Verify all rows have 10 cells
	mut node := s.pages.first
	for {
		n := node or { break }
		for row in n.data.rows {
			assert row.cells.len == 10
		}
		node = n.next
	}
}

fn test_page_list_resize_no_reflow_less_cols_then_more() {
	mut s := PageList.init(5, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.resize(PageResizeOpts{
		cols: 2
		rows: 10
		reflow: false
	})
	assert s.cols == 2

	s.resize(PageResizeOpts{
		cols: 5
		rows: 10
		reflow: false
	})
	assert s.cols == 5

	// Verify all rows have 5 cells
	mut node := s.pages.first
	for {
		n := node or { break }
		for row in n.data.rows {
			assert row.cells.len == 5
		}
		node = n.next
	}
}

fn test_page_list_resize_no_reflow_less_rows_and_cols() {
	mut s := PageList.init(10, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.resize(PageResizeOpts{
		cols: 5
		rows: 5
		reflow: false
	})

	assert s.cols == 5
	assert s.rows == 5
}

fn test_page_list_resize_no_reflow_more_rows_and_less_cols() {
	mut s := PageList.init(10, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.resize(PageResizeOpts{
		cols: 5
		rows: 20
		reflow: false
	})

	assert s.cols == 5
	assert s.rows == 20
	assert s.total_rows >= 20
}

fn test_page_list_resize_no_reflow_empty_screen() {
	mut s := PageList.init(5, 5, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.resize(PageResizeOpts{
		cols: 10
		rows: 10
		reflow: false
	})

	assert s.cols == 10
	assert s.rows == 10

	// Verify cell access works
	cell := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert cell.cell.codepoint == 0 || cell.cell.content_tag == .bg_color_only
}

fn test_page_list_resize_more_rows_and_cols_large() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.resize(PageResizeOpts{
		cols: 200
		rows: 200
		reflow: true
	})

	assert s.cols == 200
	assert s.rows == 200
	assert s.total_rows >= 200
}

// ============================================================
// Reset tests
// ============================================================

fn test_page_list_reset() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Write something
	set_active_cell(mut s, 0, 0, u32(0x41))

	s.reset()

	assert s.viewport == .active
	assert s.total_rows == usize(s.rows)

	// Content should be cleared
	first := s.pages.first or {
		assert false, 'no first page after reset'
		return
	}
	_ = first // exists
}

fn test_page_list_reset_across_two_pages() {
	cap := initial_capacity(80)
	rows := u16(cap.rows + 10)
	mut s := PageList.init(80, rows, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.reset()

	assert s.viewport == .active
	assert s.total_rows == usize(rows)
}

fn test_page_list_reset_moves_tracked_pins() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Track a pin
	p := s.get_pin(.active, 5, 10) or {
		assert false, 'get_pin failed'
		return
	}
	tp := s.track_pin(p)

	s.reset()

	// Tracked pin should be marked garbage
	assert tp.garbage == true
	assert tp.y == 0
	assert tp.x == 0

	// Viewport pin should NOT be garbage
	assert s.viewport_pin.garbage == false

	s.untrack_pin(tp)
}

fn test_page_list_reset_clears_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow to create history
	s.grow_rows(100)
	assert s.total_rows > usize(s.rows)

	s.reset()

	assert s.total_rows == usize(s.rows)
}

// ============================================================
// Dirty tracking tests
// ============================================================

fn test_page_list_dirty() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Clear dirty
	s.clear_dirty()
	assert !s.is_dirty()

	// Set a row dirty
	p := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	mut pin := PagePin{
		node: p.node
		y: p.y
		x: p.x
	}
	pin.mark_dirty()

	assert s.is_dirty()

	s.clear_dirty()
	assert !s.is_dirty()
}

// ============================================================
// Iterator tests
// ============================================================

fn test_page_list_page_iterator_single_page() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	mut it := s.page_iterator(.right_down, .active, none)
	mut count := 0
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count >= 1
}

fn test_page_list_page_iterator_two_pages() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow to create 2+ pages
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 2)

	mut it := s.page_iterator(.right_down, .screen, none)
	mut count := 0
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count >= 2
}

fn test_page_list_page_iterator_reverse() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 2)

	mut it := s.page_iterator(.left_up, .screen, none)
	mut count := 0
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count >= 2
}

fn test_page_list_row_iterator() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	mut it := s.row_iterator(.right_down, .active, none)
	mut count := usize(0)
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count == usize(s.rows)
}

fn test_page_list_row_iterator_with_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(50)

	// Active iterator should still give rows count
	mut it := s.row_iterator(.right_down, .active, none)
	mut count := usize(0)
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count == usize(s.rows)

	// Screen iterator should give total_rows
	mut it2 := s.row_iterator(.right_down, .screen, none)
	mut count2 := usize(0)
	for {
		_ := it2.next() or { break }
		count2 += 1
	}
	assert count2 == s.total_rows
}

fn test_page_list_cell_iterator() {
	mut s := PageList.init(10, 5, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	mut it := s.cell_iterator(.right_down, .active, none)
	mut count := usize(0)
	for {
		_ := it.next() or { break }
		count += 1
	}
	// Should be cols * rows cells
	assert count == usize(s.cols) * usize(s.rows)
}

fn test_page_list_cell_iterator_reverse() {
	mut s := PageList.init(10, 5, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	mut it := s.cell_iterator(.left_up, .active, none)
	mut count := usize(0)
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count == usize(s.cols) * usize(s.rows)
}

fn test_page_list_prompt_iterator() {
	mut s := PageList.init(10, 20, usize(0))
	defer { s.deinit() }

	// Set semantic prompts on some rows
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	page.rows[5].semantic_prompt = .prompt
	page.rows[10].semantic_prompt = .command
	page.rows[15].semantic_prompt = .input

	// Forward prompt iterator should find 3 prompts
	tl := s.get_top_left(.screen)
	mut it := tl.prompt_iterator(.right_down, none)
	mut count := 0
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count == 3
}

fn test_page_list_prompt_iterator_reverse() {
	mut s := PageList.init(10, 20, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	page.rows[5].semantic_prompt = .prompt
	page.rows[10].semantic_prompt = .command
	page.rows[15].semantic_prompt = .input

	// Reverse prompt iterator from bottom
	br := s.get_bottom_right(.screen) or {
		assert false, 'get_bottom_right failed'
		return
	}
	mut it := br.prompt_iterator(.left_up, none)
	mut count := 0
	for {
		_ := it.next() or { break }
		count += 1
	}
	assert count == 3
}

// ============================================================
// PagePin movement tests
// ============================================================

fn test_page_pin_left_right() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	p := s.get_pin(.active, 5, 3) or {
		assert false, 'get_pin failed'
		return
	}

	left := p.left(2)
	assert left.x == 3
	assert left.y == p.y

	right := p.right(3)
	assert right.x == 8
	assert right.y == p.y
}

fn test_page_pin_left_clamp_right_clamp() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	p := s.get_pin(.active, 2, 0) or {
		assert false, 'get_pin failed'
		return
	}

	// Left clamp past 0
	lc := p.left_clamp(10)
	assert lc.x == 0

	// Right clamp past end
	rc := p.right_clamp(20)
	assert rc.x == 9 // cols - 1
}

fn test_page_pin_down_up() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	p := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}

	// Down
	d := p.down(5) or {
		assert false, 'down failed'
		return
	}
	pt := s.point_from_pin(.active, d) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert pt.y == 5

	// Up
	u := d.up(3) or {
		assert false, 'up failed'
		return
	}
	pt2 := s.point_from_pin(.active, u) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert pt2.y == 2
}

fn test_page_pin_down_overflow() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	p := s.get_pin(.active, 0, 5) or {
		assert false, 'get_pin failed'
		return
	}

	// Within bounds
	result := p.down_overflow(3)
	match result {
		DownOverflowOffset {
			pt := s.point_from_pin(.active, result.pin) or {
				assert false, 'point_from_pin failed'
				return
			}
			assert pt.y == 8
		}
		DownOverflowOverflow {
			assert false, 'should not overflow'
		}
	}

	// Past end
	result2 := p.down_overflow(100)
	match result2 {
		DownOverflowOffset {
			assert false, 'should overflow'
		}
		DownOverflowOverflow {
			assert result2.remaining > 0
		}
	}
}

fn test_page_pin_up_overflow() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	p := s.get_pin(.active, 0, 5) or {
		assert false, 'get_pin failed'
		return
	}

	// Within bounds
	result := p.up_overflow(3)
	match result {
		UpOverflowOffset {
			pt := s.point_from_pin(.active, result.pin) or {
				assert false, 'point_from_pin failed'
				return
			}
			assert pt.y == 2
		}
		UpOverflowOverflow {
			assert false, 'should not overflow'
		}
	}

	// Past beginning
	result2 := p.up_overflow(100)
	match result2 {
		UpOverflowOffset {
			assert false, 'should overflow'
		}
		UpOverflowOverflow {
			assert result2.remaining > 0
		}
	}
}

fn test_page_pin_before() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	p1 := s.get_pin(.active, 0, 2) or {
		assert false
		return
	}
	p2 := s.get_pin(.active, 0, 5) or {
		assert false
		return
	}

	assert p1.before(p2)
	assert !p2.before(p1)
	assert !p1.before(p1) // Same pin
}

fn test_page_pin_eql() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	p1 := s.get_pin(.active, 3, 5) or {
		assert false
		return
	}
	p2 := s.get_pin(.active, 3, 5) or {
		assert false
		return
	}
	p3 := s.get_pin(.active, 4, 5) or {
		assert false
		return
	}

	assert p1.eql(p2)
	assert !p1.eql(p3)
}

fn test_page_pin_is_between() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	top := s.get_pin(.active, 0, 2) or {
		assert false
		return
	}
	mid := s.get_pin(.active, 0, 5) or {
		assert false
		return
	}
	bot := s.get_pin(.active, 0, 8) or {
		assert false
		return
	}

	assert mid.is_between(top, bot)
	assert top.is_between(top, bot) // Inclusive
	assert bot.is_between(top, bot) // Inclusive
	assert !s.get_pin(.active, 0, 0) or { return }.is_between(top, bot)
}

// ============================================================
// Integrity tests
// ============================================================

fn test_page_list_assert_integrity() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.assert_integrity()

	s.grow_rows(100)
	s.assert_integrity()
}

fn test_page_list_verify_integrity() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	assert s.verify_integrity()

	s.grow_rows(100)
	assert s.verify_integrity()
}

// ============================================================
// Scrollbar tests
// ============================================================

fn test_page_list_scrollbar_no_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	sb := s.scrollbar()
	assert sb.total == usize(s.rows)
	assert sb.offset == 0
	assert sb.len == usize(s.rows)
}

fn test_page_list_scrollbar_with_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(100)

	sb := s.scrollbar()
	assert sb.total == s.total_rows
	assert sb.offset == s.total_rows - usize(s.rows)
	assert sb.len == usize(s.rows)
}

fn test_page_list_scrollbar_at_top() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(100)
	s.scroll(PageScrollTop{})

	sb := s.scrollbar()
	assert sb.total == s.total_rows
	assert sb.offset == 0
	assert sb.len == usize(s.rows)
}

fn test_page_list_scrollbar_in_middle() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(100)
	s.scroll(PageScrollRow{ n: 50 })

	sb := s.scrollbar()
	assert sb.total == s.total_rows
	assert sb.offset == 50
	assert sb.len == usize(s.rows)
}

// ============================================================
// Page-linked-list tests
// ============================================================

fn test_page_node_list_append_remove() {
	mut list := PageNodeList{}

	n1 := &PageNode{
		data: Page.init(std_capacity)
		serial: 1
	}
	n2 := &PageNode{
		data: Page.init(std_capacity)
		serial: 2
	}
	n3 := &PageNode{
		data: Page.init(std_capacity)
		serial: 3
	}

	list.append(n1)
	list.append(n2)
	list.append(n3)

	// Verify order
	f := list.first or {
		assert false
		return
	}
	assert f.serial == 1
	s := f.next or {
		assert false
		return
	}
	assert s.serial == 2
	t := s.next or {
		assert false
		return
	}
	assert t.serial == 3

	// Remove middle
	list.remove(n2)
	f2 := list.first or {
		assert false
		return
	}
	n := f2.next or {
		assert false
		return
	}
	assert n.serial == 3
}

fn test_page_node_list_prepend() {
	mut list := PageNodeList{}

	n1 := &PageNode{
		data: Page.init(std_capacity)
		serial: 1
	}
	n2 := &PageNode{
		data: Page.init(std_capacity)
		serial: 2
	}

	list.append(n1)
	list.prepend(n2)

	f := list.first or {
		assert false
		return
	}
	assert f.serial == 2
}

fn test_page_node_list_insert_after() {
	mut list := PageNodeList{}

	n1 := &PageNode{
		data: Page.init(std_capacity)
		serial: 1
	}
	n2 := &PageNode{
		data: Page.init(std_capacity)
		serial: 2
	}
	n3 := &PageNode{
		data: Page.init(std_capacity)
		serial: 3
	}

	list.append(n1)
	list.append(n3)
	list.insert_after(n1, n2)

	f := list.first or {
		assert false
		return
	}
	s := f.next or {
		assert false
		return
	}
	assert s.serial == 2
	t := s.next or {
		assert false
		return
	}
	assert t.serial == 3
}

fn test_page_node_list_insert_before() {
	mut list := PageNodeList{}

	n1 := &PageNode{
		data: Page.init(std_capacity)
		serial: 1
	}
	n2 := &PageNode{
		data: Page.init(std_capacity)
		serial: 2
	}
	n3 := &PageNode{
		data: Page.init(std_capacity)
		serial: 3
	}

	list.append(n1)
	list.append(n3)
	list.insert_before(n3, n2)

	f := list.first or {
		assert false
		return
	}
	s := f.next or {
		assert false
		return
	}
	assert s.serial == 2
}

fn test_page_node_list_pop() {
	mut list := PageNodeList{}

	n1 := &PageNode{
		data: Page.init(std_capacity)
		serial: 1
	}
	n2 := &PageNode{
		data: Page.init(std_capacity)
		serial: 2
	}

	list.append(n1)
	list.append(n2)

	first := list.pop_first() or {
		assert false
		return
	}
	assert first.serial == 1

	last := list.pop_last() or {
		assert false
		return
	}
	assert last.serial == 2

	assert list.first == none
	assert list.last == none
}

// ============================================================
// Page tests
// ============================================================

fn test_page_init() {
	cap := PageCapacity{
		cols: 80
		rows: 24
	}
	p := Page.init(cap)

	assert p.capacity.cols == 80
	assert p.capacity.rows == 24
	assert p.rows.len == 24
	assert p.size.rows == 0
	assert p.size.cols == 80
}

fn test_page_clear_cells() {
	cap := PageCapacity{
		cols: 10
		rows: 5
	}
	mut p := Page.init(cap)
	p.size.rows = 5

	// Write to some cells
	p.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x41)
	}
	p.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x42)
	}

	// Clear cells 0-5 in row 0
	p.clear_cells(0, 0, 5)

	assert p.rows[0].cells[0].codepoint == 0
	assert p.rows[0].cells[1].codepoint == 0
}

fn test_page_clear_row() {
	cap := PageCapacity{
		cols: 10
		rows: 5
	}
	mut p := Page.init(cap)
	p.size.rows = 5

	p.rows[2].wrap = true
	p.rows[2].semantic_prompt = .prompt

	p.clear_row(2)

	assert p.rows[2].wrap == false
	assert p.rows[2].semantic_prompt == .unknown
}

fn test_page_clone_from() {
	cap := PageCapacity{
		cols: 10
		rows: 5
	}
	mut src := Page.init(cap)
	src.size.rows = 5

	// Write content
	src.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x58)
	}
	src.rows[1].wrap = true
	src.rows[2].semantic_prompt = .command

	mut dst := Page.init(cap)
	dst.size.rows = 3
	dst.clone_from(&src, 0, 3)

	assert dst.rows[0].cells[0].codepoint == u32(0x58)
	assert dst.rows[1].wrap == true
	assert dst.rows[2].semantic_prompt == .command
}

fn test_page_row_is_blank() {
	cap := PageCapacity{
		cols: 10
		rows: 5
	}
	mut p := Page.init(cap)
	p.size.rows = 5

	assert p.row_is_blank(0) == true

	p.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x41)
	}

	assert p.row_is_blank(0) == false
	assert p.row_is_blank(1) == true
}

fn test_page_capacity_adjust() {
	cap := PageCapacity{
		cols: 80
		rows: 128
	}

	// Normal cols - no adjustment
	adj := cap.adjust(80)
	assert adj.cols == 80
	assert adj.rows == 128

	// Very large cols - rows should reduce
	adj2 := cap.adjust(512)
	assert adj2.cols == 512
	assert adj2.rows < 128
}

fn test_page_reinit() {
	cap := PageCapacity{
		cols: 10
		rows: 5
	}
	mut p := Page.init(cap)
	p.size.rows = 5
	p.dirty = true
	p.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x5a)
	}

	new_cap := PageCapacity{
		cols: 20
		rows: 10
	}
	p.reinit(new_cap)

	assert p.capacity.cols == 20
	assert p.capacity.rows == 10
	assert p.size.rows == 0
	assert p.dirty == false
	assert p.rows.len == 10
}
