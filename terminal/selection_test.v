module terminal

// Tests for Selection, translated from Ghostty's Selection.zig.

// Ghostty: s.pages.pin(.{ .screen = .{ .x = x, .y = y } }).?
fn sel_test_pin(s &Screen, x u16, y u32) Pin {
	return s.pages.pin(Point.new(.screen, Coordinate{ x: x, y: y })) or {
		panic('pin(.screen, ${x}, ${y}) returned none')
	}
}

// Ghostty: s.pages.pointFromPin(.screen, p).?
fn sel_test_point(s &Screen, p Pin) Point {
	return s.pages.point_from_pin(.screen, p) or {
		panic('point_from_pin(.screen) returned none')
	}
}

// Ghostty: point.Point{ .screen = .{ .x = x, .y = y } }
fn sel_test_screen_point(x u16, y u32) Point {
	return Point.new(.screen, Coordinate{ x: x, y: y })
}

// Ghostty: testing.expectEqual(expected, actual) on two Selection values,
// which compares the bounds union tag, both pins field by field, and the
// rectangle flag.
fn sel_test_expect_equal(expected Selection, actual Selection) {
	assert expected.tracked() == actual.tracked()
	assert voidptr(expected.start().node) == voidptr(actual.start().node)
	assert expected.start().y == actual.start().y
	assert expected.start().x == actual.start().x
	assert expected.start().garbage == actual.start().garbage
	assert voidptr(expected.end().node) == voidptr(actual.end().node)
	assert expected.end().y == actual.end().y
	assert expected.end().x == actual.end().x
	assert expected.end().garbage == actual.end().garbage
	assert expected.rectangle == actual.rectangle
}

fn test_selection_adjust_right() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A1234\nB5678\nC1234\nD5678') or { panic(err) }

	// Simple movement right
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 3, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .right)

		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(4, 3) == sel_test_point(&s, sel.end())
	}

	// Already at end of the line.
	{
		mut sel := Selection.init(sel_test_pin(&s, 4, 1), sel_test_pin(&s, 4, 2), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .right)

		assert sel_test_screen_point(4, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(0, 3) == sel_test_point(&s, sel.end())
	}

	// Already at end of the screen
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 4, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .right)

		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(4, 3) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_left() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A1234\nB5678\nC1234\nD5678') or { panic(err) }

	// Simple movement left
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 3, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .left)

		// Start line
		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(2, 3) == sel_test_point(&s, sel.end())
	}

	// Already at beginning of the line.
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 0, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .left)

		// Start line
		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(4, 2) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_left_skips_blanks() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A1234\nB5678\nC12\nD56') or { panic(err) }

	// Same line
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 4, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .left)

		// Start line
		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(2, 3) == sel_test_point(&s, sel.end())
	}

	// Edge
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 0, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .left)

		// Start line
		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(2, 2) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_up() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A\nB\nC\nD\nE') or { panic(err) }

	// Not on the first line
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 3, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .up)

		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(3, 2) == sel_test_point(&s, sel.end())
	}

	// On the first line
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 3, 0), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .up)

		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(0, 0) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_down() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A\nB\nC\nD\nE') or { panic(err) }

	// Not on the first line
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 3, 3), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .down)

		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(3, 4) == sel_test_point(&s, sel.end())
	}

	// On the last line
	{
		mut sel := Selection.init(sel_test_pin(&s, 4, 1), sel_test_pin(&s, 3, 4), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .down)

		assert sel_test_screen_point(4, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(9, 4) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_down_with_not_full_screen() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A\nB\nC') or { panic(err) }

	// On the last line
	{
		mut sel := Selection.init(sel_test_pin(&s, 4, 1), sel_test_pin(&s, 3, 2), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .down)

		// Start line
		assert sel_test_screen_point(4, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(9, 2) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_home() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A\nB\nC') or { panic(err) }

	// On the last line
	{
		mut sel := Selection.init(sel_test_pin(&s, 4, 1), sel_test_pin(&s, 1, 2), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .home)

		// Start line
		assert sel_test_screen_point(4, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(0, 0) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_end_with_not_full_screen() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A\nB\nC') or { panic(err) }

	// On the last line
	{
		mut sel := Selection.init(sel_test_pin(&s, 4, 0), sel_test_pin(&s, 1, 1), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .end_)

		// Start line
		assert sel_test_screen_point(4, 0) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(9, 2) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_beginning_of_line() {
	mut s := Screen.init(8, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A12 B34\nC12 D34') or { panic(err) }

	// Not at beginning of the line
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 5, 1), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .beginning_of_line)

		// Start line
		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(0, 1) == sel_test_point(&s, sel.end())
	}

	// Already at beginning of the line
	{
		mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 0, 1), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .beginning_of_line)

		// Start line
		assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(0, 1) == sel_test_point(&s, sel.end())
	}

	// End pin moves to start pin
	{
		mut sel := Selection.init(sel_test_pin(&s, 0, 1), sel_test_pin(&s, 5, 1), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .beginning_of_line)

		// Start line
		assert sel_test_screen_point(0, 1) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(0, 1) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_adjust_end_of_line() {
	mut s := Screen.init(8, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A12 B34\nC12 D34') or { panic(err) }

	// Not at end of the line
	{
		mut sel := Selection.init(sel_test_pin(&s, 1, 0), sel_test_pin(&s, 1, 0), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .end_of_line)

		assert sel_test_screen_point(1, 0) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(7, 0) == sel_test_point(&s, sel.end())
	}

	// Already at end of the line
	{
		mut sel := Selection.init(sel_test_pin(&s, 1, 0), sel_test_pin(&s, 7, 0), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .end_of_line)

		assert sel_test_screen_point(1, 0) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(7, 0) == sel_test_point(&s, sel.end())
	}

	// End pin moves to start pin
	{
		mut sel := Selection.init(sel_test_pin(&s, 7, 0), sel_test_pin(&s, 1, 0), false)
		defer { sel.deinit(mut s) }
		sel.adjust(&s, .end_of_line)

		// Start line
		assert sel_test_screen_point(7, 0) == sel_test_point(&s, sel.start())
		assert sel_test_screen_point(7, 0) == sel_test_point(&s, sel.end())
	}
}

fn test_selection_order_standard() {
	mut s := Screen.init(100, 100, 1)
	defer { s.deinit() }

	{
		// forward, multi-line
		sel := Selection.init(sel_test_pin(&s, 2, 1), sel_test_pin(&s, 2, 2), false)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .forward
	}
	{
		// reverse, multi-line
		sel := Selection.init(sel_test_pin(&s, 2, 2), sel_test_pin(&s, 2, 1), false)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .reverse
	}
	{
		// forward, same-line
		sel := Selection.init(sel_test_pin(&s, 2, 1), sel_test_pin(&s, 3, 1), false)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .forward
	}
	{
		// forward, single char
		sel := Selection.init(sel_test_pin(&s, 2, 1), sel_test_pin(&s, 2, 1), false)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .forward
	}
	{
		// reverse, single line
		sel := Selection.init(sel_test_pin(&s, 2, 1), sel_test_pin(&s, 1, 1), false)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .reverse
	}
}

fn test_selection_order_rectangle() {
	mut s := Screen.init(100, 100, 1)
	defer { s.deinit() }

	// Conventions:
	// TL - top left
	// BL - bottom left
	// TR - top right
	// BR - bottom right
	{
		// forward (TL -> BR)
		sel := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 2, 2), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .forward
	}
	{
		// reverse (BR -> TL)
		sel := Selection.init(sel_test_pin(&s, 2, 2), sel_test_pin(&s, 1, 1), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .reverse
	}
	{
		// mirrored_forward (TR -> BL)
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 3), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .mirrored_forward
	}
	{
		// mirrored_reverse (BL -> TR)
		sel := Selection.init(sel_test_pin(&s, 1, 3), sel_test_pin(&s, 3, 1), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .mirrored_reverse
	}
	{
		// forward, single line (left -> right )
		sel := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 1), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .forward
	}
	{
		// reverse, single line (right -> left)
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 1), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .reverse
	}
	{
		// forward, single column (top -> bottom)
		sel := Selection.init(sel_test_pin(&s, 2, 1), sel_test_pin(&s, 2, 3), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .forward
	}
	{
		// reverse, single column (bottom -> top)
		sel := Selection.init(sel_test_pin(&s, 2, 3), sel_test_pin(&s, 2, 1), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .reverse
	}
	{
		// forward, single cell
		sel := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 1, 1), true)
		defer { sel.deinit(mut s) }

		assert sel.order(&s) == .forward
	}
}

fn test_top_left() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	{
		// forward
		sel := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 1), true)
		defer { sel.deinit(mut s) }
		tl := sel.top_left(&s)
		assert sel_test_screen_point(1, 1) == sel_test_point(&s, tl)
	}
	{
		// reverse
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 1), true)
		defer { sel.deinit(mut s) }
		tl := sel.top_left(&s)
		assert sel_test_screen_point(1, 1) == sel_test_point(&s, tl)
	}
	{
		// mirrored_forward
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 3), true)
		defer { sel.deinit(mut s) }
		tl := sel.top_left(&s)
		assert sel_test_screen_point(1, 1) == sel_test_point(&s, tl)
	}
	{
		// mirrored_reverse
		sel := Selection.init(sel_test_pin(&s, 1, 3), sel_test_pin(&s, 3, 1), true)
		defer { sel.deinit(mut s) }
		tl := sel.top_left(&s)
		assert sel_test_screen_point(1, 1) == sel_test_point(&s, tl)
	}
}

fn test_bottom_right() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	{
		// forward
		sel := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 1), false)
		defer { sel.deinit(mut s) }
		br := sel.bottom_right(&s)
		assert sel_test_screen_point(3, 1) == sel_test_point(&s, br)
	}
	{
		// reverse
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 1), false)
		defer { sel.deinit(mut s) }
		br := sel.bottom_right(&s)
		assert sel_test_screen_point(3, 1) == sel_test_point(&s, br)
	}
	{
		// mirrored_forward
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 3), true)
		defer { sel.deinit(mut s) }
		br := sel.bottom_right(&s)
		assert sel_test_screen_point(3, 3) == sel_test_point(&s, br)
	}
	{
		// mirrored_reverse
		sel := Selection.init(sel_test_pin(&s, 1, 3), sel_test_pin(&s, 3, 1), true)
		defer { sel.deinit(mut s) }
		br := sel.bottom_right(&s)
		assert sel_test_screen_point(3, 3) == sel_test_point(&s, br)
	}
}

fn test_ordered() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	{
		// forward
		sel := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 1), false)
		sel_reverse := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 1), false)
		assert sel.ordered(&s, .forward).eql(sel)
		assert sel.ordered(&s, .reverse).eql(sel_reverse)
		assert sel.ordered(&s, .mirrored_forward).eql(sel)
	}
	{
		// reverse
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 1), false)
		sel_forward := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 1), false)
		assert sel.ordered(&s, .forward).eql(sel_forward)
		assert sel.ordered(&s, .reverse).eql(sel)
		assert sel.ordered(&s, .mirrored_forward).eql(sel_forward)
	}
	{
		// mirrored_forward
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 1, 3), true)
		sel_forward := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 3), true)
		sel_reverse := Selection.init(sel_test_pin(&s, 3, 3), sel_test_pin(&s, 1, 1), true)
		assert sel.ordered(&s, .forward).eql(sel_forward)
		assert sel.ordered(&s, .reverse).eql(sel_reverse)
		assert sel.ordered(&s, .mirrored_reverse).eql(sel_forward)
	}
	{
		// mirrored_reverse
		sel := Selection.init(sel_test_pin(&s, 1, 3), sel_test_pin(&s, 3, 1), true)
		sel_forward := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 3), true)
		sel_reverse := Selection.init(sel_test_pin(&s, 3, 3), sel_test_pin(&s, 1, 1), true)
		assert sel.ordered(&s, .forward).eql(sel_forward)
		assert sel.ordered(&s, .reverse).eql(sel_reverse)
		assert sel.ordered(&s, .mirrored_forward).eql(sel_forward)
	}
}

fn test_selection_contains() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }
	{
		sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 3, 2), false)

		assert sel.contains(&s, sel_test_pin(&s, 6, 1))
		assert sel.contains(&s, sel_test_pin(&s, 1, 2))
		assert !sel.contains(&s, sel_test_pin(&s, 1, 1))
		assert !sel.contains(&s, sel_test_pin(&s, 5, 2))
	}

	// Reverse
	{
		sel := Selection.init(sel_test_pin(&s, 3, 2), sel_test_pin(&s, 5, 1), false)

		assert sel.contains(&s, sel_test_pin(&s, 6, 1))
		assert sel.contains(&s, sel_test_pin(&s, 1, 2))
		assert !sel.contains(&s, sel_test_pin(&s, 1, 1))
		assert !sel.contains(&s, sel_test_pin(&s, 5, 2))
	}

	// Single line
	{
		sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 8, 1), false)

		assert sel.contains(&s, sel_test_pin(&s, 6, 1))
		assert !sel.contains(&s, sel_test_pin(&s, 2, 1))
		assert !sel.contains(&s, sel_test_pin(&s, 9, 1))
	}
}

fn test_selection_contains_rectangle() {
	mut s := Screen.init(15, 15, 0)
	defer { s.deinit() }
	{
		sel := Selection.init(sel_test_pin(&s, 3, 3), sel_test_pin(&s, 7, 9), true)

		assert sel.contains(&s, sel_test_pin(&s, 5, 6)) // Center
		assert sel.contains(&s, sel_test_pin(&s, 3, 6)) // Left border
		assert sel.contains(&s, sel_test_pin(&s, 7, 6)) // Right border
		assert sel.contains(&s, sel_test_pin(&s, 5, 3)) // Top border
		assert sel.contains(&s, sel_test_pin(&s, 5, 9)) // Bottom border

		assert !sel.contains(&s, sel_test_pin(&s, 5, 2)) // Above center
		assert !sel.contains(&s, sel_test_pin(&s, 5, 10)) // Below center
		assert !sel.contains(&s, sel_test_pin(&s, 2, 6)) // Left center
		assert !sel.contains(&s, sel_test_pin(&s, 8, 6)) // Right center
		assert !sel.contains(&s, sel_test_pin(&s, 8, 3)) // Just right of top right
		assert !sel.contains(&s, sel_test_pin(&s, 2, 9)) // Just left of bottom left
	}

	// Reverse
	{
		sel := Selection.init(sel_test_pin(&s, 7, 9), sel_test_pin(&s, 3, 3), true)

		assert sel.contains(&s, sel_test_pin(&s, 5, 6)) // Center
		assert sel.contains(&s, sel_test_pin(&s, 3, 6)) // Left border
		assert sel.contains(&s, sel_test_pin(&s, 7, 6)) // Right border
		assert sel.contains(&s, sel_test_pin(&s, 5, 3)) // Top border
		assert sel.contains(&s, sel_test_pin(&s, 5, 9)) // Bottom border

		assert !sel.contains(&s, sel_test_pin(&s, 5, 2)) // Above center
		assert !sel.contains(&s, sel_test_pin(&s, 5, 10)) // Below center
		assert !sel.contains(&s, sel_test_pin(&s, 2, 6)) // Left center
		assert !sel.contains(&s, sel_test_pin(&s, 8, 6)) // Right center
		assert !sel.contains(&s, sel_test_pin(&s, 8, 3)) // Just right of top right
		assert !sel.contains(&s, sel_test_pin(&s, 2, 9)) // Just left of bottom left
	}

	// Single line
	// NOTE: This is the same as normal selection but we just do it for brevity
	{
		sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 10, 1), true)

		assert sel.contains(&s, sel_test_pin(&s, 6, 1))
		assert !sel.contains(&s, sel_test_pin(&s, 2, 1))
		assert !sel.contains(&s, sel_test_pin(&s, 12, 1))
	}
}

fn test_selection_contained_row() {
	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }

	{
		sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 3, 3), false)

		// Not contained
		assert sel.contained_row(&s, sel_test_pin(&s, 1, 4)) == none

		// Start line
		sel_test_expect_equal(Selection.init(sel.start(), sel_test_pin(&s, s.pages.cols - 1,
			1), false), sel.contained_row(&s, sel_test_pin(&s, 1, 1)) or {
			panic('contained_row returned none')
		})

		// End line
		sel_test_expect_equal(Selection.init(sel_test_pin(&s, 0, 3), sel.end(), false),
			sel.contained_row(&s, sel_test_pin(&s, 2, 3)) or {
			panic('contained_row returned none')
		})

		// Middle line
		sel_test_expect_equal(Selection.init(sel_test_pin(&s, 0, 2), sel_test_pin(&s,
			s.pages.cols - 1, 2), false), sel.contained_row(&s, sel_test_pin(&s, 2, 2)) or {
			panic('contained_row returned none')
		})
	}

	// Rectangle
	{
		sel := Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 6, 3), true)

		// Not contained
		assert sel.contained_row(&s, sel_test_pin(&s, 1, 4)) == none

		// Start line
		sel_test_expect_equal(Selection.init(sel_test_pin(&s, 3, 1), sel_test_pin(&s, 6, 1),
			true), sel.contained_row(&s, sel_test_pin(&s, 1, 1)) or {
			panic('contained_row returned none')
		})

		// End line
		sel_test_expect_equal(Selection.init(sel_test_pin(&s, 3, 3), sel_test_pin(&s, 6, 3),
			true), sel.contained_row(&s, sel_test_pin(&s, 2, 3)) or {
			panic('contained_row returned none')
		})

		// Middle line
		sel_test_expect_equal(Selection.init(sel_test_pin(&s, 3, 2), sel_test_pin(&s, 6, 2),
			true), sel.contained_row(&s, sel_test_pin(&s, 2, 2)) or {
			panic('contained_row returned none')
		})
	}

	// Single-line selection
	{
		sel := Selection.init(sel_test_pin(&s, 2, 1), sel_test_pin(&s, 6, 1), false)

		// Not contained
		assert sel.contained_row(&s, sel_test_pin(&s, 1, 0)) == none
		assert sel.contained_row(&s, sel_test_pin(&s, 1, 2)) == none

		// Contained
		sel_test_expect_equal(sel, sel.contained_row(&s, sel_test_pin(&s, 1, 1)) or {
			panic('contained_row returned none')
		})
	}
}

// ============================================================
// Witty-only tests (no direct Selection.zig counterpart)
// ============================================================

// SelectionOrder and SelectionAdjustment keep Zig's declaration order and
// one-byte backing type.
fn test_selection_enum_source_layouts() {
	assert sizeof(SelectionOrder) == 1
	assert u8(SelectionOrder.forward) == 0
	assert u8(SelectionOrder.reverse) == 1
	assert u8(SelectionOrder.mirrored_forward) == 2
	assert u8(SelectionOrder.mirrored_reverse) == 3

	assert sizeof(SelectionAdjustment) == 1
	assert u8(SelectionAdjustment.left) == 0
	assert u8(SelectionAdjustment.right) == 1
	assert u8(SelectionAdjustment.up) == 2
	assert u8(SelectionAdjustment.down) == 3
	assert u8(SelectionAdjustment.home) == 4
	assert u8(SelectionAdjustment.end_) == 5
	assert u8(SelectionAdjustment.page_up) == 6
	assert u8(SelectionAdjustment.page_down) == 7
	assert u8(SelectionAdjustment.beginning_of_line) == 8
	assert u8(SelectionAdjustment.end_of_line) == 9
}

// eql, start/end pointer access, and track/deinit bookkeeping of the pins
// registered with the page list.
fn test_selection_bounds_access_tracking_and_equality() {
	mut s := Screen.init(10, 10, 0)
	defer { s.deinit() }

	mut sel := Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 3), false)
	assert !sel.tracked()
	assert sel.eql(Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 3), false))
	assert !sel.eql(Selection.init(sel_test_pin(&s, 2, 1), sel_test_pin(&s, 3, 3), false))
	assert !sel.eql(Selection.init(sel_test_pin(&s, 1, 1), sel_test_pin(&s, 3, 3), true))

	mut untracked_start := sel.start_ptr()
	untracked_start.x = 2
	mut untracked_end := sel.end_ptr()
	untracked_end.x = 4
	assert sel_test_screen_point(2, 1) == sel_test_point(&s, sel.start())
	assert sel_test_screen_point(4, 3) == sel_test_point(&s, sel.end())

	base_tracked := s.pages.count_tracked_pins()
	mut tracked := sel.track(mut s)
	assert tracked.tracked()
	assert s.pages.count_tracked_pins() == base_tracked + 2
	mut tracked_start := tracked.start_ptr()
	tracked_start.x = 5
	mut tracked_end := tracked.end_ptr()
	tracked_end.x = 6
	assert sel_test_screen_point(5, 1) == sel_test_point(&s, tracked.start())
	assert sel_test_screen_point(6, 3) == sel_test_point(&s, tracked.end())

	// Resetting the page list keeps tracked pins alive but marks them
	// garbage and moves them to the top-left.
	s.reset()
	assert tracked.start().garbage
	assert tracked.end().garbage
	assert sel_test_screen_point(0, 0) == sel_test_point(&s, tracked.start())
	assert sel_test_screen_point(0, 0) == sel_test_point(&s, tracked.end())
	tracked.deinit(mut s)
	assert s.pages.count_tracked_pins() == base_tracked
}

// Line, absolute, and page adjustments applied in sequence. Selection.zig
// has no page_up/page_down test; with no scrollback both fall back to
// home/end.
fn test_selection_adjust_absolute_and_page() {
	mut s := Screen.init(8, 10, 0)
	defer { s.deinit() }
	s.test_write_string('A12 B34\nC12 D34\nE') or { panic(err) }

	mut sel := Selection.init(sel_test_pin(&s, 5, 1), sel_test_pin(&s, 5, 1), false)
	defer { sel.deinit(mut s) }
	sel.adjust(&s, .beginning_of_line)
	assert sel_test_screen_point(0, 1) == sel_test_point(&s, sel.end())
	sel.adjust(&s, .end_of_line)
	assert sel_test_screen_point(7, 1) == sel_test_point(&s, sel.end())
	sel.adjust(&s, .home)
	assert sel_test_screen_point(0, 0) == sel_test_point(&s, sel.end())
	sel.adjust(&s, .end_)
	assert sel_test_screen_point(7, 2) == sel_test_point(&s, sel.end())

	sel.adjust(&s, .page_up)
	assert sel_test_screen_point(0, 0) == sel_test_point(&s, sel.end())
	sel.adjust(&s, .page_down)
	assert sel_test_screen_point(7, 2) == sel_test_point(&s, sel.end())
	assert sel_test_screen_point(5, 1) == sel_test_point(&s, sel.start())
}
