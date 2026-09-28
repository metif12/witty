module vaxis

fn test_vaxis_queue_ring_and_nonblocking_operations() {
	mut q := EventQueue.new[u8](2)
	defer { q.deinit() }
	assert q.is_empty()
	assert q.try_pop() == none
	assert q.try_push(1)
	assert q.try_push(2)
	assert q.is_full()
	assert q.len() == 2
	assert !q.try_push(3)
	assert q.pop() == 1
	assert q.try_push(3)
	assert q.pop() == 2
	assert q.pop() == 3
	assert q.is_empty()
	q.push(4)
	q.lock()
	assert q.drain()? == 4
	assert q.drain() == none
	q.unlock()
}

fn queue_push_after_space(mut q EventQueue[u8]) {
	q.push(2)
}

fn queue_pop_when_ready(mut q EventQueue[u8]) u8 {
	return q.pop()
}

fn test_vaxis_queue_blocks_producer_and_consumer() {
	mut q := EventQueue.new[u8](1)
	defer { q.deinit() }
	q.push(1)
	producer := spawn queue_push_after_space(mut q)
	assert q.pop() == 1
	producer.wait()
	assert q.pop() == 2
	consumer := spawn queue_pop_when_ready(mut q)
	q.push(3)
	assert consumer.wait() == 3
}
