module lib_allocator

import buildcfg

// Zig 0.15.2 std.heap.MemoryPoolExtra's fixed-size allocator and intrusive
// free list. item_size/alignment are the source's comptime specialization
// parameters; RawMemoryPool also represents PagePool's [std_size]u8 items.
pub struct RawMemoryPool {
pub mut:
	arena          ArenaAllocator
	item_size      usize
	item_alignment u8
	growable       bool = true
mut:
	free_list voidptr
}

struct MemoryPoolFreeNode {
mut:
	next voidptr
}

pub fn RawMemoryPool.init(allocator Allocator, item_size usize, alignment u8, growable bool, scanned bool) RawMemoryPool {
	pointer_alignment := alignment_log[voidptr]()
	return RawMemoryPool{
		arena:          ArenaAllocator.init(allocator, scanned)
		item_size:      if item_size > sizeof(MemoryPoolFreeNode) {
			item_size
		} else {
			sizeof(MemoryPoolFreeNode)
		}
		item_alignment: if alignment > pointer_alignment { alignment } else { pointer_alignment }
		growable:       growable
	}
}

pub fn RawMemoryPool.init_preheated(allocator Allocator, item_size usize, alignment u8, growable bool, scanned bool, initial_size usize) !RawMemoryPool {
	mut pool := RawMemoryPool.init(allocator, item_size, alignment, growable, scanned)
	mut ready := false
	defer {
		if !ready { pool.deinit() }
	}
	pool.preheat(initial_size)!
	ready = true
	return pool
}

pub fn (mut pool RawMemoryPool) deinit() {
	pool.arena.deinit()
	pool = RawMemoryPool{}
}

pub fn (mut pool RawMemoryPool) preheat(size usize) ! {
	for _ in 0 .. size {
		ptr := pool.alloc_new()!
		mut node := unsafe { &MemoryPoolFreeNode(ptr) }
		unsafe {
			*node = MemoryPoolFreeNode{
				next: pool.free_list
			}
		}
		pool.free_list = node
	}
}

pub fn (mut pool RawMemoryPool) reset(mode ArenaResetMode) bool {
	ok := pool.arena.reset(mode)
	pool.free_list = unsafe { nil }
	return ok
}

pub fn (mut pool RawMemoryPool) create() !voidptr {
	mut ptr := pool.free_list
	if !isnil(ptr) {
		pool.free_list = unsafe { (&MemoryPoolFreeNode(ptr)).next }
	} else if pool.growable {
		ptr = pool.alloc_new()!
	} else {
		return error('OutOfMemory')
	}
	if buildcfg.runtime_safety { unsafe { vmemset(ptr, 0xaa, int(pool.item_size)) } }
	return ptr
}

pub fn (mut pool RawMemoryPool) destroy(ptr voidptr) {
	if buildcfg.runtime_safety { unsafe { vmemset(ptr, 0xaa, int(pool.item_size)) } }
	mut node := unsafe { &MemoryPoolFreeNode(ptr) }
	unsafe {
		*node = MemoryPoolFreeNode{
			next: pool.free_list
		}
	}
	pool.free_list = node
}

fn (mut pool RawMemoryPool) alloc_new() !voidptr {
	ptr := pool.arena.alloc_bytes(pool.item_size, pool.item_alignment)
	if isnil(ptr) { return error('OutOfMemory') }
	return ptr
}

pub struct MemoryPool[T] {
pub mut:
	raw RawMemoryPool
}

pub fn MemoryPool.init[T](allocator Allocator) MemoryPool[T] {
	return MemoryPool[T]{
		raw: RawMemoryPool.init(allocator, sizeof(T), alignment_log[T](), true, true)
	}
}

pub fn MemoryPool.init_preheated[T](allocator Allocator, initial_size usize) !MemoryPool[T] {
	return MemoryPool[T]{
		raw: RawMemoryPool.init_preheated(allocator, sizeof(T), alignment_log[T](), true, true,
			initial_size)!
	}
}

pub fn (mut pool MemoryPool[T]) create() !&T {
	return unsafe { &T(pool.raw.create()!) }
}

pub fn (mut pool MemoryPool[T]) destroy(ptr &T) {
	pool.raw.destroy(ptr)
}

pub fn (mut pool MemoryPool[T]) deinit() {
	pool.raw.deinit()
}

pub fn (mut pool MemoryPool[T]) reset(mode ArenaResetMode) bool {
	return pool.raw.reset(mode)
}
