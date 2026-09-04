module datastruct

// IntrusiveDoublyLinkedList is an intrusive doubly-linked list. T must have
// `next` and `prev` optional pointer fields pointing to T.
//
// This is a direct translation of Ghostty's adaptation of Zig's
// DoublyLinkedList, with the same deliberately small operation set.
pub struct IntrusiveDoublyLinkedList[T] {
pub mut:
	first ?&T
	last  ?&T
}

// insert_after inserts new_node immediately after node.
pub fn (mut self IntrusiveDoublyLinkedList[T]) insert_after(node &T, new_node &T) {
	unsafe {
		mut inserted := new_node
		inserted.prev = node
		if next_node := node.next {
			inserted.next = next_node
			mut next_mut := next_node
			next_mut.prev = new_node
		} else {
			inserted.next = none
			self.last = new_node
		}
		mut node_mut := node
		node_mut.next = new_node
	}
}

// insert_before inserts new_node immediately before node.
pub fn (mut self IntrusiveDoublyLinkedList[T]) insert_before(node &T, new_node &T) {
	unsafe {
		mut inserted := new_node
		inserted.next = node
		if prev_node := node.prev {
			inserted.prev = prev_node
			mut prev_mut := prev_node
			prev_mut.next = new_node
		} else {
			inserted.prev = none
			self.first = new_node
		}
		mut node_mut := node
		node_mut.prev = new_node
	}
}

// append inserts a node at the end of the list.
pub fn (mut self IntrusiveDoublyLinkedList[T]) append(new_node &T) {
	if last := self.last {
		self.insert_after(last, new_node)
	} else {
		self.prepend(new_node)
	}
}

// prepend inserts a node at the beginning of the list.
pub fn (mut self IntrusiveDoublyLinkedList[T]) prepend(new_node &T) {
	if first := self.first {
		self.insert_before(first, new_node)
	} else {
		self.first = new_node
		self.last = new_node
		unsafe {
			mut inserted := new_node
			inserted.prev = none
			inserted.next = none
		}
	}
}

// remove unlinks node from the list.
pub fn (mut self IntrusiveDoublyLinkedList[T]) remove(node &T) {
	if prev_node := node.prev {
		unsafe {
			mut prev_mut := prev_node
			prev_mut.next = node.next
		}
	} else {
		self.first = node.next
	}

	if next_node := node.next {
		unsafe {
			mut next_mut := next_node
			next_mut.prev = node.prev
		}
	} else {
		self.last = node.prev
	}
}

// pop removes and returns the last node.
pub fn (mut self IntrusiveDoublyLinkedList[T]) pop() ?&T {
	last := self.last or { return none }
	self.remove(last)
	return last
}

// pop_first removes and returns the first node.
pub fn (mut self IntrusiveDoublyLinkedList[T]) pop_first() ?&T {
	first := self.first or { return none }
	self.remove(first)
	return first
}
