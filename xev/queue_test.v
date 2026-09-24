module xev

struct QueueTestElem {
mut:
	next &QueueTestElem = unsafe { nil }
}

// Translated from libxev src/queue.zig `test Intrusive`.
fn test_intrusive_queue() {
	mut q := IntrusiveQueue[QueueTestElem]{}
	assert q.empty()

	// Elems
	elems := []&QueueTestElem{len: 10, init: &QueueTestElem{}}

	// One
	assert q.pop() == none
	q.push(elems[0])
	assert !q.empty()
	assert q.pop()? == elems[0]
	assert q.pop() == none
	assert q.empty()

	// Two
	assert q.pop() == none
	q.push(elems[0])
	q.push(elems[1])
	assert q.pop()? == elems[0]
	assert q.pop()? == elems[1]
	assert q.pop() == none

	// Interleaved
	assert q.pop() == none
	q.push(elems[0])
	assert q.pop()? == elems[0]
	q.push(elems[1])
	assert q.pop()? == elems[1]
	assert q.pop() == none
}

// Translated from libxev src/queue_mpsc.zig `test Intrusive`.
fn test_intrusive_mpsc_queue() {
	mut q := &IntrusiveMpscQueue[QueueTestElem]{}
	q.init()

	// Elems
	elems := []&QueueTestElem{len: 10, init: &QueueTestElem{}}

	// One
	assert q.pop() == none
	q.push(elems[0])
	assert q.pop()? == elems[0]
	assert q.pop() == none

	// Two
	assert q.pop() == none
	q.push(elems[0])
	q.push(elems[1])
	assert q.pop()? == elems[0]
	assert q.pop()? == elems[1]
	assert q.pop() == none

	// // Interleaved
	assert q.pop() == none
	q.push(elems[0])
	assert q.pop()? == elems[0]
	q.push(elems[1])
	assert q.pop()? == elems[1]
	assert q.pop() == none
}
