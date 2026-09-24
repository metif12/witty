module xev

// V translation of libxev's src/heap.zig (pinned 34fa508).

// An intrusive heap implementation backed by a pairing heap[1] implementation.
//
// Why? Intrusive data structures require the element type to hold the metadata
// required for the structure, rather than an additional container structure.
// There are numerous pros/cons that are documented well by Boost[2]. For Zig,
// I think the primary benefits are making data structures allocation free
// (rather, shifting allocation up to the consumer which can choose how they
// want the memory to be available). There are various costs to this such as
// the costs of pointer chasing, larger memory overhead, requiring the element
// type to be aware of its container, etc. But for certain use cases an intrusive
// data structure can yield much better performance.
//
// Usage notes:
// - The element T is expected to have a field "heap" of type InstrusiveHeapField.
//   See the tests for a full example of how to set this.
// - You can easily make this a min or max heap by inverting the result of
//   "less" below.
//
// [1]: https://en.wikipedia.org/wiki/Pairing_heap
// [2]: https://www.boost.org/doc/libs/1_64_0/doc/html/intrusive/intrusive_vs_nontrusive.html
//
// Zig's comptime `Context` parameter is `void` for every libxev heap, so the
// comparison function is stored on the heap value.
pub struct IntrusiveHeap[T] {
pub mut:
	root &T = unsafe { nil }
	less fn (a &T, b &T) bool @[required]
}

// Insert a new element v into the heap. An element v can only
// be a member of a single heap at any given time. When compiled
// with runtime-safety, assertions will help verify this property.
pub fn (mut self IntrusiveHeap[T]) insert(v &T) {
	self.root = if !isnil(self.root) { self.meld(v, self.root) } else { unsafe { v } }
}

// Look at the next minimum value but do not remove it.
pub fn (self &IntrusiveHeap[T]) peek() ?&T {
	if isnil(self.root) {
		return none
	}
	return self.root
}

// Delete the minimum value from the heap and return it.
pub fn (mut self IntrusiveHeap[T]) delete_min() ?&T {
	if isnil(self.root) {
		return none
	}
	mut root := self.root
	self.root = if !isnil(root.heap.child) {
		self.combine_siblings(root.heap.child)
	} else {
		unsafe { &T(nil) }
	}

	// Clear pointers with runtime safety so we can verify on
	// insert that values aren't incorrectly being set multiple times.
	root.heap = IntrusiveHeapField[T]{}

	return root
}

// Remove the value v from the heap.
pub fn (mut self IntrusiveHeap[T]) remove(v &T) {
	mut node := unsafe { v }

	// If v doesn't have a previous value, this must be the root
	// element. If it is NOT the root element, v can't be in this
	// heap and we trigger an assertion failure.
	if isnil(node.heap.prev) {
		assert self.root == v
		_ = self.delete_min()
		return
	}
	mut prev := node.heap.prev

	// Detach "v" from the tree and clean up any links so it
	// is as if this node never nexisted. The previous value
	// must point to the proper next value and the pointers
	// must all be cleaned up.
	if !isnil(node.heap.next) {
		mut next := node.heap.next
		next.heap.prev = prev
	}
	if prev.heap.child == v {
		prev.heap.child = node.heap.next
	} else {
		prev.heap.next = node.heap.next
	}
	node.heap.prev = unsafe { nil }
	node.heap.next = unsafe { nil }

	// If we have children, then we need to merge them back in.
	if isnil(node.heap.child) {
		return
	}
	child := node.heap.child
	node.heap.child = unsafe { nil }
	x := self.combine_siblings(child)
	self.root = self.meld(x, self.root)
}

// Meld (union) two heaps together. This isn't a generalized
// union. It assumes that a.heap.next is null so this is only
// meant in specific scenarios in the pairing heap where meld
// is expected.
//
// For example, when melding a new value "v" with an existing
// root "root", "v" must always be the first param.
fn (mut self IntrusiveHeap[T]) meld(a_ &T, b_ &T) &T {
	mut a := unsafe { a_ }
	mut b := unsafe { b_ }
	assert isnil(a.heap.next)

	if self.less(a, b) {
		// B points back to A
		b.heap.prev = a

		// If B has siblings, then A inherits B's siblings
		// and B's immediate sibling must point back to A to
		// maintain the doubly linked list.
		if !isnil(b.heap.next) {
			mut b_next := b.heap.next
			a.heap.next = b_next
			b_next.heap.prev = a
			b.heap.next = unsafe { nil }
		}

		// If A has a child, then B becomes the leftmost sibling
		// of that child.
		if !isnil(a.heap.child) {
			mut a_child := a.heap.child
			b.heap.next = a_child
			a_child.heap.prev = b
		}

		// B becomes the leftmost child of A
		a.heap.child = b

		return a
	}

	// Replace A with B in the tree. Any of B's children
	// become siblings of A. A becomes the leftmost child of B.
	// A points back to B
	b.heap.prev = a.heap.prev
	a.heap.prev = b
	if !isnil(b.heap.child) {
		mut b_child := b.heap.child
		a.heap.next = b_child
		b_child.heap.prev = a
	}
	b.heap.child = a
	return b
}

// Combine the siblings of the leftmost value "left" into a single
// new rooted with the minimum value.
fn (mut self IntrusiveHeap[T]) combine_siblings(left_ &T) &T {
	mut left := unsafe { left_ }
	left.heap.prev = unsafe { nil }

	// Merge pairs right
	mut root := unsafe { &T(nil) }
	mut a := left
	for {
		if isnil(a.heap.next) {
			root = a
			break
		}
		mut b := a.heap.next
		a.heap.next = unsafe { nil }
		b = self.meld(a, b)
		if isnil(b.heap.next) {
			root = b
			break
		}
		a = b.heap.next
	}

	// Merge pairs left
	for {
		if isnil(root.heap.prev) {
			return root
		}
		mut b := root.heap.prev
		b.heap.next = unsafe { nil }
		root = self.meld(b, root)
	}
	return root
}

// The state that is required for IntrusiveHeap element types. This
// should be set as the "heap" field in the type T.
pub struct IntrusiveHeapField[T] {
pub mut:
	child &T = unsafe { nil }
	prev  &T = unsafe { nil }
	next  &T = unsafe { nil }
}
