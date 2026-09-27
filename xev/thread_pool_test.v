module xev

import sync

// libxev's src/ThreadPool.zig has no `test` blocks. These tests cover what
// upstream does check about the pool: the ThreadPool part of `test "c-api
// sizes"` in src/c_api.zig, the file's own `comptime` assertions, the Batch API
// as used by src/c_api.zig, and the init/schedule/shutdown/deinit lifecycle as
// used by the backends (e.g. `test "kqueue: file IO on thread pool"`).

// Translated from src/c_api.zig `test "c-api sizes"` (ThreadPool entries).
// THE MAGIC NUMBERS ARE KEPT IN SYNC WITH "include/xev.h"
fn test_thread_pool_c_api_sizes() {
	assert sizeof(ThreadPool) == 48
	assert sizeof(ThreadPoolBatch) == 24
	// c_api.zig's Task is `[@sizeOf(xev.ThreadPool.Task)]u8` plus a callback pointer.
	assert sizeof(ThreadPoolTask) + sizeof(voidptr) == 24
	assert sizeof(ThreadPoolConfig) == 8
}

fn test_thread_pool_atomic_orders_match_compiler_builtins() {
	assert sizeof(ThreadPoolAtomicOrder) == sizeof(int)
	assert int(ThreadPoolAtomicOrder.monotonic) == 0
	assert int(ThreadPoolAtomicOrder.acquire) == 2
	assert int(ThreadPoolAtomicOrder.release) == 3
	assert int(ThreadPoolAtomicOrder.acq_rel) == 4
	assert int(ThreadPoolAtomicOrder.seq_cst) == 5
}

struct ThreadPoolTestNodeAlign {
	pad  u8
	node ThreadPoolNode
}

// The `comptime` assertions of src/ThreadPool.zig.
fn test_thread_pool_comptime_asserts() {
	// Node.Queue: assert(@alignOf(Node) >= ((IS_CONSUMING | HAS_CACHE) + 1));
	node_align := __offsetof(ThreadPoolTestNodeAlign, node)
	assert node_align >= (thread_pool_node_queue_is_consuming | thread_pool_node_queue_has_cache) +
		1
	// Node.Buffer: assert(std.math.maxInt(Index) >= capacity);
	assert max_u32 >= thread_pool_node_buffer_capacity
	// Node.Buffer: assert(std.math.isPowerOfTwo(capacity));
	assert thread_pool_node_buffer_capacity & (thread_pool_node_buffer_capacity - 1) == 0
}

// The Sync packed struct round-trips through its u32 bit layout.
fn test_thread_pool_sync_bits() {
	assert ThreadPoolSync{}.to_bits() == 0
	assert ThreadPoolSync{
		spawned: 1
	}.to_bits() == u32(1) << 14
	s := ThreadPoolSync{
		idle:     0x3fff
		spawned:  5
		notified: true
		state:    .shutdown
	}
	bits := s.to_bits()
	assert bits == 0x3fff | (u32(5) << 14) | (u32(1) << 29) | (u32(3) << 30)
	assert ThreadPoolSync.from_bits(bits) == s
}

// Mirrors xev_threadpool_config_init / xev_threadpool_init in src/c_api.zig.
fn test_thread_pool_config() {
	cfg := ThreadPoolConfig{}
	assert cfg.stack_size == 16 * 1024 * 1024
	assert cfg.max_threads == 0

	mut pool := ThreadPool.init(max_threads: 3, stack_size: 0)
	assert pool.max_threads == 3
	assert pool.stack_size == 1

	mut pool2 := ThreadPool.init()
	assert pool2.max_threads > 0
	assert pool2.stack_size == 16 * 1024 * 1024

	pool.shutdown()
	pool.deinit()
	pool2.shutdown()
	pool2.deinit()
}

// Mirrors xev_threadpool_batch_init / _push_task / _push_batch in src/c_api.zig.
fn test_thread_pool_batch_push() {
	a := ThreadPoolTask{}
	b := ThreadPoolTask{}
	c := ThreadPoolTask{}

	mut batch := ThreadPoolBatch{}
	assert batch.len == 0
	batch.push(ThreadPoolBatch.from(&a))
	assert batch.len == 1
	assert voidptr(batch.head) == voidptr(&a)
	assert voidptr(batch.tail) == voidptr(&a)

	mut other := ThreadPoolBatch.from(&b)
	other.push(ThreadPoolBatch.from(&c))
	batch.push(other)
	assert batch.len == 3
	assert voidptr(batch.head) == voidptr(&a)
	assert voidptr(batch.tail) == voidptr(&c)
	assert voidptr(a.node.next) == voidptr(&b.node)
	assert voidptr(b.node.next) == voidptr(&c.node)

	// Pushing an empty batch is a no-op.
	batch.push(ThreadPoolBatch{})
	assert batch.len == 3
	assert voidptr(batch.tail) == voidptr(&c)
}

struct ThreadPoolTestTask {
mut:
	task     ThreadPoolTask
	pool     &ThreadPool     = unsafe { nil }
	wg       &sync.WaitGroup = unsafe { nil }
	ran      u32
	children []ThreadPoolTestTask
}

// @fieldParentPtr("task", t)
fn thread_pool_test_parent(t &ThreadPoolTask) &ThreadPoolTestTask {
	return unsafe { &ThreadPoolTestTask(voidptr(usize(t) - __offsetof(ThreadPoolTestTask, task))) }
}

fn thread_pool_test_callback(t &ThreadPoolTask) {
	mut self := thread_pool_test_parent(t)
	self.ran += 1
	self.wg.done()
}

// A task that schedules its children as one batch from inside the pool, which
// goes through Thread.current and the thread's local run buffer.
fn thread_pool_test_spawning_callback(t &ThreadPoolTask) {
	mut self := thread_pool_test_parent(t)
	self.ran += 1
	mut batch := ThreadPoolBatch{}
	for i in 0 .. self.children.len {
		batch.push(ThreadPoolBatch.from(&self.children[i].task))
	}
	self.pool.schedule(batch)
	self.wg.done()
}

// A task that schedules each of its children one by one from inside the pool.
fn thread_pool_test_spawning_one_by_one_callback(t &ThreadPoolTask) {
	mut self := thread_pool_test_parent(t)
	self.ran += 1
	for i in 0 .. self.children.len {
		self.pool.schedule(ThreadPoolBatch.from(&self.children[i].task))
	}
	self.wg.done()
}

fn thread_pool_test_tasks(n int, pool &ThreadPool, wg &sync.WaitGroup, cb ThreadPoolTaskCallback) []ThreadPoolTestTask {
	mut tasks := []ThreadPoolTestTask{cap: n}
	for _ in 0 .. n {
		tasks << ThreadPoolTestTask{
			task: ThreadPoolTask{
				callback: cb
			}
			pool: unsafe { pool }
			wg:   unsafe { wg }
		}
	}
	return tasks
}

// The lifecycle used by the backends: `defer tpool.deinit(); defer tpool.shutdown();`
fn test_thread_pool_single_task() {
	mut pool := ThreadPool.init()
	defer {
		pool.deinit()
	}
	defer {
		pool.shutdown()
	}

	mut wg := sync.new_waitgroup()
	wg.add(1)
	mut tasks := thread_pool_test_tasks(1, &pool, wg, thread_pool_test_callback)
	pool.schedule(ThreadPoolBatch.from(&tasks[0].task))
	wg.wait()
	assert tasks[0].ran == 1
}

fn test_thread_pool_shutdown_without_threads() {
	mut pool := ThreadPool.init(max_threads: 4)
	pool.shutdown()
	// Scheduling after shutdown queues the tasks but never spawns a thread.
	t := ThreadPoolTask{
		callback: thread_pool_test_callback
	}
	pool.schedule(ThreadPoolBatch.from(&t))
	assert ThreadPoolSync.from_bits(pool.sync.load(.monotonic)).spawned == 0
	// shutdown() with no threads spawned notified join_event, so this returns.
	pool.deinit()
}

fn thread_pool_test_run_batch(max_threads u32, n int) {
	mut pool := ThreadPool.init(max_threads: max_threads)
	defer {
		pool.deinit()
	}
	defer {
		pool.shutdown()
	}

	mut wg := sync.new_waitgroup()
	wg.add(n)
	mut tasks := thread_pool_test_tasks(n, &pool, wg, thread_pool_test_callback)
	mut batch := ThreadPoolBatch{}
	for i in 0 .. tasks.len {
		batch.push(ThreadPoolBatch.from(&tasks[i].task))
	}
	assert batch.len == usize(n)
	pool.schedule(batch)
	wg.wait()
	for t in tasks {
		assert t.ran == 1
	}
	sync_ := ThreadPoolSync.from_bits(pool.sync.load(.monotonic))
	assert sync_.spawned <= max_threads
}

fn test_thread_pool_batch_one_thread() {
	thread_pool_test_run_batch(1, 1000)
}

fn test_thread_pool_batch_many_threads() {
	thread_pool_test_run_batch(8, 10000)
}

fn test_thread_pool_schedule_individually() {
	mut pool := ThreadPool.init(max_threads: 4)
	defer {
		pool.deinit()
	}
	defer {
		pool.shutdown()
	}

	n := 2000
	mut wg := sync.new_waitgroup()
	wg.add(n)
	mut tasks := thread_pool_test_tasks(n, &pool, wg, thread_pool_test_callback)
	for i in 0 .. tasks.len {
		pool.schedule(ThreadPoolBatch.from(&tasks[i].task))
	}
	wg.wait()
	for t in tasks {
		assert t.ran == 1
	}
}

// Scheduling from a pool thread pushes to that thread's run buffer; batches
// larger than its capacity (256) take the Overflow path into its run queue, and
// idle threads steal from both.
fn test_thread_pool_schedule_from_tasks() {
	mut pool := ThreadPool.init(max_threads: 4)
	defer {
		pool.deinit()
	}
	defer {
		pool.shutdown()
	}

	parents := 8
	children := 1000
	mut wg := sync.new_waitgroup()
	wg.add(parents * (children + 1))
	mut tasks := thread_pool_test_tasks(parents, &pool, wg, thread_pool_test_spawning_callback)
	for i in 0 .. tasks.len {
		if i % 2 == 1 {
			tasks[i].task.callback = thread_pool_test_spawning_one_by_one_callback
		}
		tasks[i].children = thread_pool_test_tasks(children, &pool, wg, thread_pool_test_callback)
	}
	mut batch := ThreadPoolBatch{}
	for i in 0 .. tasks.len {
		batch.push(ThreadPoolBatch.from(&tasks[i].task))
	}
	pool.schedule(batch)
	wg.wait()
	for t in tasks {
		assert t.ran == 1
		for c in t.children {
			assert c.ran == 1
		}
	}
}

// Workers go idle between rounds, so every round goes through the idle_event
// notify/wait path again.
fn test_thread_pool_reuses_idle_threads() {
	mut pool := ThreadPool.init(max_threads: 2)
	defer {
		pool.deinit()
	}
	defer {
		pool.shutdown()
	}

	for _ in 0 .. 50 {
		mut wg := sync.new_waitgroup()
		wg.add(4)
		mut tasks := thread_pool_test_tasks(4, &pool, wg, thread_pool_test_callback)
		for i in 0 .. tasks.len {
			pool.schedule(ThreadPoolBatch.from(&tasks[i].task))
		}
		wg.wait()
		for t in tasks {
			assert t.ran == 1
		}
	}
	assert ThreadPoolSync.from_bits(pool.sync.load(.monotonic)).spawned <= 2
}
