module terminal

import lib_allocator

// PageList.zig MemoryPool: general-allocator nodes/pins and a separately
// aligned, zero-mapped standard-page arena. PageList owns this value.
pub struct MemoryPool {
pub mut:
	alloc lib_allocator.Allocator
	nodes lib_allocator.MemoryPool[PageNode]
	pages lib_allocator.RawMemoryPool
	pins  lib_allocator.MemoryPool[Pin]
}

pub fn MemoryPool.init(gen_alloc lib_allocator.Allocator, page_alloc lib_allocator.Allocator, preheat usize) !MemoryPool {
	mut nodes := lib_allocator.MemoryPool.init_preheated[PageNode](gen_alloc, preheat)!
	mut nodes_ready := false
	defer {
		if !nodes_ready { nodes.deinit() }
	}
	mut alignment := u8(0)
	for (usize(1) << alignment) < page_memory_alignment() {
		alignment++
	}
	mut pages := lib_allocator.RawMemoryPool.init_preheated(page_alloc, standard_page_size(),
		alignment, true, false, preheat)!
	mut pages_ready := false
	defer {
		if !pages_ready { pages.deinit() }
	}
	pins := lib_allocator.MemoryPool.init_preheated[Pin](gen_alloc, 8)!
	nodes_ready = true
	pages_ready = true
	return MemoryPool{
		alloc: gen_alloc
		nodes: nodes
		pages: pages
		pins:  pins
	}
}

pub fn (mut pool MemoryPool) deinit() {
	pool.pages.deinit()
	pool.nodes.deinit()
	pool.pins.deinit()
}

pub fn (mut pool MemoryPool) reset(mode lib_allocator.ArenaResetMode) {
	pool.pages.reset(mode)
	pool.nodes.reset(mode)
	pool.pins.reset(mode)
}
