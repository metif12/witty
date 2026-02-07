module terminal

// Tests for Selection, translated from Ghostty's Selection.zig.

// ============================================================
// Helper: create a pin via Pages.pin for screen coordinates
// ============================================================

fn screen_pin(s &Screen, x u32, y u32) Pin {
	return s.pages.pin(PinOpts{ tag: .screen, x: x, y: y }) or {
		panic('screen_pin(${x}, ${y}) returned none')
	}
}

// ============================================================
// Selection: adjust right
// ============================================================

fn test_selection_adjust_right() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A1234\nB5678\nC1234\nD5678') or { assert false }

	// Simple movement right
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 3, 3),
			false
		)
		sel.adjust(&s, .right)

		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 4
		assert sel.end_pin.y == 3
	}

	// Already at end of the line.
	{
		mut sel := Selection.init(
			screen_pin(&s, 4, 1),
			screen_pin(&s, 4, 2),
			false
		)
		sel.adjust(&s, .right)

		assert sel.start_pin.x == 4
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 0
		assert sel.end_pin.y == 3
	}

	// Already at end of the screen
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 4, 3),
			false
		)
		sel.adjust(&s, .right)

		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		// No movement since D5678 ends at x=4 which is the last text cell
		assert sel.end_pin.x == 4
		assert sel.end_pin.y == 3
	}
}

// ============================================================
// Selection: adjust left
// ============================================================

fn test_selection_adjust_left() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A1234\nB5678\nC1234\nD5678') or { assert false }

	// Simple movement left
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 3, 3),
			false
		)
		sel.adjust(&s, .left)

		// Start line
		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 2
		assert sel.end_pin.y == 3
	}

	// Already at beginning of the line.
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 0, 3),
			false
		)
		sel.adjust(&s, .left)

		// Start line
		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 4
		assert sel.end_pin.y == 2
	}
}

// ============================================================
// Selection: adjust left skips blanks
// ============================================================

fn test_selection_adjust_left_skips_blanks() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A1234\nB5678\nC12\nD56') or { assert false }

	// Same line
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 4, 3),
			false
		)
		sel.adjust(&s, .left)

		// Start line
		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 2
		assert sel.end_pin.y == 3
	}

	// Edge
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 0, 3),
			false
		)
		sel.adjust(&s, .left)

		// Start line
		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 2
		assert sel.end_pin.y == 2
	}
}

// ============================================================
// Selection: adjust up
// ============================================================

fn test_selection_adjust_up() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A\nB\nC\nD\nE') or { assert false }

	// Not on the first line
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 3, 3),
			false
		)
		sel.adjust(&s, .up)

		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 3
		assert sel.end_pin.y == 2
	}

	// On the first line
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 3, 0),
			false
		)
		sel.adjust(&s, .up)

		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 0
		assert sel.end_pin.y == 0
	}
}

// ============================================================
// Selection: adjust down
// ============================================================

fn test_selection_adjust_down() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A\nB\nC\nD\nE') or { assert false }

	// Not on the last line
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 3, 3),
			false
		)
		sel.adjust(&s, .down)

		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 3
		assert sel.end_pin.y == 4
	}

	// On the last line
	{
		mut sel := Selection.init(
			screen_pin(&s, 4, 1),
			screen_pin(&s, 3, 4),
			false
		)
		sel.adjust(&s, .down)

		assert sel.start_pin.x == 4
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 9
		assert sel.end_pin.y == 4
	}
}

// ============================================================
// Selection: adjust down with not full screen
// ============================================================

fn test_selection_adjust_down_not_full_screen() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A\nB\nC') or { assert false }

	// On the last line with text
	{
		mut sel := Selection.init(
			screen_pin(&s, 4, 1),
			screen_pin(&s, 3, 2),
			false
		)
		sel.adjust(&s, .down)

		// Start line
		assert sel.start_pin.x == 4
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 9
		assert sel.end_pin.y == 2
	}
}

// ============================================================
// Selection: adjust home
// ============================================================

fn test_selection_adjust_home() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A\nB\nC') or { assert false }

	{
		mut sel := Selection.init(
			screen_pin(&s, 4, 1),
			screen_pin(&s, 1, 2),
			false
		)
		sel.adjust(&s, .home)

		// Start line
		assert sel.start_pin.x == 4
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 0
		assert sel.end_pin.y == 0
	}
}

// ============================================================
// Selection: adjust end with not full screen
// ============================================================

fn test_selection_adjust_end_not_full_screen() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A\nB\nC') or { assert false }

	{
		mut sel := Selection.init(
			screen_pin(&s, 4, 0),
			screen_pin(&s, 1, 1),
			false
		)
		sel.adjust(&s, .end_)

		// Start line
		assert sel.start_pin.x == 4
		assert sel.start_pin.y == 0
		// end should be at last cell of last row with text
		assert sel.end_pin.y == 2
		assert sel.end_pin.x == u32(s.pages.screen_rows[int(sel.end_pin.y)].cells.len - 1)
	}
}

// ============================================================
// Selection: adjust beginning of line
// ============================================================

fn test_selection_adjust_beginning_of_line() {
	mut s := Screen.init(8, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A12 B34\nC12 D34') or { assert false }

	// Not at beginning of the line
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 5, 1),
			false
		)
		sel.adjust(&s, .beginning_of_line)

		// Start line
		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 0
		assert sel.end_pin.y == 1
	}

	// Already at beginning of the line
	{
		mut sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 0, 1),
			false
		)
		sel.adjust(&s, .beginning_of_line)

		// Start line
		assert sel.start_pin.x == 5
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 0
		assert sel.end_pin.y == 1
	}

	// End pin moves to start pin
	{
		mut sel := Selection.init(
			screen_pin(&s, 0, 1),
			screen_pin(&s, 5, 1),
			false
		)
		sel.adjust(&s, .beginning_of_line)

		// Start line
		assert sel.start_pin.x == 0
		assert sel.start_pin.y == 1
		assert sel.end_pin.x == 0
		assert sel.end_pin.y == 1
	}
}

// ============================================================
// Selection: adjust end of line
// ============================================================

fn test_selection_adjust_end_of_line() {
	mut s := Screen.init(8, 10, 0)
	defer {
		s.deinit()
	}
	s.test_write_string('A12 B34\nC12 D34') or { assert false }

	// Not at end of the line
	{
		mut sel := Selection.init(
			screen_pin(&s, 1, 0),
			screen_pin(&s, 1, 0),
			false
		)
		sel.adjust(&s, .end_of_line)

		assert sel.start_pin.x == 1
		assert sel.start_pin.y == 0
		assert sel.end_pin.x == 7
		assert sel.end_pin.y == 0
	}

	// Already at end of the line
	{
		mut sel := Selection.init(
			screen_pin(&s, 1, 0),
			screen_pin(&s, 7, 0),
			false
		)
		sel.adjust(&s, .end_of_line)

		assert sel.start_pin.x == 1
		assert sel.start_pin.y == 0
		assert sel.end_pin.x == 7
		assert sel.end_pin.y == 0
	}

	// End pin moves to start pin
	{
		mut sel := Selection.init(
			screen_pin(&s, 7, 0),
			screen_pin(&s, 1, 0),
			false
		)
		sel.adjust(&s, .end_of_line)

		// Start line
		assert sel.start_pin.x == 7
		assert sel.start_pin.y == 0
		assert sel.end_pin.x == 7
		assert sel.end_pin.y == 0
	}
}

// ============================================================
// Selection: order, standard
// ============================================================

fn test_selection_order_standard() {
	mut s := Screen.init(100, 100, 0)
	defer {
		s.deinit()
	}

	{
		// forward, multi-line
		sel := Selection.init(
			screen_pin(&s, 2, 1),
			screen_pin(&s, 2, 2),
			false
		)
		assert sel.order(&s) == .forward
	}
	{
		// reverse, multi-line
		sel := Selection.init(
			screen_pin(&s, 2, 2),
			screen_pin(&s, 2, 1),
			false
		)
		assert sel.order(&s) == .reverse
	}
	{
		// forward, same-line
		sel := Selection.init(
			screen_pin(&s, 2, 1),
			screen_pin(&s, 3, 1),
			false
		)
		assert sel.order(&s) == .forward
	}
	{
		// forward, single char
		sel := Selection.init(
			screen_pin(&s, 2, 1),
			screen_pin(&s, 2, 1),
			false
		)
		assert sel.order(&s) == .forward
	}
	{
		// reverse, single line
		sel := Selection.init(
			screen_pin(&s, 2, 1),
			screen_pin(&s, 1, 1),
			false
		)
		assert sel.order(&s) == .reverse
	}
}

// ============================================================
// Selection: order, rectangle
// ============================================================

fn test_selection_order_rectangle() {
	mut s := Screen.init(100, 100, 0)
	defer {
		s.deinit()
	}

	// Conventions:
	// TL - top left
	// BL - bottom left
	// TR - top right
	// BR - bottom right
	{
		// forward (TL -> BR)
		sel := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 2, 2),
			true
		)
		assert sel.order(&s) == .forward
	}
	{
		// reverse (BR -> TL)
		sel := Selection.init(
			screen_pin(&s, 2, 2),
			screen_pin(&s, 1, 1),
			true
		)
		assert sel.order(&s) == .reverse
	}
	{
		// mirrored_forward (TR -> BL)
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 3),
			true
		)
		assert sel.order(&s) == .mirrored_forward
	}
	{
		// mirrored_reverse (BL -> TR)
		sel := Selection.init(
			screen_pin(&s, 1, 3),
			screen_pin(&s, 3, 1),
			true
		)
		assert sel.order(&s) == .mirrored_reverse
	}
	{
		// forward, single line (left -> right)
		sel := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 3, 1),
			true
		)
		assert sel.order(&s) == .forward
	}
	{
		// reverse, single line (right -> left)
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 1),
			true
		)
		assert sel.order(&s) == .reverse
	}
	{
		// forward, single column (top -> bottom)
		sel := Selection.init(
			screen_pin(&s, 2, 1),
			screen_pin(&s, 2, 3),
			true
		)
		assert sel.order(&s) == .forward
	}
	{
		// reverse, single column (bottom -> top)
		sel := Selection.init(
			screen_pin(&s, 2, 3),
			screen_pin(&s, 2, 1),
			true
		)
		assert sel.order(&s) == .reverse
	}
	{
		// forward, single cell
		sel := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 1, 1),
			true
		)
		assert sel.order(&s) == .forward
	}
}

// ============================================================
// topLeft
// ============================================================

fn test_selection_top_left() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	{
		// forward
		sel := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 3, 1),
			true
		)
		tl := sel.top_left(&s)
		assert tl.x == 1
		assert tl.y == 1
	}
	{
		// reverse
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 1),
			true
		)
		tl := sel.top_left(&s)
		assert tl.x == 1
		assert tl.y == 1
	}
	{
		// mirrored_forward
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 3),
			true
		)
		tl := sel.top_left(&s)
		assert tl.x == 1
		assert tl.y == 1
	}
	{
		// mirrored_reverse
		sel := Selection.init(
			screen_pin(&s, 1, 3),
			screen_pin(&s, 3, 1),
			true
		)
		tl := sel.top_left(&s)
		assert tl.x == 1
		assert tl.y == 1
	}
}

// ============================================================
// bottomRight
// ============================================================

fn test_selection_bottom_right() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	{
		// forward
		sel := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 3, 1),
			false
		)
		br := sel.bottom_right(&s)
		assert br.x == 3
		assert br.y == 1
	}
	{
		// reverse
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 1),
			false
		)
		br := sel.bottom_right(&s)
		assert br.x == 3
		assert br.y == 1
	}
	{
		// mirrored_forward
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 3),
			true
		)
		br := sel.bottom_right(&s)
		assert br.x == 3
		assert br.y == 3
	}
	{
		// mirrored_reverse
		sel := Selection.init(
			screen_pin(&s, 1, 3),
			screen_pin(&s, 3, 1),
			true
		)
		br := sel.bottom_right(&s)
		assert br.x == 3
		assert br.y == 3
	}
}

// ============================================================
// ordered
// ============================================================

fn test_selection_ordered() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	{
		// forward
		sel := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 3, 1),
			false
		)
		sel_reverse := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 1),
			false
		)
		assert sel.ordered(&s, .forward).eql(sel)
		assert sel.ordered(&s, .reverse).eql(sel_reverse)
		assert sel.ordered(&s, .mirrored_forward).eql(sel)
	}
	{
		// reverse
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 1),
			false
		)
		sel_forward := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 3, 1),
			false
		)
		assert sel.ordered(&s, .forward).eql(sel_forward)
		assert sel.ordered(&s, .reverse).eql(sel)
		assert sel.ordered(&s, .mirrored_forward).eql(sel_forward)
	}
	{
		// mirrored_forward
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 1, 3),
			true
		)
		sel_forward := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 3, 3),
			true
		)
		sel_reverse := Selection.init(
			screen_pin(&s, 3, 3),
			screen_pin(&s, 1, 1),
			true
		)
		assert sel.ordered(&s, .forward).eql(sel_forward)
		assert sel.ordered(&s, .reverse).eql(sel_reverse)
		assert sel.ordered(&s, .mirrored_reverse).eql(sel_forward)
	}
	{
		// mirrored_reverse
		sel := Selection.init(
			screen_pin(&s, 1, 3),
			screen_pin(&s, 3, 1),
			true
		)
		sel_forward := Selection.init(
			screen_pin(&s, 1, 1),
			screen_pin(&s, 3, 3),
			true
		)
		sel_reverse := Selection.init(
			screen_pin(&s, 3, 3),
			screen_pin(&s, 1, 1),
			true
		)
		assert sel.ordered(&s, .forward).eql(sel_forward)
		assert sel.ordered(&s, .reverse).eql(sel_reverse)
		assert sel.ordered(&s, .mirrored_forward).eql(sel_forward)
	}
}

// ============================================================
// Selection: contains
// ============================================================

fn test_selection_contains() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	{
		sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 3, 2),
			false
		)

		assert sel.contains(&s, screen_pin(&s, 6, 1))
		assert sel.contains(&s, screen_pin(&s, 1, 2))
		assert !sel.contains(&s, screen_pin(&s, 1, 1))
		assert !sel.contains(&s, screen_pin(&s, 5, 2))
	}

	// Reverse
	{
		sel := Selection.init(
			screen_pin(&s, 3, 2),
			screen_pin(&s, 5, 1),
			false
		)

		assert sel.contains(&s, screen_pin(&s, 6, 1))
		assert sel.contains(&s, screen_pin(&s, 1, 2))
		assert !sel.contains(&s, screen_pin(&s, 1, 1))
		assert !sel.contains(&s, screen_pin(&s, 5, 2))
	}

	// Single line
	{
		sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 8, 1),
			false
		)

		assert sel.contains(&s, screen_pin(&s, 6, 1))
		assert !sel.contains(&s, screen_pin(&s, 2, 1))
		assert !sel.contains(&s, screen_pin(&s, 9, 1))
	}
}

// ============================================================
// Selection: contains, rectangle
// ============================================================

fn test_selection_contains_rectangle() {
	mut s := Screen.init(15, 15, 0)
	defer {
		s.deinit()
	}
	{
		sel := Selection.init(
			screen_pin(&s, 3, 3),
			screen_pin(&s, 7, 9),
			true
		)

		assert sel.contains(&s, screen_pin(&s, 5, 6)) // Center
		assert sel.contains(&s, screen_pin(&s, 3, 6)) // Left border
		assert sel.contains(&s, screen_pin(&s, 7, 6)) // Right border
		assert sel.contains(&s, screen_pin(&s, 5, 3)) // Top border
		assert sel.contains(&s, screen_pin(&s, 5, 9)) // Bottom border

		assert !sel.contains(&s, screen_pin(&s, 5, 2)) // Above center
		assert !sel.contains(&s, screen_pin(&s, 5, 10)) // Below center
		assert !sel.contains(&s, screen_pin(&s, 2, 6)) // Left center
		assert !sel.contains(&s, screen_pin(&s, 8, 6)) // Right center
		assert !sel.contains(&s, screen_pin(&s, 8, 3)) // Just right of top right
		assert !sel.contains(&s, screen_pin(&s, 2, 9)) // Just left of bottom left
	}

	// Reverse
	{
		sel := Selection.init(
			screen_pin(&s, 7, 9),
			screen_pin(&s, 3, 3),
			true
		)

		assert sel.contains(&s, screen_pin(&s, 5, 6)) // Center
		assert sel.contains(&s, screen_pin(&s, 3, 6)) // Left border
		assert sel.contains(&s, screen_pin(&s, 7, 6)) // Right border
		assert sel.contains(&s, screen_pin(&s, 5, 3)) // Top border
		assert sel.contains(&s, screen_pin(&s, 5, 9)) // Bottom border

		assert !sel.contains(&s, screen_pin(&s, 5, 2)) // Above center
		assert !sel.contains(&s, screen_pin(&s, 5, 10)) // Below center
		assert !sel.contains(&s, screen_pin(&s, 2, 6)) // Left center
		assert !sel.contains(&s, screen_pin(&s, 8, 6)) // Right center
		assert !sel.contains(&s, screen_pin(&s, 8, 3)) // Just right of top right
		assert !sel.contains(&s, screen_pin(&s, 2, 9)) // Just left of bottom left
	}

	// Single line
	// NOTE: This is the same as normal selection but we just do it for brevity
	{
		sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 10, 1),
			true
		)

		assert sel.contains(&s, screen_pin(&s, 6, 1))
		assert !sel.contains(&s, screen_pin(&s, 2, 1))
		assert !sel.contains(&s, screen_pin(&s, 12, 1))
	}
}

// ============================================================
// Selection: containedRow
// ============================================================

fn test_selection_contained_row() {
	mut s := Screen.init(10, 5, 0)
	defer {
		s.deinit()
	}

	{
		sel := Selection.init(
			screen_pin(&s, 5, 1),
			screen_pin(&s, 3, 3),
			false
		)

		// Not contained
		assert sel.contained_row(&s, screen_pin(&s, 1, 4)) == none

		// Start line
		start_row := sel.contained_row(&s, screen_pin(&s, 1, 1)) or {
			assert false
			return
		}
		assert start_row.eql(Selection.init(
			sel.start_pin,
			Pin{ x: s.pages.cols - 1, y: 1 },
			false
		))

		// End line
		end_row := sel.contained_row(&s, screen_pin(&s, 2, 3)) or {
			assert false
			return
		}
		assert end_row.eql(Selection.init(
			Pin{ x: 0, y: 3 },
			sel.end_pin,
			false
		))

		// Middle line
		mid_row := sel.contained_row(&s, screen_pin(&s, 2, 2)) or {
			assert false
			return
		}
		assert mid_row.eql(Selection.init(
			Pin{ x: 0, y: 2 },
			Pin{ x: s.pages.cols - 1, y: 2 },
			false
		))
	}

	// Rectangle
	{
		sel := Selection.init(
			screen_pin(&s, 3, 1),
			screen_pin(&s, 6, 3),
			true
		)

		// Not contained
		assert sel.contained_row(&s, screen_pin(&s, 1, 4)) == none

		// Start line
		start_row := sel.contained_row(&s, screen_pin(&s, 1, 1)) or {
			assert false
			return
		}
		assert start_row.eql(Selection.init(
			Pin{ x: 3, y: 1 },
			Pin{ x: 6, y: 1 },
			true
		))

		// End line
		end_row := sel.contained_row(&s, screen_pin(&s, 2, 3)) or {
			assert false
			return
		}
		assert end_row.eql(Selection.init(
			Pin{ x: 3, y: 3 },
			Pin{ x: 6, y: 3 },
			true
		))

		// Middle line
		mid_row := sel.contained_row(&s, screen_pin(&s, 2, 2)) or {
			assert false
			return
		}
		assert mid_row.eql(Selection.init(
			Pin{ x: 3, y: 2 },
			Pin{ x: 6, y: 2 },
			true
		))
	}

	// Single-line selection
	{
		sel := Selection.init(
			screen_pin(&s, 2, 1),
			screen_pin(&s, 6, 1),
			false
		)

		// Not contained
		assert sel.contained_row(&s, screen_pin(&s, 1, 0)) == none
		assert sel.contained_row(&s, screen_pin(&s, 1, 2)) == none

		// Contained
		row := sel.contained_row(&s, screen_pin(&s, 1, 1)) or {
			assert false
			return
		}
		assert row.eql(sel)
	}
}

// ============================================================
// Selection: eql
// ============================================================

fn test_selection_eql() {
	mut s := Screen.init(10, 10, 0)
	defer {
		s.deinit()
	}
	sel1 := Selection.init(
		screen_pin(&s, 1, 1),
		screen_pin(&s, 3, 3),
		false
	)
	sel2 := Selection.init(
		screen_pin(&s, 1, 1),
		screen_pin(&s, 3, 3),
		false
	)
	sel3 := Selection.init(
		screen_pin(&s, 2, 1),
		screen_pin(&s, 3, 3),
		false
	)
	sel4 := Selection.init(
		screen_pin(&s, 1, 1),
		screen_pin(&s, 3, 3),
		true
	)

	assert sel1.eql(sel2)
	assert !sel1.eql(sel3)
	assert !sel1.eql(sel4)
}
