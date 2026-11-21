module terminal

import lib_allocator

fn test_original_page_list_pool_trace() ! {
	mut pool := MemoryPool.init(lib_allocator.c_allocator_value(), page_list_page_allocator(), 4)!
	mut buffers := []voidptr{}
	for _ in 0 .. 4 {
		buffers << pool.pages.create()!
	}
	pool.pages.destroy(buffers[2])
	println('reuse=${int(pool.pages.create()! == buffers[2])} aligned=${int(uint(buffers[0]) % page_memory_alignment() == 0)}')
	println('capacity=${pool.pages.arena.query_capacity()}')
	pool.deinit()
	mut list := PageList.init(80, 24, none)!
	defer { list.deinit() }
	pin := list.track_pin(list.pin(Point.new(.active, Coordinate{ x: 7, y: 3 }))?)!
	viewport := list.viewport_pin
	serial := list.page_serial
	list.reset()
	println('reset=${list.total_rows}/${int(pin.garbage)}/${int(!viewport.garbage)}/${int(voidptr(list.viewport_pin) == voidptr(viewport))}/${int(list.page_serial > serial)}')
	list.untrack_pin(pin)
	pin2 := list.track_pin(list.pin(Point.new(.active, Coordinate{ x: 1, y: 1 }))?)!
	println('pinreuse=${int(voidptr(pin2) == voidptr(pin))} tracked=${list.count_tracked_pins()}')
	list.untrack_pin(pin2)
	mut remap := PageTrackedPinsRemap.init()
	defer { remap.deinit() }
	mut cloned := list.clone(PageCloneOpts{
		top:          Point.new(.screen, Coordinate{})
		tracked_pins: &remap
	})!
	defer { cloned.deinit() }
	println('clone=${cloned.total_rows}/${cloned.count_tracked_pins()}/${remap.table.count()}')
}
