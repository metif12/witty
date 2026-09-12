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
		ns: ns
	}
}

// BlockingQueue is Ghostty's fixed-size, non-blocking-pop queue. Pushes may
// fail immediately, wait forever, or wait for a nanosecond timeout. A drain
// iterator holds the queue lock until it is deinitialized.
//
// Ghostty implements the producer wait with a condition variable. V's Cond
// has no timed wait, so an equivalent counting channel represents available
// slots while the same mutex-protected ring stores values.
@[heap]
pub struct BlockingQueue[T] {
mut:
	data     []T
	write    int
	read     int
	length   int
	capacity int
	mutex    &sync.Mutex
	slots    chan bool
}

// create allocates a fixed-capacity queue.
pub fn BlockingQueue.create[T](capacity int) !&BlockingQueue[T] {
	if capacity <= 0 {
		return error('blocking queue capacity must be positive')
	}
	mut slots := chan bool{ cap: capacity }
	for _ in 0 .. capacity {
		slots <- true
	}
	return &BlockingQueue[T]{
		data: unsafe { []T{len: capacity} }
		capacity: capacity
		mutex: sync.new_mutex()
		slots: slots
	}
}

// destroy releases queue resources. Producers and consumers must already have
// stopped, matching Ghostty's precondition.
pub fn (mut self BlockingQueue[T]) destroy() {
	self.slots.close()
	self.mutex.destroy()
	self.data = []T{}
	self.length = 0
}

// push adds a value and returns the unread queue length, or zero when the
// requested timeout expires.
pub fn (mut self BlockingQueue[T]) push(value T, timeout BlockingQueueTimeout) u32 {
	match timeout.kind {
		.instant {
			mut acquired := false
			select {
				_ := <-self.slots {
					acquired = true
				}
				else {
				}
			}
			if !acquired {
				return 0
			}
		}
		.forever {
			_ := <-self.slots
		}
		.ns {
			mut acquired := false
			select {
				_ := <-self.slots {
					acquired = true
				}
				time.Duration(timeout.ns) * time.nanosecond {
				}
			}
			if !acquired {
				return 0
			}
		}
	}

	self.mutex.lock()
	self.data[self.write] = value
	self.write++
	if self.write >= self.capacity {
		self.write -= self.capacity
	}
	self.length++
	length := self.length
	self.mutex.unlock()
	return u32(length)
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
	self.mutex.unlock()
	self.slots <- true
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
	queue          &BlockingQueue[T]
	released_slots int
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
	self.released_slots++
	return self.queue.data[idx]
}

// deinit releases the drain lock and wakes blocked producers for every freed
// slot.
pub fn (mut self BlockingQueueDrainIterator[T]) deinit() {
	self.queue.mutex.unlock()
	for _ in 0 .. self.released_slots {
		self.queue.slots <- true
	}
	self.released_slots = 0
}
