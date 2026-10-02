module lib_allocator

struct ArraySetTestState {
mut:
	allocations int
	frees       int
	fail_at     int = -1
}

fn array_set_test_alloc(ctx voidptr, len usize, alignment u8, _ usize) voidptr {
	mut state := unsafe { &ArraySetTestState(ctx) }
	call := state.allocations
	state.allocations++
	if call == state.fail_at { return unsafe { nil } }
	return c_allocator.alloc_bytes(len, alignment, 0)
}

fn array_set_test_resize(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) bool {
	return false
}

fn array_set_test_remap(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) voidptr {
	return unsafe { nil }
}

fn array_set_test_free(ctx voidptr, ptr voidptr, len usize, alignment u8, _ usize) {
	mut state := unsafe { &ArraySetTestState(ctx) }
	state.frees++
	c_allocator.free_bytes(ptr, len, alignment, 0)
}

fn array_set_test_allocator(state &ArraySetTestState, vtable &VTable) Allocator {
	return unsafe { Allocator{
		ctx:    state
		vtable: vtable
	} }
}

fn test_pointer_array_set_index_width_growth_and_swap_removal() ! {
	mut set := PointerArraySet[voidptr]{}
	defer { set.deinit(c_allocator) }
	for i in 1 .. 300 {
		set.put_no_clobber(c_allocator, unsafe { voidptr(usize(i) * 16) })!
		assert set.get_index(unsafe { voidptr(usize(i) * 16) })? == usize(i - 1)
	}
	assert set.bit_index == 9
	for i in 1 .. 300 {
		assert set.swap_remove(unsafe { voidptr(usize(i) * 16) })
		assert set.get_index(unsafe { voidptr(usize(i) * 16) }) == none
		for remaining in i + 1 .. 300 {
			assert set.get_index(unsafe { voidptr(usize(remaining) * 16) }) != none
		}
	}
	assert set.keys.len == 0
	assert !set.swap_remove(unsafe { voidptr(16) })
}

fn test_pointer_array_set_failure_retains_existing_entries() ! {
	mut state := ArraySetTestState{}
	vtable := VTable{
		alloc:   array_set_test_alloc
		resize:  array_set_test_resize
		remap:   array_set_test_remap
		free_fn: array_set_test_free
	}
	allocator := array_set_test_allocator(&state, &vtable)
	mut set := PointerArraySet[voidptr]{}
	defer { set.deinit(allocator) }
	for i in 1 .. 17 {
		set.put_no_clobber(allocator, unsafe { voidptr(usize(i)) })!
	}
	state.fail_at = state.allocations + 1
	set.put_no_clobber(allocator, unsafe { voidptr(usize(17)) }) or {
		assert err.msg() == 'OutOfMemory'
		assert set.keys.len == 16
		for i in 1 .. 17 {
			assert set.get_index(unsafe { voidptr(usize(i)) })? == usize(i - 1)
		}
		return
	}
	assert false, 'source index allocation failure must be propagated'
}
