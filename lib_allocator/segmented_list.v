module lib_allocator

// SegmentedList is std.SegmentedList(T, 2), used by OSC color requests.
// Inline entries and exponentially sized shelves preserve source allocation
// failures, pointer stability, and cleanup; the segment-pointer array itself
// also belongs to the caller's allocator.
pub struct SegmentedList[T] {
pub mut:
	prealloc [2]T
	segments []voidptr
	len int
}

pub fn (mut self SegmentedList[T]) append(allocator Allocator, value T) ! {
	new_length := self.len + 1
	mut count := 0
	mut capacity := 2
	for capacity < new_length { capacity += 4 << count; count++ }
	if count > self.segments.len {
		raw := allocator.alloc_bytes(usize(count) * sizeof(voidptr), alignment_log[voidptr](), 0)
		if isnil(raw) { return error('OutOfMemory') }
		mut segments := borrowed_array[voidptr](raw, count, count)
		for i in 0 .. self.segments.len { segments[i] = self.segments[i] }
		mut allocated := self.segments.len
		for i in self.segments.len .. count {
			size := usize(4) << i
			segment := allocator.alloc_bytes(size * sizeof(T), alignment_log[T](), 0)
			if isnil(segment) {
				for j in self.segments.len .. allocated {
					unregister_value_storage(segments[j], (usize(4) << j) * sizeof(T))
					allocator.free_bytes(segments[j], (usize(4) << j) * sizeof(T), alignment_log[T](), 0)
				}
				allocator.free_bytes(raw, usize(count) * sizeof(voidptr), alignment_log[voidptr](), 0)
				return error('OutOfMemory')
			}
			segments[i] = segment
			register_value_storage(segment, size * sizeof(T))
			allocated++
		}
		if self.segments.len > 0 { allocator.free_bytes(self.segments.data, usize(self.segments.len) * sizeof(voidptr), alignment_log[voidptr](), 0) }
		self.segments = segments
	}
	if self.len < 2 { self.prealloc[self.len] = value } else {
		index, slot := segmented_location(self.len)
		mut segment := borrowed_array[T](self.segments[index], 4 << index, 4 << index)
		segment[slot] = value
	}
	self.len = new_length
}

fn segmented_location(index int) (int, int) {
	mut shelf := 0
	mut boundary := 4
	for (boundary << 1) <= index + 2 { boundary <<= 1; shelf++ }
	return shelf, index + 2 - boundary
}

pub fn (self &SegmentedList[T]) at(index int) T {
	assert index >= 0 && index < self.len
	if index < 2 { return self.prealloc[index] }
	shelf, slot := segmented_location(index)
	segment := borrowed_array[T](self.segments[shelf], 4 << shelf, 4 << shelf)
	return segment[slot]
}

pub fn (mut self SegmentedList[T]) deinit(allocator Allocator) {
	for i in 0 .. self.segments.len {
		unregister_value_storage(self.segments[i], (usize(4) << i) * sizeof(T))
		allocator.free_bytes(self.segments[i], (usize(4) << i) * sizeof(T), alignment_log[T](), 0)
	}
	if self.segments.len > 0 { allocator.free_bytes(self.segments.data, usize(self.segments.len) * sizeof(voidptr), alignment_log[voidptr](), 0) }
	self.segments = []voidptr{}
	self.len = 0
}
