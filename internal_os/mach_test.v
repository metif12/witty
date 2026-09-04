module internal_os

fn test_vm_tag_make() {
	assert u32(VMTag.application_specific_1.make()) == u32(240) << 24
	assert u32(VMTag.application_specific_16.make()) == u32(255) << 24
}

fn test_tagged_page_allocator_alignment_zeroing_resize_and_free() {
	page_size := tagged_page_size()
	allocator := tagged_page_allocator(.application_specific_1)
	mut memory := allocator.alloc(page_size * 3 - 7, page_size * 2) or {
		assert false, 'tagged page allocation failed'
		return
	}
	assert usize(memory.ptr) % (page_size * 2) == 0
	assert memory.len == page_size * 3 - 7
	assert memory.mapped_len == page_size * 3
	unsafe {
		bytes := &u8(memory.ptr)
		assert bytes[0] == 0
		assert bytes[memory.len - 1] == 0
		bytes[0] = 0x5a
	}

	assert memory.resize(page_size + 1)
	assert memory.len == page_size + 1
	assert memory.mapped_len == page_size * 2
	unsafe {
		assert (&u8(memory.ptr))[0] == 0x5a
	}
	memory.deinit()
	assert isnil(memory.ptr)
}
