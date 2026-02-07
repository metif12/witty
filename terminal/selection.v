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
pub enum SelectionOrder {
	forward
	reverse
	mirrored_forward
	mirrored_reverse
}

// ============================================================
// Adjustment enum
// ============================================================

// Possible adjustments to the selection.
pub enum SelectionAdjustment {
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

// ============================================================
// Selection methods
// ============================================================

// Returns true if this selection is equal to another selection.
pub fn (self &Selection) eql(other Selection) bool {
	return self.start_pin.eql(other.start_pin)
		&& self.end_pin.eql(other.end_pin)
		&& self.rectangle == other.rectangle
}

// Determine the order of the selection.
pub fn (self &Selection) order(s &Screen) SelectionOrder {
	start_pt := self.start_pin
	end_pt := self.end_pin

	if self.rectangle {
		// Reverse (also handles single-column)
		if start_pt.y > end_pt.y && start_pt.x >= end_pt.x {
			return .reverse
		}
		if start_pt.y >= end_pt.y && start_pt.x > end_pt.x {
			return .reverse
		}

		// Mirror, bottom-left to top-right
		if start_pt.y > end_pt.y && start_pt.x < end_pt.x {
			return .mirrored_reverse
		}

		// Mirror, top-right to bottom-left
		if start_pt.y < end_pt.y && start_pt.x > end_pt.x {
			return .mirrored_forward
		}

		// Forward
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

// Returns the top left point of the selection.
pub fn (self &Selection) top_left(s &Screen) Pin {
	return match self.order(s) {
		.forward {
			self.start_pin
		}
		.reverse {
			self.end_pin
		}
		.mirrored_forward {
			Pin{
				x: self.end_pin.x
				y: self.start_pin.y
			}
		}
		.mirrored_reverse {
			Pin{
				x: self.start_pin.x
				y: self.end_pin.y
			}
		}
	}
}

// Returns the bottom right point of the selection.
pub fn (self &Selection) bottom_right(s &Screen) Pin {
	return match self.order(s) {
		.forward {
			self.end_pin
		}
		.reverse {
			self.start_pin
		}
		.mirrored_forward {
			Pin{
				x: self.start_pin.x
				y: self.end_pin.y
			}
		}
		.mirrored_reverse {
			Pin{
				x: self.end_pin.x
				y: self.start_pin.y
			}
		}
	}
}

// Returns the selection in the given order.
//
// The returned selection is always a new untracked selection.
//
// Note that only forward and reverse are useful desired orders for this
// function. All other orders act as if forward order was desired.
pub fn (self &Selection) ordered(s &Screen, desired SelectionOrder) Selection {
	if self.order(s) == desired {
		return Selection.init(self.start_pin, self.end_pin, self.rectangle)
	}

	tl := self.top_left(s)
	br := self.bottom_right(s)
	return match desired {
		.forward { Selection.init(tl, br, self.rectangle) }
		.reverse { Selection.init(br, tl, self.rectangle) }
		else { Selection.init(tl, br, self.rectangle) }
	}
}

// Returns true if the selection contains the given point.
//
// This recalculates top left and bottom right each call. If you have
// many points to check, it is cheaper to do the containment logic
// yourself and cache the topleft/bottomright.
pub fn (self &Selection) contains(s &Screen, pin Pin) bool {
	tl := self.top_left(s)
	br := self.bottom_right(s)
	p := pin

	// If we're in rectangle select, we can short-circuit with an easy check
	// here
	if self.rectangle {
		return p.y >= tl.y && p.y <= br.y && p.x >= tl.x && p.x <= br.x
	}

	// If tl/br are same line
	if tl.y == br.y {
		return p.y == tl.y && p.x >= tl.x && p.x <= br.x
	}

	// If on top line, just has to be left of X
	if p.y == tl.y {
		return p.x >= tl.x
	}

	// If on bottom line, just has to be right of X
	if p.y == br.y {
		return p.x <= br.x
	}

	// If between the top/bottom, always good.
	return p.y > tl.y && p.y < br.y
}

// Get a selection for a single row in the screen. This will return null
// if the row is not included in the selection.
//
// This is a very expensive operation. It has to traverse the linked list
// of pages for the top-left, bottom-right, and the given pin to find
// the coordinates. If you are calling this repeatedly, prefer
// `contained_row_cached`.
pub fn (self &Selection) contained_row(s &Screen, pin Pin) ?Selection {
	tl_pin := self.top_left(s)
	br_pin := self.bottom_right(s)
	tl := tl_pin
	br := br_pin
	p := pin

	return self.contained_row_cached(s, tl_pin, br_pin, pin, tl, br, p)
}

// Same as contained_row but useful if you're calling it repeatedly
// so that the pins can be cached across calls. Advanced.
pub fn (self &Selection) contained_row_cached(s &Screen, tl_pin Pin, br_pin Pin, pin Pin, tl Pin, br Pin, p Pin) ?Selection {
	if p.y < tl.y || p.y > br.y {
		return none
	}

	// Rectangle case: we can return early as the x range will always be the
	// same. We've already validated that the row is in the selection.
	if self.rectangle {
		return Selection.init(
			Pin{ x: tl.x, y: pin.y },
			Pin{ x: br.x, y: pin.y },
			true
		)
	}

	if p.y == tl.y {
		// If the selection is JUST this line, return it as-is.
		if p.y == br.y {
			return Selection.init(tl_pin, br_pin, false)
		}

		// Selection top-left line matches only.
		return Selection.init(
			tl_pin,
			Pin{ x: s.pages.cols - 1, y: pin.y },
			false
		)
	}

	// Row is our bottom selection, so we return the selection from the
	// beginning of the line to the br. We know our selection is more than
	// one line (due to conditionals above)
	if p.y == br.y {
		assert p.y != tl.y
		return Selection.init(
			Pin{ x: 0, y: pin.y },
			br_pin,
			false
		)
	}

	// Row is somewhere between our selection lines so we return the full line.
	return Selection.init(
		Pin{ x: 0, y: pin.y },
		Pin{ x: s.pages.cols - 1, y: pin.y },
		false
	)
}

// Adjust the selection by some given adjustment. An adjustment allows
// a selection to be expanded slightly left, right, up, down, etc.
pub fn (mut self Selection) adjust(s &Screen, adjustment SelectionAdjustment) {
	// Note that we always adjust "end" because end always represents
	// the last point of the selection by mouse, not necessarily the
	// top/bottom visually. So this results in the correct behavior
	// whether the user drags up or down.
	match adjustment {
		.up {
			if new_end := self.end_pin.up(1) {
				self.end_pin = new_end
			} else {
				self.adjust(s, .beginning_of_line)
			}
		}
		.down {
			// Find the next non-blank row
			mut current := self.end_pin
			mut found := false
			for {
				next := current.down(1) or { break }
				if int(next.y) >= s.pages.screen_rows.len {
					break
				}
				row := s.pages.screen_rows[int(next.y)]
				if has_text_any(row.cells) {
					self.end_pin = next
					found = true
					break
				}
				current = next
			}
			if !found {
				// If we're at the bottom, just go to the end of the line
				self.adjust(s, .end_of_line)
			}
		}
		.left {
			// Step left, wrapping to the previous row at the end of each line,
			// until we find a non-empty cell.
			mut cx := int(self.end_pin.x) - 1
			mut cy := int(self.end_pin.y)
			for {
				if cx < 0 {
					cy -= 1
					if cy < 0 {
						break
					}
					cx = int(s.pages.cols) - 1
				}
				if cy < s.pages.screen_rows.len {
					row := s.pages.screen_rows[cy]
					if cx < row.cells.len {
						cell := row.cells[cx]
						if cell.has_text() {
							self.end_pin = Pin{
								x: u32(cx)
								y: u32(cy)
							}
							break
						}
					}
				}
				cx -= 1
			}
		}
		.right {
			// Step right, wrapping to the next row down at the start of each new line,
			// until we find a non-empty cell.
			mut cx := int(self.end_pin.x) + 1
			mut cy := int(self.end_pin.y)
			mut found := false
			for {
				if cx >= int(s.pages.cols) {
					cy += 1
					cx = 0
				}
				if cy >= s.pages.screen_rows.len {
					break
				}
				row := s.pages.screen_rows[cy]
				if cx < row.cells.len {
					cell := row.cells[cx]
					if cell.has_text() {
						self.end_pin = Pin{
							x: u32(cx)
							y: u32(cy)
						}
						found = true
						break
					}
				}
				cx += 1
			}
			// If we didn't find anything, don't move
			_ = found
		}
		.page_up {
			if new_end := self.end_pin.up(s.pages.rows) {
				self.end_pin = new_end
			} else {
				self.adjust(s, .home)
			}
		}
		.page_down {
			if new_end := self.end_pin.down(s.pages.rows) {
				self.end_pin = new_end
			} else {
				self.adjust(s, .end_)
			}
		}
		.home {
			self.end_pin = Pin{ x: 0, y: 0 }
		}
		.end_ {
			// Find the last row with text content, scanning from the bottom
			mut cy := s.pages.screen_rows.len - 1
			for cy >= 0 {
				row := s.pages.screen_rows[cy]
				if has_text_any(row.cells) {
					self.end_pin = Pin{
						x: u32(row.cells.len - 1)
						y: u32(cy)
					}
					break
				}
				cy -= 1
			}
		}
		.beginning_of_line {
			self.end_pin.x = 0
		}
		.end_of_line {
			self.end_pin.x = s.pages.cols - 1
		}
	}
}
