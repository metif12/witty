module datastruct

// CircBufDirection selects iteration from the oldest or newest value.
pub enum CircBufDirection {
	forward
	reverse
}

// CircBufSlices contains the two contiguous storage regions that make up a
// logical circular-buffer range. The second slice is empty when the range
// does not wrap.
pub struct CircBufSlices[T] {
pub mut:
	first  []T
	second []T
}

// CircBuf is Ghostty's fixed-storage circular buffer. The default value is
// stored at runtime because V does not support a comptime value parameter.
pub struct CircBuf[T] {
pub mut:
	storage []T
	head    int
	tail    int
	full    bool
mut:
	default_value T
}

// new_circ_buf initializes a circular buffer that can store size elements.
pub fn new_circ_buf[T](size int, default_value T) CircBuf[T] {
	assert size >= 0
	return CircBuf[T]{
		storage: []T{len: size, init: default_value}
		full: size == 0
		default_value: default_value
	}
}

pub fn (mut self CircBuf[T]) deinit() {
	self.storage = []T{}
	self.head = 0
	self.tail = 0
	self.full = true
}

// append adds one value, returning an error when the buffer is full.
pub fn (mut self CircBuf[T]) append(value T) ! {
	if self.full {
		return error('OutOfMemory')
	}
	self.append_assume_capacity(value)
}

pub fn (mut self CircBuf[T]) append_assume_capacity(value T) {
	assert !self.full
	self.storage[self.head] = value
	self.head++
	if self.head >= self.storage.len {
		self.head = 0
	}
	self.full = self.head == self.tail
}

pub fn (mut self CircBuf[T]) append_slice_assume_capacity(values []T) {
	mut slices := self.get_ptr_slice(self.len(), values.len)
	for i in 0 .. slices.first.len {
		slices.first[i] = values[i]
	}
	for i in 0 .. slices.second.len {
		slices.second[i] = values[slices.first.len + i]
	}
}

pub fn (mut self CircBuf[T]) clear() {
	self.head = 0
	self.tail = 0
	self.full = false
}

pub fn (self &CircBuf[T]) iterator(direction CircBufDirection) CircBufIterator[T] {
	return CircBufIterator[T]{
		buf: *self
		direction: direction
	}
}

pub fn (self &CircBuf[T]) first() ?T {
	mut iterator := self.iterator(.forward)
	return iterator.next()
}

pub fn (self &CircBuf[T]) last() ?T {
	mut iterator := self.iterator(.reverse)
	return iterator.next()
}

pub fn (mut self CircBuf[T]) ensure_unused_capacity(amount int) {
	assert amount >= 0
	new_capacity := self.len() + amount
	if new_capacity <= self.capacity() {
		return
	}
	self.resize(new_capacity)
}

// resize changes the backing storage size. Ghostty rotates the logical data
// to zero before reallocating so its order is retained across a wrap.
pub fn (mut self CircBuf[T]) resize(size int) {
	assert size >= 0
	self.rotate_to_zero()
	previous_len := self.len()
	previous_capacity := self.storage.len
	mut storage := []T{len: size, init: self.default_value}
	copy_len := if previous_capacity < size { previous_capacity } else { size }
	for i in 0 .. copy_len {
		storage[i] = self.storage[i]
	}
	self.storage = storage

	if size > previous_capacity && self.full {
		self.head = previous_len
		self.full = false
	}
}

// rotate_to_zero aligns the oldest element with storage index zero.
pub fn (mut self CircBuf[T]) rotate_to_zero() {
	if self.tail == 0 {
		return
	}
	length := self.len()
	capacity := self.storage.len
	mut storage := []T{len: capacity, init: self.default_value}
	for i in 0 .. capacity {
		storage[i] = self.storage[(self.tail + i) % capacity]
	}
	self.storage = storage
	self.head = length % capacity
	self.tail = 0
}

pub fn (self &CircBuf[T]) empty() bool {
	return !self.full && self.head == self.tail
}

pub fn (self &CircBuf[T]) capacity() int {
	return self.storage.len
}

pub fn (self &CircBuf[T]) len() int {
	if self.full {
		return self.storage.len
	}
	if self.head >= self.tail {
		return self.head - self.tail
	}
	return self.storage.len - (self.tail - self.head)
}

// delete_oldest resets and removes up to n oldest values.
pub fn (mut self CircBuf[T]) delete_oldest(n int) {
	assert n >= 0 && n <= self.storage.len
	if n == 0 {
		return
	}

	mut slices := self.get_ptr_slice(0, n)
	for i in 0 .. slices.first.len {
		slices.first[i] = self.default_value
	}
	for i in 0 .. slices.second.len {
		slices.second[i] = self.default_value
	}

	length := self.len()
	self.tail += if length < n { length } else { n }
	if self.tail >= self.storage.len {
		self.tail -= self.storage.len
	}
	self.full = false
}

// get returns the value at a logical offset from the oldest element.
pub fn (self &CircBuf[T]) get(offset int) T {
	assert offset >= 0 && offset < self.len()
	return self.storage[self.storage_offset(offset)]
}

// get_ptr_slice returns the two storage slices for a logical range and marks
// any portion beyond the current length as written.
pub fn (mut self CircBuf[T]) get_ptr_slice(offset int, slice_len int) CircBufSlices[T] {
	if slice_len == 0 {
		return CircBufSlices[T]{}
	}
	assert offset >= 0 && slice_len >= 0 && offset + slice_len <= self.capacity()

	end_offset := offset + slice_len
	if end_offset > self.len() {
		self.advance(end_offset - self.len())
	}

	start_idx := self.storage_offset(offset)
	end_idx := self.storage_offset(end_offset - 1)
	if end_idx >= start_idx {
		return CircBufSlices[T]{
			first: unsafe { self.storage[start_idx..end_idx + 1] }
		}
	}
	return CircBufSlices[T]{
		first: unsafe { self.storage[start_idx..] }
		second: unsafe { self.storage[..end_idx + 1] }
	}
}

fn (mut self CircBuf[T]) advance(amount int) {
	assert amount >= 0 && amount <= self.storage.len - self.len()
	self.head += amount
	if self.head >= self.storage.len {
		self.head -= self.storage.len
	}
	if self.full {
		self.tail = self.head
	}
	self.full = self.head == self.tail
}

fn (self &CircBuf[T]) storage_offset(offset int) int {
	assert offset >= 0 && offset < self.storage.len
	fits_offset := self.tail + offset
	if fits_offset < self.storage.len {
		return fits_offset
	}
	return fits_offset - self.storage.len
}

pub struct CircBufIterator[T] {
	buf       CircBuf[T]
	direction CircBufDirection
mut:
	idx int
}

pub fn (mut self CircBufIterator[T]) next() ?T {
	if self.idx >= self.buf.len() {
		return none
	}
	tail_idx := match self.direction {
		.forward { self.idx }
		.reverse { self.buf.len() - self.idx - 1 }
	}
	storage_idx := (self.buf.tail + tail_idx) % self.buf.capacity()
	self.idx++
	return self.buf.storage[storage_idx]
}

// seek_by moves the iterator index with saturating subtraction, matching
// Ghostty's clamped seek behavior.
pub fn (mut self CircBufIterator[T]) seek_by(amount int) {
	if amount > 0 {
		if amount > max_int - self.idx {
			self.idx = max_int
		} else {
			self.idx += amount
		}
	} else if amount < 0 {
		decrement := if amount == min_int { max_int } else { -amount }
		self.idx = if decrement > self.idx { 0 } else { self.idx - decrement }
	}
}

pub fn (mut self CircBufIterator[T]) reset() {
	self.idx = 0
}
