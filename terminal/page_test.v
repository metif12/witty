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
	assert page.size.rows == 80
	assert page.rows.len == 80
}

fn test_page_pause_integrity_checks_is_nested() {
	mut page := Page.init(PageCapacity{
		cols: 3
		rows: 2
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = 0
	assert page.verify_integrity() != none
	page.pause_integrity_checks_set(true)
	page.pause_integrity_checks_set(true)
	assert page.verify_integrity() == none
	page.pause_integrity_checks_set(false)
	assert page.verify_integrity() == none
	page.pause_integrity_checks_set(false)
	assert page.verify_integrity() != none
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
	page.append_grapheme(0, 0, 0x0A) or { panic(err) }
	row0 := page.get_row(0)
	assert row0.grapheme
	assert page.rows[0].cells[0].has_grapheme
	assert page.grapheme_alloc.used_bytes() == grapheme_chunk
	cps1 := page.lookup_grapheme_at(0, 0) or {
		assert false, 'expected grapheme data'
		return
	}
	assert cps1 == [u32(0x0A)]

	// Two
	page.append_grapheme(0, 0, 0x0B) or { panic(err) }
	cps2 := page.lookup_grapheme_at(0, 0) or {
		assert false, 'expected grapheme data'
		return
	}
	assert cps2 == [u32(0x0A), u32(0x0B)]
	assert page.grapheme_alloc.used_bytes() == grapheme_chunk

	// Clear it
	page.clear_grapheme(0, 0)
	page.update_row_grapheme_flag(page.get_row(0))
	assert !page.rows[0].grapheme
	assert !page.rows[0].cells[0].has_grapheme
	assert page.grapheme_alloc.used_bytes() == 0
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
		page.append_grapheme(0, 0, u32(0x0A + i)) or { panic(err) }
	}

	cps := page.lookup_grapheme_at(0, 0) or {
		assert false, 'expected grapheme data'
		return
	}
	assert cps.len == count
	for i in 0 .. count {
		assert cps[i] == u32(0x0A + i)
	}
	assert page.grapheme_alloc.used_bytes() == count * int(sizeof(u32))
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
	page.append_grapheme(0, 0, 0x0A) or { panic(err) }

	// Set up second cell with grapheme.
	mut rac2 := page.get_row_and_cell(1, 0)
	unsafe {
		rac2.cell.content_tag = .codepoint
		rac2.cell.codepoint = 0x09
	}
	page.append_grapheme(0, 1, 0x0A) or { panic(err) }

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
		page.append_grapheme(0, 0, 0x0A) or { panic(err) }
		page.append_grapheme(0, 0, 0x0B) or { panic(err) }
	}

	// Clone it.
	mut page2 := page.clone()
	defer {
		page2.deinit()
	}
	{
		assert page2.rows[0].grapheme
		assert page2.rows[0].cells[0].has_grapheme
		cps := page2.lookup_grapheme_at(0, 0) or {
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

fn test_page_clone_preserves_inline_managed_values() {
	mut page := Page.init(PageCapacity{
		cols: 2
		rows: 1
		styles: 8
	})
	defer { page.deinit() }
	page.size.rows = 1

	style := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}
	style_id := page.styles.add(style) or {
		assert false, 'failed to add style'
		return
	}
	link := Hyperlink{
		id: HyperlinkExplicitId{
			value: 'clone-inline'
		}
		uri: 'https://example.com/clone-inline'
	}
	link_id := page.insert_hyperlink(link) or { panic(err) }
	page.rows[0].styled = true
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`x`)
		style_id: style_id
		style: style
		hyperlink: link.dupe()
	}
	page.set_hyperlink(0, 0, link_id) or { panic(err) }

	mut cloned := page.clone()
	defer { cloned.deinit() }
	cell := cloned.rows[0].cells[0]
	assert cell.style.eql(&style)
	assert cell.hyperlink.eql(&link)
	assert cloned.styles.get(cell.style_id).eql(&style)
	cloned_link_id := cloned.lookup_hyperlink(0, 0) or {
		assert false, 'cloned hyperlink has no mapping'
		return
	}
	assert cloned.hyperlink_set.get(cloned_link_id).eql(&link)
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
	page2.clone_from(&page, 0, page.size.rows) or { panic(err) }
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
	page2.clone_from(&page, 0, page.size.rows) or { panic(err) }
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
	page2.clone_from(&page, 0, 5) or { panic(err) }

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
		page.append_grapheme(y, 1, 0x0A) or { panic(err) }
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
	page2.clone_from(&page, 0, page.size.rows) or { panic(err) }
	page2.size.rows = page.size.rows

	// Read it again.
	for y in 0 .. int(page2.capacity.rows) {
		rac := page2.get_row_and_cell(1, y)
		assert rac.cell.codepoint == u32(y + 1)
		assert page2.rows[y].grapheme
		assert page2.rows[y].cells[1].has_grapheme
		cps := page2.lookup_grapheme_at(y, 1) or {
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
		cps := page2.lookup_grapheme_at(y, 1) or {
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
		page2.append_grapheme(y, 1, 0x0A) or { panic(err) }
	}

	// Clone from page which has no graphemes.
	page2.clone_from(&page, 0, page.size.rows) or { panic(err) }

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
	page2.clone_partial_row_from(&page, 0, 0, 2, 8) or { panic(err) }

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
		page.append_grapheme(0, 0, 0x0A) or { panic(err) }
		page.append_grapheme(0, 9, 0x0A) or { panic(err) }
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
	page2.clone_partial_row_from(&page, 0, 0, 2, 8) or { panic(err) }

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
		page2.append_grapheme(0, 0, 0x0A) or { panic(err) }
		page2.append_grapheme(0, 9, 0x0A) or { panic(err) }
	}

	// Clone partial row (cols 2..8) from page into page2.
	page2.clone_partial_row_from(&page, 0, 0, 2, 8) or { panic(err) }

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
		page.append_grapheme(0, x, 0x0A) or { panic(err) }
	}
	original_count := page.grapheme_count()

	page.move_cells(0, 0, 1, 0, int(page.size.cols))
	assert page.grapheme_count() == original_count

	// New row should have text and graphemes.
	for x in 0 .. int(page.size.cols) {
		rac := page.get_row_and_cell(x, 1)
		assert rac.cell.codepoint == u32(x + 1)
		cps := page.lookup_grapheme_at(1, x) or {
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

fn test_page_clone_partial_row_marks_kitty_virtual_placeholder() {
	mut src := Page.init(PageCapacity{
		cols: 4
		rows: 2
		styles: 8
	})
	defer { src.deinit() }
	src.size.rows = 2
	src.rows[0].cells[2] = CellData{
		content_tag: .codepoint
		codepoint: kitty_unicode_placeholder
	}
	src.set_graphemes(0, 2, [u32(0x0305)]) or { panic(err) }
	src.rows[0].kitty_virtual_placeholder = true

	mut dst := Page.init(PageCapacity{
		cols: 4
		rows: 2
		styles: 8
	})
	defer { dst.deinit() }
	dst.size.rows = 2
	dst.clone_partial_row_from(&src, 0, 0, 1, 3) or { panic(err) }

	assert dst.rows[0].cells[2].codepoint == kitty_unicode_placeholder
	assert dst.rows[0].kitty_virtual_placeholder
}

fn test_page_move_cells_marks_kitty_virtual_placeholder() {
	mut page := Page.init(PageCapacity{
		cols: 4
		rows: 2
		styles: 8
	})
	defer { page.deinit() }
	page.size.rows = 2
	page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: kitty_unicode_placeholder
	}
	page.set_graphemes(0, 1, [u32(0x0305)]) or { panic(err) }
	page.rows[0].kitty_virtual_placeholder = true

	page.move_cells(0, 0, 1, 0, int(page.size.cols))

	assert !page.rows[0].kitty_virtual_placeholder
	assert page.rows[1].cells[1].codepoint == kitty_unicode_placeholder
	assert page.rows[1].kitty_virtual_placeholder
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
		page.append_grapheme(0, x, 0x0A) or { panic(err) }
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
		page.append_grapheme(0, x, 0x0A) or { panic(err) }
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

// Page styles use the same fixed-capacity ref-counted set as Ghostty. They
// must report exhaustion so PageList can grow/split the page instead of
// silently allocating an unbounded side array.
fn test_page_style_set_honors_capacity() {
	mut page := Page.init(PageCapacity{
		cols: 1
		rows: 1
		styles: 8
	})
	defer {
		page.deinit()
	}

	// Layout.init(8) provides six item slots, with ID zero reserved.
	for i in 0 .. 5 {
		page.styles.add(CellStyle{
			fg_color: .rgb
			fg_r: u8(i + 1)
		}) or {
			assert false, 'style ${i} unexpectedly failed'
			return
		}
	}
	if _ := page.styles.add(CellStyle{
		fg_color: .rgb
		fg_r: 99
	}) {
		assert false, 'style set exceeded its page capacity'
	}
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
	assert cap.hyperlink_bytes == 0
	assert cap.string_bytes == 0
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

	// Verify clone works with exact capacity and produces the same result.
	{
		cap := page.exact_row_capacity(0, 5)
		mut cloned := Page.init(cap)
		defer { cloned.deinit() }
		for y in 0 .. 5 {
			cloned.clone_row_from(&page, u16(y), u16(y)) or { panic(err) }
		}
		cloned_cap := cloned.exact_row_capacity(0, 5)
		assert cloned_cap == cap
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
		page.append_grapheme(0, 0, 0x0301) or { panic(err) } // combining acute accent
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
		page.append_grapheme(0, 1, 0x0300) or { panic(err) } // combining grave accent
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
		page.append_grapheme(0, 2, 0x0301) or { panic(err) }
		page.append_grapheme(0, 2, 0x0302) or { panic(err) }
		page.append_grapheme(0, 2, 0x0303) or { panic(err) }
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
		page.append_grapheme(7, 0, 0x0304) or { panic(err) }
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

	// Verify clone works with exact capacity and produces the same result.
	{
		cap := page.exact_row_capacity(0, 5)
		mut cloned := Page.init(cap)
		defer { cloned.deinit() }
		for y in 0 .. 5 {
			cloned.clone_row_from(&page, u16(y), u16(y)) or { panic(err) }
		}
		cloned_cap := cloned.exact_row_capacity(0, 5)
		assert cloned_cap == cap
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
		page.append_grapheme(0, 0, u32(0x0300 + i)) or { panic(err) }
	}

	cap := page.exact_row_capacity(0, 1)
	// 6 codepoints = 24 bytes, rounds up to 32 (2 * grapheme_chunk).
	assert cap.grapheme_bytes == 32

	// Verify clone works with exact capacity and produces the same result.
	mut cloned := Page.init(cap)
	defer { cloned.deinit() }
	cloned.clone_row_from(&page, 0, 0) or { panic(err) }
	cloned_cap := cloned.exact_row_capacity(0, 1)
	assert cloned_cap == cap
}

// Reference values emitted by the pinned Zig implementation. These make the
// logical V layout auditable byte-for-byte even though V uses GC-owned arrays.
fn test_page_capacity_defaults_and_layout_reference() {
	cap := PageCapacity{
		cols: 215
		rows: 215
		styles: 128
	}
	assert cap.hyperlink_bytes == 192
	assert cap.grapheme_bytes == 1024
	assert cap.string_bytes == 2048

	l := Page.layout(cap)
	assert l.total_size == 475136
	assert l.rows_start == 0
	assert l.rows_size == 1720
	assert l.cells_start == 1720
	assert l.cells_size == 369800
	assert l.styles_start == 371520
	assert l.styles_layout.cap == 104
	assert l.styles_layout.table_cap == 128
	assert l.styles_layout.items_start == 256
	assert l.styles_layout.total_size == 4000
	assert l.grapheme_alloc_start == 375520
	assert l.grapheme_alloc_layout.total_size == 16392
	assert l.grapheme_alloc_layout.bitmap_count == 1
	assert l.grapheme_alloc_layout.chunks_start == 8
	assert l.grapheme_map_start == 391912
	assert l.grapheme_map_layout.total_size == 1360
	assert l.grapheme_map_layout.capacity == 64
	assert l.grapheme_map_layout.keys_start == 64
	assert l.grapheme_map_layout.vals_start == 320
	assert l.string_alloc_start == 393272
	assert l.string_alloc_layout.total_size == 65544
	assert l.hyperlink_set_start == 458816
	assert l.hyperlink_set_layout.cap == 3
	assert l.hyperlink_set_layout.table_cap == 4
	assert l.hyperlink_set_layout.items_start == 8
	assert l.hyperlink_set_layout.total_size == 152
	assert l.hyperlink_map_start == 458968
	assert l.hyperlink_map_layout.total_size == 464
	assert l.hyperlink_map_layout.capacity == 64
}

fn test_page_layout_small_and_zero_metadata_reference() {
	l := Page.layout(PageCapacity{
		cols: 80
		rows: 128
		styles: 16
	})
	assert l.total_size == 180224
	assert l.rows_size == 1024
	assert l.cells_start == 1024
	assert l.cells_size == 81920
	assert l.styles_start == 82944
	assert l.styles_layout.total_size == 500
	assert l.grapheme_alloc_start == 83448
	assert l.grapheme_map_start == 99840
	assert l.string_alloc_start == 101200
	assert l.hyperlink_set_start == 166744
	assert l.hyperlink_map_start == 166896

	zero := Page.layout(PageCapacity{
		cols: 10
		rows: 10
		styles: 0
		hyperlink_bytes: 0
		grapheme_bytes: 0
		string_bytes: 0
	})
	assert zero.total_size == 16384
	assert zero.rows_size == 80
	assert zero.cells_start == 80
	assert zero.cells_size == 800
	assert zero.styles_start == 880
	assert zero.grapheme_alloc_start == 880
	assert zero.grapheme_map_start == 880
	assert zero.grapheme_map_layout.total_size == 16
	assert zero.string_alloc_start == 896
	assert zero.hyperlink_set_start == 896
	assert zero.hyperlink_map_start == 896
	assert zero.hyperlink_map_layout.total_size == 16
}

fn test_standard_page_layout_and_capacity_adjust_reference() {
	l := Page.layout(std_capacity)
	assert l.total_size == 589824
	assert l.grapheme_alloc_start == 375520
	assert l.grapheme_alloc_layout.total_size == 131136
	assert l.grapheme_alloc_layout.bitmap_count == 8
	assert l.grapheme_map_start == 506656
	assert l.grapheme_map_layout.total_size == 10768
	assert l.string_alloc_start == 517424
	assert l.hyperlink_set_start == 582968
	assert l.hyperlink_map_start == 583120
	max_cols := std_capacity.max_cols() or {
		assert false, 'maxCols returned none'
		return
	}
	assert max_cols == u16(47219)

	cap80 := std_capacity.adjust_checked(80) or {
		assert false, 'capacity adjustment failed'
		return
	}
	assert cap80.rows == 582
	cap500 := std_capacity.adjust_checked(500) or {
		assert false, 'capacity adjustment failed'
		return
	}
	assert cap500.rows == 94
}

fn test_page_managed_map_capacities_follow_layout() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	defer { page.deinit() }
	assert page.grapheme_capacity() == 64
	assert page.hyperlink_capacity() == 64

	mut empty := Page.init(PageCapacity{
		cols: 1
		rows: 1
		grapheme_bytes: 0
		hyperlink_bytes: 0
	})
	defer { empty.deinit() }
	assert empty.grapheme_capacity() == 0
	assert empty.hyperlink_capacity() == 0
}

fn test_page_set_graphemes_enforces_map_capacity_and_rolls_back_allocation() {
	mut page := Page.init(PageCapacity{
		cols: 2
		rows: 1
		grapheme_bytes: 16
	})
	defer { page.deinit() }
	page.size.rows = 1
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`a`)
	}
	page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(`b`)
	}
	assert page.grapheme_capacity() == 1
	page.set_graphemes(0, 0, [u32(0x0301)]) or { panic(err) }
	assert page.grapheme_alloc.used_bytes() == grapheme_chunk

	mut error_message := ''
	page.set_graphemes(0, 1, [u32(0x0302)]) or { error_message = err.msg() }
	assert error_message == 'GraphemeMapOutOfMemory'
	assert page.grapheme_count() == 1
	assert page.grapheme_alloc.used_bytes() == grapheme_chunk
	assert !page.rows[0].cells[1].has_grapheme
}

fn test_page_set_graphemes_enforces_allocator_capacity() {
	mut page := Page.init(PageCapacity{
		cols: 2
		rows: 1
	})
	defer { page.deinit() }
	page.size.rows = 1
	page.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`a`)
	}
	page.rows[0].cells[1] = CellData{
		content_tag: .codepoint
		codepoint: u32(`b`)
	}
	page.set_graphemes(0, 0, []u32{len: int(grapheme_bytes_default / 4) - 1, init: u32(`x`)}) or {
		panic(err)
	}
	assert page.grapheme_alloc.used_bytes() == int(grapheme_bytes_default)

	mut error_message := ''
	page.append_grapheme(0, 1, 0x0301) or { error_message = err.msg() }
	assert error_message == 'GraphemeAllocOutOfMemory'
	assert page.grapheme_count() == 1
	assert !page.rows[0].cells[1].has_grapheme
}

fn test_page_set_hyperlink_reports_full_map_without_mutating_cell() {
	mut page := Page.init(PageCapacity{
		cols: 9
		rows: 8
	})
	defer { page.deinit() }
	page.size.rows = page.capacity.rows
	id := page.insert_hyperlink(Hyperlink{
		uri: 'https://example.com/full'
	}) or { panic(err) }
	for key in 0 .. page.hyperlink_capacity() {
		y := key / int(page.size.cols)
		x := key % int(page.size.cols)
		if key > 0 {
			page.hyperlink_set.use_link(id)
		}
		page.set_hyperlink(y, x, id) or { panic(err) }
	}

	mut failed := false
	page.hyperlink_set.use_link(id)
	page.set_hyperlink(7, 1, id) or { failed = true }
	assert failed
	page.hyperlink_set.release(id)
	assert page.hyperlink_count() == page.hyperlink_capacity()
	assert !page.rows[7].cells[1].has_hyperlink
}

// Translated from Ghostty's "Page cloneFrom hyperlinks exact capacity".
fn test_page_clone_from_hyperlinks_exact_capacity() {
	mut page := Page.init(PageCapacity{
		cols: 50
		rows: 50
	})
	defer { page.deinit() }
	page.size.rows = page.capacity.rows

	hyperlink_cap := page.hyperlink_capacity()
	assert hyperlink_cap <= int(page.size.cols) * int(page.size.rows)
	id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{}
		uri: 'https://example.com'
	}) or { panic(err) }

	mut full := false
	for x in 0 .. int(page.size.cols) {
		for y in 0 .. int(page.size.rows) {
			page.rows[y].cells[x] = CellData{
				content_tag: .codepoint
				codepoint: 42
			}
			if page.hyperlink_count() > 0 {
				page.hyperlink_set.use_link(id)
			}
			page.set_hyperlink(y, x, id) or { panic(err) }
			if page.hyperlink_count() == hyperlink_cap {
				full = true
				break
			}
		}
		if full {
			break
		}
	}
	assert page.hyperlink_count() == page.hyperlink_capacity()

	mut cloned := Page.init(page.capacity)
	defer { cloned.deinit() }
	cloned.size.rows = page.size.rows
	cloned.clone_from(&page, 0, page.size.rows) or { panic(err) }
	assert cloned.hyperlink_count() == page.hyperlink_count()
}

fn test_page_insert_hyperlink_enforces_string_allocator_capacity() {
	mut page := Page.init(PageCapacity{
		cols: 2
		rows: 1
	})
	defer { page.deinit() }
	page.size.rows = 1
	_ := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{}
		uri: 'a'.repeat(int(string_bytes_default) - 1)
	}) or { panic(err) }
	assert page.hyperlink_set.string_used() == int(string_bytes_default)

	mut error_message := ''
	_ := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{ offset: 1 }
		uri: 'AAAAAAAAAAAAAAAAAAAAAAAAAA'
	}) or {
		error_message = err.msg()
		u32(0)
	}
	assert error_message == 'strings out of memory'
	assert page.hyperlink_set.string_used() == int(string_bytes_default)
}

fn test_page_capacity_adjust_no_columns_request() {
	original := std_capacity
	adjusted := original.adjust_checked(none)!
	assert adjusted == original
}

fn test_page_capacity_adjust_zero_columns_is_not_noop() {
	original := std_capacity
	adjusted := original.adjust_checked(u16(0))!
	assert adjusted.cols == 0
	assert adjusted.rows == u16(original.available_bits_for_grid() / row_bit_size)
	assert Page.layout(adjusted).total_size == Page.layout(original).total_size
}

fn test_page_capacity_adjust_cols_sweep_preserves_total_size() {
	mut cap := std_capacity
	original_cols := cap.cols
	original_size := Page.layout(cap).total_size
	for c in 1 .. int(original_cols) * 2 {
		cap = cap.adjust_checked(u16(c))!
		assert Page.layout(cap).total_size == original_size

		mut bigger := cap
		bigger.rows++
		assert Page.layout(bigger).total_size > original_size
	}
}

fn test_page_capacity_max_cols_preserves_size_and_uses_one_row() {
	cap := std_capacity
	max := cap.max_cols() or { panic('maxCols returned none') }
	adjusted := cap.adjust_checked(max)!
	assert Page.layout(adjusted).total_size == Page.layout(cap).total_size
	assert adjusted.rows == 1
}

// Test capacity adjust cols down.
fn test_page_capacity_adjust_cols_down() {
	original := PageCapacity{
		cols: 80
		rows: 128
	}
	adjusted := original.adjust_checked(original.cols / 2) or {
		assert false, 'capacity adjustment failed'
		return
	}
	// Adjusted should have more rows (same total budget).
	assert adjusted.cols == original.cols / 2
	assert adjusted.rows > original.rows
	// The packed row metadata is part of the budget. The result consumes the
	// greatest whole number of rows that fits the original allocation.
	budget := original.available_bits_for_grid()
	used := usize(adjusted.rows) * (row_bit_size + cell_bit_size * usize(adjusted.cols))
	assert used <= budget
	assert used + row_bit_size + cell_bit_size * usize(adjusted.cols) > budget
}

// Test capacity adjust cols down to 1.
fn test_page_capacity_adjust_cols_down_to_1() {
	original := PageCapacity{
		cols: 80
		rows: 128
	}
	adjusted := original.adjust_checked(1) or {
		assert false, 'capacity adjustment failed'
		return
	}
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
	adjusted := original.adjust_checked(original.cols * 2) or {
		assert false, 'capacity adjustment failed'
		return
	}
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
	max := original.max_cols() or {
		assert false, 'maxCols returned none'
		return
	}
	assert max < max_u16
	mut failed := false
	original.adjust_checked(max + 1) or { failed = true }
	assert failed
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
	adjusted := cap.adjust_checked(max) or {
		assert false, 'maxCols adjustment failed'
		return
	}
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
		id: HyperlinkExplicitId{ value: '' }
	}) or { panic(err) }

	// Set it on a cell.
	page.set_hyperlink(0, 0, hl_id) or { panic(err) }
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
		page.append_grapheme(0, x, 0x0A) or { panic(err) }
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

fn test_page_clear_cells_clears_false_positive_kitty_placeholder_flag() {
	mut page := Page.init(PageCapacity{
		cols: 4
		rows: 1
	})
	defer { page.deinit() }
	page.size.rows = 1

	// The row aggregate is allowed to remain a false positive after some
	// operations; a full clear repairs it when no placeholder cell exists.
	page.rows[0].kitty_virtual_placeholder = true
	page.rows[0].cells[0] = CellData.init(u32(`x`))
	page.clear_cells(0, 0, page.size.cols)
	assert !page.rows[0].kitty_virtual_placeholder
}

fn test_page_clear_cells_preserves_dirty_state() {
	mut page := Page.init(PageCapacity{
		cols: 4
		rows: 1
	})
	defer { page.deinit() }
	page.size.rows = 1
	page.rows[0].cells[0] = CellData.init(u32(`x`))

	page.clear_cells(0, 0, page.size.cols)
	assert !page.rows[0].dirty

	page.rows[0].dirty = true
	page.clear_cells(0, 0, page.size.cols)
	assert page.rows[0].dirty
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

fn test_page_swap_cells_swaps_grapheme_and_hyperlink_mappings() {
	mut page := Page.init(PageCapacity{
		cols: 2
		rows: 1
		styles: 0
		hyperlink_bytes: 32 * 48
		grapheme_bytes: grapheme_chunk * 2
		string_bytes: 64
	})
	defer { page.deinit() }
	page.rows[0].cells[0] = CellData.init(u32(`A`))
	page.rows[0].cells[1] = CellData.init(u32(`B`))
	page.set_graphemes(0, 0, [u32(0x0301)]) or { panic(err) }
	page.set_graphemes(0, 1, [u32(0x0302)]) or { panic(err) }

	link_a := Hyperlink{ id: HyperlinkImplicitId{ offset: 1 }, uri: 'a' }
	link_b := Hyperlink{ id: HyperlinkImplicitId{ offset: 2 }, uri: 'b' }
	id_a := page.insert_hyperlink(link_a) or { panic(err) }
	id_b := page.insert_hyperlink(link_b) or { panic(err) }
	page.set_hyperlink(0, 0, id_a) or { panic(err) }
	page.set_hyperlink(0, 1, id_b) or { panic(err) }
	page.rows[0].cells[0].hyperlink = link_a.dupe()
	page.rows[0].cells[1].hyperlink = link_b.dupe()

	page.swap_cells(0, 0, 1)

	assert page.rows[0].cells[0].codepoint == u32(`B`)
	assert page.rows[0].cells[1].codepoint == u32(`A`)
	assert page.lookup_grapheme_at(0, 0) or { panic('missing grapheme') } == [
		u32(0x0302),
	]
	assert page.lookup_grapheme_at(0, 1) or { panic('missing grapheme') } == [
		u32(0x0301),
	]
	assert page.lookup_hyperlink(0, 0) or { panic('missing hyperlink') } == id_b
	assert page.lookup_hyperlink(0, 1) or { panic('missing hyperlink') } == id_a
	assert page.hyperlink_set.ref_count(id_a) == 1
	assert page.hyperlink_set.ref_count(id_b) == 1
	assert page.verify_integrity() == none
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
	assert page.size == PageSize{
		cols: 10
		rows: 10
	}

	// Should be blank now.
	{
		rac := page.get_row_and_cell(0, 0)
		assert rac.cell.codepoint == 0
	}
}

// Test capacity adjust with same cols and larger cols.
fn test_page_capacity_adjust() {
	cap := PageCapacity{
		cols: 80
		rows: 128
	}

	// The page-alignment slack may fit additional rows even at the same width.
	adj := cap.adjust_checked(80) or {
		assert false, 'capacity adjustment failed'
		return
	}
	assert adj.cols == 80
	assert adj.rows >= 128
	used := usize(adj.rows) * (row_bit_size + cell_bit_size * usize(adj.cols))
	assert used <= cap.available_bits_for_grid()

	// Very large cols - rows should reduce
	adj2 := cap.adjust_checked(512) or {
		assert false, 'capacity adjustment failed'
		return
	}
	assert adj2.cols == 512
	assert adj2.rows < 128
}

// Test clone_partial_row_from with a hyperlink in the same page, where the
// hyperlink cell IS within the copied range.
fn test_page_clone_row_from_partial_hyperlink_in_same_page_copy() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// We need to create a hyperlink.
	link := Hyperlink{
		id: HyperlinkImplicitId{
			offset: 0
		}
		uri: 'https://example.com/partial-inline'
	}
	hyperlink_id := page.insert_hyperlink(link) or { panic(err) }

	// Write
	{
		for x in 0 .. int(page.size.cols) {
			mut rac := page.get_row_and_cell(x, 0)
			unsafe {
				rac.cell.content_tag = .codepoint
				rac.cell.codepoint = u32(x + 1)
			}
		}

		// Hyperlink in a single cell.
		page.rows[0].cells[7].hyperlink = link.dupe()
		page.set_hyperlink(0, 7, hyperlink_id) or { panic(err) }
	}
	assert page.hyperlink_count() == 1

	// Clone into the same page (cols 2..8, so cell 7 IS copied).
	page.clone_partial_row_from(&page, 1, 0, 2, 8) or { panic(err) }

	// Read it again.
	{
		for x in 0 .. int(page.size.cols) {
			expected := if x >= 2 && x < 8 { u32(x + 1) } else { u32(0) }
			rac := page.get_row_and_cell(x, 1)
			assert rac.cell.codepoint == expected
		}
		{
			rac := page.get_row_and_cell(7, 1)
			assert rac.row.hyperlink
			assert rac.cell.has_hyperlink
			assert rac.cell.hyperlink.eql(&link)
		}
	}
	assert page.hyperlink_count() == 2
}

// Test clone_partial_row_from with a hyperlink in the same page, where the
// hyperlink cell is OUTSIDE the copied range (omitted).
fn test_page_clone_row_from_partial_hyperlink_in_same_page_omit() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// We need to create a hyperlink.
	hyperlink_id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 0
		}
		uri: ''
	}) or { panic(err) }

	// Write
	{
		for x in 0 .. int(page.size.cols) {
			mut rac := page.get_row_and_cell(x, 0)
			unsafe {
				rac.cell.content_tag = .codepoint
				rac.cell.codepoint = u32(x + 1)
			}
		}

		// Hyperlink in a single cell.
		page.set_hyperlink(0, 7, hyperlink_id) or { panic(err) }
	}
	assert page.hyperlink_count() == 1

	// Clone into the same page (cols 2..6, so cell 7 is NOT copied).
	page.clone_partial_row_from(&page, 1, 0, 2, 6) or { panic(err) }

	// Read it again.
	{
		for x in 0 .. int(page.size.cols) {
			expected := if x >= 2 && x < 6 { u32(x + 1) } else { u32(0) }
			rac := page.get_row_and_cell(x, 1)
			assert rac.cell.codepoint == expected
		}
		{
			rac := page.get_row_and_cell(7, 1)
			assert !rac.row.hyperlink
			assert !rac.cell.has_hyperlink
		}
	}
	assert page.hyperlink_count() == 1
}

// Regression test: verify a single style can be cloned with exact capacity.
// This tests that capacity_for_count properly accounts for ID 0 being reserved.
fn test_page_exact_row_capacity_single_style_clone() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 2
		styles: 8
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Add exactly one style to row 0.
	style_id := page.styles.add(CellStyle{
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
			rac.cell.style_id = style_id
		}
	}

	// exactRowCapacity for just row 0 should give capacity for 1 style.
	cap := page.exact_row_capacity(0, 1)
	assert cap.styles == StyleSet.capacity_for_count(1)

	// Create a new page with exact capacity and clone.
	mut cloned := Page.init(cap)
	defer {
		cloned.deinit()
	}
	cloned.size.rows = u16(cloned.capacity.rows)

	// This must not fail with a style capacity error.
	cloned.clone_row_from(&page, 0, 0) or { panic(err) }

	// Verify the style was cloned correctly.
	assert cloned.rows[0].cells[0].style_id != default_style_id
}

fn test_page_clone_row_reports_bounded_style_failure() {
	mut src := Page.init(PageCapacity{
		cols: 1
		rows: 1
		styles: u16(StyleSet.capacity_for_count(1))
	})
	defer { src.deinit() }
	style_id := src.styles.add(CellStyle{ flags: StyleFlags{ bold: true } }) or {
		panic(err)
	}
	src.rows[0].cells[0] = CellData{
		content_tag: .codepoint
		codepoint: u32(`a`)
		style_id: style_id
	}
	src.rows[0].styled = true

	mut dst := Page.init(PageCapacity{
		cols: 1
		rows: 1
		styles: 0
	})
	defer { dst.deinit() }
	mut reported := false
	dst.clone_row_from(&src, 0, 0) or {
		reported = err.msg() == PageCloneError.style_set_out_of_memory.str()
	}
	assert reported
}

fn test_page_clone_row_preserves_integrity_after_late_managed_memory_failure() {
	mut src := Page.init(PageCapacity{
		cols: 1
		rows: 1
		styles: 0
		hyperlink_bytes: 32 * 48
		grapheme_bytes: grapheme_chunk
		string_bytes: 128
	})
	defer { src.deinit() }
	src.rows[0].cells[0] = CellData.init(u32(`a`))
	src.set_graphemes(0, 0, [u32(0x0301)]) or { panic(err) }
	link_id := src.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{ offset: 1 }
		uri: 'https://example.com'
	}) or { panic(err) }
	src.set_hyperlink(0, 0, link_id) or { panic(err) }

	mut dst := Page.init(PageCapacity{
		cols: 1
		rows: 1
		styles: 0
		hyperlink_bytes: 32 * 48
		grapheme_bytes: grapheme_chunk
		string_bytes: 0
	})
	defer { dst.deinit() }
	mut error_message := ''
	dst.clone_row_from(&src, 0, 0) or { error_message = err.msg() }

	assert error_message == PageCloneError.string_alloc_out_of_memory.str()
	assert dst.rows[0].cells[0].codepoint == u32(`a`)
	assert dst.rows[0].cells[0].has_grapheme
	assert dst.rows[0].cells[0].graphemes == [u32(0x0301)]
	assert !dst.rows[0].cells[0].has_hyperlink
	assert dst.lookup_hyperlink(0, 0) == none
	assert dst.verify_integrity() == none
}

fn test_page_clone_partial_row_deduplicates_hyperlink_before_allocating_strings() {
	link := Hyperlink{
		id: HyperlinkExplicitId{ value: 'same' }
		uri: 'https://example.com'
	}
	mut src := Page.init(PageCapacity{
		cols: 2
		rows: 1
		styles: 0
		hyperlink_bytes: 32 * 48
		string_bytes: 64
	})
	defer { src.deinit() }
	src_id := src.insert_hyperlink(link) or { panic(err) }
	src.set_hyperlink(0, 1, src_id) or { panic(err) }
	src.rows[0].cells[1].hyperlink = link.dupe()

	mut dst := Page.init(PageCapacity{
		cols: 2
		rows: 1
		styles: 0
		hyperlink_bytes: 32 * 48
		string_bytes: 64
	})
	defer { dst.deinit() }
	dst_id := dst.insert_hyperlink(link) or { panic(err) }
	dst.set_hyperlink(0, 0, dst_id) or { panic(err) }
	dst.rows[0].cells[0].hyperlink = link.dupe()
	assert dst.hyperlink_set.string_used() == 64

	dst.clone_partial_row_from(&src, 0, 0, 1, 2) or { panic(err) }

	cloned_id := dst.lookup_hyperlink(0, 1) or { panic('cloned hyperlink missing') }
	assert cloned_id == dst_id
	assert dst.hyperlink_set.ref_count(dst_id) == 2
	assert dst.hyperlink_set.string_used() == 64
	assert dst.verify_integrity() == none
}

fn test_page_clone_reports_grapheme_allocator_failure_before_map_failure() {
	mut src := Page.init(PageCapacity{
		cols: 1
		rows: 1
		styles: 0
		grapheme_bytes: grapheme_chunk
	})
	defer { src.deinit() }
	src.rows[0].cells[0] = CellData.init(u32(`a`))
	src.set_graphemes(0, 0, [u32(0x0301)]) or { panic(err) }

	mut dst := Page.init(PageCapacity{
		cols: 1
		rows: 2
		styles: 0
		grapheme_bytes: grapheme_chunk
	})
	defer { dst.deinit() }
	dst.rows[1].cells[0] = CellData.init(u32(`b`))
	dst.set_graphemes(1, 0, [u32(0x0302)]) or { panic(err) }
	remaining := dst.grapheme_alloc.capacity_bytes() - grapheme_chunk
	_ := dst.grapheme_alloc.alloc(remaining) or { panic('failed to fill grapheme allocator') }

	mut error_message := ''
	dst.clone_row_from(&src, 0, 0) or { error_message = err.msg() }
	assert error_message == PageCloneError.grapheme_alloc_out_of_memory.str()
	assert !dst.rows[0].cells[0].has_grapheme
	assert dst.grapheme_count() == 1
	assert dst.verify_integrity() == none
}

// Test exactRowCapacity styles with a maxed-out single row.
fn test_page_exact_row_capacity_styles_max_single_row() {
	mut page := Page.init(PageCapacity{
		cols: 1000
		rows: 1
		styles: max_u16
	})
	defer {
		page.deinit()
	}
	page.size.rows = u16(page.capacity.rows)

	// Style our first row.
	page.rows[0].styled = true

	// Fill cells with styles until we get OOM, but limit to a reasonable count
	// to avoid overflow when computing capacity_for_count near maxInt.
	mut count := usize(0)
	max_count := 1000 // Limit to avoid overflow in capacity calculation.
	for i in 0 .. int(page.size.cols) {
		if count >= max_count {
			break
		}
		style_id := page.styles.add(CellStyle{
			fg_color: .rgb
			fg_r: u8(i & 0xFF)
			fg_g: u8((i >> 8) & 0xFF)
			fg_b: 0
		}) or { break }
		unsafe {
			page.rows[0].cells[i].style_id = style_id
		}
		count++
	}

	// Verify we added a meaningful number of styles.
	assert count > 0

	// Capacity should be at least count (adjusted for load factor).
	cap := page.exact_row_capacity(0, 1)
	assert cap.styles == StyleSet.capacity_for_count(count)
}

fn test_page_exact_row_capacity_hyperlinks() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 10
		styles: 8
		hyperlink_bytes: 32 * 48
		string_bytes: 512
	})
	defer { page.deinit() }
	page.size.rows = page.capacity.rows

	empty := page.exact_row_capacity(0, 5)
	assert empty.hyperlink_bytes == 0
	assert empty.string_bytes == 0

	id1 := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 1
		}
		uri: 'https://example.com'
	}) or { panic(err) }
	page.set_hyperlink(0, 0, id1) or { panic(err) }
	cap_one := page.exact_row_capacity(0, 5)
	assert cap_one.hyperlink_bytes == u16(HyperlinkSet.capacity_for_count(1) * 48)
	assert cap_one.string_bytes == string_chunk

	page.hyperlink_set.use_link(id1)
	page.set_hyperlink(0, 1, id1) or { panic(err) }
	duplicate := page.exact_row_capacity(0, 5)
	assert duplicate.hyperlink_bytes == cap_one.hyperlink_bytes
	assert duplicate.string_bytes == cap_one.string_bytes

	id2 := page.insert_hyperlink(Hyperlink{
		id: HyperlinkExplicitId{
			value: 'my-link-id'
		}
		uri: 'https://other.example.org/path'
	}) or { panic(err) }
	page.set_hyperlink(0, 2, id2) or { panic(err) }
	cap_two := page.exact_row_capacity(0, 5)
	assert cap_two.hyperlink_bytes == u16(HyperlinkSet.capacity_for_count(2) * 48)
	assert cap_two.string_bytes == string_chunk * 3

	id3 := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 99
		}
		uri: 'https://outside.example.com'
	}) or { panic(err) }
	page.set_hyperlink(7, 0, id3) or { panic(err) }
	ranged := page.exact_row_capacity(0, 5)
	assert ranged.hyperlink_bytes == cap_two.hyperlink_bytes
	assert ranged.string_bytes == cap_two.string_bytes

	full := page.exact_row_capacity(0, 10)
	assert full.hyperlink_bytes == u16(HyperlinkSet.capacity_for_count(3) * 48)
	assert full.string_bytes == string_chunk * 4

	mut cloned := Page.init(cap_two)
	defer { cloned.deinit() }
	cloned.size.rows = cap_two.rows
	for y in 0 .. 5 {
		cloned.clone_row_from(&page, u16(y), u16(y)) or { panic(err) }
	}
	cloned_cap := cloned.exact_row_capacity(0, 5)
	assert cloned_cap == cap_two
}

fn test_page_exact_row_capacity_single_hyperlink_clone() {
	mut page := Page.init(PageCapacity{
		cols: 10
		rows: 2
		styles: 8
		hyperlink_bytes: 32 * 48
		string_bytes: 512
	})
	defer { page.deinit() }
	page.size.rows = page.capacity.rows

	id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 1
		}
		uri: 'https://example.com'
	}) or { panic(err) }
	page.set_hyperlink(0, 0, id) or { panic(err) }
	cap := page.exact_row_capacity(0, 1)
	assert cap.hyperlink_bytes == u16(HyperlinkSet.capacity_for_count(1) * 48)

	mut cloned := Page.init(cap)
	defer { cloned.deinit() }
	cloned.size.rows = cap.rows
	cloned.clone_row_from(&page, 0, 0) or { panic(err) }
	assert cloned.rows[0].cells[0].has_hyperlink
}

fn test_page_exact_row_capacity_hyperlink_map_for_many_cells() {
	cols := u16(50)
	mut page := Page.init(PageCapacity{
		cols: cols
		rows: 2
		styles: 8
		hyperlink_bytes: 32 * 48
		string_bytes: 512
	})
	defer { page.deinit() }
	page.size.rows = page.capacity.rows

	id := page.insert_hyperlink(Hyperlink{
		id: HyperlinkImplicitId{
			offset: 1
		}
		uri: 'https://example.com'
	}) or { panic(err) }
	page.set_hyperlink(0, 0, id) or { panic(err) }
	for x in 1 .. int(cols) {
		page.hyperlink_set.use_link(id)
		page.set_hyperlink(0, x, id) or { panic(err) }
	}

	cap := page.exact_row_capacity(0, 1)
	min_for_map := (int(cols) + hyperlink_cell_multiplier - 1) / hyperlink_cell_multiplier
	assert cap.hyperlink_bytes >= u16(min_for_map * 48)

	mut cloned := Page.init(cap)
	defer { cloned.deinit() }
	cloned.size.rows = cap.rows
	cloned.clone_row_from(&page, 0, 0) or { panic(err) }
	for x in 0 .. int(cols) {
		assert cloned.rows[0].cells[x].has_hyperlink
	}
}
