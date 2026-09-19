module terminal

// Represents a selection whose bounds point directly into a PageList.
//
// This is the direct PageList-backed translation of Ghostty's Selection.zig.
// It is kept distinct from the legacy flat-coordinate Selection until Screen
// itself owns PageList; no selection behavior is reimplemented here.

// The bounds of a selection can be either tracked or untracked. Untracked
// bounds are unsafe beyond the point the page list may be modified, since they
// may point to invalid memory. Tracked bounds are updated as the page list
// changes, but are more expensive to keep alive.
pub struct PageSelectionUntrackedBounds {
pub mut:
	start PagePin
	end   PagePin
}

pub struct PageSelectionTrackedBounds {
pub mut:
	start &PagePin = unsafe { nil }
	end   &PagePin = unsafe { nil }
}

pub type PageSelectionBounds = PageSelectionTrackedBounds | PageSelectionUntrackedBounds

pub struct PageSelection {
pub mut:
	bounds    PageSelectionBounds
	rectangle bool
}

// Initialize a new selection with the given untracked bounds.
pub fn PageSelection.init(start_pin PagePin, end_pin PagePin, rectangle bool) PageSelection {
	return PageSelection{
		bounds: PageSelectionUntrackedBounds{
			start: start_pin
			end: end_pin
		}
		rectangle: rectangle
	}
}

pub fn (self PageSelection) deinit(mut pages PageList) {
	match self.bounds {
		PageSelectionTrackedBounds {
			pages.untrack_pin(self.bounds.start)
			pages.untrack_pin(self.bounds.end)
		}
		PageSelectionUntrackedBounds {}
	}
}

// Returns true if this selection is equal to another selection.
pub fn (self PageSelection) eql(other PageSelection) bool {
	return self.start().eql(other.start()) && self.end().eql(other.end())
		&& self.rectangle == other.rectangle
}

// The starting pin of the selection. This is NOT ordered.
pub fn (mut self PageSelection) start_ptr() &PagePin {
	match mut self.bounds {
		PageSelectionUntrackedBounds {
			return &self.bounds.start
		}
		PageSelectionTrackedBounds {
			return self.bounds.start
		}
	}
}

// The ending pin of the selection. This is NOT ordered.
pub fn (mut self PageSelection) end_ptr() &PagePin {
	match mut self.bounds {
		PageSelectionUntrackedBounds {
			return &self.bounds.end
		}
		PageSelectionTrackedBounds {
			return self.bounds.end
		}
	}
}

// The starting pin of the selection. This is NOT ordered.
pub fn (self PageSelection) start() PagePin {
	return match self.bounds {
		PageSelectionUntrackedBounds { self.bounds.start }
		PageSelectionTrackedBounds { *self.bounds.start }
	}
}

// The ending pin of the selection. This is NOT ordered.
pub fn (self PageSelection) end() PagePin {
	return match self.bounds {
		PageSelectionUntrackedBounds { self.bounds.end }
		PageSelectionTrackedBounds { *self.bounds.end }
	}
}

// Returns true if this is a tracked selection.
pub fn (self &PageSelection) tracked() bool {
	return self.bounds is PageSelectionTrackedBounds
}

// Convert this selection to a tracked selection. The receiver must be an
// untracked selection.
pub fn (self &PageSelection) track(mut pages PageList) PageSelection {
	assert !self.tracked()
	tracked_start := pages.track_pin(self.start())
	tracked_end := pages.track_pin(self.end())
	return PageSelection{
		bounds: PageSelectionTrackedBounds{
			start: tracked_start
			end: tracked_end
		}
		rectangle: self.rectangle
	}
}

// Returns the top-left pin of the selection.
pub fn (self PageSelection) top_left(pages &PageList) PagePin {
	return match self.order(pages) {
		.forward { self.start() }
		.reverse { self.end() }
		.mirrored_forward {
			mut p := self.start()
			p.x = self.end().x
			p
		}
		.mirrored_reverse {
			mut p := self.end()
			p.x = self.start().x
			p
		}
	}
}

// Returns the bottom-right pin of the selection.
pub fn (self PageSelection) bottom_right(pages &PageList) PagePin {
	return match self.order(pages) {
		.forward { self.end() }
		.reverse { self.start() }
		.mirrored_forward {
			mut p := self.end()
			p.x = self.start().x
			p
		}
		.mirrored_reverse {
			mut p := self.start()
			p.x = self.end().x
			p
		}
	}
}

// Determine the order of the selection.
pub fn (self PageSelection) order(pages &PageList) SelectionOrder {
	start_pt := (pages.point_from_pin(.screen, self.start()) or {
		panic('selection start is outside the page list')
	}).coord()
	end_pt := (pages.point_from_pin(.screen, self.end()) or {
		panic('selection end is outside the page list')
	}).coord()

	if self.rectangle {
		if start_pt.y > end_pt.y && start_pt.x >= end_pt.x {
			return .reverse
		}
		if start_pt.y >= end_pt.y && start_pt.x > end_pt.x {
			return .reverse
		}
		if start_pt.y > end_pt.y && start_pt.x < end_pt.x {
			return .mirrored_reverse
		}
		if start_pt.y < end_pt.y && start_pt.x > end_pt.x {
			return .mirrored_forward
		}
		return .forward
	}

	if start_pt.y < end_pt.y {
		return .forward
	}
	if start_pt.y > end_pt.y {
		return .reverse
	}
	if start_pt.x <= end_pt.x {
		return .forward
	}
	return .reverse
}

// Returns the selection in the requested order. The returned selection is
// always untracked.
pub fn (self PageSelection) ordered(pages &PageList, desired SelectionOrder) PageSelection {
	if self.order(pages) == desired {
		return PageSelection.init(self.start(), self.end(), self.rectangle)
	}

	tl := self.top_left(pages)
	br := self.bottom_right(pages)
	return match desired {
		.forward { PageSelection.init(tl, br, self.rectangle) }
		.reverse { PageSelection.init(br, tl, self.rectangle) }
		else { PageSelection.init(tl, br, self.rectangle) }
	}
}

// Returns true if the selection contains the given pin.
pub fn (self PageSelection) contains(pages &PageList, pin PagePin) bool {
	tl_pin := self.top_left(pages)
	br_pin := self.bottom_right(pages)
	tl := (pages.point_from_pin(.screen, tl_pin) or {
		panic('selection top-left is outside the page list')
	}).coord()
	br := (pages.point_from_pin(.screen, br_pin) or {
		panic('selection bottom-right is outside the page list')
	}).coord()
	p := (pages.point_from_pin(.screen, pin) or {
		panic('selection test pin is outside the page list')
	}).coord()

	if self.rectangle {
		return p.y >= tl.y && p.y <= br.y && p.x >= tl.x && p.x <= br.x
	}
	if tl.y == br.y {
		return p.y == tl.y && p.x >= tl.x && p.x <= br.x
	}
	if p.y == tl.y {
		return p.x >= tl.x
	}
	if p.y == br.y {
		return p.x <= br.x
	}
	return p.y > tl.y && p.y < br.y
}

// Get the part of this selection contained by a single row.
pub fn (self PageSelection) contained_row(pages &PageList, pin PagePin) ?PageSelection {
	tl_pin := self.top_left(pages)
	br_pin := self.bottom_right(pages)
	tl := (pages.point_from_pin(.screen, tl_pin) or {
		panic('selection top-left is outside the page list')
	}).coord()
	br := (pages.point_from_pin(.screen, br_pin) or {
		panic('selection bottom-right is outside the page list')
	}).coord()
	p := (pages.point_from_pin(.screen, pin) or {
		panic('selection row pin is outside the page list')
	}).coord()
	return self.contained_row_cached(pages, tl_pin, br_pin, pin, tl, br, p)
}

// Same as contained_row, but accepts cached point coordinates for callers
// iterating over many rows.
pub fn (self PageSelection) contained_row_cached(pages &PageList, tl_pin PagePin, br_pin PagePin, pin PagePin, tl Coordinate, br Coordinate, p Coordinate) ?PageSelection {
	if p.y < tl.y || p.y > br.y {
		return none
	}

	if self.rectangle {
		mut start := pin
		start.x = tl.x
		mut end := pin
		end.x = br.x
		return PageSelection.init(start, end, true)
	}

	if p.y == tl.y {
		if p.y == br.y {
			return PageSelection.init(tl_pin, br_pin, false)
		}
		mut end := pin
		end.x = pages.cols - 1
		return PageSelection.init(tl_pin, end, false)
	}

	if p.y == br.y {
		assert p.y != tl.y
		mut start := pin
		start.x = 0
		return PageSelection.init(start, br_pin, false)
	}

	mut start := pin
	start.x = 0
	mut end := pin
	end.x = pages.cols - 1
	return PageSelection.init(start, end, false)
}

// Adjust the selection by one logical movement.
pub fn (mut self PageSelection) adjust(pages &PageList, adjustment SelectionAdjustment) {
	mut end_pin := self.end_ptr()
	match adjustment {
		.up {
			if new_end := end_pin.up(1) {
				unsafe { *end_pin = new_end }
			} else {
				self.adjust(pages, .beginning_of_line)
			}
		}
		.down {
			mut current := *end_pin
			mut found := false
			for {
				next := current.down(1) or { break }
				rac := next.row_and_cell()
				cells := next.node.data.get_cells(rac.row)
				if has_text_any(cells) {
					unsafe { *end_pin = next }
					found = true
					break
				}
				current = next
			}
			if !found {
				self.adjust(pages, .end_of_line)
			}
		}
		.left {
			mut it := end_pin.cell_iterator(.left_up, none)
			_ = it.next()
			for {
				next := it.next() or { break }
				if next.row_and_cell().cell.has_text() {
					unsafe { *end_pin = next }
					break
				}
			}
		}
		.right {
			mut it := end_pin.cell_iterator(.right_down, none)
			_ = it.next()
			for {
				next := it.next() or { break }
				if next.row_and_cell().cell.has_text() {
					unsafe { *end_pin = next }
					break
				}
			}
		}
		.page_up {
			if new_end := end_pin.up(usize(pages.rows)) {
				unsafe { *end_pin = new_end }
			} else {
				self.adjust(pages, .home)
			}
		}
		.page_down {
			if new_end := end_pin.down(usize(pages.rows)) {
				unsafe { *end_pin = new_end }
			} else {
				self.adjust(pages, .end_)
			}
		}
		.home {
			new_end := pages.pin(Point{
				tag: .screen
				coordinate: Coordinate{}
			}) or { panic('page list has no home pin') }
			unsafe { *end_pin = new_end }
		}
		.end_ {
			mut it := pages.row_iterator(.left_up, Point{ tag: .screen }, none)
			for {
				next := it.next() or { break }
				rac := next.row_and_cell()
				cells := next.node.data.get_cells(rac.row)
				if has_text_any(cells) {
					unsafe { *end_pin = next }
					end_pin.x = u16(cells.len - 1)
					break
				}
			}
		}
		.beginning_of_line {
			end_pin.x = 0
		}
		.end_of_line {
			end_pin.x = end_pin.node.data.size.cols - 1
		}
	}
}
