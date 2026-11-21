module xev

struct HeapTestElem {
mut:
	value uint
	heap  IntrusiveHeapField[HeapTestElem]
}

fn heap_test_less(a &HeapTestElem, b &HeapTestElem) bool {
	return a.value < b.value
}

fn heap_test_elem(value uint) &HeapTestElem {
	return &HeapTestElem{
		value: value
	}
}

// Translated from libxev src/heap.zig `test "heap"`.
fn test_heap() {
	a := heap_test_elem(12)
	b := heap_test_elem(24)
	c := heap_test_elem(7)
	d := heap_test_elem(9)

	mut h := IntrusiveHeap[HeapTestElem]{
		less: heap_test_less
	}
	h.insert(a)
	h.insert(b)
	h.insert(c)
	h.insert(d)
	h.remove(d)

	assert h.delete_min()?.value == 7
	assert h.delete_min()?.value == 12
	assert h.delete_min()?.value == 24
	assert h.delete_min() == none
}

// Translated from libxev src/heap.zig `test "heap remove root"`.
fn test_heap_remove_root() {
	a := heap_test_elem(12)
	b := heap_test_elem(24)

	mut h := IntrusiveHeap[HeapTestElem]{
		less: heap_test_less
	}
	h.insert(a)
	h.insert(b)
	h.remove(a)

	assert h.delete_min()?.value == 24
	assert h.delete_min() == none
}

// Translated from libxev src/heap.zig `test "heap remove with children"`.
fn test_heap_remove_with_children() {
	a := heap_test_elem(36)
	b := heap_test_elem(24)
	c := heap_test_elem(12)

	mut h := IntrusiveHeap[HeapTestElem]{
		less: heap_test_less
	}
	h.insert(a)
	h.insert(b)
	h.insert(c)
	h.remove(b)

	assert h.delete_min()?.value == 12
	assert h.delete_min()?.value == 36
	assert h.delete_min() == none
}

// Translated from libxev src/heap.zig `test "heap equal values"`.
fn test_heap_equal_values() {
	a := heap_test_elem(1)
	b := heap_test_elem(2)
	c := heap_test_elem(3)
	d := heap_test_elem(4)

	mut h := IntrusiveHeap[HeapTestElem]{
		less: heap_test_less
	}
	h.insert(a)
	h.insert(b)
	h.insert(c)
	h.insert(d)

	assert h.delete_min()?.value == 1
	assert h.delete_min()?.value == 2
	assert h.delete_min()?.value == 3
	assert h.delete_min()?.value == 4
	assert h.delete_min() == none
}

// Translated from libxev src/heap.zig `test "heap: million values"`.
fn test_heap_million_values() {
	num_timers := uint(1000 * 1000)
	mut elems := []HeapTestElem{len: int(num_timers)}

	mut value := uint(0)
	for i in 0 .. elems.len {
		if i % 100 == 0 {
			value += 1
		}
		elems[i] = HeapTestElem{
			value: value
		}
	}

	mut h := IntrusiveHeap[HeapTestElem]{
		less: heap_test_less
	}
	for i in 0 .. elems.len {
		h.insert(unsafe { &elems[i] })
	}

	mut count := uint(0)
	mut last := uint(0)
	for {
		elem := h.delete_min() or { break }
		count += 1
		assert elem.value >= last
		last = elem.value
	}
	assert h.delete_min() == none
	assert count == num_timers
}

// Translated from libxev src/heap.zig `test "heap: dangling next pointer"`.
fn test_heap_dangling_next_pointer() {
	a := heap_test_elem(2)
	b := heap_test_elem(4)
	c := heap_test_elem(5)
	d := heap_test_elem(1)
	e := heap_test_elem(3)

	mut h := IntrusiveHeap[HeapTestElem]{
		less: heap_test_less
	}
	h.insert(a)
	h.insert(b)
	h.insert(c)
	h.insert(d)
	h.insert(e)

	assert h.delete_min()?.value == 1
	assert h.delete_min()?.value == 2
	assert h.delete_min()?.value == 3
	assert h.delete_min()?.value == 4
	assert h.delete_min()?.value == 5
	assert h.delete_min() == none
}
