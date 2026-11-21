module lib_allocator

struct PoolTestState {
mut:
	allocations int
	frees       int
	fail_at     int = -1
}

fn pool_test_alloc(ctx voidptr, len uint, alignment u8, _ uint) voidptr {
	mut state := unsafe { &PoolTestState(ctx) }
	call := state.allocations
	state.allocations++
	if call == state.fail_at { return unsafe { nil } }
	return c_allocator.alloc_bytes(len, alignment, 0)
}

fn pool_test_resize(_ voidptr, _ voidptr, _ uint, _ u8, _ uint, _ uint) bool {
	return false
}

fn pool_test_remap(_ voidptr, _ voidptr, _ uint, _ u8, _ uint, _ uint) voidptr {
	return unsafe { nil }
}

fn pool_test_free(ctx voidptr, ptr voidptr, len uint, alignment u8, _ uint) {
	mut state := unsafe { &PoolTestState(ctx) }
	state.frees++
	c_allocator.free_bytes(ptr, len, alignment, 0)
}

fn pool_test_allocator(state &PoolTestState, vtable &VTable) Allocator {
	return unsafe { Allocator{
		ctx:    state
		vtable: vtable
	} }
}

fn test_memory_pool_basic_reuses_intrusive_free_slot() ! {
	mut pool := MemoryPool.init_preheated[u32](c_allocator, 4)!
	defer { pool.deinit() }
	p1 := pool.create()!
	p2 := pool.create()!
	p3 := pool.create()!
	assert p1 != p2 && p1 != p3 && p2 != p3
	pool.destroy(p2)
	assert pool.create()! == p2
	pool.destroy(p1)
	pool.destroy(p3)
	assert pool.create()! == p3
	assert pool.create()! == p1
}

fn test_memory_pool_preheat_failure_releases_all_arena_nodes() {
	mut state := PoolTestState{
		fail_at: 1
	}
	vtable := VTable{
		alloc:   pool_test_alloc
		resize:  pool_test_resize
		remap:   pool_test_remap
		free_fn: pool_test_free
	}
	allocator := pool_test_allocator(&state, &vtable)
	RawMemoryPool.init_preheated(allocator, 64, 3, true, true, 100) or {
		assert err.msg() == 'OutOfMemory'
		assert state.allocations == 2
		assert state.frees == 1
		return
	}
	assert false, 'preheat must propagate child allocation failure'
}

fn test_memory_pool_nongrowable_and_aligned_items() ! {
	mut pool := RawMemoryPool.init_preheated(c_allocator, 32, 8, false, false, 4)!
	defer { pool.deinit() }
	for _ in 0 .. 4 {
		ptr := pool.create()!
		assert uint(ptr) % 256 == 0
	}
	pool.create() or {
		assert err.msg() == 'OutOfMemory'
		return
	}
	assert false, 'non-growable pool must not allocate beyond preheated slots'
}

fn test_arena_reset_retains_capacity_and_source_failure_boundary() ! {
	mut state := PoolTestState{}
	vtable := VTable{
		alloc:   pool_test_alloc
		resize:  pool_test_resize
		remap:   pool_test_remap
		free_fn: pool_test_free
	}
	mut arena := ArenaAllocator.init(pool_test_allocator(&state, &vtable), true)
	defer { arena.deinit() }
	assert !isnil(arena.alloc_bytes(1, 0))
	assert !isnil(arena.alloc_bytes(1000, 0))
	assert !isnil(arena.first.next)
	assert arena.query_capacity() == 1621
	state.fail_at = state.allocations
	// The unchanged stdlib returns false but leaves the oldest buffer intact.
	assert !arena.reset(ArenaResetMode{ kind: .retain_capacity })
	assert state.frees == 1
	assert arena.query_capacity() == 35
	assert arena.end_index == 0
	assert !isnil(arena.alloc_bytes(1, 0))
	state.fail_at = -1
	assert arena.reset(ArenaResetMode{ kind: .retain_with_limit, limit: 1 })
	assert arena.query_capacity() == 1
	assert arena.reset(ArenaResetMode{ kind: .free_all })
	assert arena.query_capacity() == 0
}

fn test_arena_last_allocation_resize_and_free() {
	mut arena := ArenaAllocator.init(c_allocator, true)
	defer { arena.deinit() }
	a := arena.alloc_bytes(4, 2)
	b := arena.alloc_bytes(4, 2)
	assert !isnil(a) && !isnil(b)
	assert !arena.resize_bytes(a, 4, 8)
	assert arena.resize_bytes(a, 4, 2)
	assert arena.resize_bytes(b, 4, 5)
	assert arena.remap_bytes(b, 5, 4) == b
	arena.free_bytes(b, 4)
	assert arena.alloc_bytes(4, 2) == b
}

struct PoolValue {
mut:
	data []u8
}

fn test_native_arena_registers_v_descriptor_references() ! {
	mut pool := MemoryPool.init[PoolValue](c_allocator)
	defer { pool.deinit() }
	mut value := pool.create()!
	unsafe {
		*value = PoolValue{
			data: []u8{len: 128, init: u8(index)}
		}
	}
	gc_collect()
	for i, byte in value.data {
		assert byte == u8(i)
	}
}
