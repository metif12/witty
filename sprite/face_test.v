module sprite

// Tests for the sprite Face codepoint dispatch, translated from the
// behavior of ghostty's src/font/sprite/Face.zig:
//   - getDrawFn  -> get_draw_fn   (range dispatch + special sprites)
//   - hasCodepoint -> has_codepoint
//
// Ghostty's Face.zig has a single unit test ("sprite face render all
// sprites") which is a PNG golden-atlas regression test and is not
// portable, so it is intentionally not translated. These tests instead
// verify the pure dispatch logic (which codepoint maps to which draw
// function, and which codepoints are covered at all) that ghostty builds
// at comptime from its `ranges` table and `Sprite` enum.

import sprite_types as font

fn new_face() SpriteFace {
	return SpriteFace{
		metrics: font.default_grid_metrics(8, 16)
	}
}

// draw_fn_is_none reports whether get_draw_fn returns no function for
// the given codepoint. (V generates invalid C for a direct `== none`
// comparison on an optional function-pointer value, so we branch on the
// optional with an `or` block instead.)
fn draw_fn_is_none(cp u32) bool {
	get_draw_fn(cp) or { return true }
	return false
}

// ------------------------------------------------------------
// has_codepoint: codepoints inside sprite ranges are covered.
// ------------------------------------------------------------

fn test_has_codepoint_covered_ranges() {
	f := new_face()
	covered := [
		u32(0x2500), // box drawing (min)
		0x257f, // box drawing (max)
		0x2580, // block elements (min)
		0x259f, // block elements (max)
		0x2800, // braille (min)
		0x28ff, // braille (max)
		0x25e2, // geometric shapes
		0x25e5,
		0x25f8,
		0x25fa,
		0x25ff,
		0xe0b0, // powerline
		0xe0bf,
		0xe0d2,
		0xe0d4,
		0xf5d0, // branch drawing (min)
		0xf60d, // branch drawing (max)
		0x1fb00, // legacy computing (min)
		0x1fbef, // circles (max in that block)
		0x1cd00, // octants (min)
		0x1cde5, // octants (max)
		0x1ce90, // sixteenth blocks (min)
		0x1ceaf, // sixteenth blocks (max)
	]
	for cp in covered {
		assert f.has_codepoint(cp), 'expected codepoint 0x${cp:x} to be covered'
	}
}

// ------------------------------------------------------------
// has_codepoint: codepoints outside all ranges are not covered.
// ------------------------------------------------------------

fn test_has_codepoint_uncovered() {
	f := new_face()
	uncovered := [
		u32(0x0041), // 'A'
		0x24ff, // just below box drawing
		0x25a0, // gap between block elements and geometric shapes
		0x25e1, // just below geometric shapes 0x25e2
		0x25e6, // just above geometric shapes 0x25e5
		0x2600, // miscellaneous symbols, no sprite
		0xe0af, // just below powerline 0xe0b0
		0xf5cf, // just below branch drawing
		0xf60e, // just above branch drawing
		0x10ffff, // max unicode, below sprite.start, in no range
	]
	for cp in uncovered {
		assert !f.has_codepoint(cp), 'expected codepoint 0x${cp:x} to be uncovered'
	}
}

// ------------------------------------------------------------
// has_codepoint is independent of presentation; presentation filtering is
// performed by the font resolver.
// ------------------------------------------------------------

fn test_has_codepoint_ignores_presentation() {
	f := new_face()
	assert f.has_codepoint(0x2500)
	assert !f.has_codepoint(0x0041)
}

// ------------------------------------------------------------
// get_draw_fn returns the correct function for each range.
// V supports function value equality, so we can assert the exact
// dispatch target for representative codepoints.
// ------------------------------------------------------------

fn test_get_draw_fn_box_range() {
	// Every codepoint in 0x2500..0x257f dispatches to draw_2500_257f.
	for cp in [u32(0x2500), 0x2540, 0x257f] {
		fn_ := get_draw_fn(cp) or { panic('expected draw fn for 0x${cp:x}') }
		assert fn_ == DrawFn(draw_2500_257f)
	}
}

fn test_get_draw_fn_block_range() {
	for cp in [u32(0x2580), 0x2590, 0x259f] {
		fn_ := get_draw_fn(cp) or { panic('expected draw fn for 0x${cp:x}') }
		assert fn_ == DrawFn(draw_2580_259f)
	}
}

fn test_get_draw_fn_braille_range() {
	for cp in [u32(0x2800), 0x2850, 0x28ff] {
		fn_ := get_draw_fn(cp) or { panic('expected draw fn for 0x${cp:x}') }
		assert fn_ == DrawFn(draw_2800_28ff)
	}
}

fn test_get_draw_fn_geometric_range() {
	for cp in [u32(0x25e2), 0x25e5] {
		fn_ := get_draw_fn(cp) or { panic('expected draw fn for 0x${cp:x}') }
		assert fn_ == DrawFn(draw_25e2_25e5)
	}
}

fn test_get_draw_fn_powerline_single() {
	fn_ := get_draw_fn(0xe0b0) or { panic('expected draw fn') }
	assert fn_ == DrawFn(draw_e0b0)
	fn2 := get_draw_fn(0xe0b4) or { panic('expected draw fn') }
	assert fn2 == DrawFn(draw_e0b4)
}

fn test_get_draw_fn_branch_range() {
	for cp in [u32(0xf5d0), 0xf5f0, 0xf60d] {
		fn_ := get_draw_fn(cp) or { panic('expected draw fn for 0x${cp:x}') }
		assert fn_ == DrawFn(draw_f5d0_f60d)
	}
}

fn test_get_draw_fn_legacy_computing_range() {
	for cp in [u32(0x1fb00), 0x1fb20, 0x1fb3b] {
		fn_ := get_draw_fn(cp) or { panic('expected draw fn for 0x${cp:x}') }
		assert fn_ == DrawFn(draw_1fb00_1fb3b)
	}
}

fn test_get_draw_fn_octant_range() {
	for cp in [u32(0x1cd00), 0x1cd80, 0x1cde5] {
		fn_ := get_draw_fn(cp) or { panic('expected draw fn for 0x${cp:x}') }
		assert fn_ == DrawFn(draw_1cd00_1cde5)
	}
}

fn test_get_draw_fn_none_for_gaps() {
	// Codepoints in no range return none.
	assert draw_fn_is_none(0x0041)
	assert draw_fn_is_none(0x24ff)
	assert draw_fn_is_none(0x25a0)
	assert draw_fn_is_none(0x10ffff)
}

// ------------------------------------------------------------
// Boundary transitions: min-1 differs from min, max differs from max+1.
// ------------------------------------------------------------

fn test_get_draw_fn_box_boundaries() {
	// 0x24ff is below the box range -> none.
	assert draw_fn_is_none(0x24ff)
	// 0x2500 is the first box codepoint.
	lo := get_draw_fn(0x2500) or { panic('expected box fn') }
	assert lo == DrawFn(draw_2500_257f)
	// 0x2580 is the block range, not the box range.
	hi := get_draw_fn(0x2580) or { panic('expected block fn') }
	assert hi == DrawFn(draw_2580_259f)
	assert hi != DrawFn(draw_2500_257f)
}

// ------------------------------------------------------------
// Special sprite dispatch: codepoints at Sprite.start (0x110000)
// map to the special drawing functions in enum-declaration order:
//   underline, underline_double, underline_dotted, underline_dashed,
//   underline_curly, strikethrough, overline, cursor_rect,
//   cursor_hollow_rect, cursor_bar, cursor_underline.
// ------------------------------------------------------------

const special_start = u32(0x110000)

fn test_get_draw_fn_special_sprites() {
	assert get_draw_fn(special_start + 0) or { panic('') } == DrawFn(draw_underline)
	assert get_draw_fn(special_start + 1) or { panic('') } == DrawFn(draw_underline_double)
	assert get_draw_fn(special_start + 2) or { panic('') } == DrawFn(draw_underline_dotted)
	assert get_draw_fn(special_start + 3) or { panic('') } == DrawFn(draw_underline_dashed)
	assert get_draw_fn(special_start + 4) or { panic('') } == DrawFn(draw_underline_curly)
	assert get_draw_fn(special_start + 5) or { panic('') } == DrawFn(draw_strikethrough)
	assert get_draw_fn(special_start + 6) or { panic('') } == DrawFn(draw_overline)
	assert get_draw_fn(special_start + 7) or { panic('') } == DrawFn(draw_cursor_rect)
	assert get_draw_fn(special_start + 8) or { panic('') } == DrawFn(draw_cursor_hollow_rect)
	assert get_draw_fn(special_start + 9) or { panic('') } == DrawFn(draw_cursor_bar)
	assert get_draw_fn(special_start + 10) or { panic('') } == DrawFn(draw_cursor_underline)
}

fn test_get_draw_fn_special_out_of_range() {
	// Above the last special sprite index there is no draw fn.
	assert draw_fn_is_none(special_start + 11)
	assert draw_fn_is_none(special_start + 100)
}

fn test_has_codepoint_special_sprites() {
	f := new_face()
	// The special cursor/underline sprites are all "covered".
	for i in 0 .. 11 {
		assert f.has_codepoint(special_start + u32(i))
	}
	assert !f.has_codepoint(special_start + 11)
}
