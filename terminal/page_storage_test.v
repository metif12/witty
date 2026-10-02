module terminal

import lib_allocator

fn test_page_caller_buffer_and_memcpy_relocation_own_all_storage() ! {
	allocator := lib_allocator.c_allocator_value()
	cap := PageCapacity{ cols: 4, rows: 2, styles: 16 }
	layout := Page.layout(cap)
	mut alignment := u8(0)
	for (usize(1) << alignment) < page_memory_alignment() { alignment++ }
	backing := allocator.alloc_bytes(layout.total_size, alignment, 0)
	assert !isnil(backing)
	defer { allocator.free_bytes(backing, layout.total_size, alignment, 0) }
	unsafe { vmemset(backing, 0, int(layout.total_size)) }
	mut source := Page.init_buf(OffsetBuf.init(unsafe { &u8(backing) }), layout)
	source.rows[0].cells[0] = CellData.init(u32(`A`))
	source.rows[0].cells[0].wide = .wide
	source.rows[0].cells[0].is_protected = true
	source.rows[0].cells[0].semantic_content = .prompt
	source.rows[0].header.wrap = true
	source.rows[0].header.semantic_prompt = .prompt
	source.rows[0].header.dirty = true
	word := unsafe { *(&u64(source.rows[0].cells.data)) }
	row_word := unsafe { *(&u64(source.rows[0].header)) }
	assert word == (u64(65) << 2) | (u64(1) << 42) | (u64(1) << 44) | (u64(2) << 46)
	assert row_word == u64(layout.cells_start) | (u64(1) << 32) | (u64(1) << 37) | (u64(1) << 40)
	style_id := source.styles.add(CellStyle{ fg_color: StyleColorPalette{ index: 42 }, flags: StyleFlags{ value: 1 } })!
	source.rows[0].cells[0].style_id = style_id
	source.rows[0].header.styled = true
	source.append_grapheme(0, 0, 0x301)!
	link_id := source.insert_hyperlink(Hyperlink{ id: HyperlinkImplicitId{ offset: 0x11223344 }, uri: 'https://example.com' })!
	source.set_hyperlink(0, 0, link_id)!
	assert usize(source.styles.set.items_offset.ptr(source.styles.base)) >= usize(backing)
	assert usize(source.hyperlink_set.string_alloc.chunks.data) < usize(backing) + layout.total_size
	assert usize(source.grapheme_alloc.chunks.data) < usize(backing) + layout.total_size
	clone_backing := allocator.alloc_bytes(layout.total_size, alignment, 0)
	assert !isnil(clone_backing)
	defer { allocator.free_bytes(clone_backing, layout.total_size, alignment, 0) }
	mut clone := source.clone_buf(lib_allocator.borrowed_array[u8](clone_backing, int(layout.total_size), int(layout.total_size)))
	assert clone.memory.data != source.memory.data
	assert clone.memory == source.memory
	// Modify all old storage. No cloned descriptor may keep the old base.
	source.reinit()
	mut rows := clone.rows[..2]
	rotate_row_views(mut rows, false)
	assert clone.rows[1].cells[0].codepoint() == u32(`A`)
	assert clone.lookup_grapheme_at(1, 0) or { panic('missing') } == [u32(0x301)]
	assert clone.styles.get(style_id).fg_color is StyleColorPalette
	link := clone.hyperlink_set.get(link_id)
	assert link.uri == 'https://example.com'
	assert link.id is HyperlinkImplicitId
	assert link.id.offset == 0x11223344
	assert clone.lookup_hyperlink_at(1, 0) or { panic('missing') } == link_id
	assert clone.rows[1].header.cells_offset == u32(layout.cells_start)
	assert source.rows[0].cells[0].is_zero()
	clone.clear_cells(1, 0, 1)
	assert clone.grapheme_alloc.used_bytes() == 0
	assert clone.hyperlink_set.ref_count(link_id) == 0
	clone.insert_hyperlink(Hyperlink{ id: HyperlinkImplicitId{ offset: 7 }, uri: 'https://other.example' })!
	assert clone.hyperlink_set.string_used() == 32
}

fn test_page_native_mmap_error_and_packed_sizes() {
	assert sizeof(CellData) == 8
	assert sizeof(PageRowHeader) == 8
	assert sizeof(StoredStyle) == 28
	assert sizeof(StoredHyperlink) == 40
	assert sizeof(GenericRefSetItem[StoredStyle, u16, u16]) == 36
	assert sizeof(GenericRefSetItem[StoredHyperlink, u16, u16]) == 48
	assert isnil(C.witty_page_mmap(~usize(0)))
}

fn test_page_cell_union_members_have_original_bit_widths() {
	mut cell := CellData.from_color_payload(.bg_color_rgb, 0xE23456)
	assert cell.color_rgb_r() == 0x56 && cell.color_rgb_g() == 0x34 && cell.color_rgb_b() == 0xE2
	// Writing the u21 codepoint member preserves the union's upper three bits.
	cell.content_tag = .codepoint
	cell.codepoint = 65
	assert cell.codepoint() == 65
	cell.codepoint = 0
	assert !cell.is_zero()
	cell.codepoint = 65
	word := unsafe { *(&u64(&cell)) }
	assert (word >> 2) & 0xFFFFFF == 0xE00041
}
