module datastruct

// SegmentedPool provides stable pointers to reusable values and grows when
// requested. Values must be returned in the same order they were acquired.
// Translated from Ghostty's datastruct/segmented_pool.zig.
//
// Ghostty uses std.SegmentedList for pointer stability. V arrays may relocate,
// so the direct equivalent is an array of individually stable heap pointers.
// This is not thread safe.
pub struct SegmentedPool[T] {
mut:
	i         usize
	available usize
	values    []&T
}

pub fn SegmentedPool.init[T](prealloc usize) SegmentedPool[T] {
	mut values := []&T{cap: int(prealloc)}
	for _ in 0 .. int(prealloc) {
		values << $new(T)
	}
	return SegmentedPool[T]{
		available: prealloc
		values: values
	}
}

pub fn (mut self SegmentedPool[T]) deinit() {
	self.values = []&T{}
	self.i = 0
	self.available = 0
}

// get returns the next available value without growing the pool.
pub fn (mut self SegmentedPool[T]) get() !&T {
	if self.available == 0 {
		return error('OutOfValues')
	}
	idx := self.i % usize(self.values.len)
	self.i++
	self.available--
	return self.values[int(idx)]
}

// get_grow returns the next value, doubling the pool first if necessary.
pub fn (mut self SegmentedPool[T]) get_grow() !&T {
	if self.available == 0 {
		self.grow()
	}
	return self.get()
}

fn (mut self SegmentedPool[T]) grow() {
	old_len := self.values.len
	for _ in 0 .. old_len {
		self.values << $new(T)
	}
	self.i = usize(old_len)
	self.available = usize(old_len)
}

// put returns the oldest outstanding value to the available pool. Callers
// must return values in acquisition order, as in Ghostty's implementation.
pub fn (mut self SegmentedPool[T]) put() {
	self.available++
	assert self.available <= usize(self.values.len)
}
