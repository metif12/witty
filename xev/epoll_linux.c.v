module xev

// Epoll backend.
//
// WARNING: this backend is a bit of a mess. It is missing features and in
// general is in much poorer quality than all of the other backends. It
// isn't meant to really be used yet. We should remodel this in the style of
// the kqueue backend.
//
// V translation of libxev's src/backend/epoll.zig (pinned 34fa508). Zig's
// `Xev(.epoll, epoll)` API types carry an `Epoll` prefix in this module.
// The Operation and Result tagged unions are represented as flat records with
// a tag so that the timer payload has a stable address inside a completion.

// std.os.linux.EPOLL constants.
const epoll_cloexec = u32(int(C.EPOLL_CLOEXEC))
const epoll_ctl_add = u32(int(C.EPOLL_CTL_ADD))
const epoll_ctl_del = u32(int(C.EPOLL_CTL_DEL))
const epoll_in = u32(int(C.EPOLLIN))
const epoll_out = u32(int(C.EPOLLOUT))
const epoll_rdhup = u32(int(C.EPOLLRDHUP))

// The callback of the main Loop operations. Higher level interfaces may
// use a different callback mechanism.
pub type EpollCallback = fn (userdata voidptr, loop &EpollLoop, completion &EpollCompletion, result EpollResult) CallbackAction

// A callback that does nothing and immediately disarms. This
// implements xev.Callback and is the default value for completions.
pub fn epoll_noop_callback(_ voidptr, _ &EpollLoop, _ &EpollCompletion, _ EpollResult) CallbackAction {
	return .disarm
}

// True if epoll is available on this platform.
pub fn epoll_available() bool {
	// builtin.os.tag == .linux: this file is only compiled for Linux.
	return true
}

// Some internal fields we can pack for better space.
pub struct EpollLoopFlags {
pub mut:
	value u8
}

// True once it is initialized.
pub fn (f EpollLoopFlags) init() bool {
	return f.value & 0b001 != 0
}

// Whether we're in a run or not (to prevent nested runs).
pub fn (f EpollLoopFlags) in_run() bool {
	return f.value & 0b010 != 0
}

// Whether our loop is in a stopped state or not.
pub fn (f EpollLoopFlags) stopped() bool {
	return f.value & 0b100 != 0
}

fn (mut f EpollLoopFlags) set(mask u8, v bool) {
	if v {
		f.value |= mask
	} else {
		f.value &= ~mask
	}
}

pub fn (mut f EpollLoopFlags) set_init(v bool) {
	f.set(0b001, v)
}

pub fn (mut f EpollLoopFlags) set_in_run(v bool) {
	f.set(0b010, v)
}

pub fn (mut f EpollLoopFlags) set_stopped(v bool) {
	f.set(0b100, v)
}

@[heap]
pub struct EpollLoop {
pub mut:
	fd int

	// The eventfd that this epoll queue always has a filter for. Writing
	// an empty message to this eventfd can be used to wake up the loop
	// at any time. Waking up the loop via this eventfd won't trigger any
	// particular completion, it just forces tick to cycle.
	eventfd EpollAsync

	// The number of active completions. This DOES NOT include completions that
	// are queued in the submissions queue.
	active usize

	// Our queue of submissions that we want to enqueue on the next tick.
	submissions IntrusiveQueue[EpollCompletion]

	// The queue for completions to delete from the epoll fd.
	deletions IntrusiveQueue[EpollCompletion]

	// Heap of timers.
	timers IntrusiveHeap[EpollHeapTimer] = IntrusiveHeap[EpollHeapTimer]{
		less: epoll_timer_less
	}

	// The thread pool to use for blocking operations that epoll can't do.
	thread_pool &ThreadPool = unsafe { nil }

	// The MPSC queue for completed completions from the thread pool.
	thread_pool_completions IntrusiveMpscQueue[EpollCompletion]

	// Cached time
	cached_now Timespec

	// Some internal fields we can pack for better space.
	flags EpollLoopFlags
}

pub fn EpollLoop.init(options Options) !EpollLoop {
	mut eventfd := EpollAsync.init()!

	fd := posix_epoll_create1(epoll_cloexec) or {
		// errdefer eventfd.deinit();
		eventfd.deinit()
		return err
	}
	mut res := EpollLoop{
		fd:          fd
		eventfd:     eventfd
		thread_pool: options.thread_pool
	}
	res.update_now()
	return res
}

pub fn (mut self EpollLoop) deinit() {
	posix_close(self.fd)
	self.eventfd.deinit()
}

// Run the event loop. See RunMode documentation for details on modes.
// Once the loop is run, the pointer MUST remain stable.
pub fn (mut self EpollLoop) run(mode RunMode) ! {
	match mode {
		.no_wait {
			self.tick(0)!
		}
		.once {
			self.tick(1)!
		}
		.until_done {
			for !self.done() {
				self.tick(1)!
			}
		}
	}
}

fn (self &EpollLoop) done() bool {
	return self.flags.stopped() || (self.active == 0 && self.submissions.empty())
}

// Stop the loop. This can only be called from the main thread.
// This will stop the loop forever. Future ticks will do nothing.
//
// This does NOT stop any completions that are queued to be executed
// in the thread pool. If you are using a thread pool, completions
// are not safe to recover until the thread pool is shut down. If
// you're not using a thread pool, all completions are safe to
// read/write once any outstanding `run` or `tick` calls are returned.
pub fn (mut self EpollLoop) stop() {
	self.flags.set_stopped(true)
}

// Returns true if the loop is stopped. This may mean there
// are still pending completions to be processed.
pub fn (self &EpollLoop) stopped() bool {
	return self.flags.stopped()
}

// Add a completion to the loop.
pub fn (mut self EpollLoop) add(completion &EpollCompletion) {
	mut c := unsafe { completion }
	match c.flags.state() {
		// Already adding, forget about it.
		.adding {
			return
		}
		// If it is dead we're good. If we're deleting we'll ignore it
		// while we're processing.
		.dead, .deleting {}
		.active {
			panic('unreachable')
		}
	}
	c.flags.set_state(.adding)

	// We just add the completion to the queue. Failures can happen
	// at tick time...
	self.submissions.push(c)
}

// Delete a completion from the loop.
pub fn (mut self EpollLoop) delete(completion &EpollCompletion) {
	mut c := unsafe { completion }
	match c.flags.state() {
		// Already deleted
		.deleting {
			return
		}
		// If we're active then we will stop it and remove from epoll.
		// If we're adding then we'll ignore it when adding.
		.dead, .active, .adding {}
	}
	c.flags.set_state(.deleting)

	self.deletions.push(c)
}

// Returns the "loop" time in milliseconds. The loop time is updated
// once per loop tick, before IO polling occurs. It remains constant
// throughout callback execution.
//
// You can force an update of the "now" value by calling update_now()
// at any time from the main thread.
//
// The clock that is used is not guaranteed. In general, a monotonic
// clock source is always used if available. This value should typically
// just be used for relative time calculations within the loop, such as
// answering the question "did this happen <x> ms ago?".
pub fn (self &EpollLoop) now() i64 {
	// If anything overflows we just return the max value.
	max := max_i64

	// Calculate all the values, being careful about overflows in order
	// to just return the maximum value.
	sec := mul_i64(self.cached_now.tv_sec, 1000) or { return max }
	nsec := floor_div_i64(self.cached_now.tv_nsec, 1_000_000)
	return sat_add_i64(sec, nsec)
}

// Update the cached time.
pub fn (mut self EpollLoop) update_now() {
	if new_time := posix_clock_gettime(C.CLOCK_MONOTONIC) {
		self.cached_now = new_time
	} else {
		// Errors are ignored.
	}
}

// Add a timer to the loop. The timer will execute in "next_ms". This
// is oneshot: the timer will not repeat. To repeat a timer, either
// schedule another in your callback or return rearm from the callback.
pub fn (mut self EpollLoop) timer(c &EpollCompletion, next_ms u64, userdata voidptr, cb EpollCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = EpollCompletion{
			op:       EpollOperation{
				tag:   .timer
				timer: EpollHeapTimer{
					next: self.timer_next(next_ms)
				}
			}
			userdata: userdata
			callback: cb
		}
	}

	self.add(completion)
}

// See io_uring.timer_reset for docs.
pub fn (mut self EpollLoop) timer_reset(c &EpollCompletion, c_cancel &EpollCompletion, next_ms u64, userdata voidptr, cb EpollCallback) {
	mut completion := unsafe { c }
	mut cancel := unsafe { c_cancel }
	match completion.flags.state() {
		.dead, .deleting {
			self.timer(completion, next_ms, userdata, cb)
			return
		}
		// Adding state we can just modify the metadata and return
		// since the timer isn't in the heap yet.
		.adding {
			completion.op.timer.next = self.timer_next(next_ms)
			completion.userdata = userdata
			completion.callback = cb
			return
		}
		.active {
			// Update the reset time for the timer to the desired time
			// along with all the callbacks.
			completion.op.timer.reset = self.timer_next(next_ms)
			completion.userdata = userdata
			completion.callback = cb

			// If the cancellation is active, we assume its for this timer
			// and do nothing.
			if cancel.state() == .active {
				return
			}
			assert cancel.state() == .dead && completion.state() == .active
			unsafe {
				*cancel = EpollCompletion{
					op: EpollOperation{
						tag:    .cancel
						cancel: EpollCancelOp{
							c: completion
						}
					}
				}
			}
			self.add(cancel)
		}
	}
}

fn (self &EpollLoop) timer_next(next_ms u64) Timespec {
	// Get the timestamp of the absolute time that we'll execute this timer.
	// There are lots of failure scenarios here in math. If we see any
	// of them we just use the maximum value.
	max := Timespec{
		tv_sec:  max_i64
		tv_nsec: max_i64
	}

	next_s := cast_i64(next_ms / 1000) or { return max }
	next_ns := cast_i64((next_ms % 1000) * 1_000_000) or { return max }

	return Timespec{
		tv_sec:  add_i64(self.cached_now.tv_sec, next_s) or { return max }
		tv_nsec: add_i64(self.cached_now.tv_nsec, next_ns) or { return max }
	}
}

// Tick through the event loop once, waiting for at least "wait" completions
// to be processed by the loop itself.
pub fn (mut self EpollLoop) tick(wait u32) ! {
	// If we're stopped then the loop is fully over.
	if self.flags.stopped() {
		return
	}

	// We can't nest runs.
	if self.flags.in_run() {
		return new_error(.nested_runs_not_allowed)
	}
	self.flags.set_in_run(true)
	defer {
		self.flags.set_in_run(false)
	}

	// Initialize
	if !self.flags.init() {
		self.flags.set_init(true)

		if !isnil(self.thread_pool) {
			self.thread_pool_completions.init()
		}

		mut ev := C.epoll_event{
			events: epoll_in | epoll_rdhup
		}
		ev.data.fd = self.eventfd.fd
		posix_epoll_ctl(self.fd, epoll_ctl_add, self.eventfd.fd, &ev) or {
			// We reset initialization because we can't do anything
			// safely unless we get this mach port registered!
			self.flags.set_init(false)
			return err
		}
	}

	// Submit all the submissions. We copy the submission queue so that
	// any resubmits don't cause an infinite loop.
	mut wait_rem := usize(wait)
	mut queued := self.submissions
	self.submissions = IntrusiveQueue[EpollCompletion]{}
	for {
		mut c := queued.pop() or { break }

		// We ignore any completions that aren't in the adding state.
		// This usually means that we switched them to be deleted or
		// something.
		if c.flags.state() != .adding {
			continue
		}

		// These operations happen synchronously. Ensure they are
		// decremented from wait_rem.
		match c.op.tag {
			// should noop be counted?
			// .noop,
			.cancel, .shutdown, .timer {
				wait_rem = sat_sub(wait_rem, 1)
			}
			else {}
		}

		self.start(mut c)
	}

	// Handle all deletions so we don't wait for them.
	for {
		mut c := self.deletions.pop() or { break }
		if c.flags.state() != .deleting {
			continue
		}
		self.stop_completion(mut c)
	}

	// If we have no active handles then we return no matter what.
	if self.active == 0 {
		// We still have to update our concept of "now".
		self.update_now()
		return
	}

	// Wait and process events. We only do this if we have any active.
	mut events := [1024]C.epoll_event{}
	for self.active > 0 && (wait == 0 || wait_rem > 0) {
		self.update_now()
		now_timer := EpollHeapTimer{
			next: self.cached_now
		}

		// Run our expired timers
		for {
			t := self.timers.peek() or { break }
			if !epoll_timer_less(t, &now_timer) {
				break
			}

			// Remove the timer
			deleted := self.timers.delete_min() or { panic('unreachable') }
			assert deleted == t

			// Mark completion as done
			mut c := t.c
			c.flags.set_state(.dead)
			self.active -= 1

			// Lower our remaining count
			wait_rem = sat_sub(wait_rem, 1)

			// Invoke
			action := c.callback(c.userdata, self, c, EpollResult{
				tag:   .timer
				timer: .expiration
			})
			match action {
				.disarm {}
				.rearm {
					self.start(mut c)
				}
			}
		}

		// Run our completed thread pool work
		if !isnil(self.thread_pool) {
			for {
				mut c := self.thread_pool_completions.pop() or { break }

				// Mark completion as done
				c.flags.set_state(.dead)
				self.active -= 1

				// Lower our remaining count
				wait_rem = sat_sub(wait_rem, 1)

				// Invoke
				action := c.callback(c.userdata, self, c, c.task_result)
				match action {
					.disarm {}
					.rearm {
						self.start(mut c)
					}
				}
			}
		}

		// Determine our next timeout based on the timers
		mut timeout := i32(0)
		if wait_rem == 0 {
			timeout = 0
		} else {
			// If we have a timer, we want to set the timeout to our next
			// timer value. If we have no timer, we wait forever.
			if t := self.timers.peek() {
				// Determine the time in milliseconds.
				ms_now := u64(self.cached_now.tv_sec) * 1000 + u64(self.cached_now.tv_nsec) / 1_000_000
				ms_next := u64(t.next.tv_sec) * 1000 + u64(t.next.tv_nsec) / 1_000_000
				ms := sat_sub_u64(ms_next, ms_now)
				assert ms <= u64(max_i32) // @intCast safety check
				timeout = i32(ms)
			} else {
				timeout = -1
			}
		}

		n := posix_epoll_wait(self.fd, &events[0], usize(events.len), timeout)
		// posix.epoll_wait returns an unsigned count (it retries EINTR and
		// treats every other error as unreachable), so, as in the source,
		// this branch never runs.
		if isize(n) < 0 {
			match posix_errno(i64(isize(n))) {
				C.EINTR { continue }
				else { return unexpected_errno(posix_errno(i64(isize(n)))) }
			}
		}

		// Process all our events and invoke their completion handlers
		for i in 0 .. int(n) {
			ev := events[i]

			// Handle wakeup eventfd
			if unsafe { ev.data.fd } == self.eventfd.fd {
				mut buffer := u64(0)
				_ := posix_read(self.eventfd.fd, unsafe { (&u8(&buffer)).vbytes(int(sizeof(u64))) }) or {
					0
				}
				continue
			}

			mut c := unsafe { &EpollCompletion(ev.data.ptr) }

			// We get the fd and mark this as in progress we can properly
			// clean this up late.r
			mut fd := ?int(none)
			if c.flags.dup() {
				fd = c.flags.dup_fd
			} else {
				fd = c.fd()
			}
			close_dup := c.flags.dup()
			c.flags.set_state(.dead)

			res := c.perform()
			action := c.callback(c.userdata, self, c, res)
			match action {
				.disarm {
					// We can't use self.stop because we can't trust
					// that c is still a valid pointer.
					if v := fd {
						posix_epoll_ctl(self.fd, epoll_ctl_del, v, unsafe { nil }) or {
							panic('unreachable')
						}

						if close_dup {
							posix_close(v)
						}
					}

					self.active -= 1
				}
				// For epoll, epoll remains armed by default. We have to
				// reset the state, that is all.
				.rearm {
					c.flags.set_state(.active)
				}
			}
		}

		if wait == 0 {
			break
		}
		wait_rem = sat_sub(wait_rem, n)
	}
}

// Shedule a completion to run on a thread.
fn (mut self EpollLoop) thread_schedule(mut c EpollCompletion) ! {
	if isnil(self.thread_pool) {
		return new_error(.thread_pool_required)
	}
	mut pool := self.thread_pool

	// Setup our completion state so that thread_perform can do stuff
	c.task_loop = unsafe { self }
	c.task_completions = unsafe { &self.thread_pool_completions }
	c.task = ThreadPoolTask{
		callback: epoll_thread_perform
	}

	// We need to mark this completion as active before we schedule.
	c.flags.set_state(.active)
	self.active += 1

	// Schedule it, from this point forward its not safe to touch c.
	pool.schedule(ThreadPoolBatch.from(&c.task))
}

// This is the main callback for the threadpool to perform work
// on completions for the loop.
fn epoll_thread_perform(t &ThreadPoolTask) {
	mut c := unsafe { &EpollCompletion(voidptr(usize(t) - __offsetof(EpollCompletion, task))) }

	// Do our task
	c.task_result = c.perform()

	// Add to our completion queue
	mut task_completions := c.task_completions
	task_completions.push(c)

	// Wake up our main loop
	mut loop := c.task_loop
	loop.wakeup() or {}
}

// Sends an empty message to this loop's eventfd so that it wakes up.
fn (mut self EpollLoop) wakeup() ! {
	self.eventfd.notify()!
}

fn (mut self EpollLoop) start(mut completion EpollCompletion) {
	mut res_ := ?EpollResult(none)
	match completion.op.tag {
		.noop {
			completion.flags.set_state(.dead)
			return
		}
		.cancel {
			if completion.flags.threadpool() {
				res_ = epoll_result_kind(.cancel, .thread_pool_unsupported)
			} else {
				// We stop immediately. We only stop if we are in the
				// "adding" state because cancellation or any other action
				// means we're complete already.
				if completion.flags.state() == .adding {
					mut target := completion.op.cancel.c
					if target.op.tag == .cancel {
						panic('cannot cancel a cancellation')
					}
					self.stop_completion(mut target)
				}

				// We always run timers
				res_ = EpollResult{
					tag: .cancel
				}
			}
		}
		.accept {
			mut ev := epoll_event_init(epoll_in, &completion)

			if fd := completion.fd_maybe_dup() {
				posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
					res_ = epoll_result_err(.accept, err)
				}
			} else {
				res_ = epoll_result_err(.accept, err)
			}
		}
		.connect {
			if fd := completion.fd_maybe_dup() {
				mut connected := true
				mut would_block := false
				posix_connect(fd, completion.op.connect.addr.any(), completion.op.connect.addr.get_os_sock_len()) or {
					connected = false
					match error_kind(err) {
						// If we would block then we register with epoll
						.would_block {
							would_block = true
						}
						// Any other error we just return immediately
						else {
							res_ = epoll_result_err(.connect, err)
						}
					}
				}

				if connected {
					res_ = EpollResult{
						tag: .connect
					}
				} else if would_block {
					// If connect returns WouldBlock then we register for OUT events
					// and are notified of connection completion that way.
					mut ev := epoll_event_init(epoll_out, &completion)

					posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
						res_ = epoll_result_err(.connect, err)
					}
				}
			} else {
				res_ = epoll_result_err(.connect, err)
			}
		}
		.read {
			if completion.flags.threadpool() {
				self.thread_schedule(mut completion) or { res_ = epoll_result_err(.read, err) }
				if res_ == none {
					return
				}
			} else {
				mut ev := epoll_event_init(epoll_in | epoll_rdhup, &completion)

				if fd := completion.fd_maybe_dup() {
					posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
						res_ = epoll_result_err(.read, err)
					}
				} else {
					res_ = epoll_result_err(.read, err)
				}
			}
		}
		// The source reports pread failures through the `.read` result.
		.pread {
			if completion.flags.threadpool() {
				self.thread_schedule(mut completion) or { res_ = epoll_result_err(.read, err) }
				if res_ == none {
					return
				}
			} else {
				mut ev := epoll_event_init(epoll_in | epoll_rdhup, &completion)

				if fd := completion.fd_maybe_dup() {
					posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
						res_ = epoll_result_err(.read, err)
					}
				} else {
					res_ = epoll_result_err(.read, err)
				}
			}
		}
		.write {
			if completion.flags.threadpool() {
				self.thread_schedule(mut completion) or { res_ = epoll_result_err(.write, err) }
				if res_ == none {
					return
				}
			} else {
				mut ev := epoll_event_init(epoll_out, &completion)

				if fd := completion.fd_maybe_dup() {
					posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
						res_ = epoll_result_err(.write, err)
					}
				} else {
					res_ = epoll_result_err(.write, err)
				}
			}
		}
		// The source reports pwrite failures through the `.write` result.
		.pwrite {
			if completion.flags.threadpool() {
				self.thread_schedule(mut completion) or { res_ = epoll_result_err(.write, err) }
				if res_ == none {
					return
				}
			} else {
				mut ev := epoll_event_init(epoll_out, &completion)

				if fd := completion.fd_maybe_dup() {
					posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
						res_ = epoll_result_err(.write, err)
					}
				} else {
					res_ = epoll_result_err(.write, err)
				}
			}
		}
		.send {
			mut ev := epoll_event_init(epoll_out, &completion)

			if fd := completion.fd_maybe_dup() {
				posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
					res_ = epoll_result_err(.send, err)
				}
			} else {
				res_ = epoll_result_err(.send, err)
			}
		}
		.recv {
			mut ev := epoll_event_init(epoll_in | epoll_rdhup, &completion)

			if fd := completion.fd_maybe_dup() {
				posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
					res_ = epoll_result_err(.recv, err)
				}
			} else {
				res_ = epoll_result_err(.recv, err)
			}
		}
		.sendmsg {
			if _ := completion.op.sendmsg.buffer {
				panic('TODO: sendmsg with buffer')
			}

			mut ev := epoll_event_init(epoll_out, &completion)

			if fd := completion.fd_maybe_dup() {
				posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
					res_ = epoll_result_err(.sendmsg, err)
				}
			} else {
				res_ = epoll_result_err(.sendmsg, err)
			}
		}
		.recvmsg {
			mut ev := epoll_event_init(epoll_in | epoll_rdhup, &completion)

			if fd := completion.fd_maybe_dup() {
				posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
					res_ = epoll_result_err(.recvmsg, err)
				}
			} else {
				res_ = epoll_result_err(.recvmsg, err)
			}
		}
		.close {
			if completion.flags.threadpool() {
				self.thread_schedule(mut completion) or { res_ = epoll_result_err(.close, err) }
				if res_ == none {
					return
				}
			} else {
				posix_close(completion.op.close.fd)
				res_ = EpollResult{
					tag: .close
				}
			}
		}
		.shutdown {
			res_ = EpollResult{
				tag: .shutdown
			}
			posix_shutdown(completion.op.shutdown.socket, completion.op.shutdown.how) or {
				res_ = epoll_result_err(.shutdown, err)
			}
		}
		.timer {
			// Point back to completion since we need this. In the future
			// we want to use @fieldParentPtr but https://github.com/ziglang/zig/issues/6611
			completion.op.timer.c = unsafe { &completion }

			// Insert the timer into our heap.
			self.timers.insert(&completion.op.timer)

			// We always run timers
		}
		.poll {
			mut ev := epoll_event_init(completion.op.poll.events, &completion)

			if fd := completion.fd_maybe_dup() {
				posix_epoll_ctl(self.fd, epoll_ctl_add, fd, &ev) or {
					res_ = epoll_result_err(.poll, err)
				}
			} else {
				res_ = epoll_result_err(.poll, err)
			}
		}
	}

	// If we failed to add the completion then we call the callback
	// immediately and mark the error.
	if res := res_ {
		completion.flags.set_state(.dead)

		match completion.callback(completion.userdata, self, completion, res) {
			.disarm {}
			// If we rearm then we requeue this. Due to the way that tick works,
			// this won't try to re-add immediately it won't happen until the
			// next tick.
			.rearm {
				self.add(completion)
			}
		}

		return
	}

	// If the completion was requested on a threadpool we should
	// never reach her.
	assert !completion.flags.threadpool()

	// Mark the completion as active if we reached this point
	completion.flags.set_state(.active)

	// Increase our active count
	self.active += 1
}

fn (mut self EpollLoop) stop_completion(mut completion EpollCompletion) {
	// Delete. This should never fail.
	mut maybe_fd := ?int(none)
	if completion.flags.dup() {
		maybe_fd = completion.flags.dup_fd
	} else {
		maybe_fd = completion.fd()
	}
	if fd := maybe_fd {
		posix_epoll_ctl(self.fd, epoll_ctl_del, fd, unsafe { nil }) or { panic('unreachable') }
	} else {
		match completion.op.tag {
			.timer {
				mut v := unsafe { &completion.op.timer }
				mut c := v.c

				if c.flags.state() == .active {
					// Timers needs to be removed from the timer heap.
					self.timers.remove(v)
				}

				// If the timer was never fired, we need to fire it with
				// the cancellation notice.
				if c.flags.state() != .dead {
					// If we have reset set AND we got a cancellation result,
					// that means that we were canceled so that we can update
					// our expiration time.
					if r := v.reset {
						v.next = r
						v.reset = none
						self.active -= 1
						self.start(mut c)
						return
					}

					action := c.callback(c.userdata, self, c, EpollResult{
						tag:   .timer
						timer: .cancel
					})
					match action {
						.disarm {}
						.rearm {
							self.active -= 1
							self.start(mut c)
							return
						}
					}
				}
			}
			else {
				panic('unreachable')
			}
		}
	}

	// Decrement the active count so we know how many are running for
	// .until_done run semantics.
	if completion.flags.state() == .active {
		self.active -= 1
	}

	// Mark the completion as done
	completion.flags.set_state(.dead)
}

// The epoll_event registered for a completion: `.data = .{ .ptr = @intFromPtr(completion) }`.
@[inline]
fn epoll_event_init(events u32, completion &EpollCompletion) C.epoll_event {
	mut ev := C.epoll_event{
		events: events
	}
	ev.data.ptr = voidptr(completion)
	return ev
}

// Watch state of this completion. We use this to determine whether
// we're active, adding, deleting, etc. This lets us add and delete
// multiple times before a loop tick and handle the state properly.
pub enum EpollCompletionStateFlag as u8 {
	// completion is not part of any loop
	dead     = 0
	// completion is in the submission queue
	adding   = 1
	// completion is in the deletion queue
	deleting = 2
	// completion is registered with epoll
	active   = 3
}

// The Zig packed struct holds the state (3 bits), threadpool, and dup flags
// followed by dup_fd. The flag bits are kept in `value` and dup_fd, the only
// non-flag member, is a plain field.
pub struct EpollCompletionFlags {
pub mut:
	value u8
	// See dup.
	dup_fd int
}

// Watch state of this completion.
pub fn (f EpollCompletionFlags) state() EpollCompletionStateFlag {
	return unsafe { EpollCompletionStateFlag(f.value & 0b111) }
}

pub fn (mut f EpollCompletionFlags) set_state(state EpollCompletionStateFlag) {
	f.value = (f.value & ~u8(0b111)) | u8(state)
}

// Schedule this onto the threadpool rather than epoll. Not all
// operations support this.
pub fn (f EpollCompletionFlags) threadpool() bool {
	return f.value & 0b1000 != 0
}

pub fn (mut f EpollCompletionFlags) set_threadpool(v bool) {
	if v {
		f.value |= 0b1000
	} else {
		f.value &= ~u8(0b1000)
	}
}

// Set to true to dup the file descriptor for the operation prior
// to setting it up with epoll. This is a hack to make it so that
// a completion can represent a single op per fd, since epoll requires
// a single fd for multiple ops. We don't want to track that esp
// since epoll isn't the primary Linux interface.
pub fn (f EpollCompletionFlags) dup() bool {
	return f.value & 0b10000 != 0
}

pub fn (mut f EpollCompletionFlags) set_dup(v bool) {
	if v {
		f.value |= 0b10000
	} else {
		f.value &= ~u8(0b10000)
	}
}

@[heap]
pub struct EpollCompletion {
pub mut:
	// Operation to execute. This is only safe to read BEFORE the completion
	// is queued. After being queued (with "add"), the operation may change.
	op EpollOperation

	// Userdata and callback for when the completion is finished.
	userdata voidptr       = unsafe { nil }
	callback EpollCallback = epoll_noop_callback

	//---------------------------------------------------------------
	// Internal fields

	// If scheduled on a thread pool, this will be set. This is NOT a
	// reliable way to get access to the loop and shouldn't be used
	// except internally.
	task             ThreadPoolTask
	task_loop        &EpollLoop = unsafe { nil }
	task_completions &IntrusiveMpscQueue[EpollCompletion] = unsafe { nil }
	task_result      EpollResult

	flags EpollCompletionFlags

	// Intrusive queue field
	next &EpollCompletion = unsafe { nil }
}

// Returns the state of this completion. There are some things to
// be caution about when calling this function.
//
// First, this is only safe to call from the main thread. This cannot
// be called from any other thread.
//
// Second, if you are using default "undefined" completions, this will
// NOT return a valid value if you access it. You must zero your
// completion using ".{}". You only need to zero the completion once.
// Once the completion is in use, it will always be valid.
//
// Third, if you stop the loop (loop.stop()), the completions registered
// with the loop will NOT be reset to a dead state.
pub fn (self &EpollCompletion) state() CompletionState {
	return match self.flags.state() {
		.dead { .dead }
		.adding, .deleting, .active { .active }
	}
}

// Perform the operation associated with this completion. This will
// perform the full blocking operation for the completion.
fn (mut self EpollCompletion) perform() EpollResult {
	match self.op.tag {
		// This should never happen because we always do these synchronously
		// or in another location.
		.cancel, .noop, .shutdown, .timer {
			panic('unreachable')
		}
		.accept {
			v := posix_accept(self.op.accept.socket, &self.op.accept.addr, &self.op.accept.addr_size,
				self.op.accept.flags) or { return epoll_result_kind(.accept, .unknown) }
			return EpollResult{
				tag:    .accept
				socket: v
			}
		}
		.connect {
			posix_getsockopt_error(self.op.connect.socket) or {
				return epoll_result_err(.connect, err)
			}
			return EpollResult{
				tag: .connect
			}
		}
		.poll {
			return EpollResult{
				tag: .poll
			}
		}
		.read {
			n := posix_read(self.op.read.fd, self.op.read.buffer.slice_ptr()) or {
				return epoll_result_err(.read, err)
			}
			return epoll_read_result(.read, n)
		}
		.pread {
			n := posix_pread(self.op.pread.fd, self.op.pread.buffer.slice_ptr(), self.op.pread.offset) or {
				return epoll_result_err(.pread, err)
			}
			return epoll_read_result(.pread, n)
		}
		.write {
			n := posix_write(self.op.write.fd, self.op.write.buffer.bytes()) or {
				return epoll_result_err(.write, err)
			}
			return epoll_result_n(.write, n)
		}
		.pwrite {
			n := posix_pwrite(self.op.pwrite.fd, self.op.pwrite.buffer.bytes(), self.op.pwrite.offset) or {
				return epoll_result_err(.pwrite, err)
			}
			return epoll_result_n(.pwrite, n)
		}
		.send {
			n := posix_send(self.op.send.fd, self.op.send.buffer.bytes(), 0) or {
				return epoll_result_err(.send, err)
			}
			return epoll_result_n(.send, n)
		}
		.sendmsg {
			n := posix_sendmsg(self.op.sendmsg.fd, self.op.sendmsg.msghdr, 0) or {
				return epoll_result_err(.sendmsg, err)
			}
			return epoll_result_n(.sendmsg, n)
		}
		.recvmsg {
			res := linux_recvmsg(self.op.recvmsg.fd, self.op.recvmsg.msghdr, 0)
			// Like the source, this tests the raw usize result, so every
			// non-zero result (including a negated errno) is a byte count.
			if res == 0 {
				return epoll_result_kind(.recvmsg, .eof)
			} else if res > 0 {
				return epoll_result_n(.recvmsg, res)
			} else {
				return epoll_result_err(.recvmsg, unexpected_errno(linux_errno(res)))
			}
		}
		.recv {
			n := posix_recv(self.op.recv.fd, self.op.recv.buffer.slice_ptr(), 0) or {
				return epoll_result_err(.recv, err)
			}
			return epoll_read_result(.recv, n)
		}
		.close {
			posix_close(self.op.close.fd)
			return EpollResult{
				tag: .close
			}
		}
	}
}

// Return the fd for the completion. This will perform a dup(2) if
// requested.
fn (mut self EpollCompletion) fd_maybe_dup() !int {
	old_fd := self.fd() or { panic('unreachable') }
	if !self.flags.dup() {
		return old_fd
	}
	if self.flags.dup_fd > 0 {
		return self.flags.dup_fd
	}

	self.flags.dup_fd = posix_dup(old_fd) or { return new_error(.dup_failed) }
	return self.flags.dup_fd
}

// Returns the fd associated with the completion (if any).
fn (self &EpollCompletion) fd() ?int {
	match self.op.tag {
		.accept { return self.op.accept.socket }
		.connect { return self.op.connect.socket }
		.poll { return self.op.poll.fd }
		.read { return self.op.read.fd }
		.pread { return self.op.pread.fd }
		.recv { return self.op.recv.fd }
		.write { return self.op.write.fd }
		.pwrite { return self.op.pwrite.fd }
		.send { return self.op.send.fd }
		.sendmsg { return self.op.sendmsg.fd }
		.recvmsg { return self.op.recvmsg.fd }
		.close { return self.op.close.fd }
		.shutdown { return self.op.shutdown.socket }
		.cancel, .timer { return none }
		.noop { panic('unreachable') }
	}
}

pub enum EpollOperationType {
	noop
	cancel
	accept
	connect
	poll
	read
	pread
	write
	pwrite
	send
	recv
	sendmsg
	recvmsg
	close
	shutdown
	timer
}

// The result type based on the operation type. For a callback, the
// result tag will ALWAYS match the operation tag.
//
// The Zig Result union carries each operation's error union. The flat record
// keeps the failing Zig error name in `err`, or the success payload in the
// field the operation uses.
pub struct EpollResult {
pub mut:
	tag EpollOperationType
	err ?ErrorKind
	// accept: the accepted socket
	socket int
	// read, pread, write, pwrite, send, recv, sendmsg, recvmsg: byte count
	n usize
	// timer
	timer EpollTimerTrigger
}

fn epoll_result_kind(tag EpollOperationType, kind ErrorKind) EpollResult {
	return EpollResult{
		tag: tag
		err: kind
	}
}

fn epoll_result_err(tag EpollOperationType, err IError) EpollResult {
	return EpollResult{
		tag: tag
		err: error_kind(err)
	}
}

fn epoll_result_n(tag EpollOperationType, n usize) EpollResult {
	return EpollResult{
		tag: tag
		n:   n
	}
}

// Reads return EOF for a zero byte count.
fn epoll_read_result(tag EpollOperationType, n usize) EpollResult {
	if n == 0 {
		return EpollResult{
			tag: tag
			err: .eof
		}
	}
	return EpollResult{
		tag: tag
		n:   n
	}
}

// All the supported operations of this event loop. These are always
// backend-specific and therefore the structure and types change depending
// on the underlying system in use. The high level operations are
// done by initializing the request handles.
pub struct EpollOperation {
pub mut:
	tag      EpollOperationType
	cancel   EpollCancelOp
	accept   EpollAcceptOp
	connect  EpollConnectOp
	poll     EpollPollOp
	read     EpollReadOp
	pread    EpollPReadOp
	write    EpollWriteOp
	pwrite   EpollPWriteOp
	send     EpollWriteOp
	recv     EpollReadOp
	sendmsg  EpollSendMsgOp
	recvmsg  EpollRecvMsgOp
	close    EpollCloseOp
	shutdown EpollShutdownOp
	timer    EpollHeapTimer
}

pub struct EpollCancelOp {
pub mut:
	c &EpollCompletion = unsafe { nil }
}

pub struct EpollAcceptOp {
pub mut:
	socket    int
	addr      C.sockaddr
	addr_size u32 = u32(sizeof(C.sockaddr))
	flags     u32 = sock_cloexec
}

pub struct EpollConnectOp {
pub mut:
	socket int
	addr   NetAddress
}

// Poll for events but do not perform any operations on them being
// ready. The "events" field are a OR-ed list of EPOLL events.
pub struct EpollPollOp {
pub mut:
	fd     int
	events u32
}

pub struct EpollReadOp {
pub mut:
	fd     int
	buffer EpollReadBuffer
}

pub struct EpollPReadOp {
pub mut:
	fd     int
	buffer EpollReadBuffer
	offset u64
}

pub struct EpollWriteOp {
pub mut:
	fd     int
	buffer EpollWriteBuffer
}

pub struct EpollPWriteOp {
pub mut:
	fd     int
	buffer EpollWriteBuffer
	offset u64
}

pub struct EpollSendMsgOp {
pub mut:
	fd     int
	msghdr &C.msghdr = unsafe { nil }

	// Optionally, a write buffer can be specified and the given
	// msghdr will be populated with information about this buffer.
	buffer ?EpollWriteBuffer

	// Do not use this, it is only used internally.
	iov [1]C.iovec
}

pub struct EpollRecvMsgOp {
pub mut:
	fd     int
	msghdr &C.msghdr = unsafe { nil }
}

pub struct EpollCloseOp {
pub mut:
	fd int
}

pub struct EpollShutdownOp {
pub mut:
	socket int
	how    ShutdownHow = .both
}

// Operation.Timer
pub struct EpollHeapTimer {
pub mut:
	// The absolute time to fire this timer next.
	next Timespec

	// Only used internally. If this is non-null and timer is
	// CANCELLED, then the timer is rearmed automatically with this
	// as the next time. The callback will not be called on the
	// cancellation.
	reset ?Timespec

	// Internal heap fields.
	heap IntrusiveHeapField[EpollHeapTimer]

	// We point back to completion for now. When issue[1] is fixed,
	// we can juse use that from our heap fields.
	// [1]: https://github.com/ziglang/zig/issues/6611
	c &EpollCompletion = unsafe { nil }
}

fn epoll_timer_less(a &EpollHeapTimer, b &EpollHeapTimer) bool {
	return a.ns() < b.ns()
}

// Returns the nanoseconds of this timer. Note that maxInt(u64) ns is
// 584 years so if we get any overflows we just use maxInt(u64). If
// any software is running in 584 years waiting on this timer...
// shame on me I guess... but I'll be dead.
fn (self &EpollHeapTimer) ns() u64 {
	assert self.next.tv_sec >= 0
	assert self.next.tv_nsec >= 0

	max := max_u64
	s_ns := mul_u64(u64(self.next.tv_sec), 1_000_000_000) or { return max }
	return add_u64(s_ns, u64(self.next.tv_nsec)) or { return max }
}

// ReadBuffer are the various options for reading.
pub struct EpollReadBuffer {
pub mut:
	kind BufferKind
	// Read into this slice.
	slice []u8
	// Read into this array, just set this to undefined and it will
	// be populated up to the size of the array. This is an option because
	// the other union members force a specific size anyways so this lets us
	// use the other size in the union to support small reads without worrying
	// about buffer allocation.
	//
	// To know the size read you have to use the return value of the
	// read operations (i.e. recv).
	//
	// Note that the union at the time of this writing could accomodate a
	// much larger fixed size array here but we want to retain flexiblity
	// for future fields.
	array [32]u8

	// TODO: future will have vectors
}

// slice_ptr returns the active buffer as a slice that aliases the completion.
fn (self &EpollReadBuffer) slice_ptr() []u8 {
	return match self.kind {
		.slice { self.slice }
		.array { unsafe { (&self.array[0]).vbytes(self.array.len) } }
	}
}

// WriteBuffer are the various options for writing.
pub struct EpollWriteBuffer {
pub mut:
	kind BufferKind
	// Write from this buffer.
	slice []u8
	// Write from this array. See ReadBuffer.array for why we support this.
	array     [32]u8
	array_len usize

	// TODO: future will have vectors
}

fn (self &EpollWriteBuffer) bytes() []u8 {
	return match self.kind {
		.slice { self.slice }
		.array { unsafe { (&self.array[0]).vbytes(int(self.array_len)) } }
	}
}

// Error sets. Each Zig error set is a set of ErrorKind members:
//
//   ThreadPoolError = ThreadPoolRequired, ThreadPoolUnsupported
//   CancelError = ThreadPoolError || NotFound
//   AcceptError = posix.EpollCtlError || DupFailed, Unknown
//   CloseError = posix.EpollCtlError || ThreadPoolError || Unknown
//   PollError = posix.EpollCtlError || DupFailed, Unknown
//   ShutdownError = posix.EpollCtlError || posix.ShutdownError || Unknown
//   ConnectError = posix.EpollCtlError || posix.ConnectError || DupFailed, Unknown
//   ReadError = ThreadPoolError || posix.EpollCtlError || posix.ReadError ||
//       posix.PReadError || posix.RecvFromError || DupFailed, EOF, Unknown
//   WriteError = ThreadPoolError || posix.EpollCtlError || posix.WriteError ||
//       posix.PWriteError || posix.SendError || posix.SendMsgError ||
//       DupFailed, Unknown
//   TimerError = Unexpected

pub enum EpollTimerTrigger {
	// Unused with epoll
	request
	// Timer expired.
	expiration
	// Timer was canceled.
	cancel
}
