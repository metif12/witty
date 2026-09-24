module xev

// V translation of libxev's src/queue.zig (pinned 34fa508).

// An intrusive queue implementation. The type T must have a field
// "next" of type `&T` (nil for none).
//
// For those unaware, an intrusive variant of a data structure is one in which
// the data type in the list has the pointer to the next element, rather
// than a higher level "node" or "container" type. The primary benefit
// of this (and the reason we implement this) is that it defers all memory
// management to the caller: the data structure implementation doesn't need
// to allocate "nodes" to contain each element. Instead, the caller provides
// the element and how its allocated is up to them.
pub struct IntrusiveQueue[T] {
mut:
	// Head is the front of the queue and tail is the back of the queue.
	head &T = unsafe { nil }
	tail &T = unsafe { nil }
}

// Enqueue a new element to the back of the queue.
pub fn (mut self IntrusiveQueue[T]) push(v &T) {
	assert isnil(v.next)

	if !isnil(self.tail) {
		// If we have elements in the queue, then we add a new tail.
		mut tail := self.tail
		unsafe {
			tail.next = v
			self.tail = v
		}
	} else {
		// No elements in the queue we setup the initial state.
		unsafe {
			self.head = v
			self.tail = v
		}
	}
}

// Dequeue the next element from the queue.
pub fn (mut self IntrusiveQueue[T]) pop() ?&T {
	// The next element is in "head".
	if isnil(self.head) {
		return none
	}
	mut next := self.head

	// If the head and tail are equal this is the last element
	// so we also set tail to null so we can now be empty.
	if self.head == self.tail {
		self.tail = unsafe { nil }
	}

	// Head is whatever is next (if we're the last element,
	// this will be null);
	self.head = next.next

	// We set the "next" field to null so that this element
	// can be inserted again.
	next.next = unsafe { nil }
	return next
}

// Returns true if the queue is empty.
pub fn (self &IntrusiveQueue[T]) empty() bool {
	return isnil(self.head)
}
