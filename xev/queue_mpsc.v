module xev

import sync.stdatomic as _

// V translation of libxev's src/queue_mpsc.zig (pinned 34fa508).
//
// V exposes only sequentially consistent pointer atomics, so every atomic
// load, store, and exchange below is at least as strong as the Zig ordering
// noted beside it.

// An intrusive MPSC (multi-provider, single consumer) queue implementation.
// The type T must have a field "next" of type `&T` (nil for none).
//
// This is an implementatin of a Vyukov Queue[1].
// TODO(mitchellh): I haven't audited yet if I got all the atomic operations
// correct. I was short term more focused on getting something that seemed
// to work; I need to make sure it actually works.
//
// For those unaware, an intrusive variant of a data structure is one in which
// the data type in the list has the pointer to the next element, rather
// than a higher level "node" or "container" type. The primary benefit
// of this (and the reason we implement this) is that it defers all memory
// management to the caller: the data structure implementation doesn't need
// to allocate "nodes" to contain each element. Instead, the caller provides
// the element and how its allocated is up to them.
//
// [1]: https://www.1024cores.net/home/lock-free-algorithms/queues/intrusive-mpsc-node-based-queue
pub struct IntrusiveMpscQueue[T] {
mut:
	// Head is the front of the queue and tail is the back of the queue.
	head &T = unsafe { nil }
	tail &T = unsafe { nil }
	stub T
}

// Initialize the queue. This requires a stable pointer to itself.
// This must be called before the queue is used concurrently.
pub fn (mut self IntrusiveMpscQueue[T]) init() {
	unsafe {
		self.head = &self.stub
		self.tail = &self.stub
	}
	self.stub.next = unsafe { nil }
}

// Push an item onto the queue. This can be called by any number
// of producers.
pub fn (mut self IntrusiveMpscQueue[T]) push(v &T) {
	unsafe {
		// .unordered
		C.atomic_store_ptr(&v.next, nil)
		// .acq_rel
		mut prev := &T(C.atomic_exchange_ptr(&self.head, voidptr(v)))
		// .release
		C.atomic_store_ptr(&prev.next, voidptr(v))
	}
}

// Pop the first in element from the queue. This must be called
// by only a single consumer at any given time.
pub fn (mut self IntrusiveMpscQueue[T]) pop() ?&T {
	unsafe {
		// .unordered
		mut tail := &T(C.atomic_load_ptr(&self.tail))
		// .acquire
		mut next_ := &T(C.atomic_load_ptr(&tail.next))
		if tail == &self.stub {
			if isnil(next_) {
				return none
			}
			next := next_
			// .unordered
			C.atomic_store_ptr(&self.tail, voidptr(next))
			tail = next
			// .acquire
			next_ = &T(C.atomic_load_ptr(&tail.next))
		}

		if !isnil(next_) {
			// .release
			C.atomic_store_ptr(&self.tail, voidptr(next_))
			tail.next = nil
			return tail
		}

		// .unordered
		head := &T(C.atomic_load_ptr(&self.head))
		if tail != head {
			return none
		}
		self.push(&self.stub)

		// .acquire
		next_ = &T(C.atomic_load_ptr(&tail.next))
		if !isnil(next_) {
			// .unordered
			C.atomic_store_ptr(&self.tail, voidptr(next_))
			tail.next = nil
			return tail
		}

		return none
	}
}
