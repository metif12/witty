module datastruct

// ArrayListCollection is a collection of arrays with methods for bulk
// operations. Translated from Ghostty's datastruct/array_list_collection.zig.
pub struct ArrayListCollection[T] {
mut:
	// The arrays that belong to this collection.
	lists [][]T
}

// init creates list_count empty arrays, each reserving initial_capacity.
pub fn ArrayListCollection.init[T](list_count usize, initial_capacity usize) ArrayListCollection[T] {
	mut lists := [][]T{len: int(list_count)}
	for i in 0 .. lists.len {
		lists[i] = []T{cap: int(initial_capacity)}
	}
	return ArrayListCollection[T]{
		lists: lists
	}
}

// deinit releases every list and then the collection itself.
pub fn (mut self ArrayListCollection[T]) deinit() {
	for i in 0 .. self.lists.len {
		self.lists[i] = []T{}
	}
	self.lists = [][]T{}
}

// reset clears all lists while retaining their capacity.
pub fn (mut self ArrayListCollection[T]) reset() {
	for i in 0 .. self.lists.len {
		self.lists[i].clear()
	}
}
