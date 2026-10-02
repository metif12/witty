module lib_allocator

// Zig 0.15.2 std.heap.ArenaAllocator. The buffer headers live in the child
// allocation, and individual frees only reclaim the most recent allocation.
pub enum ArenaResetKind {
	free_all
	retain_capacity
	retain_with_limit
}

pub struct ArenaResetMode {
pub:
	kind  ArenaResetKind
	limit usize
}

struct ArenaBufNode {
mut:
	data usize
	next &ArenaBufNode = unsafe { nil }
}

pub struct ArenaAllocator {
pub mut:
	child_allocator Allocator
mut:
	first     &ArenaBufNode = unsafe { nil }
	end_index usize
	// V descriptors stored in native arenas have references to GC objects.
	// Register their backing ranges without altering allocation semantics.
	scanned bool = true
}

pub fn ArenaAllocator.init(child_allocator Allocator, scanned bool) ArenaAllocator {
	return ArenaAllocator{
		child_allocator: child_allocator
		scanned:         scanned
	}
}

fn (mut self ArenaAllocator) release_node(node &ArenaBufNode) {
	if self.scanned { unregister_value_storage(node, node.data) }
	self.child_allocator.free_bytes(node, node.data, alignment_log[ArenaBufNode](), 0)
}

pub fn (mut self ArenaAllocator) deinit() {
	mut it := self.first
	for !isnil(it) {
		next := it.next
		self.release_node(it)
		it = next
	}
}

pub fn (self &ArenaAllocator) query_capacity() usize {
	mut total := usize(0)
	mut it := self.first
	for !isnil(it) {
		total += it.data - sizeof(ArenaBufNode)
		it = it.next
	}
	return total
}

pub fn (mut self ArenaAllocator) reset(mode ArenaResetMode) bool {
	capacity := self.query_capacity()
	requested := match mode.kind {
		.retain_capacity {
			capacity
		}
		.retain_with_limit {
			if mode.limit < capacity { mode.limit } else { capacity }
		}
		.free_all {
			usize(0)
		}
	}

	if requested == 0 {
		self.deinit()
		self.first = unsafe { nil }
		self.end_index = 0
		return true
	}
	total_size := requested + sizeof(ArenaBufNode)
	mut it := self.first
	mut last := &ArenaBufNode(unsafe { nil })
	for !isnil(it) {
		next := it.next
		if isnil(next) {
			last = it
			break
		}
		self.release_node(it)
		it = next
	}
	assert isnil(last) || isnil(last.next)
	self.end_index = 0
	if !isnil(last) {
		self.first = last
		if last.data == total_size { return true }
		if self.child_allocator.resize_bytes(last, last.data, alignment_log[ArenaBufNode](),
			total_size, 0)
		{
			if self.scanned {
				unregister_value_storage(last, last.data)
				register_value_storage(last, total_size)
			}
			last.data = total_size
		} else {
			ptr := self.child_allocator.alloc_bytes(total_size, alignment_log[ArenaBufNode](), 0)
			if isnil(ptr) { return false }
			self.release_node(last)
			mut node := unsafe { &ArenaBufNode(ptr) }
			unsafe {
				*node = ArenaBufNode{
					data: total_size
				}
			}
			if self.scanned { register_value_storage(node, total_size) }
			self.first = node
		}
	}
	return true
}

fn (mut self ArenaAllocator) create_node(previous_len usize, minimum_size usize) &ArenaBufNode {
	actual_min_size := minimum_size + sizeof(ArenaBufNode) + 16
	big_enough_len := previous_len + actual_min_size
	len := big_enough_len + big_enough_len / 2
	ptr := self.child_allocator.alloc_bytes(len, alignment_log[ArenaBufNode](), 0)
	if isnil(ptr) { return unsafe { nil } }
	mut node := unsafe { &ArenaBufNode(ptr) }
	unsafe {
		*node = ArenaBufNode{
			data: len
			next: self.first
		}
	}
	if self.scanned { register_value_storage(node, len) }
	self.first = node
	self.end_index = 0
	return node
}

pub fn (mut self ArenaAllocator) alloc_bytes(n usize, alignment u8) voidptr {
	ptr_align := usize(1) << alignment
	mut node := self.first
	if isnil(node) { node = self.create_node(0, n + ptr_align) }
	if isnil(node) { return unsafe { nil } }
	for {
		base := usize(node) + sizeof(ArenaBufNode)
		capacity := node.data - sizeof(ArenaBufNode)
		addr := base + self.end_index
		adjusted_addr := (addr + ptr_align - 1) & ~(ptr_align - 1)
		adjusted_index := self.end_index + adjusted_addr - addr
		new_end_index := adjusted_index + n
		if new_end_index <= capacity {
			self.end_index = new_end_index
			return unsafe { voidptr(adjusted_addr) }
		}
		bigger_size := sizeof(ArenaBufNode) + new_end_index
		if self.child_allocator.resize_bytes(node, node.data, alignment_log[ArenaBufNode](),
			bigger_size, 0)
		{
			if self.scanned {
				unregister_value_storage(node, node.data)
				register_value_storage(node, bigger_size)
			}
			node.data = bigger_size
		} else {
			node = self.create_node(capacity, n + ptr_align)
			if isnil(node) { return unsafe { nil } }
		}
	}
	return unsafe { nil }
}

pub fn (mut self ArenaAllocator) resize_bytes(memory voidptr, memory_len usize, new_len usize) bool {
	if isnil(self.first) { return false }
	base := usize(self.first) + sizeof(ArenaBufNode)
	capacity := self.first.data - sizeof(ArenaBufNode)
	if base + self.end_index != usize(memory) + memory_len { return new_len <= memory_len }
	if memory_len >= new_len {
		self.end_index -= memory_len - new_len
		return true
	}
	if capacity - self.end_index >= new_len - memory_len {
		self.end_index += new_len - memory_len
		return true
	}
	return false
}

pub fn (mut self ArenaAllocator) remap_bytes(memory voidptr, memory_len usize, new_len usize) voidptr {
	if self.resize_bytes(memory, memory_len, new_len) { return memory }
	return unsafe { nil }
}

pub fn (mut self ArenaAllocator) free_bytes(memory voidptr, memory_len usize) {
	if isnil(self.first) { return }
	base := usize(self.first) + sizeof(ArenaBufNode)
	if base + self.end_index == usize(memory) + memory_len { self.end_index -= memory_len }
}

pub fn (mut self ArenaAllocator) zero_payloads() {
	mut it := self.first
	for !isnil(it) {
		unsafe { vmemset(voidptr(usize(it) + sizeof(ArenaBufNode)), 0,
			int(it.data - sizeof(ArenaBufNode))) }
		it = it.next
	}
}
