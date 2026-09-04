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

fn test_page_list_from_pages_translates_managed_cells() {
	mut src := Pages.init(4, 2, 0)
	defer { src.deinit() }

	style_a := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	style_b := CellStyle{
		flags: StyleFlags{
			italic: true
		}
	}
	link := Hyperlink{
		id: HyperlinkExplicitId{
			value: 'snapshot-link'
		}
		uri: 'https://example.com/snapshot'
	}

	src.screen_rows[0].styled = true
	src.screen_rows[0].hyperlink = true
	src.screen_rows[0].grapheme = true
	src.screen_rows[0].cells[0] = CellData{
		content_tag: .codepoint_grapheme
		codepoint: u32(`a`)
		has_grapheme: true
		graphemes: [u32(0x0301)]
		style_id: 1
		style: style_a
		has_hyperlink: true
		hyperlink: link.dupe()
	}
	src.screen_rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(`b`)
		style_id: 1
		style: style_a
		has_hyperlink: true
		hyperlink: link.dupe()
	}
	src.screen_rows[0].cells[2] = CellData{
		content_tag: .codepoint
		codepoint: u32(`c`)
		style_id: 1
		style: style_b
	}

	mut list := PageList.from_pages(&src)
	defer { list.deinit() }
	node := list.pages.first or {
		assert false, 'snapshot has no page'
		return
	}
	page := &node.data
	row := page.rows[0]

	assert row.cells[0].graphemes == [u32(0x0301)]
	assert row.cells[0].style_id != default_style_id
	assert row.cells[0].style_id == row.cells[1].style_id
	assert row.cells[2].style_id != row.cells[0].style_id
	assert page.styles.get(row.cells[0].style_id).eql(&style_a)
	assert page.styles.get(row.cells[2].style_id).eql(&style_b)
	assert page.styles.ref_count(row.cells[0].style_id) == 2
	assert page.styles.ref_count(row.cells[2].style_id) == 1

	first_link_id := page.lookup_hyperlink(0, 0) or {
		assert false, 'first snapshot hyperlink has no mapping'
		return
	}
	second_link_id := page.lookup_hyperlink(0, 1) or {
		assert false, 'second snapshot hyperlink has no mapping'
		return
	}
	assert first_link_id == second_link_id
	assert page.hyperlink_set.get(first_link_id).eql(&link)
	assert page.hyperlink_set.ref_count(first_link_id) == 2

	if integrity_error := page.verify_integrity() {
		assert false, 'snapshot page failed integrity: ${integrity_error}'
	}
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
	assert cell.cell.codepoint == 0 || cell.cell.content_tag == .bg_color_palette
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
	assert cell2.cell.codepoint == 0 || cell2.cell.content_tag == .bg_color_palette
}

fn test_page_list_erase_history_preserves_managed_survivor() {
	mut s := PageList.init(6, 4, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	s.grow_rows(2)
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	style_id := page.styles.add(CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}) or {
		assert false, 'style add failed'
		return
	}
	page.rows[2].cells[3] = CellData{
		content_tag: .codepoint
		codepoint: u32(`S`)
		style_id: style_id
	}
	page.rows[2].styled = true
	page.set_graphemes(2, 3, [u32(0x0302)])
	hyperlink_id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkExplicitId{
			value: 'survivor'
		}
		uri: 'https://example.com/survivor'
	})
	page.set_hyperlink(2, 3, hyperlink_id)

	// The first two rows are history. Erasing them compacts old row 2 to row 0.
	s.erase_rows(.history, none)

	assert s.total_rows == 4
	cell := page.rows[0].cells[3]
	assert cell.codepoint == u32(`S`)
	assert cell.graphemes == [u32(0x0302)]
	assert page.styles.get(cell.style_id).flags.bold
	assert page.styles.ref_count(cell.style_id) == 1
	moved_link_id := page.lookup_hyperlink(0, 3) or {
		assert false, 'survivor hyperlink mapping missing'
		return
	}
	assert page.hyperlink_set.get(moved_link_id).uri == 'https://example.com/survivor'
	assert page.hyperlink_set.ref_count(moved_link_id) == 1
	assert page.lookup_hyperlink(2, 3) == none
	page.assert_integrity()
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

fn test_page_list_erase_row_preserves_managed_cell_data() {
	mut s := PageList.init(8, 4, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	style_id := page.styles.add(CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}) or {
		assert false, 'style add failed'
		return
	}
	page.rows[1].cells[2] = CellData{
		content_tag: .codepoint
		codepoint: u32(`M`)
		style_id: style_id
	}
	page.rows[1].styled = true
	page.set_graphemes(1, 2, [u32(0x0301)])
	hyperlink_id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkExplicitId{
			value: 'managed'
		}
		uri: 'https://example.com/managed'
	})
	page.set_hyperlink(1, 2, hyperlink_id)

	s.erase_row(PagePin{ node: first, y: 0, x: 0 })

	cell := page.rows[0].cells[2]
	assert cell.codepoint == u32(`M`)
	assert cell.has_grapheme
	assert cell.graphemes == [u32(0x0301)]
	assert cell.style_id == style_id
	assert page.styles.get(cell.style_id).flags.bold
	assert page.styles.ref_count(cell.style_id) == 1
	assert cell.has_hyperlink
	moved_link_id := page.lookup_hyperlink(0, 2) or {
		assert false, 'moved hyperlink mapping missing'
		return
	}
	assert moved_link_id == hyperlink_id
	assert page.hyperlink_set.get(moved_link_id).uri == 'https://example.com/managed'
	assert page.hyperlink_set.ref_count(moved_link_id) == 1
	assert page.lookup_hyperlink(1, 2) == none
	page.assert_integrity()
}

fn test_page_list_erase_row_moves_managed_cell_and_pin_across_page_boundary() {
	mut s := PageList.init(4, 4, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	s.split(PagePin{ node: first, y: 2, x: 0 }) or {
		assert false, 'split failed'
		return
	}
	second := first.next or {
		assert false, 'no second page'
		return
	}
	mut second_page := &second.data
	second_page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(`B`)
	}
	hyperlink_id := second_page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 7
		}
		uri: 'https://example.com/boundary'
	})
	second_page.set_hyperlink(0, 1, hyperlink_id)
	tracked := s.track_pin(PagePin{ node: second, y: 0, x: 1 })

	s.erase_row(PagePin{ node: first, y: 1, x: 0 })

	assert voidptr(tracked.node) == voidptr(first)
	assert tracked.y == 1
	assert tracked.x == 1
	mut first_page := &first.data
	assert first_page.rows[1].cells[1].codepoint == u32(`B`)
	moved_link_id := first_page.lookup_hyperlink(1, 1) or {
		assert false, 'cross-page hyperlink mapping missing'
		return
	}
	assert first_page.hyperlink_set.get(moved_link_id).uri == 'https://example.com/boundary'
	assert first_page.hyperlink_set.ref_count(moved_link_id) == 1
	assert second_page.lookup_hyperlink(0, 1) == none
	first_page.assert_integrity()
	second_page.assert_integrity()
	s.untrack_pin(tracked)
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
	assert cell.cell.codepoint == 0 || cell.cell.content_tag == .bg_color_palette
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
// Newly translated tests from Ghostty PageList.zig
// ============================================================

fn test_page_list_point_from_pin_active_from_prior_page() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow so we take up at least 5 pages.
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 5)

	last := s.pages.last or {
		assert false, 'no last page'
		return
	}
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	// Pin in the active (last) page.
	pt := s.point_from_pin(.active, PagePin{ node: last, y: 0, x: 2 }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert pt.x == 2
	assert pt.y == 0

	// A pin in a prior (first) page is not in the active area.
	if _ := s.point_from_pin(.active, PagePin{ node: first, y: 0, x: 0 }) {
		assert false, 'expected point_from_pin to return none for prior page'
	}
}

fn test_page_list_scroll_delta_row_back_without_space_preserves_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.scroll(PageScrollDeltaRow{ delta: -1 })

	pc := s.get_cell(.viewport, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp := pc.screen_point()
	assert sp.x == 0
	assert sp.y == 0

	assert s.viewport == .active

	sb := s.scrollbar()
	assert sb.total == s.total_rows
	assert sb.offset == s.total_rows - usize(s.rows)
	assert sb.len == usize(s.rows)
}

fn test_page_list_scroll_to_row_with_cache_fast_path_down() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	s.grow_rows(50)

	s.scroll(PageScrollRow{ n: 10 })
	assert s.viewport == .pin
	sb1 := s.scrollbar()
	assert sb1.total == s.total_rows
	assert sb1.offset == 10
	assert sb1.len == usize(s.rows)

	pc1 := s.get_cell(.viewport, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp1 := pc1.screen_point()
	assert sp1.x == 0
	assert sp1.y == 10

	// Cache should be populated.
	off1 := s.viewport_pin_row_offset or {
		assert false, 'viewport_pin_row_offset not cached'
		return
	}
	assert off1 == 10

	// Scroll down to a different row - fast path.
	s.scroll(PageScrollRow{ n: 20 })
	assert s.viewport == .pin
	sb2 := s.scrollbar()
	assert sb2.offset == 20

	pc2 := s.get_cell(.viewport, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp2 := pc2.screen_point()
	assert sp2.y == 20

	s.grow_rows(10)
	pc3 := s.get_cell(.viewport, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp3 := pc3.screen_point()
	assert sp3.y == 20

	sb3 := s.scrollbar()
	assert sb3.offset == 20
}

fn test_page_list_scroll_to_row_with_cache_fast_path_up() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	s.grow_rows(50)

	s.scroll(PageScrollRow{ n: 30 })
	assert s.viewport == .pin
	sb1 := s.scrollbar()
	assert sb1.offset == 30

	pc1 := s.get_cell(.viewport, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert pc1.screen_point().y == 30

	off1 := s.viewport_pin_row_offset or {
		assert false, 'viewport_pin_row_offset not cached'
		return
	}
	assert off1 == 30

	// Scroll up to a different row - fast path.
	s.scroll(PageScrollRow{ n: 15 })
	assert s.viewport == .pin
	sb2 := s.scrollbar()
	assert sb2.offset == 15

	pc2 := s.get_cell(.viewport, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert pc2.screen_point().y == 15

	s.grow_rows(10)
	pc3 := s.get_cell(.viewport, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert pc3.screen_point().y == 15

	sb3 := s.scrollbar()
	assert sb3.offset == 15
}

fn test_page_list_reset_moves_tracked_pins_and_marks_garbage() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	p := s.get_pin(.active, 42, 12) or {
		assert false, 'get_pin failed'
		return
	}
	tp := s.track_pin(p)

	s.reset()

	// Our added pin should now be garbage.
	assert tp.garbage

	// Viewport pin should not be garbage because it makes sense.
	assert !s.viewport_pin.garbage

	s.untrack_pin(tp)
}

fn test_page_list_clears_history() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	s.grow_rows(30)
	s.reset()
	assert s.viewport == .active
	assert s.pages.first != none
	assert s.total_rows == usize(s.rows)

	// Active area should be the top.
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	tl := s.get_top_left(.active)
	assert voidptr(tl.node) == voidptr(first)
	assert tl.y == 0
	assert tl.x == 0
}

// ============================================================
// erase_row_bounded tests
// ============================================================

fn test_page_list_erase_row_bounded_less_than_full_row() {
	mut s := PageList.init(80, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	p_top := s.track_pin(s.get_pin(.active, 0, 5) or {
		assert false, 'get_pin failed'
		return
	})
	p_bot := s.track_pin(s.get_pin(.active, 0, 8) or {
		assert false, 'get_pin failed'
		return
	})
	p_out := s.track_pin(s.get_pin(.active, 0, 9) or {
		assert false, 'get_pin failed'
		return
	})

	// Erase only a few rows in our active.
	erase_pin := s.get_pin(.active, 0, 5) or {
		assert false, 'get_pin failed'
		return
	}
	s.erase_row_bounded(erase_pin, 3)
	assert s.total_rows == usize(s.rows)

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(p_top.node) == voidptr(first)
	assert p_top.y == 4
	assert p_top.x == 0

	assert voidptr(p_bot.node) == voidptr(first)
	assert p_bot.y == 7
	assert p_bot.x == 0

	assert voidptr(p_out.node) == voidptr(first)
	assert p_out.y == 9
	assert p_out.x == 0

	s.untrack_pin(p_top)
	s.untrack_pin(p_bot)
	s.untrack_pin(p_out)
}

fn test_page_list_erase_row_bounded_preserves_managed_cell_data() {
	mut s := PageList.init(6, 4, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	style_id := page.styles.add(CellStyle{
		flags: StyleFlags{
			italic: true
		}
	}) or {
		assert false, 'style add failed'
		return
	}
	page.rows[1].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(`M`)
		style_id: style_id
	}
	page.rows[1].styled = true
	page.set_graphemes(1, 1, [u32(0x0308)])
	hyperlink_id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 9
		}
		uri: 'https://example.com/bounded'
	})
	page.set_hyperlink(1, 1, hyperlink_id)

	s.erase_row_bounded(PagePin{ node: first, y: 0, x: 0 }, 1)

	cell := page.rows[0].cells[1]
	assert cell.codepoint == u32(`M`)
	assert cell.graphemes == [u32(0x0308)]
	assert page.styles.get(cell.style_id).flags.italic
	assert page.styles.ref_count(cell.style_id) == 1
	moved_link_id := page.lookup_hyperlink(0, 1) or {
		assert false, 'bounded hyperlink mapping missing'
		return
	}
	assert page.hyperlink_set.get(moved_link_id).uri == 'https://example.com/bounded'
	assert page.hyperlink_set.ref_count(moved_link_id) == 1
	assert page.rows[1].cells[1].is_zero()
	page.assert_integrity()
}

fn test_page_list_erase_row_bounded_exact_page_boundary() {
	mut s := PageList.init(4, 4, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	s.split(PagePin{ node: first, y: 2, x: 0 }) or {
		assert false, 'split failed'
		return
	}
	second := first.next or {
		assert false, 'no second page'
		return
	}
	mut second_page := &second.data
	second_page.rows[0].cells[2] = CellData{
		content_tag: .codepoint
		codepoint: u32(`B`)
	}
	hyperlink_id := second_page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 10
		}
		uri: 'https://example.com/exact-boundary'
	})
	second_page.set_hyperlink(0, 2, hyperlink_id)
	tracked := s.track_pin(PagePin{ node: second, y: 0, x: 2 })

	// One row remains in the first page. A limit of one must pull the next
	// page's first row across the boundary, then blank that source row.
	s.erase_row_bounded(PagePin{ node: first, y: 1, x: 0 }, 1)

	assert voidptr(tracked.node) == voidptr(first)
	assert tracked.y == 1
	assert tracked.x == 2
	mut first_page := &first.data
	assert first_page.rows[1].cells[2].codepoint == u32(`B`)
	moved_link_id := first_page.lookup_hyperlink(1, 2) or {
		assert false, 'exact-boundary hyperlink mapping missing'
		return
	}
	assert first_page.hyperlink_set.get(moved_link_id).uri == 'https://example.com/exact-boundary'
	assert first_page.hyperlink_set.ref_count(moved_link_id) == 1
	assert second_page.rows[0].cells[2].is_zero()
	assert second_page.lookup_hyperlink(0, 2) == none
	first_page.assert_integrity()
	second_page.assert_integrity()
	s.untrack_pin(tracked)
}

fn test_page_list_erase_row_bounded_with_pin_at_top() {
	mut s := PageList.init(80, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	p_top := s.track_pin(s.get_pin(.active, 5, 0) or {
		assert false, 'get_pin failed'
		return
	})

	erase_pin := s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	}
	s.erase_row_bounded(erase_pin, 3)
	assert s.total_rows == usize(s.rows)

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(p_top.node) == voidptr(first)
	assert p_top.y == 0
	assert p_top.x == 0

	s.untrack_pin(p_top)
}

fn test_page_list_erase_row_bounded_full_rows_single_page() {
	mut s := PageList.init(80, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	p_in := s.track_pin(s.get_pin(.active, 0, 7) or {
		assert false, 'get_pin failed'
		return
	})
	p_out := s.track_pin(s.get_pin(.active, 0, 9) or {
		assert false, 'get_pin failed'
		return
	})

	erase_pin := s.get_pin(.active, 0, 5) or {
		assert false, 'get_pin failed'
		return
	}
	s.erase_row_bounded(erase_pin, 10)
	assert s.total_rows == usize(s.rows)

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(p_in.node) == voidptr(first)
	assert p_in.y == 6
	assert p_in.x == 0

	assert voidptr(p_out.node) == voidptr(first)
	assert p_out.y == 8
	assert p_out.x == 0

	s.untrack_pin(p_in)
	s.untrack_pin(p_out)
}

fn test_page_list_erase_row_bounded_full_rows_two_pages() {
	mut s := PageList.init(80, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow to two pages so our active area straddles.
	first_page := s.pages.first or {
		assert false, 'no first page'
		return
	}
	remaining := usize(first_page.data.capacity.rows) - usize(first_page.data.size.rows)
	s.grow_rows(remaining)
	s.grow_rows(5)
	assert s.total_pages() == 2

	last := s.pages.last or {
		assert false, 'no last page'
		return
	}
	assert last.data.size.rows == 5
	prev := last.prev or {
		assert false, 'no prev page'
		return
	}

	// Pins
	p_first := s.track_pin(s.get_pin(.active, 0, 4) or {
		assert false, 'get_pin failed'
		return
	})
	p_first_out := s.track_pin(s.get_pin(.active, 0, 3) or {
		assert false, 'get_pin failed'
		return
	})
	p_in := s.track_pin(s.get_pin(.active, 0, 8) or {
		assert false, 'get_pin failed'
		return
	})
	p_out := s.track_pin(s.get_pin(.active, 0, 9) or {
		assert false, 'get_pin failed'
		return
	})

	// Verify initial pin placement.
	assert voidptr(p_first.node) == voidptr(prev)
	assert p_first.y == u16(prev.data.size.rows - 1)
	assert voidptr(p_first_out.node) == voidptr(prev)
	assert p_first_out.y == u16(prev.data.size.rows - 2)
	assert voidptr(p_in.node) == voidptr(last)
	assert p_in.y == 3
	assert voidptr(p_out.node) == voidptr(last)
	assert p_out.y == 4

	// Erase a few rows in our active starting at active y=4.
	erase_pin := s.get_pin(.active, 0, 4) or {
		assert false, 'get_pin failed'
		return
	}
	s.erase_row_bounded(erase_pin, 4)

	// In-page pin in first page is shifted up by one.
	assert voidptr(p_first.node) == voidptr(prev)
	assert p_first.y == u16(prev.data.size.rows - 2)
	assert p_first.x == 0

	// Out pin in first page should not be shifted.
	assert voidptr(p_first_out.node) == voidptr(prev)
	assert p_first_out.y == u16(prev.data.size.rows - 2)
	assert p_first_out.x == 0

	// In-page pin in last page is shifted.
	assert voidptr(p_in.node) == voidptr(last)
	assert p_in.y == 2
	assert p_in.x == 0

	// Out pin in last page is not shifted.
	assert voidptr(p_out.node) == voidptr(last)
	assert p_out.y == 4
	assert p_out.x == 0

	s.untrack_pin(p_first)
	s.untrack_pin(p_first_out)
	s.untrack_pin(p_in)
	s.untrack_pin(p_out)
}

// ============================================================
// resize (no reflow) tests
// ============================================================

fn test_page_list_resize_no_reflow_one_row_precise() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }
	assert s.total_rows == 10

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	// Write into all rows so we don't get trim behavior.
	for y in u16(0) .. 10 {
		page.rows[int(y)].cells[0] = CellData{
			content_tag: .codepoint
			codepoint: u32(`A`)
		}
	}

	s.resize(PageResizeOpts{ rows: 1, reflow: false })
	assert s.rows == 1
	assert s.total_rows == 10

	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp := pc.screen_point()
	assert sp.x == 0
	assert sp.y == 9
}

fn test_page_list_resize_no_reflow_less_rows_cursor_on_bottom() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }
	assert s.total_rows == 10

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in u16(0) .. 10 {
		page.rows[int(y)].cells[0] = CellData{
			content_tag: .codepoint
			codepoint: u32(y)
		}
	}

	p := s.track_pin(s.get_pin(.active, 0, 9) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ rows: 5, reflow: false })
	assert s.rows == 5
	assert s.total_rows == 10

	// Our cursor should move since it's in the scrollback.
	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 0
	assert cursor.y == 4

	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp := pc.screen_point()
	assert sp.x == 0
	assert sp.y == 5

	s.untrack_pin(p)
}

fn test_page_list_resize_no_reflow_less_rows_cursor_in_scrollback() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }
	assert s.total_rows == 10

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in u16(0) .. 10 {
		page.rows[int(y)].cells[0] = CellData{
			content_tag: .codepoint
			codepoint: u32(y)
		}
	}

	p := s.track_pin(s.get_pin(.active, 0, 2) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ rows: 5, reflow: false })
	assert s.rows == 5
	assert s.total_rows == 10

	// Our cursor should now be in scrollback (not active).
	if _ := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) {
		assert false, 'expected pin to be outside active'
	}
	sp_pin := s.point_from_pin(.screen, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin screen failed'
		return
	}
	assert sp_pin.x == 0
	assert sp_pin.y == 2

	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp := pc.screen_point()
	assert sp.x == 0
	assert sp.y == 5

	s.untrack_pin(p)
}

fn test_page_list_resize_no_reflow_more_rows_contains_viewport() {
	mut s := PageList.init(5, 5, usize(1))
	defer { s.deinit() }

	// Make it so we have scrollback.
	s.grow() or {}
	assert s.rows == 5
	assert s.total_rows == 6

	// Set viewport above active by scrolling up one.
	s.scroll(PageScrollDeltaRow{ delta: -1 })
	assert s.viewport == .top

	s.resize(PageResizeOpts{ rows: 7, reflow: false })
	assert s.rows == 7
	assert s.total_rows == 7
	assert s.viewport == .top
}

fn test_page_list_resize_no_reflow_more_rows_extends_blank_lines() {
	mut s := PageList.init(10, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Write codepoint into first line.
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`A`)
	}
	// Fill remaining lines with a background color (still blank).
	for y in u16(1) .. 3 {
		page.rows[int(y)].cells[0] = CellData{
			content_tag: .bg_color_rgb
			color_rgb_r: 0xFF
		}
	}

	s.resize(PageResizeOpts{ rows: 7, reflow: false })
	assert s.rows == 7
	assert s.total_rows == 7

	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp := pc.screen_point()
	assert sp.x == 0
	assert sp.y == 0
}

fn test_page_list_resize_no_reflow_less_rows_trims_blank_lines() {
	mut s := PageList.init(10, 5, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Write codepoint into first line.
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`A`)
	}
	// Fill remaining lines with a background color (still blank).
	for y in u16(1) .. 5 {
		page.rows[int(y)].cells[0] = CellData{
			content_tag: .bg_color_rgb
			color_rgb_r: 0xFF
		}
	}

	p := s.track_pin(s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ rows: 2, reflow: false })
	assert s.rows == 2
	assert s.total_rows == 2

	// Cursor should not move since we trimmed.
	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 0
	assert cursor.y == 0

	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp := pc.screen_point()
	assert sp.x == 0
	assert sp.y == 0

	s.untrack_pin(p)
}

fn test_page_list_resize_no_reflow_less_cols_clears_graphemes() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Add a grapheme at (9, 0).
	page.rows[0].cells[9] = CellData{
		content_tag: .codepoint
		codepoint: u32(`A`)
	}
	page.append_grapheme(0, 9, u32(`A`))
	assert page.grapheme_count() == 1

	s.resize(PageResizeOpts{ cols: 5, reflow: false })
	assert s.cols == 5
	assert s.total_rows == 10

	mut it := s.page_iterator(.right_down, .screen, none)
	for {
		chunk := it.next() or { break }
		assert chunk.node.data.grapheme_count() == 0
	}
}

fn test_page_list_resize_no_reflow_less_rows_trims_blank_lines_cursor_in_blank_line() {
	mut s := PageList.init(10, 5, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`A`)
	}
	for y in u16(1) .. 5 {
		page.rows[int(y)].cells[0] = CellData{
			content_tag: .bg_color_rgb
			color_rgb_r: 0xFF
		}
	}

	// Tracked pin in a blank line.
	p := s.track_pin(s.get_pin(.active, 0, 3) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ rows: 2, reflow: false })
	assert s.rows == 2
	assert s.total_rows == 4

	// Our cursor should not move since we trimmed.
	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 0
	assert cursor.y == 1

	s.untrack_pin(p)
}

fn test_page_list_resize_no_reflow_less_rows_trims_blank_lines_erases_pages() {
	mut s := PageList.init(100, 5, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}

	// Resize to take up two pages.
	rows := u16(int(first.data.capacity.rows) + 10)
	s.resize(PageResizeOpts{ rows: rows, reflow: false })
	assert s.total_pages() == 2

	// Write codepoint into first line.
	mut page := &first.data
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`A`)
	}

	// Resize down. Every row except the first is blank so we should
	// erase the second page.
	s.resize(PageResizeOpts{ rows: 5, reflow: false })
	assert s.rows == 5
	assert s.total_rows == 5
	assert s.total_pages() == 1
}

fn test_page_list_resize_no_reflow_more_cols_with_spacer_head() {
	mut s := PageList.init(2, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Row 0: 'x' then a spacer_head (wrapped line).
	page.rows[0].wrap = true
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`x`)
	}
	page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: 0
		wide: .spacer_head
	}
	// Row 1: wide emoji + spacer_tail.
	page.rows[1].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x1F600)
		wide: .wide
	}
	page.rows[1].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: 0
		wide: .spacer_tail
	}

	s.resize(PageResizeOpts{ cols: 3, reflow: false })
	assert s.cols == 3
	assert s.total_rows == 3

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut new_page := &np.data
	// Row 0 col 0: 'x' narrow.
	assert new_page.rows[0].cells[0].codepoint == u32(`x`)
	assert new_page.rows[0].cells[0].wide == .narrow
	// Row 0 col 1: the spacer head should now be narrow/empty.
	assert new_page.rows[0].cells[1].codepoint == 0
	assert new_page.rows[0].cells[1].wide == .narrow
	// Row 0 col 2: blank narrow.
	assert new_page.rows[0].cells[2].codepoint == 0
	assert new_page.rows[0].cells[2].wide == .narrow
}

fn test_page_list_resize_no_reflow_more_cols_forces_smaller_cap() {
	cap := initial_capacity(100)
	cap2 := initial_capacity(500)
	assert cap2.cols == 500
	assert cap2.rows < cap.rows

	mut s := PageList.init(cap.cols, u16(cap.rows), usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(first) == voidptr(s.pages.last or { return })
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(`A`)
			}
		}
	}

	rows := s.total_rows
	s.resize(PageResizeOpts{ cols: cap2.cols, reflow: false })
	assert s.total_rows == rows

	mut it := s.row_iterator(.right_down, .screen, none)
	for {
		row := it.next() or { break }
		mut rp := &row.node.data
		assert rp.size.cols == cap2.cols
		assert rp.rows[int(row.y)].cells[0].codepoint == u32(`A`)
	}
}

fn test_page_list_resize_no_reflow_more_rows_adds_blank_rows_if_cursor_at_bottom() {
	mut s := PageList.init(5, 3, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow to 5 total rows (3 active + 2 scrollback).
	s.grow_rows(2)
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(first) == voidptr(s.pages.last or { return })
	mut page := &first.data
	for y in 0 .. int(s.total_rows) {
		page.rows[y].cells[0] = CellData{
			content_tag: .codepoint
			codepoint: u32(y)
		}
	}

	// Active should be on row 3 (screen y=2).
	pc0 := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert pc0.screen_point().y == 2

	// Tracked pin at cursor position (near bottom of active).
	p := s.track_pin(s.get_pin(.active, 0, u16(s.rows - 2)) or {
		assert false, 'get_pin failed'
		return
	})
	original_cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}

	// Resize with cursor preserved.
	s.resize(PageResizeOpts{
		rows: 10
		reflow: false
		cursor: PageResizeCursor{
			x: 0
			y: u16(s.rows - 2)
		}
	})
	assert s.cols == 5
	assert s.rows == 10

	// Our cursor should not change.
	new_cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert new_cursor.x == original_cursor.x
	assert new_cursor.y == original_cursor.y

	// 12 = 10 active + 2 scrollback preserved by the cursor.
	assert s.total_rows == 12

	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert pc.screen_point().y == 2

	s.untrack_pin(p)
}

// ============================================================
// resize reflow tests
// ============================================================

fn test_page_list_resize_reflow_more_cols_no_wrapped_rows() {
	mut s := PageList.init(5, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(`A`)
			}
		}
	}

	s.resize(PageResizeOpts{ cols: 10, reflow: true })
	assert s.cols == 10
	assert s.total_rows == 3

	mut it := s.row_iterator(.right_down, .screen, none)
	for {
		row := it.next() or { break }
		mut rp := &row.node.data
		assert rp.size.cols == 10
		assert rp.rows[int(row.y)].cells[0].codepoint == u32(`A`)
	}
}

fn test_page_list_resize_reflow_more_cols_wrapped_rows() {
	mut s := PageList.init(2, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		if y % 2 == 0 {
			page.rows[y].wrap = true
		} else {
			page.rows[y].wrap_continuation = true
		}
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(`A`)
			}
		}
	}

	s.resize(PageResizeOpts{ cols: 4, reflow: true })
	assert s.cols == 4
	assert s.total_rows == 4

	// Active should still be on top.
	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	sp := pc.screen_point()
	assert sp.x == 0
	assert sp.y == 0

	// First row should be unwrapped and hold the reflowed content.
	mut it := s.row_iterator(.right_down, .screen, none)
	row := it.next() or {
		assert false, 'no row'
		return
	}
	mut rp := &row.node.data
	rd := rp.rows[int(row.y)]
	assert !rd.wrap
	assert rp.size.cols == 4
	assert rd.cells[0].codepoint == u32(`A`)
	assert rd.cells[2].codepoint == u32(`A`)
}

fn test_page_list_resize_reflow_invalidates_viewport_offset_cache() {
	mut s := PageList.init(2, 4, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	s.grow_rows(20)

	last := s.pages.last or {
		assert false, 'no last page'
		return
	}
	mut page := &last.data
	for y in 0 .. int(s.rows) {
		if y % 2 == 0 {
			page.rows[y].wrap = true
		} else {
			page.rows[y].wrap_continuation = true
		}
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(`A`)
			}
		}
	}

	// Scroll to a pinned viewport in history.
	pin := s.get_pin(.screen, 0, 10) or {
		assert false, 'get_pin failed'
		return
	}
	s.scroll(PageScrollPin{ pin: pin })
	assert s.viewport == .pin
	sb1 := s.scrollbar()
	assert sb1.total == s.total_rows
	assert sb1.offset == 10
	assert sb1.len == usize(s.rows)

	// Resize with reflow - unwrapping rows changes total_rows.
	s.resize(PageResizeOpts{ cols: 4, reflow: true })
	assert s.cols == 4

	// Verify the scrollbar cache was invalidated during reflow.
	sb2 := s.scrollbar()
	assert sb2.total == s.total_rows
	assert sb2.offset == 5
	assert sb2.len == usize(s.rows)
}

fn test_page_list_resize_reflow_more_cols_creates_multiple_pages() {
	// Find a wide col count whose capacity has < 100 rows.
	mut current := u16(100)
	mut cap := initial_capacity(current)
	for cap.rows >= 100 {
		current += 100
		cap = initial_capacity(current)
	}

	mut s := PageList.init(cap.cols, u16(cap.rows), usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(first) == voidptr(s.pages.last or { return })
	mut page := &first.data
	// Wrap every other row so every line is wrapped for reflow.
	for y in 0 .. int(s.rows) {
		if y % 2 == 0 {
			page.rows[y].wrap = true
		} else {
			page.rows[y].wrap_continuation = true
		}
		page.rows[y].cells[0] = CellData{
			content_tag: .codepoint
			codepoint: u32(`A`)
		}
	}

	newcap := initial_capacity(cap.cols + 100)
	assert newcap.rows < cap.rows
	s.resize(PageResizeOpts{ cols: newcap.cols, reflow: true })
	assert s.cols == newcap.cols
	assert s.total_rows == cap.rows

	mut count := 0
	mut it := s.pages.first
	for {
		p := it or { break }
		count += 1
		assert p.data.capacity.cols == newcap.cols
		assert p.data.capacity.rows == newcap.rows
		it = p.next
	}
	// We should have created at least one additional page.
	assert count > 1
}

fn test_page_list_resize_grow_cols_with_unwrap_fixes_viewport_pin() {
	// Regression: after resize/reflow, the viewport pin can end up where
	// pin.y + rows > total_rows, causing get_bottom_right to fail.
	mut s := PageList.init(2, 10, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	s.grow_rows(30)
	assert s.total_rows == 40

	// Fill all rows with wrapped content.
	mut pit := s.page_iterator(.right_down, .screen, none)
	for {
		chunk := pit.next() or { break }
		mut page := &chunk.node.data
		for y in int(chunk.start) .. int(chunk.end) {
			if y % 2 == 0 {
				page.rows[y].wrap = true
			} else {
				page.rows[y].wrap_continuation = true
			}
			for x in 0 .. int(s.cols) {
				page.rows[y].cells[x] = CellData{
					content_tag: .codepoint
					codepoint: u32(`A`)
				}
			}
		}
	}

	// Pin viewport at row 28 (in history).
	pin := s.get_pin(.screen, 0, 28) or {
		assert false, 'get_pin failed'
		return
	}
	s.scroll(PageScrollPin{ pin: pin })
	assert s.viewport == .pin
	if _ := s.get_bottom_right(.viewport) {
		// ok
	} else {
		assert false, 'get_bottom_right returned none before resize'
	}

	// Resize with reflow: unwraps rows, reducing total_rows.
	s.resize(PageResizeOpts{ cols: 4, reflow: true })
	assert s.cols == 4
	assert s.total_rows < 40

	// Used to fail here; test that we can still get the bottom right.
	if _ := s.get_bottom_right(.viewport) {
		// ok
	} else {
		assert false, 'get_bottom_right returned none after resize'
	}
}

fn test_page_list_resize_reflow_more_cols_cursor_in_wrapped_row() {
	mut s := PageList.init(2, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	// Row 0: wrapped.
	page.rows[0].wrap = true
	for x in 0 .. int(s.cols) {
		page.rows[0].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}
	// Row 1: wrap continuation.
	page.rows[1].wrap_continuation = true
	for x in 0 .. int(s.cols) {
		page.rows[1].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}

	p := s.track_pin(s.get_pin(.active, 1, 1) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ cols: 4, reflow: true })
	assert s.cols == 4
	assert s.total_rows == 4

	// Cursor should move to the first row (unwrapped).
	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 3
	assert cursor.y == 0

	s.untrack_pin(p)
}

fn test_page_list_resize_reflow_more_cols_cursor_in_not_wrapped_row() {
	mut s := PageList.init(2, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[0].wrap = true
	for x in 0 .. int(s.cols) {
		page.rows[0].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}
	page.rows[1].wrap_continuation = true
	for x in 0 .. int(s.cols) {
		page.rows[1].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}

	p := s.track_pin(s.get_pin(.active, 1, 0) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ cols: 4, reflow: true })
	assert s.cols == 4
	assert s.total_rows == 4

	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 1
	assert cursor.y == 0

	s.untrack_pin(p)
}

fn test_page_list_resize_reflow_more_cols_cursor_in_wrapped_row_that_isnt_unwrapped() {
	mut s := PageList.init(2, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	// Row 0: wrap.
	page.rows[0].wrap = true
	for x in 0 .. int(s.cols) {
		page.rows[0].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}
	// Row 1: wrap + wrap_continuation.
	page.rows[1].wrap = true
	page.rows[1].wrap_continuation = true
	for x in 0 .. int(s.cols) {
		page.rows[1].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}
	// Row 2: wrap_continuation.
	page.rows[2].wrap_continuation = true
	for x in 0 .. int(s.cols) {
		page.rows[2].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}

	p := s.track_pin(s.get_pin(.active, 1, 2) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ cols: 4, reflow: true })
	assert s.cols == 4
	assert s.total_rows == 4

	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 1
	assert cursor.y == 1

	s.untrack_pin(p)
}

fn test_page_list_resize_reflow_more_cols_no_reflow_preserves_semantic_prompt() {
	mut s := PageList.init(2, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[1].semantic_prompt = .prompt

	s.resize(PageResizeOpts{ cols: 4, reflow: true })
	assert s.cols == 4
	assert s.total_rows == 4

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(np) == voidptr(s.pages.last or { return })
	mut new_page := &np.data
	assert new_page.rows[1].semantic_prompt == .prompt
}

fn test_page_list_resize_reflow_less_cols_no_reflow_preserves_semantic_prompt() {
	mut s := PageList.init(4, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[1].semantic_prompt = .prompt
	for x in 0 .. int(s.cols) {
		page.rows[1].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 4

	assert voidptr(s.pages.first or { return }) == voidptr(s.pages.last or { return })

	p1 := s.get_pin(.active, 0, 1) or {
		assert false, 'get_pin failed'
		return
	}
	assert p1.row_data().wrap
	assert p1.row_data().semantic_prompt == .prompt

	p2 := s.get_pin(.active, 0, 2) or {
		assert false, 'get_pin failed'
		return
	}
	assert p2.row_data().semantic_prompt == .prompt
}

fn test_page_list_resize_reflow_less_cols_no_reflow_preserves_semantic_prompt_on_first_line() {
	mut s := PageList.init(4, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[0].semantic_prompt = .prompt

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 4

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(np) == voidptr(s.pages.last or { return })
	mut new_page := &np.data
	assert new_page.rows[0].semantic_prompt == .prompt
}

fn test_page_list_resize_reflow_less_cols_wrap_preserves_semantic_prompt() {
	mut s := PageList.init(4, 4, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[0].semantic_prompt = .prompt

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 4

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(np) == voidptr(s.pages.last or { return })
	mut new_page := &np.data
	assert new_page.rows[0].semantic_prompt == .prompt
}

fn test_page_list_resize_reflow_less_cols_no_wrapped_rows() {
	mut s := PageList.init(10, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. 4 {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	s.resize(PageResizeOpts{ cols: 5, reflow: true })
	assert s.cols == 5
	assert s.total_rows == 3

	mut it := s.row_iterator(.right_down, .screen, none)
	for {
		row := it.next() or { break }
		mut rp := &row.node.data
		assert rp.size.cols == 5
		for x in 0 .. 4 {
			assert rp.rows[int(row.y)].cells[x].codepoint == u32(x)
		}
	}
}

fn test_page_list_resize_reflow_less_cols_wrapped_rows() {
	mut s := PageList.init(4, 2, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 4

	// Active moves due to scrollback.
	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert pc.screen_point().y == 2

	mut it := s.row_iterator(.right_down, .screen, none)
	// Row 0: wrapped, cells[0]=0.
	r0 := it.next() or {
		assert false, 'no row'
		return
	}
	assert r0.row_data().wrap
	assert r0.node.data.rows[int(r0.y)].cells[0].codepoint == 0
	// Row 1: not wrapped, cells[0]=2.
	r1 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r1.row_data().wrap
	assert r1.node.data.rows[int(r1.y)].cells[0].codepoint == 2
	// Row 2: wrapped, cells[0]=0.
	r2 := it.next() or {
		assert false, 'no row'
		return
	}
	assert r2.row_data().wrap
	assert r2.node.data.rows[int(r2.y)].cells[0].codepoint == 0
	// Row 3: not wrapped, cells[0]=2.
	r3 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r3.row_data().wrap
	assert r3.node.data.rows[int(r3.y)].cells[0].codepoint == 2
}

fn test_page_list_resize_reflow_preserves_hyperlink_mapping() {
	mut s := PageList.init(4, 2, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[0].cells[3] = CellData{
		content_tag: .codepoint
		codepoint: u32(`L`)
	}
	source_id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkExplicitId{
			value: 'link-id'
		}
		uri: 'https://example.com/reflow'
	})
	page.set_hyperlink(0, 3, source_id)

	s.resize(PageResizeOpts{ cols: 2, reflow: true })

	mut found := false
	mut it := s.row_iterator(.right_down, .screen, none)
	for {
		pin := it.next() or { break }
		mut reflowed := &pin.node.data
		for x, cell in reflowed.rows[int(pin.y)].cells[..int(reflowed.size.cols)] {
			if cell.codepoint != u32(`L`) {
				continue
			}
			assert cell.has_hyperlink
			id := reflowed.lookup_hyperlink(int(pin.y), x) or {
				assert false, 'reflowed hyperlink mapping missing'
				return
			}
			link := reflowed.hyperlink_set.get(id)
			assert link.uri == 'https://example.com/reflow'
			match link.id {
				HyperlinkExplicitId {
					assert link.id.value == 'link-id'
				}
				HyperlinkImplicitId {
					assert false
				}
			}
			found = true
		}
	}
	assert found
}

fn test_page_list_resize_reflow_preserves_hyperlinks_across_source_pages() {
	mut s := PageList.init(2, 4, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	s.split(PagePin{ node: first, y: 2, x: 0 }) or {
		assert false, 'split failed'
		return
	}
	second := first.next or {
		assert false, 'no second page'
		return
	}

	mut first_page := &first.data
	first_page.rows[1].wrap = true
	first_page.rows[1].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(`A`)
	}
	first_id := first_page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 1
		}
		uri: 'https://example.com/first'
	})
	first_page.set_hyperlink(1, 1, first_id)

	mut second_page := &second.data
	second_page.rows[0].wrap_continuation = true
	second_page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`B`)
	}
	second_id := second_page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 2
		}
		uri: 'https://example.com/second'
	})
	second_page.set_hyperlink(0, 0, second_id)

	// The wrapped logical line crosses the old page boundary and is unwrapped
	// into one destination row.
	s.resize(PageResizeOpts{ cols: 3, reflow: true })

	mut found := map[u32]string{}
	mut it := s.row_iterator(.right_down, .screen, none)
	for {
		pin := it.next() or { break }
		mut reflowed := &pin.node.data
		for x, cell in reflowed.rows[int(pin.y)].cells[..int(reflowed.size.cols)] {
			if cell.codepoint != u32(`A`) && cell.codepoint != u32(`B`) {
				continue
			}
			id := reflowed.lookup_hyperlink(int(pin.y), x) or {
				assert false, 'reflowed hyperlink mapping missing'
				return
			}
			found[cell.codepoint] = reflowed.hyperlink_set.get(id).uri
		}
	}
	assert found[u32(`A`)] == 'https://example.com/first'
	assert found[u32(`B`)] == 'https://example.com/second'
}

fn test_page_list_resize_reflow_less_cols_cursor_in_wrapped_row() {
	mut s := PageList.init(4, 2, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	p := s.track_pin(s.get_pin(.active, 2, 1) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 4

	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 0
	assert cursor.y == 1

	s.untrack_pin(p)
}

fn reflow_cursor_cell_helper(init_cols u16, new_cols u16, pin_x u16, exp_x u32, exp_y u32) {
	mut s := PageList.init(init_cols, 2, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or { return }
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. 2 {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	p := s.track_pin(s.get_pin(.active, pin_x, 0) or { return })

	s.resize(PageResizeOpts{ cols: new_cols, reflow: true })
	assert s.cols == new_cols
	assert s.total_rows == 2

	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == exp_x
	assert cursor.y == exp_y

	s.untrack_pin(p)
}

fn test_page_list_resize_reflow_less_cols_cursor_in_unchanged_row() {
	reflow_cursor_cell_helper(4, 2, 1, 1, 0)
}

fn test_page_list_resize_reflow_less_cols_cursor_in_blank_cell() {
	reflow_cursor_cell_helper(6, 4, 2, 2, 0)
}

fn test_page_list_resize_reflow_less_cols_cursor_in_final_blank_cell() {
	reflow_cursor_cell_helper(6, 4, 3, 3, 0)
}

fn test_page_list_resize_reflow_less_cols_cursor_in_wrapped_blank_cell() {
	reflow_cursor_cell_helper(6, 4, 5, 3, 0)
}

fn test_page_list_resize_reflow_less_cols_blank_lines() {
	mut s := PageList.init(4, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for x in 0 .. 4 {
		page.rows[0].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 3

	mut it := s.row_iterator(.right_down, .active, none)
	r0 := it.next() or {
		assert false, 'no row'
		return
	}
	assert r0.row_data().wrap
	assert r0.node.data.rows[int(r0.y)].cells[0].codepoint == 0
	r1 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r1.row_data().wrap
	assert r1.node.data.rows[int(r1.y)].cells[0].codepoint == 2
}

fn test_page_list_resize_reflow_less_cols_wrapped_rows_with_graphemes() {
	mut s := PageList.init(4, 2, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
		page.append_grapheme(y, 2, u32(`A`))
	}

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 4

	pc := s.get_cell(.active, 0, 0) or {
		assert false, 'get_cell failed'
		return
	}
	assert pc.screen_point().y == 2

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(np) == voidptr(s.pages.last or { return })

	mut it := s.row_iterator(.right_down, .screen, none)
	// Row 0: wrapped, cells[0]=0.
	r0 := it.next() or {
		assert false, 'no row'
		return
	}
	assert r0.row_data().wrap
	assert r0.node.data.rows[int(r0.y)].cells[0].codepoint == 0
	// Row 1: not wrapped, has grapheme, cells[0]=2.
	r1 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r1.row_data().wrap
	assert r1.row_data().grapheme
	assert r1.node.data.rows[int(r1.y)].cells[0].codepoint == 2
	cps := r1.node.data.lookup_grapheme(int(r1.y), 0) or {
		assert false, 'lookup_grapheme failed'
		return
	}
	assert cps.len == 1
	assert cps[0] == u32(`A`)
}

fn test_page_list_resize_reflow_less_cols_cursor_goes_to_scrollback() {
	mut s := PageList.init(4, 2, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. int(s.cols) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	p := s.track_pin(s.get_pin(.active, 2, 0) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 4

	// Our cursor should now be in scrollback (outside active).
	if _ := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) {
		assert false, 'expected pin outside active'
	}

	s.untrack_pin(p)
}

fn test_page_list_resize_reflow_less_cols_copy_style() {
	mut s := PageList.init(4, 2, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	style_id := page.styles.add(CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}) or {
		assert false, 'style add failed'
		return
	}
	for x in 0 .. int(s.cols) - 1 {
		page.rows[0].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
			style_id: style_id
		}
		page.rows[0].styled = true
		page.styles.use_style(style_id)
	}
	page.styles.release(style_id)

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 2

	mut it := s.row_iterator(.right_down, .active, none)
	for {
		row := it.next() or { break }
		mut rp := &row.node.data
		rd := rp.rows[int(row.y)]
		for x in 0 .. int(s.cols) - 1 {
			c := rd.cells[x]
			assert c.style_id != 0
			st := rp.styles.get(c.style_id)
			assert st.flags.bold
			assert rd.styled
		}
	}
}

fn test_page_list_resize_reflow_less_cols_to_eliminate_a_wide_char() {
	mut s := PageList.init(2, 1, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x1F600)
		wide: .wide
	}
	page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: 0
		wide: .spacer_tail
	}

	s.resize(PageResizeOpts{ cols: 1, reflow: true })
	assert s.cols == 1
	assert s.total_rows == 1

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(np) == voidptr(s.pages.last or { return })
	mut new_page := &np.data
	assert new_page.rows[0].cells[0].codepoint == 0
	assert new_page.rows[0].cells[0].wide == .narrow
}

fn test_page_list_resize_reflow_less_cols_to_wrap_a_wide_char() {
	mut s := PageList.init(3, 1, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`x`)
	}
	page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x1F600)
		wide: .wide
	}
	page.rows[0].cells[2] = CellData{
		content_tag: .codepoint
		codepoint: 0
		wide: .spacer_tail
	}

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 2

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(np) == voidptr(s.pages.last or { return })
	mut new_page := &np.data
	// Row 0: 'x' narrow, wrapped, then spacer head.
	assert new_page.rows[0].cells[0].codepoint == u32(`x`)
	assert new_page.rows[0].cells[0].wide == .narrow
	assert new_page.rows[0].wrap
	assert new_page.rows[0].cells[1].codepoint == 0
	assert new_page.rows[0].cells[1].wide == .spacer_head
	// Row 1: wide emoji + spacer tail.
	assert new_page.rows[1].cells[0].codepoint == u32(0x1F600)
	assert new_page.rows[1].cells[0].wide == .wide
	assert new_page.rows[1].cells[1].codepoint == 0
	assert new_page.rows[1].cells[1].wide == .spacer_tail
}

fn test_page_list_resize_reflow_less_cols_blank_lines_between() {
	mut s := PageList.init(4, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for x in 0 .. 4 {
		page.rows[0].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
		page.rows[2].cells[x] = CellData{
			content_tag: .codepoint
			codepoint: u32(x)
		}
	}

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 5

	mut it := s.row_iterator(.right_down, .active, none)
	r0 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r0.row_data().wrap
	r1 := it.next() or {
		assert false, 'no row'
		return
	}
	assert r1.row_data().wrap
	assert r1.node.data.rows[int(r1.y)].cells[0].codepoint == 0
	r2 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r2.row_data().wrap
	assert r2.node.data.rows[int(r2.y)].cells[0].codepoint == 2
}

fn test_page_list_resize_reflow_less_cols_blank_lines_between_no_scrollback() {
	mut s := PageList.init(5, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`A`)
	}
	page.rows[2].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`C`)
	}

	s.resize(PageResizeOpts{ cols: 2, reflow: true })
	assert s.cols == 2
	assert s.total_rows == 3

	mut it := s.row_iterator(.right_down, .active, none)
	r0 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r0.row_data().wrap
	assert r0.node.data.rows[int(r0.y)].cells[0].codepoint == u32(`A`)
	r1 := it.next() or {
		assert false, 'no row'
		return
	}
	assert r1.node.data.rows[int(r1.y)].cells[0].codepoint == 0
	r2 := it.next() or {
		assert false, 'no row'
		return
	}
	assert !r2.row_data().wrap
	assert r2.node.data.rows[int(r2.y)].cells[0].codepoint == u32(`C`)
}

fn test_page_list_resize_reflow_less_cols_cursor_not_on_last_line_preserves_location() {
	mut s := PageList.init(5, 5, usize(1))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in 0 .. int(s.rows) {
		for x in 0 .. 2 {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	// Grow blank rows to push our rows back into scrollback.
	s.grow_rows(5)
	assert s.total_rows == 10

	p := s.track_pin(s.get_pin(.active, 0, 0) or {
		assert false, 'get_pin failed'
		return
	})

	s.resize(PageResizeOpts{
		cols: 4
		reflow: true
		cursor: PageResizeCursor{
			x: 1
			y: 1
		}
	})
	assert s.cols == 4
	assert s.total_rows == 10

	cursor := s.point_from_pin(.active, PagePin{ node: p.node, y: p.y, x: p.x }) or {
		assert false, 'point_from_pin failed'
		return
	}
	assert cursor.x == 0
	assert cursor.y == 0

	s.untrack_pin(p)
}

fn test_page_list_resize_reflow_less_cols_wraps_spacer_head() {
	mut s := PageList.init(4, 3, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	// Row 0: 'x','x','x' then a spacer_head (wrapped).
	page.rows[0].wrap = true
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`x`)
	}
	page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(`x`)
	}
	page.rows[0].cells[2] = CellData{
		content_tag: .codepoint
		codepoint: u32(`x`)
	}
	page.rows[0].cells[3] = CellData{
		content_tag: .codepoint
		codepoint: 0
		wide: .spacer_head
	}
	// Row 1: wide emoji + spacer tail.
	page.rows[1].wrap_continuation = true
	page.rows[1].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x1F600)
		wide: .wide
	}
	page.rows[1].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: 0
		wide: .spacer_tail
	}

	s.resize(PageResizeOpts{ cols: 3, reflow: true })
	assert s.cols == 3
	assert s.total_rows == 3

	np := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(np) == voidptr(s.pages.last or { return })
	mut new_page := &np.data
	// Row 0: xxx wrapped.
	assert new_page.rows[0].cells[0].codepoint == u32(`x`)
	assert new_page.rows[0].cells[0].wide == .narrow
	assert new_page.rows[0].wrap
	assert new_page.rows[0].cells[1].codepoint == u32(`x`)
	assert new_page.rows[0].cells[2].codepoint == u32(`x`)
	// Row 1: wide emoji + spacer tail.
	assert new_page.rows[1].cells[0].codepoint == u32(0x1F600)
	assert new_page.rows[1].cells[0].wide == .wide
	assert new_page.rows[1].cells[1].codepoint == 0
	assert new_page.rows[1].cells[1].wide == .spacer_tail
}

// ============================================================
// pageIterator / cellIterator precise tests
// ============================================================

fn test_page_list_page_iterator_single_page_precise() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert first.next == none

	mut it := s.page_iterator(.right_down, .active, none)
	chunk := it.next() or {
		assert false, 'no chunk'
		return
	}
	assert voidptr(chunk.node) == voidptr(first)
	assert chunk.start == 0
	assert chunk.end == u16(s.rows)

	assert it.next() == none
}

fn test_page_list_page_iterator_two_pages_precise() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow to fill page1 then one more to spill onto page2.
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	remaining := usize(first.data.capacity.rows) - usize(first.data.size.rows)
	s.grow_rows(remaining)
	s.grow_rows(1)
	assert s.total_pages() == 2

	last := s.pages.last or {
		assert false, 'no last page'
		return
	}

	mut it := s.page_iterator(.right_down, .active, none)
	chunk1 := it.next() or {
		assert false, 'no chunk1'
		return
	}
	assert voidptr(chunk1.node) == voidptr(first)
	assert chunk1.start == u16(int(first.data.size.rows) - int(s.rows) + 1)
	assert chunk1.end == first.data.size.rows

	chunk2 := it.next() or {
		assert false, 'no chunk2'
		return
	}
	assert voidptr(chunk2.node) == voidptr(last)
	assert chunk2.start == 0
	assert chunk2.end == 1

	assert it.next() == none
}

fn test_page_list_page_iterator_history_two_pages() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	remaining := usize(first.data.capacity.rows) - usize(first.data.size.rows)
	s.grow_rows(remaining)
	s.grow_rows(1)
	assert s.total_pages() == 2

	active_tl := s.get_top_left(.active)
	mut it := s.page_iterator(.right_down, .history, none)
	chunk := it.next() or {
		assert false, 'no chunk'
		return
	}
	assert voidptr(chunk.node) == voidptr(first)
	assert chunk.start == 0
	assert chunk.end == active_tl.y

	assert it.next() == none
}

fn test_page_list_page_iterator_reverse_single_page() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert first.next == none

	mut it := s.page_iterator(.left_up, .active, none)
	chunk := it.next() or {
		assert false, 'no chunk'
		return
	}
	assert voidptr(chunk.node) == voidptr(first)
	assert chunk.start == 0
	assert chunk.end == u16(s.rows)

	assert it.next() == none
}

fn test_page_list_page_iterator_reverse_two_pages() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	remaining := usize(first.data.capacity.rows) - usize(first.data.size.rows)
	s.grow_rows(remaining)
	s.grow_rows(1)
	assert s.total_pages() == 2

	last := s.pages.last or {
		assert false, 'no last page'
		return
	}

	mut it := s.page_iterator(.left_up, .active, none)
	mut count := u16(0)

	chunk1 := it.next() or {
		assert false, 'no chunk1'
		return
	}
	assert voidptr(chunk1.node) == voidptr(last)
	assert chunk1.start == 0
	assert chunk1.end == 1
	count += chunk1.end - chunk1.start

	chunk2 := it.next() or {
		assert false, 'no chunk2'
		return
	}
	assert voidptr(chunk2.node) == voidptr(first)
	assert chunk2.start == u16(int(first.data.size.rows) - int(s.rows) + 1)
	assert chunk2.end == first.data.size.rows
	count += chunk2.end - chunk2.start

	assert it.next() == none
	assert count == u16(s.rows)
}

fn test_page_list_page_iterator_reverse_history_two_pages() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	remaining := usize(first.data.capacity.rows) - usize(first.data.size.rows)
	s.grow_rows(remaining)
	s.grow_rows(1)
	assert s.total_pages() == 2

	active_tl := s.get_top_left(.active)
	mut it := s.page_iterator(.left_up, .history, none)
	chunk := it.next() or {
		assert false, 'no chunk'
		return
	}
	assert voidptr(chunk.node) == voidptr(first)
	assert chunk.start == 0
	assert chunk.end == active_tl.y

	assert it.next() == none
}

fn test_page_list_cell_iterator_precise() {
	mut s := PageList.init(2, 2, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(first) == voidptr(s.pages.last or { return })
	mut page := &first.data
	for y in u16(0) .. 2 {
		for x in u16(0) .. 2 {
			page.rows[int(y)].cells[int(x)] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	mut it := s.cell_iterator(.right_down, .screen, none)
	expected := [[u32(0), 0], [u32(1), 0], [u32(0), 1], [u32(1), 1]]
	for exp in expected {
		p := it.next() or {
			assert false, 'iterator ended early'
			return
		}
		pt := s.point_from_pin(.screen, p) or {
			assert false, 'point_from_pin failed'
			return
		}
		assert pt.x == exp[0]
		assert pt.y == exp[1]
	}
	assert it.next() == none
}

fn test_page_list_cell_iterator_reverse_precise() {
	mut s := PageList.init(2, 2, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data
	for y in u16(0) .. 2 {
		for x in u16(0) .. 2 {
			page.rows[int(y)].cells[int(x)] = CellData{
				content_tag: .codepoint
				codepoint: u32(x)
			}
		}
	}

	mut it := s.cell_iterator(.left_up, .screen, none)
	expected := [[u32(1), 1], [u32(0), 1], [u32(1), 0], [u32(0), 0]]
	for exp in expected {
		p := it.next() or {
			assert false, 'iterator ended early'
			return
		}
		pt := s.point_from_pin(.screen, p) or {
			assert false, 'point_from_pin failed'
			return
		}
		assert pt.x == exp[0]
		assert pt.y == exp[1]
	}
	assert it.next() == none
}

// ============================================================
// erase tests (whole-region)
// ============================================================

fn test_page_list_erase_reaccounts_page_size() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }
	start_size := s.page_size

	// Grow so we take up at least 5 pages.
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 5)
	assert s.page_size > start_size

	// Erase the entire history; we should be back to just our active set.
	s.erase_rows(.history, none)
	assert s.page_size == start_size
}

fn test_page_list_erase_row_with_tracked_pin_resets_to_top_left() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	// Grow so we take up at least 5 pages.
	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 5)
	assert s.total_rows > usize(s.rows)

	// Put a tracked pin in the history.
	p := s.track_pin(s.get_top_left(.history))

	// Erase the entire history; we should be back to just our active set.
	s.erase_rows(.history, none)
	assert s.total_rows == usize(s.rows)

	// Our pin should move to the first page.
	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(p.node) == voidptr(first)
	assert p.y == 0
	assert p.x == 0

	s.untrack_pin(p)
}

fn test_page_list_erase_resets_viewport_to_active_if_moves_within_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 5)

	// Move our viewport to the top.
	s.scroll(PageScrollDeltaRow{ delta: -int(s.total_rows) })
	assert s.viewport == .top

	// Erase the entire history; we should be back to just our active set.
	s.erase_rows(.history, none)
	assert s.viewport == .active
}

fn test_page_list_erase_resets_viewport_to_active_if_top_is_inside_active() {
	mut s := PageList.init(80, 24, usize(0x7FFFFFFFFFFFFFFF))
	defer { s.deinit() }

	cap := initial_capacity(80)
	s.grow_rows(usize(cap.rows) * 5)

	// Move our viewport to the top.
	s.scroll(PageScrollTop{})

	// Erase the entire history; we should be back to just our active set.
	s.erase_rows(.history, none)
	assert s.viewport == .active
}

// ============================================================
// Split tests
// ============================================================

fn test_page_list_split_single_row_page_returns_out_of_space() {
	mut s := PageList.init(10, 1, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	split_pin := PagePin{ node: first, y: 0, x: 0 }
	// Splitting a single-row page is impossible (analogous to ghostty's
	// error.OutOfSpace). witty returns an error for a page with <= 1 row.
	mut errored := false
	s.split(split_pin) or { errored = true }
	assert errored

	// The page is unchanged.
	assert s.total_pages() == 1
	assert first.data.size.rows == 1
}

fn test_page_list_split_multiple_tracked_pins_across_regions() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	original := s.pages.first or {
		assert false, 'no first page'
		return
	}

	pin_before := s.track_pin(PagePin{ node: original, y: 1, x: 0 })
	pin_at_split := s.track_pin(PagePin{ node: original, y: 5, x: 2 })
	pin_after1 := s.track_pin(PagePin{ node: original, y: 7, x: 3 })
	pin_after2 := s.track_pin(PagePin{ node: original, y: 9, x: 8 })

	s.split(PagePin{ node: original, y: 5, x: 0 }) or {
		assert false, 'split failed: ${err}'
		return
	}

	first_page := s.pages.first or {
		assert false, 'no first page'
		return
	}
	second_page := first_page.next or {
		assert false, 'no second page'
		return
	}

	// Pin before split point stays in original page.
	assert voidptr(pin_before.node) == voidptr(first_page)
	assert pin_before.y == 1
	assert pin_before.x == 0

	// Pin at split point moves to new page with y=0.
	assert voidptr(pin_at_split.node) == voidptr(second_page)
	assert pin_at_split.y == 0
	assert pin_at_split.x == 2

	// Pins after split move to new page with adjusted y.
	assert voidptr(pin_after1.node) == voidptr(second_page)
	assert pin_after1.y == 2
	assert pin_after1.x == 3

	assert voidptr(pin_after2.node) == voidptr(second_page)
	assert pin_after2.y == 4
	assert pin_after2.x == 8

	s.untrack_pin(pin_before)
	s.untrack_pin(pin_at_split)
	s.untrack_pin(pin_after1)
	s.untrack_pin(pin_after2)
}

fn test_page_list_split_tracked_viewport_pin_in_split_region_moves_correctly() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	original := s.pages.first or {
		assert false, 'no first page'
		return
	}

	// Set viewport_pin to row 7 (after split point).
	s.viewport_pin.node = original
	s.viewport_pin.y = 7
	s.viewport_pin.x = 6

	s.split(PagePin{ node: original, y: 5, x: 0 }) or {
		assert false, 'split failed: ${err}'
		return
	}

	second := original.next or {
		assert false, 'no second page'
		return
	}
	assert voidptr(s.viewport_pin.node) == voidptr(second)
	assert s.viewport_pin.y == 2
	assert s.viewport_pin.x == 6
}

fn test_page_list_split_last_page_makes_new_page_the_last() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first_node := s.pages.first or {
		assert false, 'no first page'
		return
	}
	s.split(PagePin{ node: first_node, y: 5, x: 0 }) or {
		assert false, 'split failed'
		return
	}

	last_before := s.pages.last or {
		assert false, 'no last page'
		return
	}
	assert last_before.data.size.rows == 5

	s.split(PagePin{ node: last_before, y: 2, x: 0 }) or {
		assert false, 'split failed'
		return
	}

	new_last := s.pages.last or {
		assert false, 'no last page'
		return
	}
	assert voidptr(new_last) != voidptr(last_before)
	prev := new_last.prev or {
		assert false, 'no prev'
		return
	}
	assert voidptr(prev) == voidptr(last_before)
	assert new_last.next == none

	assert last_before.data.size.rows == 2
	assert new_last.data.size.rows == 3
}

fn test_page_list_split_first_page_keeps_original_as_first() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	original_first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	s.split(PagePin{ node: original_first, y: 5, x: 0 }) or {
		assert false, 'split failed'
		return
	}

	// Split the first page again.
	s.split(PagePin{ node: original_first, y: 2, x: 0 }) or {
		assert false, 'split failed'
		return
	}

	// Original first should still be first.
	new_first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	assert voidptr(new_first) == voidptr(original_first)
	assert original_first.prev == none
}

fn test_page_list_split_preserves_styled_cells() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Create a style and apply it to cells in rows 5-7.
	style := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	style_id := page.styles.add(style) or {
		assert false, 'style add failed'
		return
	}

	for y in u16(5) .. 8 {
		mut row := &page.rows[int(y)]
		row.cells[0] = CellData{
			content_tag: .codepoint
			codepoint: u32(`S`)
			style_id: style_id
		}
		row.styled = true
		page.styles.use_style(style_id)
	}
	// Release the extra ref from add.
	page.styles.release(style_id)

	s.split(PagePin{ node: first, y: 5, x: 0 }) or {
		assert false, 'split failed'
		return
	}

	second := first.next or {
		assert false, 'no second page'
		return
	}
	mut second_page := &second.data

	// Verify styled cells preserved in new page (rows 0-2).
	for y in u16(0) .. 3 {
		c := second_page.rows[int(y)].cells[0]
		assert c.codepoint == u32(`S`)
		assert c.style_id != 0
		got_style := second_page.styles.get(c.style_id)
		assert got_style.flags.bold
		assert second_page.rows[int(y)].styled
	}
}

fn test_page_list_split_preserves_grapheme_clusters() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Add a grapheme cluster to row 6 (will be row 1 in second page).
	mut row6 := &page.rows[6]
	row6.cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(0x1F468) // Man emoji
	}
	page.set_graphemes(6, 0, [u32(0x200D), u32(0x1F469)])

	assert page.grapheme_count() == 1

	s.split(PagePin{ node: first, y: 5, x: 0 }) or {
		assert false, 'split failed'
		return
	}

	second := first.next or {
		assert false, 'no second page'
		return
	}
	mut second_page := &second.data

	// Second page should have exactly 1 grapheme.
	assert second_page.grapheme_count() == 1

	c := second_page.rows[1].cells[0]
	assert c.codepoint == u32(0x1F468)
	assert second_page.rows[1].grapheme

	cps := second_page.lookup_grapheme(1, 0) or {
		assert false, 'lookup_grapheme failed'
		return
	}
	assert cps.len == 2
	assert cps[0] == u32(0x200D)
	assert cps[1] == u32(0x1F469)
}

fn test_page_list_split_preserves_hyperlinks() {
	mut s := PageList.init(10, 10, usize(0))
	defer { s.deinit() }

	first := s.pages.first or {
		assert false, 'no first page'
		return
	}
	mut page := &first.data

	// Add a hyperlink to row 7 (will be row 2 in second page).
	hyperlink_id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 0
		}
		uri: 'https://example.com'
	})
	mut row7 := &page.rows[7]
	row7.cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`L`)
	}
	page.set_hyperlink(7, 0, hyperlink_id)

	s.split(PagePin{ node: first, y: 5, x: 0 }) or {
		assert false, 'split failed'
		return
	}

	second := first.next or {
		assert false, 'no second page'
		return
	}
	mut second_page := &second.data

	// Second page should have exactly 1 hyperlink.
	assert second_page.hyperlink_count() == 1

	c := second_page.rows[2].cells[0]
	assert c.codepoint == u32(`L`)
	assert c.has_hyperlink

	link_id := second_page.lookup_hyperlink(2, 0) or {
		assert false, 'lookup_hyperlink failed'
		return
	}
	link := second_page.hyperlink_set.get(link_id)
	assert link.uri == 'https://example.com'
	assert second_page.hyperlink_set.ref_count(link_id) == 1
}
