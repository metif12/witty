module terminal

// Represents a single selection within the terminal (i.e. a highlight region).
// Translated from Ghostty's Selection.zig.

// NOTE(mitchellh): I'm not very happy with how this is implemented, because
// the ordering operations which are used frequently require using
// pointFromPin which -- at the time of writing this -- is slow. The overall
// style of this struct is due to porting it from the previous implementation
// which had an efficient ordering operation.
//
// While reimplementing this, there were too many callers that already
// depended on this behavior so I kept it despite the inefficiency. In the
// future, we should take a look at this again!

// ============================================================
// Order enum
// ============================================================

// The order of the selection:
//
//  * forward: start(x, y) is before end(x, y) (top-left to bottom-right).
//  * reverse: end(x, y) is before start(x, y) (bottom-right to top-left).
//  * mirrored_[forward|reverse]: special, rectangle selections only (see below).
//
//  For regular selections, the above also holds for top-right to bottom-left
//  (forward) and bottom-left to top-right (reverse). However, for rectangle
//  selections, both of these selections are *mirrored* as orientation
//  operations only flip the x or y axis, not both. Depending on the y axis
//  direction, this is either mirrored_forward or mirrored_reverse.
pub enum SelectionOrder as u8 {
	forward
	reverse
	mirrored_forward
	mirrored_reverse
}

// ============================================================
// Adjustment enum
// ============================================================

// Possible adjustments to the selection.
pub enum SelectionAdjustment as u8 {
	left
	right
	up
	down
	home
	end_
	page_up
	page_down
	beginning_of_line
	end_of_line
}

pub struct SelectionUntrackedBounds {
pub mut:
	start Pin
	end   Pin
}

pub struct SelectionTrackedBounds {
pub mut:
	start &Pin = unsafe { nil }
	end   &Pin = unsafe { nil }
}

pub type SelectionBounds = SelectionTrackedBounds | SelectionUntrackedBounds

pub struct Selection {
pub mut:
	bounds    SelectionBounds
	rectangle bool
}

// Initialize a new selection with the given untracked bounds.
pub fn Selection.init(start_pin Pin, end_pin Pin, rectangle bool) Selection {
	return Selection{
		bounds:    SelectionUntrackedBounds{
			start: start_pin
			end:   end_pin
		}
		rectangle: rectangle
	}
}

pub fn (self Selection) deinit(mut s Screen) {
	match self.bounds {
		SelectionTrackedBounds {
			s.pages.untrack_pin(self.bounds.start)
			s.pages.untrack_pin(self.bounds.end)
		}
		SelectionUntrackedBounds {}
	}
}

// Returns true if this selection is equal to another selection.
pub fn (self Selection) eql(other Selection) bool {
	return self.start().eql(other.start()) && self.end().eql(other.end())
		&& self.rectangle == other.rectangle
}

// The starting pin of the selection. This is NOT ordered.
pub fn (mut self Selection) start_ptr() &Pin {
	match mut self.bounds {
		SelectionUntrackedBounds {
			return &self.bounds.start
		}
		SelectionTrackedBounds {
			return self.bounds.start
		}
	}
}

// The ending pin of the selection. This is NOT ordered.
pub fn (mut self Selection) end_ptr() &Pin {
	match mut self.bounds {
		SelectionUntrackedBounds {
			return &self.bounds.end
		}
		SelectionTrackedBounds {
			return self.bounds.end
		}
	}
}

// The starting pin of the selection. This is NOT ordered.
pub fn (self Selection) start() Pin {
	return match self.bounds {
		SelectionUntrackedBounds { self.bounds.start }
		SelectionTrackedBounds { *self.bounds.start }
	}
}

// The ending pin of the selection. This is NOT ordered.
pub fn (self Selection) end() Pin {
	return match self.bounds {
		SelectionUntrackedBounds { self.bounds.end }
		SelectionTrackedBounds { *self.bounds.end }
	}
}

// Returns true if this is a tracked selection.
pub fn (self &Selection) tracked() bool {
	return self.bounds is SelectionTrackedBounds
}

// Convert this selection to a tracked selection. The receiver must be an
// untracked selection.
pub fn (self &Selection) track(mut s Screen) !Selection {
	assert !self.tracked()
	tracked_start := s.pages.track_pin(self.start())!
	tracked_end := s.pages.track_pin(self.end()) or {
		s.pages.untrack_pin(tracked_start)
		return err
	}
	return Selection{
		bounds:    SelectionTrackedBounds{
			start: tracked_start
			end:   tracked_end
		}
		rectangle: self.rectangle
	}
}

// Returns the top-left pin of the selection.
pub fn (self Selection) top_left(s &Screen) Pin {
	return match self.order(s) {
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
pub fn (self Selection) bottom_right(s &Screen) Pin {
	return match self.order(s) {
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
pub fn (self Selection) order(s &Screen) SelectionOrder {
	start_pt := (s.pages.point_from_pin(.screen, self.start()) or {
		panic('selection start is outside the page list')
	}).coord()
	end_pt := (s.pages.point_from_pin(.screen, self.end()) or {
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
pub fn (self Selection) ordered(s &Screen, desired SelectionOrder) Selection {
	if self.order(s) == desired {
		return Selection.init(self.start(), self.end(), self.rectangle)
	}

	tl := self.top_left(s)
	br := self.bottom_right(s)
	return match desired {
		.forward { Selection.init(tl, br, self.rectangle) }
		.reverse { Selection.init(br, tl, self.rectangle) }
		else { Selection.init(tl, br, self.rectangle) }
	}
}

// Returns true if the selection contains the given pin.
pub fn (self Selection) contains(s &Screen, pin Pin) bool {
	tl_pin := self.top_left(s)
	br_pin := self.bottom_right(s)
	tl := (s.pages.point_from_pin(.screen, tl_pin) or {
		panic('selection top-left is outside the page list')
	}).coord()
	br := (s.pages.point_from_pin(.screen, br_pin) or {
		panic('selection bottom-right is outside the page list')
	}).coord()
	p := (s.pages.point_from_pin(.screen, pin) or {
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
pub fn (self Selection) contained_row(s &Screen, pin Pin) ?Selection {
	tl_pin := self.top_left(s)
	br_pin := self.bottom_right(s)
	tl := (s.pages.point_from_pin(.screen, tl_pin) or {
		panic('selection top-left is outside the page list')
	}).coord()
	br := (s.pages.point_from_pin(.screen, br_pin) or {
		panic('selection bottom-right is outside the page list')
	}).coord()
	p := (s.pages.point_from_pin(.screen, pin) or {
		panic('selection row pin is outside the page list')
	}).coord()
	return self.contained_row_cached(s, tl_pin, br_pin, pin, tl, br, p)
}

// Same as contained_row, but accepts cached point coordinates for callers
// iterating over many rows.
pub fn (self Selection) contained_row_cached(s &Screen, tl_pin Pin, br_pin Pin, pin Pin, tl Coordinate, br Coordinate, p Coordinate) ?Selection {
	if p.y < tl.y || p.y > br.y {
		return none
	}

	if self.rectangle {
		mut start := pin
		start.x = tl.x
		mut end := pin
		end.x = br.x
		return Selection.init(start, end, true)
	}

	if p.y == tl.y {
		if p.y == br.y {
			return Selection.init(tl_pin, br_pin, false)
		}
		mut end := pin
		end.x = s.pages.cols - 1
		return Selection.init(tl_pin, end, false)
	}

	if p.y == br.y {
		assert p.y != tl.y
		mut start := pin
		start.x = 0
		return Selection.init(start, br_pin, false)
	}

	mut start := pin
	start.x = 0
	mut end := pin
	end.x = s.pages.cols - 1
	return Selection.init(start, end, false)
}

// Adjust the selection by one logical movement.
pub fn (mut self Selection) adjust(s &Screen, adjustment SelectionAdjustment) {
	mut end_pin := self.end_ptr()
	match adjustment {
		.up {
			if new_end := end_pin.up(1) {
				unsafe { *end_pin = new_end }
			} else {
				self.adjust(s, .beginning_of_line)
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
				self.adjust(s, .end_of_line)
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
			if new_end := end_pin.up(uint(s.pages.rows)) {
				unsafe { *end_pin = new_end }
			} else {
				self.adjust(s, .home)
			}
		}
		.page_down {
			if new_end := end_pin.down(uint(s.pages.rows)) {
				unsafe { *end_pin = new_end }
			} else {
				self.adjust(s, .end_)
			}
		}
		.home {
			new_end := s.pages.pin(Point.new(.screen, Coordinate{})) or {
				panic('page list has no home pin')
			}
			unsafe { *end_pin = new_end }
		}
		.end_ {
			mut it := s.pages.row_iterator(.left_up, Point.new(.screen, Coordinate{}), none)
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
