module terminal

// Tests translated from Ghostty's Selection.zig for the PageList-backed
// selection representation.

fn page_selection_pin(pages &PageList, x u16, y u16) PagePin {
	return pages.pin(Point.new(.screen, Coordinate{ x: x, y: y })) or {
		panic('page_selection_pin(${x}, ${y}) returned none')
	}
}

fn page_selection_point(pages &PageList, pin PagePin) Coordinate {
	return (pages.point_from_pin(.screen, pin) or {
		panic('page selection pin is outside the page list')
	}).coord()
}

fn page_selection_assert_point(pages &PageList, pin PagePin, x u16, y u16) {
	point := page_selection_point(pages, pin)
	assert point.x == x
	assert point.y == y
}

fn page_selection_write(mut pages PageList, text string) {
	mut x := u16(0)
	mut y := u16(0)
	for cp in text.runes() {
		if cp == `\n` {
			x = 0
			y++
			continue
		}
		pin := page_selection_pin(&pages, x, y)
		mut row := &pin.node.data.rows[int(pin.y)]
		row.cells[int(pin.x)] = CellData{
			content_tag: .codepoint
			codepoint: u32(cp)
		}
		x++
	}
}

fn test_page_selection_bounds_access_tracking_and_equality() {
	mut pages := PageList.init(10, 10, usize(0))
	defer { pages.deinit() }

	mut selection := PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 3, 3), false)
	assert !selection.tracked()
	assert selection.eql(PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 3, 3), false))
	assert !selection.eql(PageSelection.init(page_selection_pin(&pages, 2, 1), page_selection_pin(&pages, 3, 3), false))
	assert !selection.eql(PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 3, 3), true))

	mut untracked_start := selection.start_ptr()
	untracked_start.x = 2
	mut untracked_end := selection.end_ptr()
	untracked_end.x = 4
	page_selection_assert_point(&pages, selection.start(), 2, 1)
	page_selection_assert_point(&pages, selection.end(), 4, 3)

	assert pages.count_tracked_pins() == 1
	mut tracked := selection.track(mut pages)
	assert tracked.tracked()
	assert pages.count_tracked_pins() == 3
	mut tracked_start := tracked.start_ptr()
	tracked_start.x = 5
	mut tracked_end := tracked.end_ptr()
	tracked_end.x = 6
	page_selection_assert_point(&pages, tracked.start(), 5, 1)
	page_selection_assert_point(&pages, tracked.end(), 6, 3)

	pages.reset()
	assert tracked.start().garbage
	assert tracked.end().garbage
	assert tracked.start().x == 0
	assert tracked.start().y == 0
	assert tracked.end().x == 0
	assert tracked.end().y == 0
	tracked.deinit(mut pages)
	assert pages.count_tracked_pins() == 1
}

fn test_page_selection_order_standard() {
	mut pages := PageList.init(100, 100, usize(0))
	defer { pages.deinit() }

	assert PageSelection.init(page_selection_pin(&pages, 2, 1), page_selection_pin(&pages, 2, 2), false).order(&pages) == .forward
	assert PageSelection.init(page_selection_pin(&pages, 2, 2), page_selection_pin(&pages, 2, 1), false).order(&pages) == .reverse
	assert PageSelection.init(page_selection_pin(&pages, 2, 1), page_selection_pin(&pages, 3, 1), false).order(&pages) == .forward
	assert PageSelection.init(page_selection_pin(&pages, 2, 1), page_selection_pin(&pages, 2, 1), false).order(&pages) == .forward
	assert PageSelection.init(page_selection_pin(&pages, 2, 1), page_selection_pin(&pages, 1, 1), false).order(&pages) == .reverse
}

fn test_page_selection_order_rectangle() {
	mut pages := PageList.init(100, 100, usize(0))
	defer { pages.deinit() }

	assert PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 2, 2), true).order(&pages) == .forward
	assert PageSelection.init(page_selection_pin(&pages, 2, 2), page_selection_pin(&pages, 1, 1), true).order(&pages) == .reverse
	assert PageSelection.init(page_selection_pin(&pages, 3, 1), page_selection_pin(&pages, 1, 3), true).order(&pages) == .mirrored_forward
	assert PageSelection.init(page_selection_pin(&pages, 1, 3), page_selection_pin(&pages, 3, 1), true).order(&pages) == .mirrored_reverse
	assert PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 3, 1), true).order(&pages) == .forward
	assert PageSelection.init(page_selection_pin(&pages, 3, 1), page_selection_pin(&pages, 1, 1), true).order(&pages) == .reverse
	assert PageSelection.init(page_selection_pin(&pages, 2, 1), page_selection_pin(&pages, 2, 3), true).order(&pages) == .forward
	assert PageSelection.init(page_selection_pin(&pages, 2, 3), page_selection_pin(&pages, 2, 1), true).order(&pages) == .reverse
	assert PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 1, 1), true).order(&pages) == .forward
}

fn test_page_selection_corners_and_ordered() {
	mut pages := PageList.init(10, 10, usize(0))
	defer { pages.deinit() }

	for selection in [
		PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 3, 3), true),
		PageSelection.init(page_selection_pin(&pages, 3, 3), page_selection_pin(&pages, 1, 1), true),
		PageSelection.init(page_selection_pin(&pages, 3, 1), page_selection_pin(&pages, 1, 3), true),
		PageSelection.init(page_selection_pin(&pages, 1, 3), page_selection_pin(&pages, 3, 1), true),
	] {
		page_selection_assert_point(&pages, selection.top_left(&pages), 1, 1)
		page_selection_assert_point(&pages, selection.bottom_right(&pages), 3, 3)
		forward := PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 3, 3), true)
		reverse := PageSelection.init(page_selection_pin(&pages, 3, 3), page_selection_pin(&pages, 1, 1), true)
		assert selection.ordered(&pages, .forward).eql(forward)
		assert selection.ordered(&pages, .reverse).eql(reverse)
	}
	normal_forward := PageSelection.init(page_selection_pin(&pages, 1, 1), page_selection_pin(&pages, 3, 3), true)
	assert normal_forward.ordered(&pages, .mirrored_forward).eql(normal_forward)
}

fn test_page_selection_contains() {
	mut pages := PageList.init(15, 15, usize(0))
	defer { pages.deinit() }

	for selection in [
		PageSelection.init(page_selection_pin(&pages, 5, 1), page_selection_pin(&pages, 3, 2), false),
		PageSelection.init(page_selection_pin(&pages, 3, 2), page_selection_pin(&pages, 5, 1), false),
	] {
		assert selection.contains(&pages, page_selection_pin(&pages, 6, 1))
		assert selection.contains(&pages, page_selection_pin(&pages, 1, 2))
		assert !selection.contains(&pages, page_selection_pin(&pages, 1, 1))
		assert !selection.contains(&pages, page_selection_pin(&pages, 5, 2))
	}

	single := PageSelection.init(page_selection_pin(&pages, 5, 1), page_selection_pin(&pages, 8, 1), false)
	assert single.contains(&pages, page_selection_pin(&pages, 6, 1))
	assert !single.contains(&pages, page_selection_pin(&pages, 2, 1))
	assert !single.contains(&pages, page_selection_pin(&pages, 9, 1))
}

fn test_page_selection_contains_rectangle() {
	mut pages := PageList.init(15, 15, usize(0))
	defer { pages.deinit() }

	for selection in [
		PageSelection.init(page_selection_pin(&pages, 3, 3), page_selection_pin(&pages, 7, 9), true),
		PageSelection.init(page_selection_pin(&pages, 7, 9), page_selection_pin(&pages, 3, 3), true),
	] {
		assert selection.contains(&pages, page_selection_pin(&pages, 5, 6))
		assert selection.contains(&pages, page_selection_pin(&pages, 3, 6))
		assert selection.contains(&pages, page_selection_pin(&pages, 7, 6))
		assert selection.contains(&pages, page_selection_pin(&pages, 5, 3))
		assert selection.contains(&pages, page_selection_pin(&pages, 5, 9))
		assert !selection.contains(&pages, page_selection_pin(&pages, 5, 2))
		assert !selection.contains(&pages, page_selection_pin(&pages, 5, 10))
		assert !selection.contains(&pages, page_selection_pin(&pages, 2, 6))
		assert !selection.contains(&pages, page_selection_pin(&pages, 8, 6))
	}
}

fn test_page_selection_contained_row() {
	mut pages := PageList.init(10, 5, usize(0))
	defer { pages.deinit() }

	selection := PageSelection.init(page_selection_pin(&pages, 5, 1), page_selection_pin(&pages, 3, 3), false)
	assert selection.contained_row(&pages, page_selection_pin(&pages, 1, 4)) == none
	start_row := selection.contained_row(&pages, page_selection_pin(&pages, 1, 1)) or {
		assert false
		return
	}
	assert start_row.eql(PageSelection.init(page_selection_pin(&pages, 5, 1), page_selection_pin(&pages, 9, 1), false))
	end_row := selection.contained_row(&pages, page_selection_pin(&pages, 2, 3)) or {
		assert false
		return
	}
	assert end_row.eql(PageSelection.init(page_selection_pin(&pages, 0, 3), page_selection_pin(&pages, 3, 3), false))
	mid_row := selection.contained_row(&pages, page_selection_pin(&pages, 2, 2)) or {
		assert false
		return
	}
	assert mid_row.eql(PageSelection.init(page_selection_pin(&pages, 0, 2), page_selection_pin(&pages, 9, 2), false))

	rectangle := PageSelection.init(page_selection_pin(&pages, 3, 1), page_selection_pin(&pages, 6, 3), true)
	assert rectangle.contained_row(&pages, page_selection_pin(&pages, 1, 4)) == none
	for y in u16(1) .. u16(4) {
		row := rectangle.contained_row(&pages, page_selection_pin(&pages, 1, y)) or {
			assert false
			return
		}
		assert row.eql(PageSelection.init(page_selection_pin(&pages, 3, y), page_selection_pin(&pages, 6, y), true))
	}

	single := PageSelection.init(page_selection_pin(&pages, 2, 1), page_selection_pin(&pages, 6, 1), false)
	assert single.contained_row(&pages, page_selection_pin(&pages, 1, 0)) == none
	assert single.contained_row(&pages, page_selection_pin(&pages, 1, 2)) == none
	assert (single.contained_row(&pages, page_selection_pin(&pages, 1, 1)) or {
		assert false
		return
	}).eql(single)
}

fn test_page_selection_adjust_horizontal_and_vertical() {
	mut pages := PageList.init(10, 10, usize(0))
	defer { pages.deinit() }
	page_selection_write(mut pages, 'A1234\nB5678\nC12\nD56\nE')

	mut selection := PageSelection.init(page_selection_pin(&pages, 5, 1), page_selection_pin(&pages, 2, 3), false)
	selection.adjust(&pages, .right)
	page_selection_assert_point(&pages, selection.end(), 0, 4)
	selection.adjust(&pages, .left)
	page_selection_assert_point(&pages, selection.end(), 2, 3)
	selection.adjust(&pages, .left)
	page_selection_assert_point(&pages, selection.end(), 1, 3)
	selection.adjust(&pages, .up)
	page_selection_assert_point(&pages, selection.end(), 1, 2)
	selection.adjust(&pages, .down)
	page_selection_assert_point(&pages, selection.end(), 1, 3)

	mut beginning := PageSelection.init(page_selection_pin(&pages, 5, 1), page_selection_pin(&pages, 0, 0), false)
	beginning.adjust(&pages, .up)
	page_selection_assert_point(&pages, beginning.end(), 0, 0)

	mut last_text := PageSelection.init(page_selection_pin(&pages, 4, 1), page_selection_pin(&pages, 0, 4), false)
	last_text.adjust(&pages, .down)
	page_selection_assert_point(&pages, last_text.end(), 9, 4)
}

fn test_page_selection_adjust_absolute_and_page() {
	mut pages := PageList.init(8, 10, usize(0))
	defer { pages.deinit() }
	page_selection_write(mut pages, 'A12 B34\nC12 D34\nE')

	mut selection := PageSelection.init(page_selection_pin(&pages, 5, 1), page_selection_pin(&pages, 5, 1), false)
	selection.adjust(&pages, .beginning_of_line)
	page_selection_assert_point(&pages, selection.end(), 0, 1)
	selection.adjust(&pages, .end_of_line)
	page_selection_assert_point(&pages, selection.end(), 7, 1)
	selection.adjust(&pages, .home)
	page_selection_assert_point(&pages, selection.end(), 0, 0)
	selection.adjust(&pages, .end_)
	page_selection_assert_point(&pages, selection.end(), 7, 2)

	selection.adjust(&pages, .page_up)
	page_selection_assert_point(&pages, selection.end(), 0, 0)
	selection.adjust(&pages, .page_down)
	page_selection_assert_point(&pages, selection.end(), 7, 2)
}
