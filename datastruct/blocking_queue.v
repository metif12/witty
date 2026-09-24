module datastruct

import sync
import time

// BlockingQueueTimeoutKind selects how a full-queue push behaves.
pub enum BlockingQueueTimeoutKind as u8 {
	instant
	forever
	ns
}

pub struct BlockingQueueTimeout {
pub:
	kind BlockingQueueTimeoutKind
	ns   u64
}

pub const blocking_queue_instant = BlockingQueueTimeout{ kind: .instant }
pub const blocking_queue_forever = BlockingQueueTimeout{ kind: .forever }

pub fn blocking_queue_timeout(ns u64) BlockingQueueTimeout {
	return BlockingQueueTimeout{
		kind: .ns
		ns:   ns
	}
}

// Condition translates the Zig std.Thread.Condition operations used by the
// queue and by internal_os.FlatpakHostCommand. V's sync.Cond has no timed
// wait, so each waiter parks on its own one-slot channel, as sync.Cond does.
// A signal wakes at most one registered waiter and is lost when none is
// registered. A timed waiter that was already selected by a signal consumes
// it instead of timing out, matching Zig.
pub struct Condition {
mut:
	lock    &sync.Mutex
	waiters []chan bool
}

pub fn Condition.init() Condition {
	return Condition{
		lock: sync.new_mutex()
	}
}

pub fn (mut self Condition) deinit() {
	self.lock.destroy()
	self.waiters = []chan bool{}
}

// wait atomically releases mutex, blocks until signaled, and reacquires it.
pub fn (mut self Condition) wait(mut mutex sync.Mutex) {
	waiter := chan bool{cap: 1}
	defer {
		waiter.close()
	}
	self.lock.lock()
	self.waiters << waiter
	self.lock.unlock()

	mutex.unlock()
	_ := <-waiter
	mutex.lock()
}

// timed_wait is wait with a nanosecond timeout. It returns an error when the
// timeout expires before this waiter is signaled.
pub fn (mut self Condition) timed_wait(mut mutex sync.Mutex, timeout_ns u64) ! {
	waiter := chan bool{cap: 1}
	defer {
		waiter.close()
	}
	self.lock.lock()
	self.waiters << waiter
	self.lock.unlock()

	mutex.unlock()
	defer {
		mutex.lock()
	}

	// V durations are signed; larger source values wait without limit.
	timeout := if timeout_ns >= u64(time.infinite) {
		time.infinite
	} else {
		time.Duration(timeout_ns)
	}
	select {
		_ := <-waiter {
			return
		}
		timeout * time.nanosecond {
		}
	}

	self.lock.lock()
	defer {
		self.lock.unlock()
	}
	for i, registered in self.waiters {
		if registered == waiter {
			self.waiters.delete(i)
			return error('Timeout')
		}
	}
}

// signal wakes one waiting thread, if any.
pub fn (mut self Condition) signal() {
	self.lock.lock()
	defer {
		self.lock.unlock()
	}
	if self.waiters.len > 0 {
		waiter := self.waiters[0]
		self.waiters.delete(0)
		waiter <- true
	}
}

// broadcast wakes all waiting threads.
pub fn (mut self Condition) broadcast() {
	self.lock.lock()
	defer {
		self.lock.unlock()
	}
	for waiter in self.waiters {
		waiter <- true
	}
	self.waiters.clear()
}

// BlockingQueue is Ghostty's fixed-size, non-blocking-pop queue. Pushes may
// fail immediately, wait forever, or wait for a nanosecond timeout. A drain
// iterator holds the queue lock until it is deinitialized.
@[heap]
pub struct BlockingQueue[T] {
mut:
	data     []T
	write    int
	read     int
	length   int
	capacity int
	mutex    &sync.Mutex
	// A CV for being notified when the queue is no longer full. This is used
	// for writing; consumers use external notifiers for non-empty queues.
	cond_not_full    Condition
	not_full_waiters usize
}

// create allocates a fixed-capacity queue.
pub fn BlockingQueue.create[T](capacity int) !&BlockingQueue[T] {
	if capacity < 0 {
		return error('blocking queue capacity must not be negative')
	}
	return &BlockingQueue[T]{
		data:          unsafe { []T{len: capacity} }
		capacity:      capacity
		mutex:         sync.new_mutex()
		cond_not_full: Condition.init()
	}
}

// destroy releases queue resources. Producers and consumers must already have
// stopped, matching Ghostty's precondition.
pub fn (mut self BlockingQueue[T]) destroy() {
	self.cond_not_full.deinit()
	self.mutex.destroy()
	self.data = []T{}
	self.length = 0
}

// push adds a value and returns the unread queue length, or zero when the
// push failed.
pub fn (mut self BlockingQueue[T]) push(value T, timeout BlockingQueueTimeout) u32 {
	self.mutex.lock()
	defer {
		self.mutex.unlock()
	}

	if self.full() {
		match timeout.kind {
			// If we're not waiting, then we failed to write.
			.instant {
				return 0
			}
			.forever {
				self.not_full_waiters++
				self.cond_not_full.wait(mut self.mutex)
				self.not_full_waiters--
			}
			.ns {
				self.not_full_waiters++
				self.cond_not_full.timed_wait(mut self.mutex, timeout.ns) or {
					self.not_full_waiters--
					return 0
				}
				self.not_full_waiters--
			}
		}

		// If we're still full, then we failed to write. This can happen in
		// situations where we are interrupted.
		if self.full() {
			return 0
		}
	}

	self.data[self.write] = value
	self.write++
	if self.write >= self.capacity {
		self.write -= self.capacity
	}
	self.length++
	return u32(self.length)
}

// pop removes a value without blocking.
pub fn (mut self BlockingQueue[T]) pop() ?T {
	self.mutex.lock()
	if self.length == 0 {
		self.mutex.unlock()
		return none
	}

	idx := self.read
	self.read++
	if self.read >= self.capacity {
		self.read -= self.capacity
	}
	self.length--
	value := self.data[idx]
	// If we have producers waiting on a full queue, notify.
	if self.not_full_waiters > 0 {
		self.cond_not_full.signal()
	}
	self.mutex.unlock()
	return value
}

pub fn (mut self BlockingQueue[T]) len() int {
	self.mutex.lock()
	length := self.length
	self.mutex.unlock()
	return length
}

// drain locks the queue once for a sequence of non-blocking reads.
pub fn (mut self BlockingQueue[T]) drain() BlockingQueueDrainIterator[T] {
	self.mutex.lock()
	return BlockingQueueDrainIterator[T]{
		queue: self
	}
}

pub struct BlockingQueueDrainIterator[T] {
mut:
	queue &BlockingQueue[T]
}

pub fn (mut self BlockingQueueDrainIterator[T]) next() ?T {
	if self.queue.length == 0 {
		return none
	}
	idx := self.queue.read
	self.queue.read++
	if self.queue.read >= self.queue.capacity {
		self.queue.read -= self.queue.capacity
	}
	self.queue.length--
	return self.queue.data[idx]
}

// deinit releases the drain lock and wakes one blocked producer, matching the
// source condition-variable signal regardless of how many entries were read.
pub fn (mut self BlockingQueueDrainIterator[T]) deinit() {
	if self.queue.not_full_waiters > 0 {
		self.queue.cond_not_full.signal()
	}
	self.queue.mutex.unlock()
}

// full reports whether the queue is full. The caller must hold the lock.
@[inline]
fn (self &BlockingQueue[T]) full() bool {
	return self.length == self.capacity
}
