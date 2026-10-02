module lib_allocator

fn test_pointer_hash_map_source_load_and_lookup() ! {
	mut table := PointerHashMap.init[voidptr, voidptr](c_allocator)
	defer { table.deinit() }
	for i in 1 .. 300 {
		table.put_no_clobber(unsafe { voidptr(i * 16) }, unsafe { voidptr(i * 32) })!
		assert table.count() == u32(i)
		assert table.capacity() >= 8
		assert u64(table.capacity()) * 80 / 100 >= table.count()
	}
	for i in 1 .. 300 {
		assert table.get(unsafe { voidptr(i * 16) })? == unsafe { voidptr(i * 32) }
	}
	assert table.get(unsafe { voidptr(1) }) == none
}

struct PointerMapFailState {
mut:
	calls   int
	frees   int
	fail_at int = -1
}

fn pointer_map_test_alloc(ctx voidptr, length usize, alignment u8, _ usize) voidptr {
	mut state := unsafe { &PointerMapFailState(ctx) }
	state.calls++
	if state.calls == state.fail_at { return unsafe { nil } }
	return c_allocator.alloc_bytes(length, alignment, 0)
}

fn pointer_map_test_resize(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) bool {
	return false
}

fn pointer_map_test_remap(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) voidptr {
	return unsafe { nil }
}

fn pointer_map_test_free(ctx voidptr, memory voidptr, length usize, alignment u8, _ usize) {
	mut state := unsafe { &PointerMapFailState(ctx) }
	state.frees++
	c_allocator.free_bytes(memory, length, alignment, 0)
}

fn test_pointer_hash_map_growth_failure_keeps_source_table() ! {
	mut state := PointerMapFailState{
		fail_at: 2
	}
	vtable := VTable{
		alloc:   pointer_map_test_alloc
		resize:  pointer_map_test_resize
		remap:   pointer_map_test_remap
		free_fn: pointer_map_test_free
	}
	allocator := unsafe { Allocator{
		ctx:    &state
		vtable: &vtable
	} }
	mut table := PointerHashMap.init[voidptr, voidptr](allocator)
	defer { table.deinit() }
	for i in 1 .. 7 {
		table.put_no_clobber(unsafe { voidptr(i) }, unsafe { voidptr(i + 10) })!
	}
	assert table.capacity() == 8
	table.put_no_clobber(unsafe { voidptr(7) }, unsafe { voidptr(17) }) or {
		assert err.msg() == 'OutOfMemory'
		assert table.capacity() == 8 && table.count() == 6
		assert state.frees == 0
		for i in 1 .. 7 {
			assert table.get(unsafe { voidptr(i) })? == unsafe { voidptr(i + 10) }
		}
		return
	}
	assert false
}
