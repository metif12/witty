module lib_allocator

// Source values are inline. V sum types contain GC pointers, so allocator-
// owned containers must register their backing ranges with V's collector.
pub fn register_value_storage(ptr voidptr, bytes uint) {
	$if gcboehm ? { C.GC_add_roots(ptr, unsafe { &u8(ptr) + bytes }) }
}

pub fn unregister_value_storage(ptr voidptr, bytes uint) {
	$if gcboehm ? { C.GC_remove_roots(ptr, unsafe { &u8(ptr) + bytes }) }
}

// AlignProbe places a T after one byte, so the offset of `value` is T's alignment.
struct AlignProbe[T] {
	pad   u8
	value T
}

pub fn alignment_log[T]() u8 {
	bytes := uint(__offsetof(AlignProbe[T], value))
	mut result := u8(0)
	for (uint(1) << result) < bytes {
		result++
	}
	return result
}

// ArrayList translates std.ArrayListUnmanaged's allocator-facing growth.
// Its arrays are borrowed views of allocator-owned memory, never V allocations.
pub struct ArrayList[T] {
pub mut:
	items    []T
	capacity uint
}

pub fn (mut self ArrayList[T]) ensure_total_capacity(allocator Allocator, minimum uint) ! {
	if self.capacity >= minimum { return }
	mut capacity := self.capacity
	mut initial := uint(1)
	if sizeof(T) < 64 { initial = 64 / sizeof(T) }
	for capacity < minimum {
		increment := capacity / 2 + initial
		capacity = if capacity > ~uint(0) - increment { ~uint(0) } else { capacity + increment }
	}
	if capacity > ~uint(0) / sizeof(T) { return error('OutOfMemory') }
	old := self.items.data
	mut raw := unsafe { nil }
	if self.capacity > 0 {
		raw = allocator.remap_bytes(old, self.capacity * sizeof(T), alignment_log[T](),
			capacity * sizeof(T), 0)
	}
	if isnil(raw) {
		raw = allocator.alloc_bytes(capacity * sizeof(T), alignment_log[T](), 0)
		if isnil(raw) { return error('OutOfMemory') }
		register_value_storage(raw, capacity * sizeof(T))
		if self.items.len > 0 { unsafe { vmemcpy(raw, old, self.items.len * int(sizeof(T))) } }
		if self.capacity > 0 {
			unregister_value_storage(old, self.capacity * sizeof(T))
			allocator.free_bytes(old, self.capacity * sizeof(T), alignment_log[T](), 0)
		}
	} else {
		unregister_value_storage(old, self.capacity * sizeof(T))
		register_value_storage(raw, capacity * sizeof(T))
	}
	self.items = borrowed_array[T](raw, self.items.len, int(capacity))
	self.capacity = capacity
}

pub fn (mut self ArrayList[T]) append(allocator Allocator, value T) ! {
	self.ensure_total_capacity(allocator, uint(self.items.len) + 1)!
	length := self.items.len
	self.items = borrowed_array[T](self.items.data, length + 1, int(self.capacity))
	self.items[length] = value
}

pub fn borrowed_array[T](data voidptr, len int, capacity int) []T {
	mut view := []T{}
	unsafe {
		view.data = data
		view.len = len
		view.cap = capacity
		view.flags = .nofree | .nogrow
	}
	return view
}

pub fn (mut self ArrayList[T]) deinit(allocator Allocator) {
	if self.capacity > 0 {
		unregister_value_storage(self.items.data, self.capacity * sizeof(T))
		allocator.free_bytes(self.items.data, self.capacity * sizeof(T), alignment_log[T](), 0)
	}
	self.items = []T{}
	self.capacity = 0
}
