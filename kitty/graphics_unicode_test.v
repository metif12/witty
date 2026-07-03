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

// ============================================================
// PlacementIterator tests
//
// Ghostty drives these via a full Terminal + printString + grapheme_cluster
// mode. The witty terminal model stores each cell's resolved style directly
// on the CellData and marks placeholder rows with kitty_virtual_placeholder,
// so we build the Pages/RowData/CellData grid directly and exercise the same
// placement_iterator logic. A ghostty printString("\u{10EEEE}<d1><d2>...")
// produces a single cell whose codepoint is the placeholder and whose
// graphemes slice holds the trailing diacritics.
// ============================================================

// Build a placeholder cell carrying the given diacritics and (optional) style.
fn placeholder_cell(diacritics []u32, style terminal.CellStyle) terminal.CellData {
	return terminal.CellData{
		codepoint: placeholder
		content_tag: .codepoint_grapheme
		has_grapheme: diacritics.len > 0
		graphemes: diacritics
		style: style
	}
}

// Build a plain text cell (no placeholder).
fn text_cell(cp rune) terminal.CellData {
	return terminal.CellData{
		codepoint: u32(cp)
		content_tag: .codepoint
	}
}

fn test_unicode_placement_none() {
	// A grid with ordinary text ("hello\nworld\n1\n2") but no virtual
	// placeholders: no rows have kitty_virtual_placeholder set, so there
	// are no placements.
	mut pages := terminal.Pages.init(5, 5, 0)
	pages.screen_rows[0].cells[0] = text_cell(`h`)
	pages.screen_rows[1].cells[0] = text_cell(`w`)
	pages.screen_rows[2].cells[0] = text_cell(`1`)
	pages.screen_rows[3].cells[0] = text_cell(`2`)

	mut it := placement_iterator(&pages, 0, 5)
	assert it.next() == none
}

fn test_unicode_placement_single_row_col() {
	mut pages := terminal.Pages.init(5, 5, 0)
	// \u{10EEEE}\u{0305}\u{0305}
	pages.screen_rows[0].cells[0] = placeholder_cell([u32(0x0305), 0x0305],
		terminal.CellStyle{})
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected one placement'
		return
	}
	assert p.image_id == 0
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert it.next() == none
}

fn test_unicode_placement_continuation_break() {
	mut pages := terminal.Pages.init(10, 5, 0)
	// Two runs because it jumps cols (col 0 then col 2).
	pages.screen_rows[0].cells[0] = placeholder_cell([u32(0x0305), 0x0305],
		terminal.CellStyle{}) // row 0, col 0
	pages.screen_rows[0].cells[1] = placeholder_cell([u32(0x0305), 0x030E],
		terminal.CellStyle{}) // row 0, col 2
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p1 := it.next() or {
		assert false, 'expected first placement'
		return
	}
	assert p1.image_id == 0
	assert p1.placement_id == 0
	assert p1.row == 0
	assert p1.col == 0
	assert p1.width == 1

	p2 := it.next() or {
		assert false, 'expected second placement'
		return
	}
	assert p2.image_id == 0
	assert p2.placement_id == 0
	assert p2.row == 0
	assert p2.col == 2
	assert p2.width == 1

	assert it.next() == none
}

fn test_unicode_placement_continuation_with_diacritics_set() {
	mut pages := terminal.Pages.init(10, 5, 0)
	// Three cells that continue even though they're explicit.
	pages.screen_rows[0].cells[0] = placeholder_cell([u32(0x0305), 0x0305],
		terminal.CellStyle{}) // col 0
	pages.screen_rows[0].cells[1] = placeholder_cell([u32(0x0305), 0x030D],
		terminal.CellStyle{}) // col 1
	pages.screen_rows[0].cells[2] = placeholder_cell([u32(0x0305), 0x030E],
		terminal.CellStyle{}) // col 2
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected placement'
		return
	}
	assert p.image_id == 0
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert p.width == 3
	assert it.next() == none
}

fn test_unicode_placement_continuation_with_no_col() {
	mut pages := terminal.Pages.init(10, 5, 0)
	// First cell fully specified, the rest have no col diacritic.
	pages.screen_rows[0].cells[0] = placeholder_cell([u32(0x0305), 0x0305],
		terminal.CellStyle{})
	pages.screen_rows[0].cells[1] = placeholder_cell([u32(0x0305)], terminal.CellStyle{})
	pages.screen_rows[0].cells[2] = placeholder_cell([u32(0x0305)], terminal.CellStyle{})
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected placement'
		return
	}
	assert p.image_id == 0
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert p.width == 3
	assert it.next() == none
}

fn test_unicode_placement_continuation_with_no_diacritics() {
	mut pages := terminal.Pages.init(10, 5, 0)
	// Bare placeholder cells with no diacritics at all.
	pages.screen_rows[0].cells[0] = placeholder_cell([]u32{}, terminal.CellStyle{})
	pages.screen_rows[0].cells[1] = placeholder_cell([]u32{}, terminal.CellStyle{})
	pages.screen_rows[0].cells[2] = placeholder_cell([]u32{}, terminal.CellStyle{})
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected placement'
		return
	}
	assert p.image_id == 0
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert p.width == 3
	assert it.next() == none
}

fn test_unicode_placement_run_ending() {
	mut pages := terminal.Pages.init(10, 5, 0)
	// Two placeholders then normal text "ABC".
	pages.screen_rows[0].cells[0] = placeholder_cell([u32(0x0305), 0x0305],
		terminal.CellStyle{})
	pages.screen_rows[0].cells[1] = placeholder_cell([u32(0x0305), 0x030D],
		terminal.CellStyle{})
	pages.screen_rows[0].cells[2] = text_cell(`A`)
	pages.screen_rows[0].cells[3] = text_cell(`B`)
	pages.screen_rows[0].cells[4] = text_cell(`C`)
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected placement'
		return
	}
	assert p.image_id == 0
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert p.width == 2
	assert it.next() == none
}

fn test_unicode_placement_run_starting_in_the_middle() {
	mut pages := terminal.Pages.init(10, 5, 0)
	// Normal text "ABC" then two placeholders.
	pages.screen_rows[0].cells[0] = text_cell(`A`)
	pages.screen_rows[0].cells[1] = text_cell(`B`)
	pages.screen_rows[0].cells[2] = text_cell(`C`)
	pages.screen_rows[0].cells[3] = placeholder_cell([u32(0x0305), 0x0305],
		terminal.CellStyle{})
	pages.screen_rows[0].cells[4] = placeholder_cell([u32(0x0305), 0x030D],
		terminal.CellStyle{})
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected placement'
		return
	}
	assert p.image_id == 0
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert p.width == 2
	assert it.next() == none
}

fn test_unicode_placement_specifying_image_id_as_palette() {
	mut pages := terminal.Pages.init(5, 5, 0)
	// setAttribute 256_fg = 42, then a single placeholder cell.
	style := terminal.CellStyle{
		fg_color: .palette
		fg_palette: 42
	}
	pages.screen_rows[0].cells[0] = placeholder_cell([u32(0x0305), 0x0305], style)
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected placement'
		return
	}
	assert p.image_id == 42
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert it.next() == none
}

fn test_unicode_placement_specifying_image_id_with_high_bits() {
	mut pages := terminal.Pages.init(5, 5, 0)
	// 256_fg = 42 plus a 3rd diacritic (0x030E -> index 2) sets the high bits.
	style := terminal.CellStyle{
		fg_color: .palette
		fg_palette: 42
	}
	pages.screen_rows[0].cells[0] = placeholder_cell([u32(0x0305), 0x0305, 0x030E],
		style)
	pages.screen_rows[0].kitty_virtual_placeholder = true

	mut it := placement_iterator(&pages, 0, 5)
	p := it.next() or {
		assert false, 'expected placement'
		return
	}
	// 42 | (2 << 24) == 33554474
	assert p.image_id == 33554474
	assert p.placement_id == 0
	assert p.row == 0
	assert p.col == 0
	assert it.next() == none
}

// SKIPPED (un-translated logic): "unicode placement: specifying placement id as
// palette". The placement id comes from the underline color palette value, but
// the witty terminal.CellStyle only tracks underline_color as a ColorType and
// does not store an underline palette/rgb value (and terminal/ is out of scope
// to edit). Without underline palette storage there is no faithful way to encode
// placement id 21, so this test is intentionally omitted rather than weakened.

// fn test_unicode_render_placement_dog_4x2() {
//     // Requires full terminal with VirtualPlacement.render_placement test
// }

// fn test_unicode_render_placement_dog_2x2_with_blank_cells() {
//     // Requires full terminal with VirtualPlacement.render_placement test
// }

// fn test_unicode_render_placement_dog_1x1() {
//     // Requires full terminal with VirtualPlacement.render_placement test
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
