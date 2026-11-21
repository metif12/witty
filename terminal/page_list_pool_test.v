module terminal

import lib_allocator

struct PagePoolTestState {
mut:
	calls   int
	frees   int
	live    int
	fail_at int = -1
	page    bool
}

fn page_pool_test_alloc(ctx voidptr, length uint, alignment u8, _ uint) voidptr {
	mut state := unsafe { &PagePoolTestState(ctx) }
	call := state.calls
	state.calls++
	if call == state.fail_at { return unsafe { nil } }
	child := if state.page { page_list_page_allocator() } else { lib_allocator.c_allocator_value() }
	ptr := child.alloc_bytes(length, alignment, 0)
	if !isnil(ptr) { state.live++ }
	return ptr
}

fn page_pool_test_resize(ctx voidptr, memory voidptr, old uint, alignment u8, length uint, _ uint) bool {
	state := unsafe { &PagePoolTestState(ctx) }
	child := if state.page { page_list_page_allocator() } else { lib_allocator.c_allocator_value() }
	return child.resize_bytes(memory, old, alignment, length, 0)
}

fn page_pool_test_remap(ctx voidptr, memory voidptr, old uint, alignment u8, length uint, _ uint) voidptr {
	state := unsafe { &PagePoolTestState(ctx) }
	child := if state.page { page_list_page_allocator() } else { lib_allocator.c_allocator_value() }
	return child.remap_bytes(memory, old, alignment, length, 0)
}

fn page_pool_test_free(ctx voidptr, memory voidptr, length uint, alignment u8, _ uint) {
	mut state := unsafe { &PagePoolTestState(ctx) }
	state.frees++
	state.live--
	child := if state.page { page_list_page_allocator() } else { lib_allocator.c_allocator_value() }
	child.free_bytes(memory, length, alignment, 0)
}

fn page_pool_test_allocator(state &PagePoolTestState, vtable &lib_allocator.VTable) lib_allocator.Allocator {
	return unsafe { lib_allocator.Allocator{
		ctx:    state
		vtable: vtable
	} }
}

fn test_page_list_original_init_allocation_failures_release_arena_pools() ! {
	vtable := lib_allocator.VTable{
		alloc:   page_pool_test_alloc
		resize:  page_pool_test_resize
		remap:   page_pool_test_remap
		free_fn: page_pool_test_free
	}
	for page_failure in [false, true] {
		mut reached_success := false
		for fail_at in 0 .. 30 {
			mut gen_state := PagePoolTestState{
				fail_at: if page_failure { -1 } else { fail_at }
			}
			mut page_state := PagePoolTestState{
				page:    true
				fail_at: if page_failure { fail_at } else { -1 }
			}
			gen := page_pool_test_allocator(&gen_state, &vtable)
			pages := page_pool_test_allocator(&page_state, &vtable)
			mut list := PageList.init_alloc(gen, pages, 80, 24, none) or {
				assert err.msg() == 'OutOfMemory'
				assert gen_state.live == 0 && page_state.live == 0
				continue
			}
			list.deinit()
			assert gen_state.live == 0 && page_state.live == 0
			reached_success = true
			break
		}
		assert reached_success
	}
}

fn test_page_list_pool_returns_actual_standard_block_and_reuses_zeroed_memory() ! {
	mut list := PageList.init(80, 24, none)!
	defer { list.deinit() }
	before := list.page_size
	mut node := list.create_page(PageCapacity{ cols: 4, rows: 2, styles: 16 })!
	assert uint(node.data.memory.len) == standard_page_size()
	assert uint(node.data.memory.data) % page_memory_alignment() == 0
	pointer := node.data.memory.data
	serial := node.serial
	node.data.memory[100] = 99
	list.destroy_node(node)
	assert list.page_size == before
	node = list.create_page(PageCapacity{ cols: 4, rows: 2, styles: 16 })!
	assert node.data.memory.data == pointer
	assert node.serial == serial + 1
	assert node.data.memory[100] == 0
	list.destroy_node(node)
}

fn test_page_list_pool_nonstandard_pages_are_freed_outside_arena() ! {
	vtable := lib_allocator.VTable{
		alloc:   page_pool_test_alloc
		resize:  page_pool_test_resize
		remap:   page_pool_test_remap
		free_fn: page_pool_test_free
	}
	mut gen_state := PagePoolTestState{}
	mut page_state := PagePoolTestState{
		page: true
	}
	mut list := PageList.init_alloc(page_pool_test_allocator(&gen_state, &vtable), page_pool_test_allocator(&page_state,
		&vtable), 80, 24, none)!
	initial_live := page_state.live
	mut cap := std_capacity
	cap.cols = (std_capacity.max_cols() or { panic('standard capacity max columns') }) + 1
	node := list.create_page(cap)!
	assert uint(node.data.memory.len) > standard_page_size()
	assert page_state.live == initial_live + 1
	list.destroy_node(node)
	assert page_state.live == initial_live
	list.deinit()
	assert gen_state.live == 0 && page_state.live == 0
}

fn test_page_list_reset_preserves_pin_addresses_and_clears_retained_pages() ! {
	mut list := PageList.init(80, 24, none)!
	defer { list.deinit() }
	pin := list.track_pin(list.pin(Point.new(.active, Coordinate{ x: 7, y: 3 }))?)!
	viewport := list.viewport_pin
	serial := list.page_serial
	mut first := list.pages.first?
	first.data.rows[0].cells[0].codepoint = 88
	list.reset()
	assert list.viewport_pin == viewport
	assert list.tracked_pins_storage[1] == pin
	assert pin.x == 0 && pin.y == 0 && pin.garbage
	assert !viewport.garbage
	assert list.page_serial > serial
	assert list.total_rows == uint(list.rows)
	assert list.pages.first?.data.rows[0].cells[0].codepoint == 0
	list.untrack_pin(pin)
	pin2 := list.track_pin(list.pin(Point.new(.active, Coordinate{ x: 1, y: 1 }))?)!
	assert pin2 == pin
	list.untrack_pin(pin2)
}

fn test_page_list_pin_set_allocation_failure_returns_pin_to_intrusive_pool() ! {
	vtable := lib_allocator.VTable{
		alloc:   page_pool_test_alloc
		resize:  page_pool_test_resize
		remap:   page_pool_test_remap
		free_fn: page_pool_test_free
	}
	mut state := PagePoolTestState{}
	mut list := PageList.init_alloc(page_pool_test_allocator(&state, &vtable),
		page_list_page_allocator(), 80, 24, none)!
	defer { list.deinit() }
	pin := list.pin(Point.new(.active, Coordinate{}))?
	for _ in 0 .. 15 {
		_ = list.track_pin(pin)!
	}
	assert list.count_tracked_pins() == 16
	state.fail_at = state.calls
	list.track_pin(pin) or {
		assert err.msg() == 'OutOfMemory'
		assert list.count_tracked_pins() == 16
		before := state.calls
		state.fail_at = -1
		_ = list.track_pin(pin)!
		assert list.count_tracked_pins() == 17
		// Only key/index storage grows after retry. The pin is returned on failure.
		assert state.calls == before + 2
		return
	}
	assert false
}

fn test_page_list_clone_remap_allocation_failure_releases_new_pool() ! {
	mut source := PageList.init(80, 24, none)!
	defer { source.deinit() }
	vtable := lib_allocator.VTable{
		alloc:   page_pool_test_alloc
		resize:  page_pool_test_resize
		remap:   page_pool_test_remap
		free_fn: page_pool_test_free
	}
	mut state := PagePoolTestState{}
	mut map_state := PagePoolTestState{
		fail_at: 0
	}
	mut remap := PageTrackedPinsRemap.init_alloc(page_pool_test_allocator(&map_state, &vtable))
	defer { remap.deinit() }
	source.clone_alloc(page_pool_test_allocator(&state, &vtable), PageCloneOpts{
		top:          Point.new(.screen, Coordinate{})
		tracked_pins: &remap
	}) or {
		assert err.msg() == 'OutOfMemory'
		assert state.live == 0 && map_state.live == 0
		assert source.count_tracked_pins() == 1
		return
	}
	assert false
}

fn test_screen_original_init_general_allocator_failures_release_owned_pools() ! {
 vtable := lib_allocator.VTable{alloc:page_pool_test_alloc,resize:page_pool_test_resize,remap:page_pool_test_remap,free_fn:page_pool_test_free}
 mut reached_success := false
 for fail_at in 0 .. 30 {
  mut state := PagePoolTestState{fail_at:fail_at}
  mut screen := Screen.init_alloc(page_pool_test_allocator(&state,&vtable),80,24,0) or {
   assert err.msg() == 'OutOfMemory'
   assert state.live == 0
   continue
  }
  screen.deinit()
  assert state.live == 0
  reached_success = true
  break
 }
 assert reached_success
}

fn test_screen_original_clone_general_allocator_failures_release_remap_and_new_pools() ! {
 mut source := Screen.init(80,24,0)!
 defer {source.deinit()}
 first := source.pages.pin(Point.new(.active,Coordinate{x:2,y:1}))?
 last := source.pages.pin(Point.new(.active,Coordinate{x:6,y:3}))?
 source.select(Selection.init(first,last,false))!
 mut first_page := source.pages.pages.first?
 first_page.data.rows[1].cells[2].codepoint = 65
 first_page.data.rows[1].header.dirty = true
 source_pins := source.pages.count_tracked_pins()
 vtable := lib_allocator.VTable{alloc:page_pool_test_alloc,resize:page_pool_test_resize,remap:page_pool_test_remap,free_fn:page_pool_test_free}
 mut reached_success := false
 for fail_at in 0 .. 50 {
  mut state := PagePoolTestState{fail_at:fail_at}
  mut cloned := source.clone_alloc(page_pool_test_allocator(&state,&vtable),Point.new(.active,Coordinate{}),none) or {
   assert err.msg() == 'OutOfMemory'
   assert state.live == 0
   assert source.pages.count_tracked_pins() == source_pins
   continue
  }
  assert cloned.selection != none
  cloned_first := cloned.pages.pages.first?
  assert cloned_first.data.rows[1].cells[2].codepoint == 65
  cloned.deinit()
  assert state.live == 0
  assert source.pages.count_tracked_pins() == source_pins
  reached_success = true
  break
 }
 assert reached_success
}
