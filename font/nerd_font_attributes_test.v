module font

// Test that a known single codepoint returns the correct constraint.
fn test_get_constraint_single_codepoint() {
	c := get_constraint(0x2630) or {
		assert false, 'expected constraint for 0x2630'
		return
	}
	assert c.size == .cover
	assert c.height == .icon
	assert c.max_constraint_width == 1
	assert c.align_horizontal == .center1
	assert c.align_vertical == .center1
	assert c.pad_left == 0.05
	assert c.pad_right == 0.05
	assert c.pad_top == 0.05
	assert c.pad_bottom == 0.05
}

// Test that a codepoint in a range returns the correct constraint.
fn test_get_constraint_range() {
	c := get_constraint(0x276c) or {
		assert false, 'expected constraint for 0x276c'
		return
	}
	assert c.size == .cover
	assert c.max_constraint_width == 1
	assert c.relative_width == 0.7142857142857143
	assert c.pad_top == 0.15
	assert c.pad_bottom == 0.15

	// End of range should also match.
	c2 := get_constraint(0x276d) or {
		assert false, 'expected constraint for 0x276d'
		return
	}
	assert c2.size == .cover
	assert c2.relative_width == 0.7142857142857143
}

// Test a powerline symbol with stretch size.
fn test_get_constraint_powerline_stretch() {
	c := get_constraint(0xe0b0) or {
		assert false, 'expected constraint for 0xe0b0'
		return
	}
	assert c.size == .stretch
	assert c.max_constraint_width == 1
	assert c.align_horizontal == .start
	assert c.align_vertical == .center1
	assert c.pad_left == -0.03
	assert c.pad_right == -0.03
	assert c.pad_top == -0.005
	assert c.pad_bottom == -0.005
	assert c.max_xy_ratio == 0.7
}

// Test multi-codepoint arm (0xe0a0...0xe0a3 and 0xe0cf share constraint).
fn test_get_constraint_multi_codepoint() {
	c1 := get_constraint(0xe0a0) or {
		assert false, 'expected constraint for 0xe0a0'
		return
	}
	assert c1.size == .fit_cover1
	assert c1.align_horizontal == .center1

	c2 := get_constraint(0xe0a3) or {
		assert false, 'expected constraint for 0xe0a3'
		return
	}
	assert c2.size == .fit_cover1

	c3 := get_constraint(0xe0cf) or {
		assert false, 'expected constraint for 0xe0cf'
		return
	}
	assert c3.size == .fit_cover1
}

// Test that an unknown codepoint returns none.
fn test_get_constraint_unknown_returns_none() {
	result := get_constraint(0x0041) // 'A' - not a nerd font glyph
	assert result == none
}

// Test the last entry in the table (0xf4f1).
fn test_get_constraint_last_entry() {
	c := get_constraint(0xf4f1) or {
		assert false, 'expected constraint for 0xf4f1'
		return
	}
	assert c.size == .fit_cover1
	assert c.height == .icon
	assert c.align_horizontal == .center1
	assert c.align_vertical == .center1
	assert c.relative_width == 0.9642857142857143
	assert c.relative_height == 0.7407407407407407
}

// Test Constraint.does_anything().
fn test_constraint_does_anything() {
	// Default constraint does nothing.
	c := constraint_none
	assert c.does_anything() == false

	// A constraint with size set does something.
	c2 := Constraint{
		size: .fit
	}
	assert c2.does_anything() == true

	// A constraint with only alignment does something.
	c3 := Constraint{
		align_horizontal: .center
	}
	assert c3.does_anything() == true
}

// Test a codepoint just outside a range returns none.
fn test_get_constraint_boundary() {
	// 0x276b is just before the 0x276c...0x276d range.
	result := get_constraint(0x276b)
	assert result == none
}
