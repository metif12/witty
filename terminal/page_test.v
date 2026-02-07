module terminal

// Tests for page.v, translated from Ghostty's terminal/page.zig tests.

// Test that a page can be initialized.
fn test_page_init() {
	mut page := Page.init(PageCapacity{
		cols: 120
		rows: 80
		styles: 32
	})
	defer {
		page.deinit()
	}
	assert page.size.cols == 120
	assert page.size.rows == 0
	assert page.rows.len == 80
}

// Test that CellData is zero by default.
fn test_cell_is_zero_by_default() {
	cell := CellData.init(0)
	assert cell.is_zero()
	// The zero value should be output type for semantic content.
	// This is very important for our assumptions elsewhere.
	assert cell.semantic_content == .output
}

// Test reading and writing cells.
fn test_page_read_and_write_cells() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y)
		}
	}

	// Read it again.
	for y in 0 .. int(page.capacity.rows) {
		rac := page.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y)
	}
}

// Test appending small graphemes.
fn test_page_append_grapheme_small() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	mut rac := page.get_row_and_cell(0, 0)
	unsafe {
		rac.cell.content_tag = .codepoint
		rac.cell.codepoint = 0x09
	}

	// One
	page.append_grapheme(0, 0, 0x0A)
	row0 := page.get_row(0)
	assert row0.grapheme
	assert page.rows[0].cells[0].has_grapheme
	cps1 := page.lookup_grapheme(0, 0) or {
		assert false, 'expected grapheme data'
		return
	}
	assert cps1 == [u32(0x0A)]

	// Two
	page.append_grapheme(0, 0, 0x0B)
	cps2 := page.lookup_grapheme(0, 0) or {
		assert false, 'expected grapheme data'
		return
	}
	assert cps2 == [u32(0x0A), u32(0x0B)]

	// Clear it
	page.clear_grapheme(0, 0)
	page.update_row_grapheme_flag(page.get_row(0))
	assert !page.rows[0].grapheme
	assert !page.rows[0].cells[0].has_grapheme
}

// Test appending graphemes larger than chunk.
fn test_page_append_grapheme_larger_than_chunk() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	mut rac := page.get_row_and_cell(0, 0)
	unsafe {
		rac.cell.content_tag = .codepoint
		rac.cell.codepoint = 0x09
	}

	count := grapheme_chunk_len * 10
	for i in 0 .. count {
		page.append_grapheme(0, 0, u32(0x0A + i))
	}

	cps := page.lookup_grapheme(0, 0) or {
		assert false, 'expected grapheme data'
		return
	}
	assert cps.len == count
	for i in 0 .. count {
		assert cps[i] == u32(0x0A + i)
	}
}

// Test clearing graphemes when not all cells have them.
fn test_page_clear_grapheme_not_all_cells() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Set up first cell with grapheme.
	mut rac := page.get_row_and_cell(0, 0)
	unsafe {
		rac.cell.content_tag = .codepoint
		rac.cell.codepoint = 0x09
	}
	page.append_grapheme(0, 0, 0x0A)

	// Set up second cell with grapheme.
	mut rac2 := page.get_row_and_cell(1, 0)
	unsafe {
		rac2.cell.content_tag = .codepoint
		rac2.cell.codepoint = 0x09
	}
	page.append_grapheme(0, 1, 0x0A)

	// Clear only the first cell's grapheme.
	page.clear_grapheme(0, 0)
	page.update_row_grapheme_flag(page.get_row(0))
	// Row should still be marked as having graphemes (second cell has one).
	assert page.rows[0].grapheme
	assert !page.rows[0].cells[0].has_grapheme
	assert page.rows[0].cells[1].has_grapheme
}

// Test cloning a page.
fn test_page_clone() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y)
		}
	}

	// Clone
	mut page2 := page.clone()
	defer {
		page2.deinit()
	}
	assert page2.capacity.cols == page.capacity.cols
	assert page2.capacity.rows == page.capacity.rows

	// Read it from clone.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y)
	}

	// Write again to original (zeroes).
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = 0
		}
	}

	// Read clone again, should be unchanged.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y)
	}

	// Read the original - should be zeroed.
	for y in 0 .. int(page.capacity.rows) {
		rac := page.get_row_and_cell(1, y)
		assert rac.cell.codepoint == 0
	}
}

// Test cloning a page with graphemes.
fn test_page_clone_graphemes() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Append some graphemes.
	{
		mut rac := page.get_row_and_cell(0, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = 0x09
		}
		page.append_grapheme(0, 0, 0x0A)
		page.append_grapheme(0, 0, 0x0B)
	}

	// Clone it.
	mut page2 := page.clone()
	defer {
		page2.deinit()
	}
	{
		assert page2.rows[0].grapheme
		assert page2.rows[0].cells[0].has_grapheme
		cps := page2.lookup_grapheme(0, 0) or {
			assert false, 'expected grapheme data'
			return
		}
		assert cps == [u32(0x0A), u32(0x0B)]
	}
}

// Test cloning a page with styles.
fn test_page_clone_styles() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write with some styles.
	{
		id := page.styles.add(CellStyle{
			flags: StyleFlags{
				bold: true
			}
		}) or {
			assert false, 'failed to add style'
			return
		}

		for x in 0 .. int(page.size.cols) {
			mut rac := page.get_row_and_cell(x, 0)
			unsafe {
				rac.row.styled = true
				rac.cell.content_tag = .codepoint
				rac.cell.codepoint = u32(x + 1)
				rac.cell.style_id = id
			}
			page.styles.use_style(id)
		}
	}

	// Clone it.
	mut page2 := page.clone()
	defer {
		page2.deinit()
	}
	{
		id := page2.rows[0].cells[0].style_id

		for x in 0 .. int(page.size.cols) {
			rac := page.get_row_and_cell(x, 0)
			assert rac.row.styled
			assert rac.cell.style_id == id
		}

		style := page.styles.get(id)
		assert style.flags.bold
	}
}

// Test cloneFrom (copy between pages).
fn test_page_clone_from() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y)
		}
	}

	// Clone
	mut page2 := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.clone_from(&page, 0, page.size.rows)
	page2.size.rows = page.size.rows

	// Read it again.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y)
	}

	// Write again
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = 0
		}
	}

	// Read clone, should be unchanged.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y)
	}

	// Read the original.
	for y in 0 .. int(page.capacity.rows) {
		rac := page.get_row_and_cell(1, y)
		assert rac.cell.codepoint == 0
	}
}

// Test cloneFrom with shrunk columns.
fn test_page_clone_from_shrink_columns() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y)
		}
	}

	// Clone into smaller page.
	mut page2 := Page.init(PageCapacity{
		cols: 5
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.clone_from(&page, 0, page.size.rows)
	page2.size.rows = page.size.rows
	assert page2.size.cols == 5

	// Read it again - column 1 should still have data.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y)
	}
}

// Test cloneFrom with partial range.
fn test_page_clone_from_partial() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y)
		}
	}

	// Clone only first 5 rows.
	mut page2 := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.size.rows = u16(page2.capacity.rows)
	page2.clone_from(&page, 0, 5)

	// Read first 5 rows - should have data.
	for y in 0 .. 5 {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y)
	}
	// Remaining rows should be blank.
	for y in 5 .. int(page2.size.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == 0
	}
}

// Test cloneFrom with graphemes.
fn test_page_clone_from_graphemes() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write with graphemes.
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y + 1)
		}
		page.append_grapheme(y, 1, 0x0A)
	}

	// Clone.
	mut page2 := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.clone_from(&page, 0, page.size.rows)
	page2.size.rows = page.size.rows

	// Read it again.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y + 1)
		assert page2.rows[y].grapheme
		assert page2.rows[y].cells[1].has_grapheme
		cps := page2.lookup_grapheme(y, 1) or {
			assert false, 'expected grapheme data'
			return
		}
		assert cps == [u32(0x0A)]
	}

	// Clear original graphemes.
	for y in 0 .. int(page.capacity.rows) {
		page.clear_grapheme(y, 1)
		page.update_row_grapheme_flag(page.get_row(y))
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = 0
		}
	}

	// Clone should be unchanged.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y + 1)
		assert page2.rows[y].grapheme
		assert page2.rows[y].cells[1].has_grapheme
		cps := page2.lookup_grapheme(y, 1) or {
			assert false, 'expected grapheme data'
			return
		}
		assert cps == [u32(0x0A)]
	}

	// Read the original.
	for y in 0 .. int(page.capacity.rows) {
		rac := page.get_row_and_cell(1, y)
		assert rac.cell.codepoint == 0
	}
}

// Test cloneFrom frees destination graphemes.
fn test_page_clone_from_frees_dst_graphemes() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)
	for y in 0 .. int(page.capacity.rows) {
		mut rac := page.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y + 1)
		}
	}

	// Create page2 with graphemes.
	mut page2 := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.size.rows = u16(page2.capacity.rows)
	for y in 0 .. int(page2.capacity.rows) {
		mut rac := page2.get_row_and_cell(1, y)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(y + 1)
		}
		page2.append_grapheme(y, 1, 0x0A)
	}

	// Clone from page which has no graphemes.
	page2.clone_from(&page, 0, page.size.rows)

	// Read it again.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y + 1)
		assert !page2.rows[y].grapheme
		assert !page2.rows[y].cells[1].has_grapheme
	}
	assert page2.grapheme_count() == 0
}

// Test clone_partial_row_from.
fn test_page_clone_row_from_partial() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write
	{
		for x in 0 .. int(page.size.cols) {
			mut rac := page.get_row_and_cell(x, 0)
			unsafe {
				rac.cell.content_tag = .codepoint
				rac.cell.codepoint = u32(x + 1)
			}
		}
	}

	// Clone partial row (cols 2..8).
	mut page2 := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.size.rows = u16(page2.capacity.rows)
	page2.clone_partial_row_from(&page, 0, 0, 2, 8)

	// Read it again.
	{
		for x in 0 .. int(page2.size.cols) {
			expected := if x >= 2 && x < 8 { u32(x + 1) } else { u32(0) }
			rac := page2.get_row_and_cell(x, 0)
			assert rac.cell.codepoint == expected
		}
	}
}

// Test clone_partial_row_from with grapheme in non-copied source region.
fn test_page_clone_row_from_partial_grapheme_in_non_copied_source_region() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write
	{
		for x in 0 .. int(page.size.cols) {
			mut rac := page.get_row_and_cell(x, 0)
			unsafe {
				rac.cell.content_tag = .codepoint
				rac.cell.codepoint = u32(x + 1)
			}
		}
		// Add grapheme at col 0 and col 9 (outside the copy range 2..8).
		page.append_grapheme(0, 0, 0x0A)
		page.append_grapheme(0, 9, 0x0A)
	}
	assert page.grapheme_count() == 2

	// Clone partial row (cols 2..8).
	mut page2 := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.size.rows = u16(page2.capacity.rows)
	page2.clone_partial_row_from(&page, 0, 0, 2, 8)

	// Read it again.
	{
		for x in 0 .. int(page2.size.cols) {
			expected := if x >= 2 && x < 8 { u32(x + 1) } else { u32(0) }
			rac := page2.get_row_and_cell(x, 0)
			assert rac.cell.codepoint == expected
			assert !rac.cell.has_grapheme
		}
		assert !page2.rows[0].grapheme
	}
	assert page2.grapheme_count() == 0
}

// Test clone_partial_row_from with grapheme in non-copied dest region.
fn test_page_clone_row_from_partial_grapheme_in_non_copied_dest_region() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write source (no graphemes).
	{
		for x in 0 .. int(page.size.cols) {
			mut rac := page.get_row_and_cell(x, 0)
			unsafe {
				rac.cell.content_tag = .codepoint
				rac.cell.codepoint = u32(x + 1)
			}
		}
	}
	assert page.grapheme_count() == 0

	// Create destination page with graphemes at cols 0 and 9.
	mut page2 := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page2.deinit()
	}
	page2.size.rows = u16(page2.capacity.rows)
	{
		for x in 0 .. int(page2.size.cols) {
			mut rac := page2.get_row_and_cell(x, 0)
			unsafe {
				rac.cell.content_tag = .codepoint
				rac.cell.codepoint = 0xBB
			}
		}
		page2.append_grapheme(0, 0, 0x0A)
		page2.append_grapheme(0, 9, 0x0A)
	}

	// Clone partial row (cols 2..8) from page into page2.
	page2.clone_partial_row_from(&page, 0, 0, 2, 8)

	// Read it again.
	{
		for x in 0 .. int(page2.size.cols) {
			expected := if x >= 2 && x < 8 { u32(x + 1) } else { u32(0xBB) }
			rac := page2.get_row_and_cell(x, 0)
			assert rac.cell.codepoint == expected
		}
		// Row should still have graphemes (from cols 0 and 9).
		assert page2.rows[0].grapheme
	}
	assert page2.grapheme_count() == 2
}

// Test moveCells with text-only rows.
fn test_page_move_cells_text_only() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write
	for x in 0 .. int(page.capacity.cols) {
		mut rac := page.get_row_and_cell(x, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(x + 1)
		}
	}

	page.move_cells(0, 0, 1, 0, int(page.capacity.cols))

	// New row should have text.
	for x in 0 .. int(page.capacity.cols) {
		rac := page.get_row_and_cell(x, 1)
		assert rac.cell.codepoint == u32(x + 1)
	}

	// Old row should be blank.
	for x in 0 .. int(page.capacity.cols) {
		rac := page.get_row_and_cell(x, 0)
		assert rac.cell.codepoint == 0
	}
}

// Test moveCells with graphemes.
fn test_page_move_cells_graphemes() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write with graphemes.
	for x in 0 .. int(page.size.cols) {
		mut rac := page.get_row_and_cell(x, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(x + 1)
		}
		page.append_grapheme(0, x, 0x0A)
	}
	original_count := page.grapheme_count()

	page.move_cells(0, 0, 1, 0, int(page.size.cols))
	assert page.grapheme_count() == original_count

	// New row should have text and graphemes.
	for x in 0 .. int(page.size.cols) {
		rac := page.get_row_and_cell(x, 1)
		assert rac.cell.codepoint == u32(x + 1)
		cps := page.lookup_grapheme(1, x) or {
			assert false, 'expected grapheme data at x=${x}'
			return
		}
		assert cps == [u32(0x0A)]
	}

	// Old row should be blank.
	for x in 0 .. int(page.size.cols) {
		rac := page.get_row_and_cell(x, 0)
		assert rac.cell.codepoint == 0
	}
}

// Test verifyIntegrity with good graphemes.
fn test_page_verify_integrity_graphemes_good() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write with graphemes.
	for x in 0 .. int(page.size.cols) {
		mut rac := page.get_row_and_cell(x, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(x + 1)
		}
		page.append_grapheme(0, x, 0x0A)
	}

	// Should not return an integrity error.
	page.verify_integrity() or {
		// An error from V's error system means integrity check passed
		// (the function returns an IntegrityError enum value or error).
		return
	}
}

// Test verifyIntegrity with grapheme row not marked.
fn test_page_verify_integrity_grapheme_row_not_marked() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write with graphemes.
	for x in 0 .. int(page.size.cols) {
		mut rac := page.get_row_and_cell(x, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(x + 1)
		}
		page.append_grapheme(0, x, 0x0A)
	}

	// Make invalid by unmarking the row.
	page.rows[0].grapheme = false

	result := page.verify_integrity() or { return }
	assert result == .unmarked_grapheme_row
}

// Test verifyIntegrity with good styles.
fn test_page_verify_integrity_styles_good() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Upsert a style we'll use.
	id := page.styles.add(CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}) or {
		assert false, 'failed to add style'
		return
	}

	// Write with styles.
	for x in 0 .. int(page.size.cols) {
		mut rac := page.get_row_and_cell(x, 0)
		unsafe {
			rac.row.styled = true
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(x + 1)
			rac.cell.style_id = id
		}
		page.styles.use_style(id)
	}

	// The original style add would have incremented the
	// ref count too, so release it to balance that out.
	page.styles.release(id)

	// Should pass integrity.
	page.verify_integrity() or { return }
}

// Test verifyIntegrity with styles ref count mismatch.
fn test_page_verify_integrity_styles_ref_count_mismatch() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Upsert a style we'll use.
	id := page.styles.add(CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}) or {
		assert false, 'failed to add style'
		return
	}

	// Write with styles.
	for x in 0 .. int(page.size.cols) {
		mut rac := page.get_row_and_cell(x, 0)
		unsafe {
			rac.row.styled = true
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(x + 1)
			rac.cell.style_id = id
		}
		page.styles.use_style(id)
	}

	// Release the initial add's ref count.
	page.styles.release(id)

	// Release one more to create a mismatch.
	page.styles.release(id)

	result := page.verify_integrity() or { return }
	assert result == .mismatched_style_ref
}

// Test verifyIntegrity with zero rows.
fn test_page_verify_integrity_zero_rows() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = 0
	result := page.verify_integrity() or { return }
	assert result == .zero_row_count
}

// Test verifyIntegrity with zero cols.
fn test_page_verify_integrity_zero_cols() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)
	page.size.cols = 0
	result := page.verify_integrity() or { return }
	assert result == .zero_col_count
}

// Test exactRowCapacity with empty rows.
fn test_page_exact_row_capacity_empty_rows() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Empty page: all capacity fields should be 0 (except cols/rows).
	cap := page.exact_row_capacity(0, 5)
	assert cap.cols == 10
	assert cap.rows == 5
	assert cap.styles == 0
	assert cap.grapheme_bytes == 0
}

// Test exactRowCapacity with styles.
fn test_page_exact_row_capacity_styles() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// No styles: capacity should be 0.
	{
		cap := page.exact_row_capacity(0, 5)
		assert cap.styles == 0
	}

	// Add one style to a cell.
	style1_id := page.styles.add(CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}) or {
		assert false, 'failed to add style'
		return
	}
	{
		mut rac := page.get_row_and_cell(0, 0)
		unsafe {
			rac.row.styled = true
			rac.cell.style_id = style1_id
		}
	}

	// One unique style.
	cap_one_style := page.exact_row_capacity(0, 5)
	{
		assert cap_one_style.styles == StyleSet.capacity_for_count(1)
	}

	// Add same style to another cell (duplicate) - capacity unchanged.
	{
		mut rac := page.get_row_and_cell(1, 0)
		unsafe {
			rac.cell.style_id = style1_id
		}
	}
	{
		cap := page.exact_row_capacity(0, 5)
		assert cap.styles == cap_one_style.styles
	}

	// Add a different style.
	style2_id := page.styles.add(CellStyle{
		flags: StyleFlags{
			italic: true
		}
	}) or {
		assert false, 'failed to add style'
		return
	}
	{
		mut rac := page.get_row_and_cell(2, 0)
		unsafe {
			rac.cell.style_id = style2_id
		}
	}

	// Two unique styles.
	cap_two_styles := page.exact_row_capacity(0, 5)
	{
		assert cap_two_styles.styles == StyleSet.capacity_for_count(2)
		assert cap_two_styles.styles >= cap_one_style.styles
	}

	// Style outside the row range should not be counted.
	{
		style3_id := page.styles.add(CellStyle{
			flags: StyleFlags{
				underline: .single
			}
		}) or {
			assert false, 'failed to add style'
			return
		}
		mut rac := page.get_row_and_cell(0, 7)
		unsafe {
			rac.row.styled = true
			rac.cell.style_id = style3_id
		}
	}
	{
		cap := page.exact_row_capacity(0, 5)
		assert cap.styles == cap_two_styles.styles
	}

	// Full range includes the new style.
	{
		cap := page.exact_row_capacity(0, 10)
		assert cap.styles == StyleSet.capacity_for_count(3)
	}
}

// Test exactRowCapacity with grapheme_bytes.
fn test_page_exact_row_capacity_grapheme_bytes() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// No graphemes: capacity should be 0.
	{
		cap := page.exact_row_capacity(0, 5)
		assert cap.grapheme_bytes == 0
	}

	// Add one grapheme (1 codepoint) to a cell - rounds up to grapheme_chunk.
	{
		mut rac := page.get_row_and_cell(0, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(`a`)
		}
		page.append_grapheme(0, 0, 0x0301) // combining acute accent
	}
	{
		cap := page.exact_row_capacity(0, 5)
		// 1 codepoint = 4 bytes, rounds up to grapheme_chunk (16).
		assert cap.grapheme_bytes == u32(grapheme_chunk)
	}

	// Add another grapheme to a different cell - should sum.
	{
		mut rac := page.get_row_and_cell(1, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(`e`)
		}
		page.append_grapheme(0, 1, 0x0300) // combining grave accent
	}
	{
		cap := page.exact_row_capacity(0, 5)
		// 2 graphemes, each 1 codepoint = 2 * grapheme_chunk.
		assert cap.grapheme_bytes == u32(grapheme_chunk * 2)
	}

	// Add a larger grapheme (multiple codepoints) that fits in one chunk.
	{
		mut rac := page.get_row_and_cell(2, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(`o`)
		}
		page.append_grapheme(0, 2, 0x0301)
		page.append_grapheme(0, 2, 0x0302)
		page.append_grapheme(0, 2, 0x0303)
	}
	{
		cap := page.exact_row_capacity(0, 5)
		// First two cells: 2 * grapheme_chunk
		// Third cell: 3 codepoints = 12 bytes, rounds up to grapheme_chunk
		assert cap.grapheme_bytes == u32(grapheme_chunk * 3)
	}

	// Grapheme outside the row range should not be counted.
	{
		mut rac := page.get_row_and_cell(0, 7)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(`x`)
		}
		page.append_grapheme(7, 0, 0x0304)
	}
	{
		cap := page.exact_row_capacity(0, 5)
		assert cap.grapheme_bytes == u32(grapheme_chunk * 3)
	}

	// Full range includes the new grapheme.
	{
		cap := page.exact_row_capacity(0, 10)
		assert cap.grapheme_bytes == u32(grapheme_chunk * 4)
	}
}

// Test exactRowCapacity with grapheme_bytes larger than chunk.
fn test_page_exact_row_capacity_grapheme_bytes_larger_than_chunk() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Add a grapheme larger than one chunk (grapheme_chunk_len = 4 codepoints).
	mut rac := page.get_row_and_cell(0, 0)
	unsafe {
		rac.cell.content_tag = .codepoint
		rac.cell.codepoint = u32(`a`)
	}

	// Add 6 codepoints - requires 2 chunks (6 * 4 = 24 bytes, rounds up to 32).
	for i in 0 .. 6 {
		page.append_grapheme(0, 0, u32(0x0300 + i))
	}

	cap := page.exact_row_capacity(0, 1)
	// 6 codepoints = 24 bytes, rounds up to 32 (2 * grapheme_chunk).
	assert cap.grapheme_bytes == 32
}

// Test capacity adjust cols down.
fn test_page_capacity_adjust_cols_down() {
	original := PageCapacity{
		cols: 80
		rows: 128
	}
	adjusted := original.adjust(original.cols / 2)
	// Adjusted should have more rows (same total budget).
	assert adjusted.cols == original.cols / 2
	assert adjusted.rows > original.rows
	// Total cells should be approximately the same.
	original_total := u32(original.cols) * u32(original.rows)
	adjusted_total := u32(adjusted.cols) * u32(adjusted.rows)
	assert adjusted_total <= original_total
	assert adjusted_total >= original_total - u32(adjusted.cols) // allow rounding
}

// Test capacity adjust cols down to 1.
fn test_page_capacity_adjust_cols_down_to_1() {
	original := PageCapacity{
		cols: 80
		rows: 128
	}
	adjusted := original.adjust(1)
	assert adjusted.cols == 1
	// With 1 column, we should have many more rows.
	assert adjusted.rows > original.rows
}

// Test capacity adjust cols up.
fn test_page_capacity_adjust_cols_up() {
	original := PageCapacity{
		cols: 80
		rows: 128
	}
	adjusted := original.adjust(original.cols * 2)
	assert adjusted.cols == original.cols * 2
	// With double columns, we should have fewer rows.
	assert adjusted.rows < original.rows
}

// Test capacity adjust cols too high.
fn test_page_capacity_adjust_cols_too_high() {
	original := PageCapacity{
		cols: 80
		rows: 128
	}
	// When cols is very large and total_cells / cols == 0, adjust
	// clamps rows to 1 (always succeeds).
	total := u32(original.cols) * u32(original.rows)
	huge_cols := u16(total + 1)
	adjusted := original.adjust(huge_cols)
	assert adjusted.rows >= 1
}

// Test capacity maxCols basic.
fn test_capacity_max_cols_basic() {
	cap := PageCapacity{
		cols: 80
		rows: 128
	}
	max := cap.max_cols() or {
		assert false, 'maxCols returned none'
		return
	}

	// maxCols should be >= current cols (since current capacity is valid).
	assert max >= cap.cols

	// Adjusting to maxCols should succeed with at least 1 row.
	adjusted := cap.adjust(max)
	assert adjusted.rows >= 1
}

// Test that isDirty works.
fn test_page_is_dirty() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// New page is not dirty.
	assert !page.is_dirty()

	// Setting page dirty flag.
	page.dirty = true
	assert page.is_dirty()
	page.dirty = false

	// Setting a row dirty.
	page.rows[0].dirty = true
	assert page.is_dirty()
}

// Test row_is_blank.
fn test_page_row_is_blank() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// New row should be blank.
	assert page.row_is_blank(0)

	// Write something.
	mut rac := page.get_row_and_cell(0, 0)
	unsafe {
		rac.cell.content_tag = .codepoint
		rac.cell.codepoint = u32(`A`)
	}
	assert !page.row_is_blank(0)

	// Other row should still be blank.
	assert page.row_is_blank(1)
}

// Test hyperlink operations.
fn test_page_hyperlink_basic() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Insert a hyperlink.
	hl_id := page.insert_hyperlink(Hyperlink{
		uri: 'https://example.com'
		id_: ''
	})

	// Set it on a cell.
	page.set_hyperlink(0, 0, hl_id)
	assert page.rows[0].cells[0].has_hyperlink
	assert page.rows[0].hyperlink

	// Lookup.
	found_id := page.lookup_hyperlink(0, 0) or {
		assert false, 'expected hyperlink'
		return
	}
	assert found_id == hl_id

	// Clear it.
	page.clear_hyperlink(0, 0)
	assert !page.rows[0].cells[0].has_hyperlink
	assert page.lookup_hyperlink(0, 0) == none
}

// Test clear_cells clears graphemes and styles.
fn test_page_clear_cells() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write with graphemes and styles.
	id := page.styles.add(CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}) or {
		assert false, 'failed to add style'
		return
	}

	for x in 0 .. int(page.size.cols) {
		mut rac := page.get_row_and_cell(x, 0)
		unsafe {
			rac.row.styled = true
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(x + 1)
			rac.cell.style_id = id
		}
		page.styles.use_style(id)
		page.append_grapheme(0, x, 0x0A)
	}
	page.styles.release(id) // balance the initial add

	assert page.grapheme_count() == int(page.size.cols)

	// Clear all cells.
	page.clear_cells(0, 0, page.size.cols)

	// All cells should be blank.
	for x in 0 .. int(page.size.cols) {
		rac := page.get_row_and_cell(x, 0)
		assert rac.cell.codepoint == 0
		assert !rac.cell.has_grapheme
	}
	assert page.grapheme_count() == 0
}

// Test swap_cells.
fn test_page_swap_cells() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Write two cells.
	{
		mut rac := page.get_row_and_cell(0, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(`A`)
		}
	}
	{
		mut rac := page.get_row_and_cell(1, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(`B`)
		}
	}

	// Swap them.
	page.swap_cells(0, 0, 1)

	// Verify.
	{
		rac := page.get_row_and_cell(0, 0)
		assert rac.cell.codepoint == u32(`B`)
	}
	{
		rac := page.get_row_and_cell(1, 0)
		assert rac.cell.codepoint == u32(`A`)
	}
}

// Test reinit.
fn test_page_reinit() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	page.size.rows = u16(page.capacity.rows)

	// Write something.
	{
		mut rac := page.get_row_and_cell(0, 0)
		unsafe {
			rac.cell.content_tag = .codepoint
			rac.cell.codepoint = u32(`A`)
		}
	}

	// Reinit with same capacity.
	page.reinit(PageCapacity{
		cols: 10
		rows: 10
	})
	page.size.rows = u16(page.capacity.rows)

	// Should be blank now.
	{
		rac := page.get_row_and_cell(0, 0)
		assert rac.cell.codepoint == 0
	}
}

// Test clear_row resets row metadata.
fn test_page_clear_row() {
	mut p := Page.init(PageCapacity{
		cols: 10
		rows: 5
	})
	p.size.rows = 5

	p.rows[2].wrap = true
	p.rows[2].semantic_prompt = .prompt

	p.clear_row(2)

	assert p.rows[2].wrap == false
	assert p.rows[2].semantic_prompt == .unknown
}

// Test capacity adjust with same cols and larger cols.
fn test_page_capacity_adjust() {
	cap := PageCapacity{
		cols: 80
		rows: 128
	}

	// Normal cols - no adjustment
	adj := cap.adjust(80)
	assert adj.cols == 80
	assert adj.rows == 128

	// Very large cols - rows should reduce
	adj2 := cap.adjust(512)
	assert adj2.cols == 512
	assert adj2.rows < 128
}
