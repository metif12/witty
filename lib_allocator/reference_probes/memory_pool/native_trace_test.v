module lib_allocator

struct NativeTraceState {
mut:
	calls   usize
	fail_at usize = ~usize(0)
}

fn native_trace_alloc(ctx voidptr, n usize, alignment u8, _ usize) voidptr {
	mut state := unsafe { &NativeTraceState(ctx) }
	call := state.calls
	state.calls++
	println('alloc ${call} ${n} ${usize(1) << alignment}')
	if call == state.fail_at { return unsafe { nil } }
	return c_allocator.alloc_bytes(n, 12, 0)
}

fn native_trace_resize(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) bool {
	return false
}

fn native_trace_remap(_ voidptr, _ voidptr, _ usize, _ u8, _ usize, _ usize) voidptr {
	return unsafe { nil }
}

fn native_trace_free(_ voidptr, ptr voidptr, n usize, alignment u8, _ usize) {
	println('free ${n} ${usize(1) << alignment}')
	c_allocator.free_bytes(ptr, n, 12, 0)
}

fn test_original_pool_arena_and_pin_map_trace() ! {
	mut state := NativeTraceState{}
	vtable := VTable{
		alloc:   native_trace_alloc
		resize:  native_trace_resize
		remap:   native_trace_remap
		free_fn: native_trace_free
	}
	allocator := unsafe { Allocator{
		ctx:    &state
		vtable: &vtable
	} }
	mut pool := MemoryPool.init_preheated[u32](allocator, 4)!
	p1 := pool.create()!
	p2 := pool.create()!
	p3 := pool.create()!
	pool.destroy(p2)
	println('reuse ${int(pool.create()! == p2)}')
	pool.destroy(p1)
	pool.destroy(p3)
	println('lifo ${int(pool.create()! == p3)} ${int(pool.create()! == p1)}')
	pool.deinit()
	mut arena := ArenaAllocator.init(allocator, true)
	assert !isnil(arena.alloc_bytes(1, 0))
	assert !isnil(arena.alloc_bytes(1000, 0))
	println('capacity ${arena.query_capacity()}')
	state.fail_at = state.calls
	println('reset ${int(arena.reset(ArenaResetMode{ kind: .retain_capacity }))}')
	println('capacity ${arena.query_capacity()}')
	state.fail_at = ~usize(0)
	println('limit ${int(arena.reset(ArenaResetMode{ kind: .retain_with_limit, limit: 1 }))}')
	arena.deinit()
	mut set := PointerArraySet[voidptr]{}
	for i in 1 .. 300 {
		set.put_no_clobber(allocator, unsafe { voidptr(i * 16) })!
	}
	for i in 1 .. 300 {
		if i % 3 == 0 { set.swap_remove(unsafe { voidptr(i * 16) }) }
	}
	mut digest := u64(0)
	for i, key in set.keys {
		digest += u64(usize(key)) * u64(i + 1)
	}
	println('set ${set.keys.len} ${digest}')
	set.deinit(allocator)
	mut table := PointerHashMap.init[voidptr, voidptr](allocator)
	for i in 1 .. 300 {
		table.put_no_clobber(unsafe { voidptr(i * 16) }, unsafe { voidptr(i * 32) })!
	}
	digest = 0
	for i in 1 .. 300 {
		digest += u64(usize(table.get(unsafe { voidptr(i * 16) })?))
	}
	println('map ${table.count()} ${table.capacity()} ${digest}')
	table.deinit()
}
