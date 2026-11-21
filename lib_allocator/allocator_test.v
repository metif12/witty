module lib_allocator

struct CountingAllocator {
mut:
	allocs   int
	remaps   int
	frees    int
	last_len uint
}

fn counting_alloc(ctx voidptr, len uint, _ u8, _ uint) voidptr {
	mut state := unsafe { &CountingAllocator(ctx) }
	state.allocs++
	state.last_len = len
	return unsafe { malloc(if len == 0 { uint(1) } else { len }) }
}

fn counting_resize(ctx voidptr, _ voidptr, memory_len uint, _ u8, new_len uint, _ uint) bool {
	mut state := unsafe { &CountingAllocator(ctx) }
	state.last_len = new_len
	return new_len <= memory_len
}

fn counting_remap(ctx voidptr, memory voidptr, memory_len uint, _ u8, new_len uint, _ uint) voidptr {
	mut state := unsafe { &CountingAllocator(ctx) }
	state.remaps++
	state.last_len = new_len
	return unsafe { realloc_data(&u8(memory), int(memory_len), int(new_len)) }
}

fn counting_free(ctx voidptr, memory voidptr, _ uint, _ u8, _ uint) {
	mut state := unsafe { &CountingAllocator(ctx) }
	state.frees++
	unsafe { free(memory) }
}

fn test_custom_allocator_round_trip_and_operations() {
	assert sizeof(VTable) == sizeof(voidptr) * 4
	assert sizeof(Allocator) == sizeof(voidptr) * 2
	mut state := CountingAllocator{}
	vtable := VTable{
		alloc: counting_alloc
		resize: counting_resize
		remap: counting_remap
		free_fn: counting_free
	}
	original := Allocator{
		ctx: &state
		vtable: &vtable
	}
	c_side := Allocator.from_zig(&original)
	allocator := c_side.zig()

	ptr := allocator.alloc_bytes(8, 1, 0)
	assert !isnil(ptr)
	assert state.allocs == 1
	assert state.last_len == 8
	assert allocator.resize_bytes(ptr, 8, 1, 4, 0)
	assert !allocator.resize_bytes(ptr, 4, 1, 16, 0)
	remapped := allocator.remap_bytes(ptr, 4, 1, 16, 0)
	assert !isnil(remapped)
	assert state.remaps == 1
	allocator.free_bytes(remapped, 16, 1, 0)
	assert state.frees == 1
}

fn test_default_allocator_and_nullable_boundaries() {
	allocator := default(none)
	ptr := allocator.alloc_bytes(10, 1, 0)
	assert !isnil(ptr)
	unsafe {
		(&u8(ptr))[0] = 0xA5
		assert (&u8(ptr))[0] == 0xA5
	}
	assert allocator.resize_bytes(ptr, 10, 1, 5, 0)
	allocator.free_bytes(ptr, 5, 1, 0)
	allocator.free_bytes(unsafe { nil }, 0, 1, 0)

	value := c_allocator_value()
	round_trip := value.zig()
	assert !isnil(round_trip.vtable)
}

fn test_default_allocator_preserves_alignment_and_remap_contract() {
	allocator := default(none)
	for alignment in [u8(0), 3, 6, 12, 16] {
		ptr := allocator.alloc_bytes(24, alignment, 0)
		assert !isnil(ptr)
		assert uint(ptr) % (uint(1) << alignment) == 0
		unsafe { (&u8(ptr))[0] = 0xa5 }
		assert allocator.remap_bytes(ptr, 24, alignment, 12, 0) == ptr
		// The source's CAllocator may grow only into usable malloc space.
		assert isnil(allocator.remap_bytes(ptr, 24, alignment, uint(1) << 40, 0))
		unsafe { assert (&u8(ptr))[0] == 0xa5 }
		allocator.free_bytes(ptr, 12, alignment, 0)
	}
}
