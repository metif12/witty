module xev

// Thread pool copied almost directly from Zap[1]. In @kprotty's own words:
// lock-free, allocation-free* (excluding spawning threads), supports batch
// scheduling, and dynamically spawns threads while handling thread spawn
// failure. I highly recommend reading @kprotty's incredible blog post[2] on
// this topic.
//
// The original file in Zap is licensed under the MIT license, and the
// license and copyright is reproduced below. The libxev project is also
// MIT licensed so the entire project (including this file) are equally
// licensed. This is just a convenience note for any OSS users, contributors,
// etc.
//
// MIT License
//
// Copyright (c) 2021 kprotty
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// [1]: https://github.com/kprotty/zap
// [2]: https://zig.news/kprotty/resource-efficient-thread-pools-with-zig-3291
//
// V translation of libxev's src/ThreadPool.zig (pinned 34fa508).
import runtime
import sync as vsync

$if linux {
	#include <sys/syscall.h>
}

pub struct ThreadPool {
pub mut:
	stack_size  u32
	max_threads u32
mut:
	sync       ThreadPoolAtomic[u32] = ThreadPoolAtomic[u32]{
		raw: ThreadPoolSync{}.to_bits()
	}
	idle_event ThreadPoolEvent
	join_event ThreadPoolEvent
	run_queue  ThreadPoolNodeQueue
	threads    ThreadPoolAtomic[&ThreadPoolThread] = ThreadPoolAtomic[&ThreadPoolThread]{
		raw: unsafe { nil }
	}
}

// Sync is a Zig `packed struct(u32)`. V has no bit-fields, so it is a regular
// struct converted with ThreadPoolSync.from_bits()/to_bits() in place of
// @bitCast, using the same bit layout (idle: bits 0-13, spawned: 14-27,
// unused: 28, notified: 29, state: 30-31).
struct ThreadPoolSync {
mut:
	// Tracks the number of threads not searching for Tasks
	idle u16 // u14
	// Tracks the number of threads spawned
	spawned u16 // u14
	// What you see is what you get
	unused bool
	// Used to not miss notifications while state = waking
	notified bool
	// The current state of the thread pool
	state ThreadPoolSyncState = .pending
}

enum ThreadPoolSyncState as u8 {
	// A notification can be issued to wake up a sleeping as the "waking thread".
	pending = 0
	// The state was notifiied with a signal. A thread is woken up.
	// The first thread to transition to `waking` becomes the "waking thread".
	signaled
	// There is a "waking thread" among us.
	// No other thread should be woken up until the waking thread transitions the state.
	waking
	// The thread pool was terminated. Start decremented `spawned` so that it can be joined.
	shutdown
}

const thread_pool_sync_u14_mask = u32(0x3fff)

// @bitCast(u32) -> Sync
@[inline]
fn ThreadPoolSync.from_bits(bits u32) ThreadPoolSync {
	return ThreadPoolSync{
		idle:     u16(bits & thread_pool_sync_u14_mask)
		spawned:  u16((bits >> 14) & thread_pool_sync_u14_mask)
		unused:   (bits >> 28) & 1 != 0
		notified: (bits >> 29) & 1 != 0
		state:    unsafe { ThreadPoolSyncState(u8(bits >> 30)) }
	}
}

// @bitCast(Sync) -> u32
@[inline]
fn (self ThreadPoolSync) to_bits() u32 {
	mut bits := u32(self.idle) & thread_pool_sync_u14_mask
	bits |= (u32(self.spawned) & thread_pool_sync_u14_mask) << 14
	if self.unused {
		bits |= u32(1) << 28
	}
	if self.notified {
		bits |= u32(1) << 29
	}
	bits |= (u32(self.state) & 0b11) << 30
	return bits
}

// std.Thread.SpawnConfig.default_stack_size
const thread_pool_default_stack_size = u32(16 * 1024 * 1024)

// Configuration options for the thread pool.
// TODO: add CPU core affinity?
@[params]
pub struct ThreadPoolConfig {
pub mut:
	stack_size  u32 = thread_pool_default_stack_size
	max_threads u32
}

// Statically initialize the thread pool using the configuration.
pub fn ThreadPool.init(config ThreadPoolConfig) ThreadPool {
	return ThreadPool{
		stack_size:  if config.stack_size > 1 { config.stack_size } else { 1 }
		max_threads: if config.max_threads > 0 {
			config.max_threads
		} else {
			thread_pool_get_cpu_count()
		}
	}
}

// Wait for a thread to call shutdown() on the thread pool and kill the worker threads.
pub fn (mut self ThreadPool) deinit() {
	self.join()
	// `self.* = undefined;` has no V equivalent. The pool must not be used after deinit().
}

// The type of ThreadPoolTask.callback (`*const fn (*Task) void`).
pub type ThreadPoolTaskCallback = fn (task &ThreadPoolTask)

// A Task represents the unit of Work / Job / Execution that the ThreadPool schedules.
// The user provides a `callback` which is invoked when the *Task can run on a thread.
pub struct ThreadPoolTask {
mut:
	node ThreadPoolNode
pub mut:
	callback ThreadPoolTaskCallback = unsafe { nil }
}

// An unordered collection of Tasks which can be submitted for scheduling as a group.
pub struct ThreadPoolBatch {
pub mut:
	len  usize
	head &ThreadPoolTask = unsafe { nil }
	tail &ThreadPoolTask = unsafe { nil }
}

// Create a batch from a single task.
pub fn ThreadPoolBatch.from(task &ThreadPoolTask) ThreadPoolBatch {
	return ThreadPoolBatch{
		len:  1
		head: unsafe { task }
		tail: unsafe { task }
	}
}

// Another batch into this one, taking ownership of its tasks.
pub fn (mut self ThreadPoolBatch) push(batch ThreadPoolBatch) {
	if batch.len == 0 {
		return
	}
	if self.len == 0 {
		self = batch
	} else {
		mut tail := self.tail
		if !isnil(batch.head) {
			tail.node.next = unsafe { &batch.head.node }
		} else {
			tail.node.next = unsafe { nil }
		}
		self.tail = batch.tail
		self.len += batch.len
	}
}

// Schedule a batch of tasks to be executed by some thread on the thread pool.
pub fn (mut self ThreadPool) schedule(batch ThreadPoolBatch) {
	// Sanity check
	if batch.len == 0 {
		return
	}

	// Extract out the Node's from the Tasks
	mut list := ThreadPoolNodeList{
		head: unsafe { &batch.head.node }
		tail: unsafe { &batch.tail.node }
	}

	// Push the task Nodes to the most approriate queue
	mut thread_ := ThreadPoolThread.current()
	if !isnil(thread_) {
		thread_.run_buffer.push(mut list) or { thread_.run_queue.push(list) }
	} else {
		self.run_queue.push(list)
	}

	// Try to notify a thread
	is_waking := false
	self.notify(is_waking)
}

@[inline]
fn (mut self ThreadPool) notify(is_waking bool) {
	// Fast path to check the Sync state to avoid calling into notifySlow().
	// If we're waking, then we need to update the state regardless
	if !is_waking {
		sync := ThreadPoolSync.from_bits(self.sync.load(.monotonic))
		if sync.notified {
			return
		}
	}

	self.notify_slow(is_waking)
}

@[noinline]
fn (mut self ThreadPool) notify_slow(is_waking bool) {
	mut sync := ThreadPoolSync.from_bits(self.sync.load(.monotonic))
	for sync.state != .shutdown {
		can_wake := is_waking || sync.state == .pending
		if is_waking {
			assert sync.state == .waking
		}

		mut new_sync := sync
		new_sync.notified = true
		if can_wake && sync.idle > 0 { // wake up an idle thread
			new_sync.state = .signaled
		} else if can_wake && sync.spawned < self.max_threads { // spawn a new thread
			new_sync.state = .signaled
			new_sync.spawned += 1
		} else if is_waking { // no other thread to pass on "waking" status
			new_sync.state = .pending
		} else if sync.notified { // nothing to update
			return
		}

		// Release barrier synchronizes with Acquire in wait()
		// to ensure pushes to run queues happen before observing a posted notification.
		sync = ThreadPoolSync.from_bits(self.sync.cmpxchg_weak(sync.to_bits(), new_sync.to_bits(),
			.release, .monotonic) or {
			// We signaled to notify an idle thread
			if can_wake && sync.idle > 0 {
				self.idle_event.notify()
				return
			}

			// We signaled to spawn a new thread
			if can_wake && sync.spawned < self.max_threads {
				spawn_config := ThreadPoolSpawnConfig{
					stack_size: self.stack_size
				}
				thread_ := thread_pool_spawn(spawn_config, self) or {
					self.unregister(unsafe { nil })
					return
				}
				thread_pool_detach(thread_)
				return
			}

			return
		})
	}
}

@[noinline]
fn (mut self ThreadPool) wait(_is_waking bool) !bool {
	mut is_idle := false
	mut is_waking := _is_waking
	mut sync := ThreadPoolSync.from_bits(self.sync.load(.monotonic))

	for {
		if sync.state == .shutdown {
			return thread_pool_error_shutdown
		}
		if is_waking {
			assert sync.state == .waking
		}

		// Consume a notification made by notify().
		if sync.notified {
			mut new_sync := sync
			new_sync.notified = false
			if is_idle {
				new_sync.idle -= 1
			}
			if sync.state == .signaled {
				new_sync.state = .waking
			}

			// Acquire barrier synchronizes with notify()
			// to ensure that pushes to run queue are observed after wait() returns.
			sync = ThreadPoolSync.from_bits(self.sync.cmpxchg_weak(sync.to_bits(),
				new_sync.to_bits(), .acquire, .monotonic) or {
				return is_waking || sync.state == .signaled
			})

			// No notification to consume.
			// Mark this thread as idle before sleeping on the idle_event.
		} else if !is_idle {
			mut new_sync := sync
			new_sync.idle += 1
			if is_waking {
				new_sync.state = .pending
			}

			sync = ThreadPoolSync.from_bits(self.sync.cmpxchg_weak(sync.to_bits(),
				new_sync.to_bits(), .monotonic, .monotonic) or {
				is_waking = false
				is_idle = true
				continue
			})

			// Wait for a signal by either notify() or shutdown() without wasting cpu cycles.
			// TODO: Add I/O polling here.
		} else {
			self.idle_event.wait()
			sync = ThreadPoolSync.from_bits(self.sync.load(.monotonic))
		}
	}
	return false
}

// Marks the thread pool as shutdown
@[noinline]
pub fn (mut self ThreadPool) shutdown() {
	mut sync := ThreadPoolSync.from_bits(self.sync.load(.monotonic))
	for sync.state != .shutdown {
		mut new_sync := sync
		new_sync.notified = true
		new_sync.state = .shutdown
		new_sync.idle = 0

		// Full barrier to synchronize with both wait() and notify()
		sync = ThreadPoolSync.from_bits(self.sync.cmpxchg_weak(sync.to_bits(), new_sync.to_bits(),
			.acq_rel, .monotonic) or {
			// Wake up any threads sleeping on the idle_event.
			// TODO: I/O polling notification here.
			if sync.idle > 0 {
				self.idle_event.shutdown()
			}
			if sync.spawned == 0 {
				self.join_event.notify()
			}
			return
		})
	}
}

fn (mut self ThreadPool) register(mut thread_ ThreadPoolThread) {
	// Push the thread onto the threads stack in a lock-free manner.
	mut threads := self.threads.load(.monotonic)
	for {
		thread_.next = threads
		threads = self.threads.cmpxchg_weak(threads, thread_, .release, .monotonic) or { break }
	}
}

fn (mut self ThreadPool) unregister(maybe_thread &ThreadPoolThread) {
	// Un-spawn one thread, either due to a failed OS thread spawning or the thread is exitting.
	one_spawned := ThreadPoolSync{
		spawned: 1
	}.to_bits()
	sync := ThreadPoolSync.from_bits(self.sync.fetch_sub(one_spawned, .release))
	assert sync.spawned > 0

	// The last thread to exit must wake up the thread pool join()er
	// who will start the chain to shutdown all the threads.
	if sync.state == .shutdown && sync.spawned == 1 {
		self.join_event.notify()
	}

	// If this is a thread pool thread, wait for a shutdown signal by the thread pool join()er.
	if isnil(maybe_thread) {
		return
	}
	mut thread_ := unsafe { maybe_thread }
	thread_.join_event.wait()

	// After receiving the shutdown signal, shutdown the next thread in the pool.
	// We have to do that without touching the thread pool itself since it's memory is invalidated by now.
	// So just follow our .next link.
	mut next_thread := thread_.next
	if isnil(next_thread) {
		return
	}
	next_thread.join_event.notify()
}

fn (mut self ThreadPool) join() {
	// Wait for the thread pool to be shutdown() then for all threads to enter a joinable state
	self.join_event.wait()
	sync := ThreadPoolSync.from_bits(self.sync.load(.monotonic))

	assert sync.state == .shutdown
	assert sync.spawned == 0

	// If there are threads, start off the chain sending it the shutdown signal.
	// The thread receives the shutdown signal and sends it to the next thread, and the next..
	mut thread_ := self.threads.load(.acquire)
	if isnil(thread_) {
		return
	}
	thread_.join_event.notify()
}

struct ThreadPoolThread {
mut:
	next       &ThreadPoolThread = unsafe { nil }
	target     &ThreadPoolThread = unsafe { nil }
	join_event ThreadPoolEvent
	run_queue  ThreadPoolNodeQueue
	run_buffer ThreadPoolNodeBuffer
}

// `threadlocal var current: ?*Thread = null;`
// V has no threadlocal variables; the V equivalent is sync's pthread-key based
// ThreadLocalStorage, which starts out as null on every thread.
const thread_pool_thread_current = $if wasm32_wasi {
	unsafe { nil }
} $else {
	vsync.new_tls[voidptr](unsafe { nil }) or { panic(err) }
}

// Reads `Thread.current`.
@[inline]
fn ThreadPoolThread.current() &ThreadPoolThread {
	$if wasm32_wasi {
		return unsafe { &ThreadPoolThread(C.witty_xev_thread_current_get()) }
	} $else {
		mut tls := thread_pool_thread_current
		return unsafe { &ThreadPoolThread(tls.get() or { nil }) }
	}
}

// Writes `Thread.current`.
@[inline]
fn ThreadPoolThread.set_current(thread_ &ThreadPoolThread) {
	$if wasm32_wasi {
		C.witty_xev_thread_current_set(voidptr(thread_))
	} $else {
		mut tls := thread_pool_thread_current
		tls.set(voidptr(thread_)) or { panic(err) }
	}
}

// Thread entry point which runs a worker for the ThreadPool
fn ThreadPoolThread.run(mut thread_pool ThreadPool) {
	mut self := ThreadPoolThread{}
	ThreadPoolThread.set_current(unsafe { &self })

	thread_pool.register(mut self)
	defer {
		thread_pool.unregister(unsafe { &self })
	}

	mut is_waking := false
	for {
		is_waking = thread_pool.wait(is_waking) or { return }

		for {
			result := self.pop(mut thread_pool) or { break }
			if result.pushed || is_waking {
				thread_pool.notify(is_waking)
			}
			is_waking = false

			// @fieldParentPtr("node", result.node)
			task := unsafe {
				&ThreadPoolTask(voidptr(usize(result.node) - __offsetof(ThreadPoolTask, node)))
			}
			task.callback(task)
		}
	}
}

// Try to dequeue a Node/Task from the ThreadPool.
// Spurious reports of dequeue() returning empty are allowed.
fn (mut self ThreadPoolThread) pop(mut thread_pool ThreadPool) ?ThreadPoolNodeBufferStole {
	// Check our local buffer first
	node := self.run_buffer.pop()
	if !isnil(node) {
		return ThreadPoolNodeBufferStole{
			node:   node
			pushed: false
		}
	}

	// Then check our local queue
	if stole := self.run_buffer.consume(mut self.run_queue) {
		return stole
	}

	// Then the global queue
	if stole := self.run_buffer.consume(mut thread_pool.run_queue) {
		return stole
	}

	// TODO: add optimistic I/O polling here

	// Then try work stealing from other threads
	mut num_threads := u32(ThreadPoolSync.from_bits(thread_pool.sync.load(.monotonic)).spawned)
	for ; num_threads > 0; num_threads -= 1 {
		// Traverse the stack of registered threads on the thread pool
		mut target := self.target
		if isnil(target) {
			target = thread_pool.threads.load(.acquire)
			if isnil(target) {
				panic('unreachable')
			}
		}
		self.target = target.next

		// Try to steal from their queue first to avoid contention (the target steal's from queue last).
		if stole := self.run_buffer.consume(mut target.run_queue) {
			return stole
		}

		// Skip stealing from the buffer if we're the target.
		// We still steal from our own queue above given it may have just been locked the first time we tried.
		if voidptr(target) == voidptr(self) {
			continue
		}

		// Steal from the buffer of a remote thread as a last resort
		if stole := self.run_buffer.steal(mut target.run_buffer) {
			return stole
		}
	}

	return none
}

// An event which stores 1 semaphore token and is multi-threaded safe.
// The event can be shutdown(), waking up all wait()ing threads and
// making subsequent wait()'s return immediately.
struct ThreadPoolEvent {
mut:
	state ThreadPoolAtomic[u32] = ThreadPoolAtomic[u32]{
		raw: thread_pool_event_empty
	}
}

const thread_pool_event_empty = u32(0)
const thread_pool_event_waiting = u32(1)
const thread_pool_event_notified = u32(2)
const thread_pool_event_shutdown = u32(3)

// Wait for and consume a notification
// or wait for the event to be shutdown entirely
@[noinline]
fn (mut self ThreadPoolEvent) wait() {
	mut acquire_with := thread_pool_event_empty
	mut state := self.state.load(.monotonic)

	for {
		// If we're shutdown then exit early.
		// Acquire barrier to ensure operations before the shutdown() are seen after the wait().
		// Shutdown is rare so it's better to have an Acquire barrier here instead of on CAS failure + load which are common.
		if state == thread_pool_event_shutdown {
			_ = self.state.load(.acquire)
			return
		}

		// Consume a notification when it pops up.
		// Acquire barrier to ensure operations before the notify() appear after the wait().
		if state == thread_pool_event_notified {
			state = self.state.cmpxchg_weak(state, acquire_with, .acquire, .monotonic) or { return }
			continue
		}

		// There is no notification to consume, we should wait on the event by ensuring its WAITING.
		if state != thread_pool_event_waiting {
			// blk:
			if new_state := self.state.cmpxchg_weak(state, thread_pool_event_waiting, .monotonic,
				.monotonic)
			{
				state = new_state
				continue
			}
			// break :blk
		}

		// Wait on the event until a notify() or shutdown().
		// If we wake up to a notification, we must acquire it with WAITING instead of EMPTY
		// since there may be other threads sleeping on the Futex who haven't been woken up yet.
		//
		// Acquiring to WAITING will make the next notify() or shutdown() wake a sleeping futex thread
		// who will either exit on SHUTDOWN or acquire with WAITING again, ensuring all threads are awoken.
		// This unfortunately results in the last notify() or shutdown() doing an extra futex wake but that's fine.
		thread_pool_futex_wait(&self.state, thread_pool_event_waiting)
		state = self.state.load(.monotonic)
		acquire_with = thread_pool_event_waiting
	}
}

// Post a notification to the event if it doesn't have one already
// then wake up a waiting thread if there is one as well.
fn (mut self ThreadPoolEvent) notify() {
	self.wake(thread_pool_event_notified, 1)
}

// Marks the event as shutdown, making all future wait()'s return immediately.
// Then wakes up any threads currently waiting on the Event.
fn (mut self ThreadPoolEvent) shutdown() {
	self.wake(thread_pool_event_shutdown, max_u32)
}

fn (mut self ThreadPoolEvent) wake(release_with u32, wake_threads u32) {
	// Update the Event to notifty it with the new `release_with` state (either NOTIFIED or SHUTDOWN).
	// Release barrier to ensure any operations before this are this to happen before the wait() in the other threads.
	state := self.state.swap(release_with, .release)

	// Only wake threads sleeping in futex if the state is WAITING.
	// Avoids unnecessary wake ups.
	if state == thread_pool_event_waiting {
		thread_pool_futex_wake(&self.state, wake_threads)
	}
}

// Linked list intrusive memory node and lock-free data structures to operate with it
struct ThreadPoolNode {
mut:
	next &ThreadPoolNode = unsafe { nil }
}

// A linked list of Nodes
struct ThreadPoolNodeList {
mut:
	head &ThreadPoolNode
	tail &ThreadPoolNode
}

// An unbounded multi-producer-(non blocking)-multi-consumer queue of Node pointers.
struct ThreadPoolNodeQueue {
mut:
	stack ThreadPoolAtomic[usize]
	cache &ThreadPoolNode = unsafe { nil }
}

const thread_pool_node_queue_has_cache = usize(0b01)
const thread_pool_node_queue_is_consuming = usize(0b10)
const thread_pool_node_queue_ptr_mask = ~(thread_pool_node_queue_has_cache | thread_pool_node_queue_is_consuming)

// comptime { assert(@alignOf(Node) >= ((IS_CONSUMING | HAS_CACHE) + 1)); }
// V has no comptime assertions; this one is checked in thread_pool_test.v.

fn (mut self ThreadPoolNodeQueue) push(list ThreadPoolNodeList) {
	mut stack := self.stack.load(.monotonic)
	mut list_tail := list.tail
	for {
		// Attach the list to the stack (pt. 1)
		list_tail.next = unsafe { &ThreadPoolNode(voidptr(stack & thread_pool_node_queue_ptr_mask)) }

		// Update the stack with the list (pt. 2).
		// Don't change the HAS_CACHE and IS_CONSUMING bits of the consumer.
		mut new_stack := usize(voidptr(list.head))
		assert new_stack & ~thread_pool_node_queue_ptr_mask == 0
		new_stack |= (stack & ~thread_pool_node_queue_ptr_mask)

		// Push to the stack with a release barrier for the consumer to see the proper list links.
		stack = self.stack.cmpxchg_weak(stack, new_stack, .release, .monotonic) or { break }
	}
}

fn (mut self ThreadPoolNodeQueue) try_acquire_consumer() !&ThreadPoolNode {
	mut stack := self.stack.load(.monotonic)
	for {
		if stack & thread_pool_node_queue_is_consuming != 0 {
			return thread_pool_error_contended // The queue already has a consumer.
		}
		if stack & (thread_pool_node_queue_has_cache | thread_pool_node_queue_ptr_mask) == 0 {
			return thread_pool_error_empty // The queue is empty when there's nothing cached and nothing in the stack.
		}

		// When we acquire the consumer, also consume the pushed stack if the cache is empty.
		mut new_stack := stack | thread_pool_node_queue_has_cache | thread_pool_node_queue_is_consuming
		if stack & thread_pool_node_queue_has_cache == 0 {
			assert stack & thread_pool_node_queue_ptr_mask != 0
			new_stack &= ~thread_pool_node_queue_ptr_mask
		}

		// Acquire barrier on getting the consumer to see cache/Node updates done by previous consumers
		// and to ensure our cache/Node updates in pop() happen after that of previous consumers.
		stack = self.stack.cmpxchg_weak(stack, new_stack, .acquire, .monotonic) or {
			if !isnil(self.cache) {
				return self.cache
			}
			return unsafe { &ThreadPoolNode(voidptr(stack & thread_pool_node_queue_ptr_mask)) }
		}
	}
	return thread_pool_error_empty
}

fn (mut self ThreadPoolNodeQueue) release_consumer(consumer &ThreadPoolNode) {
	// Stop consuming and remove the HAS_CACHE bit as well if the consumer's cache is empty.
	// When HAS_CACHE bit is zeroed, the next consumer will acquire the pushed stack nodes.
	mut remove := thread_pool_node_queue_is_consuming
	if isnil(consumer) {
		remove |= thread_pool_node_queue_has_cache
	}

	// Release the consumer with a release barrier to ensure cache/node accesses
	// happen before the consumer was released and before the next consumer starts using the cache.
	self.cache = unsafe { consumer }
	stack := self.stack.fetch_sub(remove, .release)
	assert stack & remove != 0
}

fn (mut self ThreadPoolNodeQueue) pop(consumer_ref &&ThreadPoolNode) &ThreadPoolNode {
	// Check the consumer cache (fast path)
	cached := unsafe { *consumer_ref }
	if !isnil(cached) {
		unsafe {
			*consumer_ref = cached.next
		}
		return cached
	}

	// Load the stack to see if there was anything pushed that we could grab.
	mut stack := self.stack.load(.monotonic)
	assert stack & thread_pool_node_queue_is_consuming != 0
	if stack & thread_pool_node_queue_ptr_mask == 0 {
		return unsafe { nil }
	}

	// Nodes have been pushed to the stack, grab then with an Acquire barrier to see the Node links.
	stack = self.stack.swap(thread_pool_node_queue_has_cache | thread_pool_node_queue_is_consuming,
		.acquire)
	assert stack & thread_pool_node_queue_is_consuming != 0
	assert stack & thread_pool_node_queue_ptr_mask != 0

	node := unsafe { &ThreadPoolNode(voidptr(stack & thread_pool_node_queue_ptr_mask)) }
	unsafe {
		*consumer_ref = node.next
	}
	return node
}

// A bounded single-producer, multi-consumer ring buffer for node pointers.
struct ThreadPoolNodeBuffer {
mut:
	head  ThreadPoolAtomic[u32] // Atomic(Index)
	tail  ThreadPoolAtomic[u32] // Atomic(Index)
	array [thread_pool_node_buffer_capacity]ThreadPoolAtomic[&ThreadPoolNode] // = undefined
}

// const Index = u32;
const thread_pool_node_buffer_capacity = 256 // Appears to be a pretty good trade-off in space vs contended throughput

// comptime {
//     assert(std.math.maxInt(Index) >= capacity);
//     assert(std.math.isPowerOfTwo(capacity));
// }
// V has no comptime assertions; these are checked in thread_pool_test.v.

fn (mut self ThreadPoolNodeBuffer) push(mut list ThreadPoolNodeList) ! {
	mut head := self.head.load(.monotonic)
	mut tail := self.tail.raw // we're the only thread that can change this

	for {
		mut size := tail - head
		assert size <= thread_pool_node_buffer_capacity

		// Push nodes from the list to the buffer if it's not empty..
		if size < thread_pool_node_buffer_capacity {
			mut nodes := list.head
			for ; size < thread_pool_node_buffer_capacity; size += 1 {
				node := nodes
				if isnil(node) {
					break
				}
				nodes = node.next

				// Array written atomically with weakest ordering since it could be getting atomically read by steal().
				// (Zig `.unordered` has no C11 equivalent; the next-stronger `.monotonic` is used.)
				self.array[tail % thread_pool_node_buffer_capacity].store(node, .monotonic)
				tail += 1
			}

			// Release barrier synchronizes with Acquire loads for steal()ers to see the array writes.
			self.tail.store(tail, .release)

			// Update the list with the nodes we pushed to the buffer and try again if there's more.
			if isnil(nodes) {
				return
			}
			list.head = nodes
			C.cpu_relax() // std.atomic.spinLoopHint()
			head = self.head.load(.monotonic)
			continue
		}

		// Try to steal/overflow half of the tasks in the buffer to make room for future push()es.
		// Migrating half amortizes the cost of stealing while requiring future pops to still use the buffer.
		// Acquire barrier to ensure the linked list creation after the steal only happens after we succesfully steal.
		mut migrate := size / 2
		head = self.head.cmpxchg_weak(head, head + migrate, .acquire, .monotonic) or {
			// Link the migrated Nodes together
			first := self.array[head % thread_pool_node_buffer_capacity].raw
			for ; migrate > 0; migrate -= 1 {
				mut prev := self.array[head % thread_pool_node_buffer_capacity].raw
				head += 1
				prev.next = self.array[head % thread_pool_node_buffer_capacity].raw
			}

			// Append the list that was supposed to be pushed to the end of the migrated Nodes
			mut last := self.array[(head - 1) % thread_pool_node_buffer_capacity].raw
			last.next = list.head
			list.tail.next = unsafe { nil }

			// Return the migrated nodes + the original list as overflowed
			list.head = first
			return thread_pool_error_overflow
		}
	}
}

fn (mut self ThreadPoolNodeBuffer) pop() &ThreadPoolNode {
	mut head := self.head.load(.monotonic)
	tail := self.tail.raw // we're the only thread that can change this

	for {
		// Quick sanity check and return null when not empty
		size := tail - head
		assert size <= thread_pool_node_buffer_capacity
		if size == 0 {
			return unsafe { nil }
		}

		// Dequeue with an acquire barrier to ensure any writes done to the Node
		// only happen after we succesfully claim it from the array.
		head = self.head.cmpxchg_weak(head, head + 1, .acquire, .monotonic) or {
			return self.array[head % thread_pool_node_buffer_capacity].raw
		}
	}
	return unsafe { nil }
}

struct ThreadPoolNodeBufferStole {
	node   &ThreadPoolNode
	pushed bool
}

fn (mut self ThreadPoolNodeBuffer) consume(mut queue ThreadPoolNodeQueue) ?ThreadPoolNodeBufferStole {
	mut consumer := queue.try_acquire_consumer() or { return none }
	defer {
		queue.release_consumer(consumer)
	}

	head := self.head.load(.monotonic)
	tail := self.tail.raw // we're the only thread that can change this

	size := tail - head
	assert size <= thread_pool_node_buffer_capacity
	assert size == 0 // we should only be consuming if our array is empty

	// Pop nodes from the queue and push them to our array.
	// Atomic stores to the array as steal() threads may be atomically reading from it.
	mut pushed := u32(0)
	for ; pushed < thread_pool_node_buffer_capacity; pushed += 1 {
		node := queue.pop(&consumer)
		if isnil(node) {
			break
		}
		// (Zig `.unordered` has no C11 equivalent; the next-stronger `.monotonic` is used.)
		self.array[(tail + pushed) % thread_pool_node_buffer_capacity].store(node, .monotonic)
	}

	// We will be returning one node that we stole from the queue.
	// Get an extra, and if that's not possible, take one from our array.
	mut node := queue.pop(&consumer)
	if isnil(node) {
		// blk:
		if pushed == 0 {
			return none
		}
		pushed -= 1
		node = self.array[(tail + pushed) % thread_pool_node_buffer_capacity].raw
	}

	// Update the array tail with the nodes we pushed to it.
	// Release barrier to synchronize with Acquire barrier in steal()'s to see the written array Nodes.
	if pushed > 0 {
		self.tail.store(tail + pushed, .release)
	}
	return ThreadPoolNodeBufferStole{
		node:   node
		pushed: pushed > 0
	}
}

fn (mut self ThreadPoolNodeBuffer) steal(mut buffer ThreadPoolNodeBuffer) ?ThreadPoolNodeBufferStole {
	head := self.head.load(.monotonic)
	tail := self.tail.raw // we're the only thread that can change this

	size := tail - head
	assert size <= thread_pool_node_buffer_capacity
	assert size == 0 // we should only be stealing if our array is empty

	// `while (true) : (std.atomic.spinLoopHint())`: cpu_relax() is a statement
	// macro, so it is called before each `continue` and at the end of the body.
	for {
		buffer_head := buffer.head.load(.acquire)
		buffer_tail := buffer.tail.load(.acquire)

		// Overly large size indicates the the tail was updated a lot after the head was loaded.
		// Reload both and try again.
		buffer_size := buffer_tail - buffer_head
		if buffer_size > thread_pool_node_buffer_capacity {
			C.cpu_relax()
			continue
		}

		// Try to steal half (divCeil) to amortize the cost of stealing from other threads.
		steal_size := buffer_size - (buffer_size / 2)
		if steal_size == 0 {
			return none
		}

		// Copy the nodes we will steal from the target's array to our own.
		// Atomically load from the target buffer array as it may be pushing and atomically storing to it.
		// Atomic store to our array as other steal() threads may be atomically loading from it as above.
		// (Zig `.unordered` has no C11 equivalent; the next-stronger `.monotonic` is used.)
		mut i := u32(0)
		for ; i < steal_size; i += 1 {
			node :=
				buffer.array[(buffer_head + i) % thread_pool_node_buffer_capacity].load(.monotonic)
			self.array[(tail + i) % thread_pool_node_buffer_capacity].store(node, .monotonic)
		}

		// Try to commit the steal from the target buffer using:
		// - an Acquire barrier to ensure that we only interact with the stolen Nodes after the steal was committed.
		// - a Release barrier to ensure that the Nodes are copied above prior to the committing of the steal
		//   because if they're copied after the steal, the could be getting rewritten by the target's push().
		_ = buffer.head.cmpxchg_strong(buffer_head, buffer_head + steal_size, .acq_rel, .monotonic) or {
			// Pop one from the nodes we stole as we'll be returning it
			pushed := steal_size - 1
			node := self.array[(tail + pushed) % thread_pool_node_buffer_capacity].raw

			// Update the array tail with the nodes we pushed to it.
			// Release barrier to synchronize with Acquire barrier in steal()'s to see the written array Nodes.
			if pushed > 0 {
				self.tail.store(tail + pushed, .release)
			}
			return ThreadPoolNodeBufferStole{
				node:   node
				pushed: pushed > 0
			}
		}
		C.cpu_relax()
	}
	return none
}

// ---------------------------------------------------------------------------
// V translations of the Zig std primitives used above.
// ---------------------------------------------------------------------------

// Zig error values used by this file. They never leave the thread pool, and
// are created once so that returning them does not allocate (the pool is
// allocation-free).
const thread_pool_error_shutdown = error('Shutdown')
const thread_pool_error_empty = error('Empty')
const thread_pool_error_contended = error('Contended')
const thread_pool_error_overflow = error('Overflow')
const thread_pool_error_system_resources = error('SystemResources')
const thread_pool_error_unexpected = error('Unexpected')

// std.builtin.AtomicOrder, with the values of the GCC/Clang `__ATOMIC_*`
// constants that the `__atomic_*` builtins take. Zig's `.unordered` has no
// C11/GCC equivalent; call sites use the next-stronger `.monotonic` (relaxed).
enum ThreadPoolAtomicOrder as int {
	monotonic = 0 // __ATOMIC_RELAXED
	acquire   = 2 // __ATOMIC_ACQUIRE
	release   = 3 // __ATOMIC_RELEASE
	acq_rel   = 4 // __ATOMIC_ACQ_REL
	seq_cst   = 5 // __ATOMIC_SEQ_CST
}

// sync.stdatomic only offers sequentially consistent operations, so the
// type-generic GCC/Clang `__atomic_*` builtins (also implemented by tcc) are
// called directly to keep the exact orderings of the Zig code.
fn C.__atomic_load(ptr voidptr, ret voidptr, order int)
fn C.__atomic_store(ptr voidptr, val voidptr, order int)
fn C.__atomic_exchange(ptr voidptr, val voidptr, ret voidptr, order int)
fn C.__atomic_compare_exchange(ptr voidptr, expected voidptr, desired voidptr, weak bool, success_order int, failure_order int) bool
fn C.__atomic_fetch_sub(ptr voidptr, val u64, order int) u64

// std.atomic.Value(T). T is u32, usize or a pointer type.
struct ThreadPoolAtomic[T] {
mut:
	// Care must be taken to avoid data races when interacting with this field directly.
	raw T
}

@[inline]
fn thread_pool_atomic_zero[T]() T {
	$if T is $pointer {
		return unsafe { T(nil) }
	} $else {
		return T(0)
	}
}

@[inline]
fn (self &ThreadPoolAtomic[T]) load(order ThreadPoolAtomicOrder) T {
	mut ret := thread_pool_atomic_zero[T]()
	C.__atomic_load(&self.raw, &ret, int(order))
	return ret
}

@[inline]
fn (mut self ThreadPoolAtomic[T]) store(value T, order ThreadPoolAtomicOrder) {
	mut val := unsafe { value }
	C.__atomic_store(&self.raw, &val, int(order))
}

@[inline]
fn (mut self ThreadPoolAtomic[T]) swap(operand T, order ThreadPoolAtomicOrder) T {
	mut val := unsafe { operand }
	mut ret := thread_pool_atomic_zero[T]()
	C.__atomic_exchange(&self.raw, &val, &ret, int(order))
	return ret
}

@[inline]
fn (mut self ThreadPoolAtomic[T]) fetch_sub(operand T, order ThreadPoolAtomicOrder) T {
	$if T is $int {
		return T(C.__atomic_fetch_sub(&self.raw, u64(operand), int(order)))
	} $else {
		panic('ThreadPoolAtomic.fetch_sub needs an integer type')
	}
}

// cmpxchgWeak: returns none on success and the current value on failure.
@[inline]
fn (mut self ThreadPoolAtomic[T]) cmpxchg_weak(expected_value T, new_value T, success_order ThreadPoolAtomicOrder, failure_order ThreadPoolAtomicOrder) ?T {
	mut expected := unsafe { expected_value }
	mut desired := unsafe { new_value }
	if C.__atomic_compare_exchange(&self.raw, &expected, &desired, true, int(success_order),
		int(failure_order))
	{
		return none
	}
	return expected
}

// cmpxchgStrong: returns none on success and the current value on failure.
@[inline]
fn (mut self ThreadPoolAtomic[T]) cmpxchg_strong(expected_value T, new_value T, success_order ThreadPoolAtomicOrder, failure_order ThreadPoolAtomicOrder) ?T {
	mut expected := unsafe { expected_value }
	mut desired := unsafe { new_value }
	if C.__atomic_compare_exchange(&self.raw, &expected, &desired, false, int(success_order),
		int(failure_order))
	{
		return none
	}
	return expected
}

// std.Thread.getCpuCount() catch 1
fn thread_pool_get_cpu_count() u32 {
	count := runtime.nr_cpus()
	return if count > 0 { u32(count) } else { 1 }
}

// std.Thread.SpawnConfig
struct ThreadPoolSpawnConfig {
	stack_size u32 = thread_pool_default_stack_size
}

// std.Thread.Futex. V's sync module has no futex, so the minimal behavior of
// Zig's DarwinImpl and LinuxImpl (wait without timeout, wake) is translated.
@[c_extern]
fn C.__ulock_wait2(operation u32, addr voidptr, value u64, timeout_ns u64, value2 u64) int

@[c_extern]
fn C.__ulock_wake(operation u32, addr voidptr, wake_value u64) int

// Darwin `UL` flags: .op = .COMPARE_AND_WAIT, .WAKE_ALL, .NO_ERRNO.
const thread_pool_ul_compare_and_wait = u32(1)
const thread_pool_ulf_wake_all = u32(0x100)
const thread_pool_ulf_no_errno = u32(0x1000000)

// Linux FUTEX_OP: .cmd = .WAIT / .WAKE, .private = true.
const thread_pool_futex_wait_private = 0 | 128
const thread_pool_futex_wake_private = 1 | 128

// Checks if `ptr` still contains the value `expect` and, if so, blocks the caller until either:
// - The value at `ptr` is no longer equal to `expect`.
// - The caller is unblocked by a matching `wake()`.
// - The caller is unblocked spuriously ("at random").
fn thread_pool_futex_wait(ptr &ThreadPoolAtomic[u32], expect u32) {
	$if macos {
		// Zig uses __ulock_wait2 when targeting macOS 11+; timeout 0 means no timeout.
		flags := thread_pool_ul_compare_and_wait | thread_pool_ulf_no_errno
		status := C.__ulock_wait2(flags, voidptr(&ptr.raw), u64(expect), 0, 0)
		if status >= 0 {
			return
		}
		match -status {
			// Wait was interrupted by the OS or other spurious signalling.
			C.EINTR {}
			// Address of the futex was paged out. This is unlikely, but possible in theory, and
			// pthread/libdispatch on darwin bother to handle it. In this case we'll return
			// without waiting, but the caller should retry anyway.
			C.EFAULT {}
			else {
				panic('unreachable')
			}
		}
	} $else $if linux {
		rc := unsafe {
			C.syscall(C.SYS_futex, voidptr(&ptr.raw),
				voidptr(usize(thread_pool_futex_wait_private)), voidptr(usize(expect)), nil)
		}
		if rc == 0 {
			// notified by `wake()`
			return
		}
		match C.errno {
			C.EINTR {} // spurious wakeup
			C.EAGAIN {} // ptr.* != expect
			C.EINVAL {} // possibly timeout overflow
			else {
				panic('unreachable')
			}
		}
	} $else $if windows {
		thread_pool_windows_futex_wait(ptr, expect)
	} $else $if wasm32_wasi {
		thread_pool_wasi_futex_wait(ptr, expect)
	} $else {
		$compile_error('xev.ThreadPool: no translated futex for this target')
	}
}

// Unblocks at most `max_waiters` callers blocked in a `wait()` call on `ptr`.
fn thread_pool_futex_wake(ptr &ThreadPoolAtomic[u32], max_waiters u32) {
	// Avoid calling into the OS if there's nothing to wake up.
	if max_waiters == 0 {
		return
	}

	$if macos {
		mut flags := thread_pool_ul_compare_and_wait | thread_pool_ulf_no_errno
		if max_waiters > 1 {
			flags |= thread_pool_ulf_wake_all
		}

		for {
			status := C.__ulock_wake(flags, voidptr(&ptr.raw), 0)
			if status >= 0 {
				return
			}
			match -status {
				C.EINTR { continue } // spurious wake()
				C.ENOENT { return } // nothing was woken up
				else { panic('unreachable') }
			}
		}
	} $else $if linux {
		n := if max_waiters > u32(max_i32) { u32(max_i32) } else { max_waiters }
		rc := unsafe {
			C.syscall(C.SYS_futex, voidptr(&ptr.raw),
				voidptr(usize(thread_pool_futex_wake_private)), voidptr(usize(n)))
		}
		if rc >= 0 {
			// successful wake up
			return
		}
		match C.errno {
			C.EINVAL {} // invalid futex_wait() on ptr done elsewhere
			C.EFAULT {} // pointer became invalid while doing the wake
			else {
				panic('unreachable')
			}
		}
	} $else $if windows {
		thread_pool_windows_futex_wake(ptr, max_waiters)
	} $else $if wasm32_wasi {
		thread_pool_wasi_futex_wake(ptr, max_waiters)
	} $else {
		$compile_error('xev.ThreadPool: no translated futex for this target')
	}
}
