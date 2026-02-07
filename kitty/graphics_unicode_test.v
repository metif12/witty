module kitty

// Tests for Kitty graphics protocol unicode placement feature.
//
// Source: graphics_unicode.zig tests

import terminal

fn test_unicode_diacritic_sorted() {
	// diacritics must be sorted since we use a binary search.
	for i in 1 .. diacritics.len {
		assert diacritics[i - 1] < diacritics[i], 'diacritics not sorted at index ${i}'
	}
}

fn test_unicode_diacritic() {
	// Some spot checks based on Kitty behavior
	idx1 := get_index(0x483) or {
		assert false, 'expected diacritic 0x483 to be found'
		return
	}
	assert idx1 == 30

	idx2 := get_index(0x1d242) or {
		assert false, 'expected diacritic 0x1d242 to be found'
		return
	}
	assert idx2 == 294
}

// XTODO: The unicode placement iterator tests require a full terminal
// with printString/setAttribute support and the grapheme_cluster mode.
// These tests are stubs that will be enabled once those features are
// available in the V terminal module.

// fn test_unicode_placement_none() {
//     // XTODO: requires t.printString("hello\nworld\n1\n2") and
//     // placementIterator scanning rows
// }

// fn test_unicode_placement_single_row_col() {
//     // XTODO: requires t.printString with placeholder char + diacritics
// }

// fn test_unicode_placement_continuation_break() {
//     // XTODO: requires t.printString with two placeholder runs
// }

// fn test_unicode_placement_continuation_with_diacritics_set() {
//     // XTODO: requires t.printString with three continuing cells
// }

// fn test_unicode_placement_continuation_with_no_col() {
//     // XTODO: requires t.printString with continuation cells
// }

// fn test_unicode_placement_continuation_with_no_diacritics() {
//     // XTODO: requires t.printString with bare placeholder chars
// }

// fn test_unicode_placement_run_ending() {
//     // XTODO: requires t.printString with placeholder followed by normal text
// }

// fn test_unicode_placement_run_starting_in_the_middle() {
//     // XTODO: requires t.printString with normal text followed by placeholder
// }

// fn test_unicode_placement_specifying_image_id_as_palette() {
//     // XTODO: requires t.setAttribute(.{ .@"256_fg" = 42 })
// }

// fn test_unicode_placement_specifying_image_id_with_high_bits() {
//     // XTODO: requires t.setAttribute and 3rd diacritic
// }

// fn test_unicode_placement_specifying_placement_id_as_palette() {
//     // XTODO: requires t.setAttribute with underline color
// }

// fn test_unicode_render_placement_dog_4x2() {
//     // XTODO: requires full VirtualPlacement.render_placement test
// }

// fn test_unicode_render_placement_dog_2x2_with_blank_cells() {
//     // XTODO: requires full VirtualPlacement.render_placement test
// }

// fn test_unicode_render_placement_dog_1x1() {
//     // XTODO: requires full VirtualPlacement.render_placement test
// }

fn test_unicode_render_placement_dog_4x2_direct() ! {
	// Direct test of VirtualPlacement.render_placement without full terminal.
	// Fish:
	// printf "\033_Gf=100,i=1,t=f,q=2;$(printf dog.png | base64)\033\\"
	// printf "\033_Ga=p,i=1,U=1,q=2,c=4,r=2\033\\"
	cell_width := u32(36)
	cell_height := u32(80)

	mut s := ImageStorage{}
	image := Image{ id: 1, width: 500, height: 306 }
	s.add_image(image)!
	s.add_placement(1, 0, Placement{
		location: PlacementLocation(PlacementVirtual{})
		columns: 4
		rows: 2
	})

	// Row 1
	{
		p := VirtualPlacement{
			pin: terminal.Pin{ x: 0, y: 0 }
			image_id: 1
			placement_id: 0
			col: 0
			row: 0
			width: 4
			height: 1
		}
		rp := p.render_placement(&s, &image, cell_width, cell_height)!
		assert rp.offset_x == 0
		assert rp.offset_y == 36
		assert rp.source_x == 0
		assert rp.source_y == 0
		assert rp.source_width == 500
		assert rp.source_height == 153
		assert rp.dest_width == 144
		assert rp.dest_height == 44
	}
	// Row 2
	{
		p := VirtualPlacement{
			pin: terminal.Pin{ x: 0, y: 1 }
			image_id: 1
			placement_id: 0
			col: 0
			row: 1
			width: 4
			height: 1
		}
		rp := p.render_placement(&s, &image, cell_width, cell_height)!
		assert rp.offset_x == 0
		assert rp.offset_y == 0
		assert rp.source_x == 0
		assert rp.source_y == 153
		assert rp.source_width == 500
		assert rp.source_height == 153
		assert rp.dest_width == 144
		assert rp.dest_height == 44
	}
}

fn test_unicode_render_placement_dog_2x2_with_blank_cells_direct() ! {
	// Fish:
	// printf "\033_Ga=p,i=1,U=1,q=2,c=2,r=2\033\\"
	cell_width := u32(36)
	cell_height := u32(80)

	mut s := ImageStorage{}
	image := Image{ id: 1, width: 500, height: 306 }
	s.add_image(image)!
	s.add_placement(1, 0, Placement{
		location: PlacementLocation(PlacementVirtual{})
		columns: 2
		rows: 2
	})

	// Row 1
	{
		p := VirtualPlacement{
			pin: terminal.Pin{ x: 0, y: 0 }
			image_id: 1
			placement_id: 0
			col: 0
			row: 0
			width: 4
			height: 1
		}
		rp := p.render_placement(&s, &image, cell_width, cell_height)!
		assert rp.offset_x == 0
		assert rp.offset_y == 58
		assert rp.source_x == 0
		assert rp.source_y == 0
		assert rp.source_width == 500
		assert rp.source_height == 153
		assert rp.dest_width == 72
		assert rp.dest_height == 22
	}
	// Row 2
	{
		p := VirtualPlacement{
			pin: terminal.Pin{ x: 0, y: 1 }
			image_id: 1
			placement_id: 0
			col: 0
			row: 1
			width: 4
			height: 1
		}
		rp := p.render_placement(&s, &image, cell_width, cell_height)!
		assert rp.offset_x == 0
		assert rp.offset_y == 0
		assert rp.source_x == 0
		assert rp.source_y == 153
		assert rp.source_width == 500
		assert rp.source_height == 153
		assert rp.dest_width == 72
		assert rp.dest_height == 22
	}
}

fn test_unicode_render_placement_dog_1x1_direct() ! {
	// Fish:
	// printf "\033_Ga=p,i=1,U=1,q=2,c=1,r=1\033\\"
	cell_width := u32(36)
	cell_height := u32(80)

	mut s := ImageStorage{}
	image := Image{ id: 1, width: 500, height: 306 }
	s.add_image(image)!
	s.add_placement(1, 0, Placement{
		location: PlacementLocation(PlacementVirtual{})
		columns: 1
		rows: 1
	})

	// Row 1
	{
		p := VirtualPlacement{
			pin: terminal.Pin{ x: 0, y: 0 }
			image_id: 1
			placement_id: 0
			col: 0
			row: 0
			width: 4
			height: 1
		}
		rp := p.render_placement(&s, &image, cell_width, cell_height)!
		assert rp.offset_x == 0
		assert rp.offset_y == 29
		assert rp.source_x == 0
		assert rp.source_y == 0
		assert rp.source_width == 500
		assert rp.source_height == 306
		assert rp.dest_width == 36
		assert rp.dest_height == 22
	}
}

fn test_incomplete_placement_can_append_same_image() {
	a := IncompletePlacement{
		pin: terminal.Pin{ x: 0, y: 0 }
		image_id_low: 42
		row: 0
		col: 0
		width: 1
	}
	b := IncompletePlacement{
		pin: terminal.Pin{ x: 1, y: 0 }
		image_id_low: 42
		row: 0
		col: 1
		width: 1
	}
	assert a.can_append(&b)
}

fn test_incomplete_placement_cannot_append_different_image() {
	a := IncompletePlacement{
		pin: terminal.Pin{ x: 0, y: 0 }
		image_id_low: 42
		row: 0
		col: 0
		width: 1
	}
	b := IncompletePlacement{
		pin: terminal.Pin{ x: 1, y: 0 }
		image_id_low: 99
		row: 0
		col: 1
		width: 1
	}
	assert !a.can_append(&b)
}

fn test_incomplete_placement_cannot_append_discontinuous_col() {
	a := IncompletePlacement{
		pin: terminal.Pin{ x: 0, y: 0 }
		image_id_low: 42
		row: 0
		col: 0
		width: 1
	}
	b := IncompletePlacement{
		pin: terminal.Pin{ x: 1, y: 0 }
		image_id_low: 42
		row: 0
		col: 2 // should be 1 (col + width)
		width: 1
	}
	assert !a.can_append(&b)
}

fn test_incomplete_placement_complete() {
	ip := IncompletePlacement{
		pin: terminal.Pin{ x: 3, y: 5 }
		image_id_low: 0x123456
		image_id_high: 0xAB
		placement_id: 42
		row: 7
		col: 2
		width: 3
	}
	vp := ip.complete()
	assert vp.pin.x == 3
	assert vp.pin.y == 5
	assert vp.image_id == 0xAB123456
	assert vp.placement_id == 42
	assert vp.row == 7
	assert vp.col == 2
	assert vp.width == 3
	assert vp.height == 1
}
