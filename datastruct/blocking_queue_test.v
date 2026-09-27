module datastruct

import sync
import time

fn test_blocking_queue_timeout_source_layout_and_payload() {
	assert sizeof(BlockingQueueTimeoutKind) == 1
	assert u8(BlockingQueueTimeoutKind.instant) == 0
	assert u8(BlockingQueueTimeoutKind.forever) == 1
	assert u8(BlockingQueueTimeoutKind.ns) == 2
	assert sizeof(BlockingQueueTimeout) == 2 * sizeof(u64)
	assert blocking_queue_instant is BlockingQueueTimeoutInstant
	assert blocking_queue_instant.kind() == .instant
	assert blocking_queue_forever is BlockingQueueTimeoutForever
	assert blocking_queue_forever.kind() == .forever
	timeout := blocking_queue_timeout(1_099_511_627_776)
	assert timeout is BlockingQueueTimeoutNs
	assert timeout.kind() == .ns
	if timeout is BlockingQueueTimeoutNs {
		assert timeout.ns == u64(1_099_511_627_776)
	}
}

fn test_blocking_queue_condition_signal_without_waiter_is_lost() {
	mut mutex := sync.new_mutex()
	mut cond := Condition.init()
	defer {
		cond.deinit()
		mutex.destroy()
	}

	cond.signal()
	mutex.lock()
	mut timed_out := false
	cond.timed_wait(mut mutex, 1_000_000) or { timed_out = true }
	mutex.unlock()
	assert timed_out
	assert cond.waiters.len == 0
}

fn test_blocking_queue_condition_signal_wakes_registered_waiter() {
	mut mutex := sync.new_mutex()
	mut cond := &Condition{
		lock: sync.new_mutex()
	}
	defer {
		cond.deinit()
		mutex.destroy()
	}

	waiter := spawn condition_timed_wait(mut cond, mut mutex)
	for {
		cond.lock.lock()
		registered := cond.waiters.len
		cond.lock.unlock()
		if registered == 1 {
			break
		}
		time.sleep(time.millisecond)
	}
	mutex.lock()
	cond.signal()
	mutex.unlock()
	assert waiter.wait()
	assert cond.waiters.len == 0
}

fn condition_timed_wait(mut cond Condition, mut mutex sync.Mutex) bool {
	mutex.lock()
	defer {
		mutex.unlock()
	}
	cond.timed_wait(mut mutex, 1_000_000_000) or { return false }
	return true
}

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

fn test_blocking_queue_zero_capacity_is_permanently_full() {
	mut queue := BlockingQueue.create[u64](0)!
	defer { queue.destroy() }
	assert queue.pop() == none
	assert queue.push(1, blocking_queue_instant) == 0
	assert queue.push(1, blocking_queue_timeout(1_000)) == 0
}

fn test_blocking_queue_drain_releases_capacity() {
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

fn test_blocking_queue_drain_signals_only_one_waiter() {
	mut queue := BlockingQueue.create[int](2)!
	defer { queue.destroy() }
	assert queue.push(1, blocking_queue_instant) == 1
	assert queue.push(2, blocking_queue_instant) == 2

	first := spawn push_with_timeout(mut queue, 3)
	second := spawn push_with_timeout(mut queue, 4)
	for {
		queue.mutex.lock()
		waiters := queue.not_full_waiters
		queue.mutex.unlock()
		if waiters == 2 {
			break
		}
		time.sleep(time.millisecond)
	}

	mut drain := queue.drain()
	assert drain.next()? == 1
	assert drain.next()? == 2
	drain.deinit()

	mut results := [first.wait(), second.wait()]
	results.sort()
	assert results == [u32(0), 1]
}

fn push_with_timeout(mut queue BlockingQueue[int], value int) u32 {
	return queue.push(value, blocking_queue_timeout(100_000_000))
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
