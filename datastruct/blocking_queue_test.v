module datastruct

import time

fn test_blocking_queue_basic_push_pop_and_drain() {
	mut queue := BlockingQueue.create[u64](4)!
	defer { queue.destroy() }

	assert queue.pop() == none
	assert queue.push(1, blocking_queue_instant) == 1
	assert queue.push(2, blocking_queue_instant) == 2
	assert queue.push(3, blocking_queue_instant) == 3
	assert queue.push(4, blocking_queue_instant) == 4
	assert queue.push(5, blocking_queue_instant) == 0

	assert queue.pop()? == 1
	assert queue.pop()? == 2
	assert queue.pop()? == 3
	assert queue.pop()? == 4
	assert queue.pop() == none

	mut drain := queue.drain()
	assert drain.next() == none
	drain.deinit()
	assert queue.push(1, blocking_queue_instant) == 1
}

fn test_blocking_queue_timed_push() {
	mut queue := BlockingQueue.create[u64](1)!
	defer { queue.destroy() }
	assert queue.push(1, blocking_queue_instant) == 1
	assert queue.push(2, blocking_queue_instant) == 0
	assert queue.push(2, blocking_queue_timeout(1_000)) == 0
}

fn test_blocking_queue_drain_releases_all_slots() {
	mut queue := BlockingQueue.create[int](3)!
	defer { queue.destroy() }
	for i in 0 .. 3 {
		assert queue.push(i, blocking_queue_instant) == u32(i + 1)
	}
	mut drain := queue.drain()
	for i in 0 .. 3 {
		assert drain.next()? == i
	}
	assert drain.next() == none
	drain.deinit()
	for i in 0 .. 3 {
		assert queue.push(i + 3, blocking_queue_instant) == u32(i + 1)
	}
}

fn test_blocking_queue_forever_waits_for_space() {
	mut queue := BlockingQueue.create[int](1)!
	defer { queue.destroy() }
	assert queue.push(1, blocking_queue_instant) == 1
	worker := spawn push_after_space(mut queue)
	time.sleep(2 * time.millisecond)
	assert queue.pop()? == 1
	assert worker.wait() == 1
	assert queue.pop()? == 2
}

fn push_after_space(mut queue BlockingQueue[int]) u32 {
	return queue.push(2, blocking_queue_forever)
}
