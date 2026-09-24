module xev

// Backend to use kqueue. This is currently only tested on macOS but
// support for BSDs is planned (if it doesn't already work).
//
// V translation of libxev's src/backend/kqueue.zig (pinned 34fa508). Zig's
// `Xev(.kqueue, kqueue)` API types carry a `Kqueue` prefix in this module.
// The Operation and Result tagged unions are represented as flat records with
// a tag so that the timer payload has a stable address inside a completion.

#include <sys/event.h>

pub struct C.kevent64_s {
mut:
	ident  u64
	filter i16
	flags  u16
	fflags u32
	data   i64
	udata  u64
	ext    [2]u64
}

fn C.kqueue() int
fn C.kevent64(kq int, changelist &C.kevent64_s, nchanges int, eventlist &C.kevent64_s, nevents int, flags u32, timeout &C.timespec) int
fn C.shutdown(socket int, how int) int
fn C.connect(socket int, address voidptr, address_len u32) int

// Kevent is either kevent_s or kevent64_s depending on the target platform.
// This lets us support both Mac and non-Mac platforms.
pub type Kevent = C.kevent64_s

// The callback of the main Loop operations. Higher level interfaces may
// use a different callback mechanism.
pub type KqueueCallback = fn (userdata voidptr, loop &KqueueLoop, completion &KqueueCompletion, result KqueueResult) CallbackAction

// A callback that does nothing and immediately disarms. This
// implements xev.Callback and is the default value for completions.
pub fn kqueue_noop_callback(_ voidptr, _ &KqueueLoop, _ &KqueueCompletion, _ KqueueResult) CallbackAction {
	return .disarm
}

// True if this backend is available on this platform.
pub fn kqueue_available() bool {
	// macOS uses kqueue
	return true
}

pub const kqueue_note_exit_flags = u32(int(C.NOTE_EXIT)) | u32(int(C.NOTE_EXITSTATUS))

// Some internal fields we can pack for better space.
pub struct KqueueLoopFlags {
pub mut:
	value u8
}

// True once it is initialized.
pub fn (f KqueueLoopFlags) init() bool {
	return f.value & 0b001 != 0
}

// Whether we're in a run or not (to prevent nested runs).
pub fn (f KqueueLoopFlags) in_run() bool {
	return f.value & 0b010 != 0
}

// Whether our loop is in a stopped state or not.
pub fn (f KqueueLoopFlags) stopped() bool {
	return f.value & 0b100 != 0
}

fn (mut f KqueueLoopFlags) set(mask u8, v bool) {
	if v {
		f.value |= mask
	} else {
		f.value &= ~mask
	}
}

pub fn (mut f KqueueLoopFlags) set_init(v bool) {
	f.set(0b001, v)
}

pub fn (mut f KqueueLoopFlags) set_in_run(v bool) {
	f.set(0b010, v)
}

pub fn (mut f KqueueLoopFlags) set_stopped(v bool) {
	f.set(0b100, v)
}

@[heap]
pub struct KqueueLoop {
pub mut:
	// The fd of the kqueue.
	kqueue_fd int

	// The wakeup mechanism (mach ports on Apple, eventfd on BSD).
	wakeup_state KqueueWakeup

	// The number of active completions. This DOES NOT include completions that
	// are queued in the submissions queue.
	active usize

	// Our queue of submissions that we want to enqueue on the next tick.
	// These are NOT started, they are NOT submitted to kqueue. They are
	// pending.
	submissions IntrusiveQueue[KqueueCompletion]

	// The queue of cancellation requests. These will point to the
	// completion that we need to cancel. We don't queue the exact completion
	// to cancel because it may be in another queue.
	cancellations IntrusiveQueue[KqueueCompletion]

	// Our queue of completed completions where the callback hasn't been
	// called yet, but the "result" field should be set on every completion.
	// This is used to delay completion callbacks until the next tick.
	// Values in the completion queue must not be in the kqueue.
	completions IntrusiveQueue[KqueueCompletion]

	// Heap of timers. We use heaps instead of the EVFILT_TIMER because
	// it avoids a lot of syscalls in the case where there are a LOT of
	// timers.
	timers IntrusiveHeap[KqueueHeapTimer] = IntrusiveHeap[KqueueHeapTimer]{
		less: kqueue_timer_less
	}

	// The thread pool to use for blocking operations that kqueue can't do.
	thread_pool &ThreadPool = unsafe { nil }

	// The MPSC queue for completed completions from the thread pool.
	thread_pool_completions IntrusiveMpscQueue[KqueueCompletion]

	// Cached time
	cached_now Timespec

	// Some internal fields we can pack for better space.
	flags KqueueLoopFlags
}

// Initialize a new kqueue-backed event loop. See the Options docs
// for what options matter for kqueue.
pub fn KqueueLoop.init(options Options) !KqueueLoop {
	// This creates a new kqueue fd
	fd := posix_kqueue()!

	mut wakeup_state := KqueueWakeup.init() or {
		posix_close(fd)
		return err
	}

	mut res := KqueueLoop{
		kqueue_fd: fd
		wakeup_state: wakeup_state
		thread_pool: options.thread_pool
	}

	res.update_now()
	return res
}

// Deinitialize the loop, this closes the kqueue. Any events that
// were unprocessed are lost -- their callbacks will never be called.
pub fn (mut self KqueueLoop) deinit() {
	posix_close(self.kqueue_fd)
	self.wakeup_state.deinit()
}

// Stop the loop. This can only be called from the main thread.
// This will stop the loop forever. Future ticks will do nothing.
//
// This does NOT stop any completions that are queued to be executed
// in the thread pool. If you are using a thread pool, completions
// are not safe to recover until the thread pool is shut down. If
// you're not using a thread pool, all completions are safe to
// read/write once any outstanding `run` or `tick` calls are returned.
pub fn (mut self KqueueLoop) stop() {
	self.flags.set_stopped(true)
}

// Returns true if the loop is stopped. This may mean there
// are still pending completions to be processed.
pub fn (self &KqueueLoop) stopped() bool {
	return self.flags.stopped()
}

// Add a completion to the loop. The completion is not started until
// the loop is run (`run`, `tick`) or an explicit submission request
// is made (`submit`).
pub fn (mut self KqueueLoop) add(completion &KqueueCompletion) {
	mut c := unsafe { completion }

	// If this is a cancellation, we special case it and add it to
	// a separate queue so we can handle them first.
	if c.op.tag == .cancel {
		mut unused := Kevent{}
		assert !self.start(mut c, mut unused)
		return
	}

	// We just add the completion to the queue. Failures can happen
	// at submission or tick time.
	c.flags.set_state(.adding)
	self.submissions.push(c)
}

// Submit any enqueue completions. This does not fire any callbacks
// for completed events (success or error). Callbacks are only fired
// on the next tick.
//
// If an error is returned, some events might be lost. Errors are
// exceptional and should generally not happen. If we could recover
// which completions were not submitted and restore them we would,
// but the kqueue API doesn't provide that level of clarity.
pub fn (mut self KqueueLoop) submit() ! {
	// We try to submit as many events at once as we can.
	mut events := [256]Kevent{}
	mut events_len := 0

	// Submit all the submissions. We copy the submission queue so that
	// any resubmits don't cause an infinite loop.
	mut queued := self.submissions
	self.submissions = IntrusiveQueue[KqueueCompletion]{}

	for {
		queue_pop: for {
			mut c := queued.pop() or { break }
			match c.flags.state() {
				// If we're adding then we start the event.
				.adding {
					if self.start(mut c, mut events[events_len]) {
						events_len += 1
						if events_len >= events.len {
							break queue_pop
						}
					}
				}
				// If we're deleting then we create a deletion event and
				// queue the completion to notify cancellation.
				.deleting {
					if ev := c.kevent() {
						ecanceled := -1 * i32(C.ECANCELED)
						c.result = c.syscall_result(ecanceled)
						c.flags.set_state(.dead)
						self.completions.push(c)

						events[events_len] = ev
						events[events_len].flags = u16(int(C.EV_DELETE))
						events_len += 1
						if events_len >= events.len {
							break queue_pop
						}
					}
				}
				// This is set if the completion was canceled while in the
				// submission queue. This is a special case where we still
				// want to call the callback to tell it it was canceled.
				.dead {
					self.stop_completion(mut c)
				}
				// Shouldn't happen if our logic is all correct.
				.active {
					eprintln('libxev_kqueue: invalid state in submission queue state=${c.flags.state()}')
				}
			}
		}

		// If we have no events then we have to have gone through the entire
		// submission queue and we're done.
		if events_len == 0 {
			break
		}

		// Zero timeout so that kevent returns immediately.
		mut timeout := Timespec{}
		completed := kevent_syscall(self.kqueue_fd, &events[0], usize(events_len), &events[0],
			usize(events.len), &timeout) or {
			// On error, we have to restore the queue because we may be batching.
			self.submissions = queued
			return err
		}
		events_len = 0

		// Go through the completed events and queue them.
		// NOTE: we currently never process completions (we set
		// event list to zero length) because it was leading to
		// memory corruption we need to investigate.
		for i in 0 .. completed {
			ev := events[i]

			// Zero udata values are internal events that we do nothing
			// on such as the mach port wakeup.
			if ev.udata == 0 {
				continue
			}

			// We handle deletions separately.
			if ev.flags & u16(C.EV_DELETE) != 0 {
				continue
			}

			mut c := unsafe { &KqueueCompletion(voidptr(usize(ev.udata))) }

			// If EV_ERROR is set, then submission failed for this
			// completion. We get the syscall errorcode from data and
			// store it.
			if ev.flags & u16(C.EV_ERROR) != 0 {
				c.result = c.syscall_result(-i32(ev.data))
			} else {
				// No error, means that this completion is ready to work.
				c.result = c.perform(&ev)
			}

			assert c.result != none
			self.completions.push(c)
		}
	}
}

// Process the cancellations queue. This doesn't call any callbacks
// or perform any syscalls. This just shuffles state around and sets
// things up for cancellation to occur.
fn (mut self KqueueLoop) process_cancellations() {
	for {
		mut c := self.cancellations.pop() or { break }
		mut target := c.op.cancel.c
		match target.flags.state() {
			// If the target is dead already we do nothing.
			.dead {}
			// If the targeting is in the process of being removed
			// from the kqueue we do nothing because its already done.
			.deleting {}
			// If they are in the submission queue, mark them as dead
			// so they will never be submitted.
			.adding {
				target.flags.set_state(.dead)
			}
			// If it is active we need to schedule the deletion.
			.active {
				self.stop_completion(mut target)
			}
		}

		// We completed the cancellation.
		c.result = KqueueResult{
			tag: .cancel
		}
		self.completions.push(c)
	}
}

// Run the event loop. See RunMode documentation for details on modes.
// Once the loop is run, the pointer MUST remain stable.
pub fn (mut self KqueueLoop) run(mode RunMode) ! {
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

// Tick through the event loop once, waiting for at least "wait" completions
// to be processed by the loop itself.
pub fn (mut self KqueueLoop) tick(wait u32) ! {
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

		self.wakeup_state.setup(self.kqueue_fd) or {
			// We reset initialization because we can't do anything
			// safely unless we get this mach port registered!
			self.flags.set_init(false)
			return err
		}
	}

	// The list of events, used as both a changelist and eventlist.
	mut events := [256]Kevent{}

	// The number of events in the events array to submit as changes
	// on repeat ticks. Used mostly for efficient disarm.
	mut changes := 0

	mut wait_rem := usize(wait)

	// Handle all of our cancellations first because we may be able
	// to stop submissions from even happening if its still queued.
	// Plus, cancellations sometimes add more to the submission queue
	// (to remove from kqueue)
	self.process_cancellations()

	// TODO(mitchellh): an optimization in the future is for the last
	// batch of submissions to return the changelist, because we can
	// reuse that for the kevent call later...
	self.submit()!

	// Explaining the loop condition: we want to loop only if we have
	// active handles (because it means we have something to do)
	// and we have stuff we want to wait for still (wait_rem > 0) or
	// we requested just a nowait tick (because we have to loop at least
	// once).
	//
	// We also loop if there are any requested changes. Requested
	// changes are only ever deletions currently, so we just process
	// those until we have no more.
	for {
		// If we're stopped then the loop is fully over.
		if self.flags.stopped() {
			return
		}

		// We must update our time no matter what
		self.update_now()

		// NOTE(mitchellh): This is a hideous boolean statement we should
		// clean it up.
		if !((self.active > 0 && (wait == 0 || wait_rem > 0)) || changes > 0
			|| !self.completions.empty()) {
			break
		}

		// Run our expired timers
		now_timer := KqueueHeapTimer{
			next: self.cached_now
		}
		for {
			mut t := self.timers.peek() or { break }
			if !kqueue_timer_less(t, &now_timer) {
				break
			}

			// Remove the timer
			deleted := self.timers.delete_min() or { panic('unreachable') }
			assert deleted == t

			// Mark completion as done
			mut c := t.c
			c.flags.set_state(.dead)

			// We mark it as inactive here because if we rearm below
			// the start() function will reincrement this.
			self.active -= 1

			// Lower our remaining count since we have processed something.
			wait_rem = sat_sub(wait_rem, 1)

			// Invoke
			action := c.callback(c.userdata, self, c, KqueueResult{
				tag: .timer
				timer: .expiration
			})
			match action {
				.disarm {}
				// We use undefined as the second param because timers
				// never set a kevent, and we assert false for the same
				// reason.
				.rearm {
					mut unused := Kevent{}
					assert !self.start(mut c, mut unused)
				}
			}
		}

		// Migrate our completions from the thread pool MPSC queue to our
		// completion queue.
		// TODO: unify the queues
		if !isnil(self.thread_pool) {
			for {
				c := self.thread_pool_completions.pop() or { break }
				self.completions.push(c)
			}
		}

		// Process the completions we already have completed.
		for {
			mut c := self.completions.pop() or { break }

			// disarm_ev is the Kevent to use for disarming if the
			// completion wants to disarm. We have to calculate this up
			// front because c can be reused in callback.
			disarm_ev := if c.flags.state() != .active || c.flags.threadpool() {
				// If we're not active then we were never part of the kqueue.
				// If we are part of a threadpool we also never were part
				// of the kqueue.
				?Kevent(none)
			} else {
				c.kevent()
			}

			// We store whether this completion was active so we can decrement
			// the active count later
			c_active := c.flags.state() == .active
			c.flags.set_state(.dead)

			// Decrease our waiters because we are definitely processing one.
			wait_rem = sat_sub(wait_rem, 1)

			// Completion queue items MUST have a result set.
			result := c.result or { panic('unreachable') }
			action := c.callback(c.userdata, self, c, result)
			match action {
				// If we're active we have to schedule a delete. Otherwise
				// we do nothing because we were never part of the kqueue.
				.disarm {
					if ev := disarm_ev {
						events[changes] = ev
						events[changes].flags = u16(int(C.EV_DELETE))
						events[changes].udata = 0
						changes += 1
						assert changes <= events.len
					}

					if c_active {
						self.active -= 1
					}
				}
				// Only resubmit if we aren't already active (in the queue)
				.rearm {
					if !c_active {
						self.submissions.push(c)
					}
				}
			}

			// If we filled the events slice, we break to avoid overflow.
			if changes == events.len {
				break
			}
		}

		// Determine our next timeout based on the timers
		mut timeout_value := Timespec{}
		mut has_timeout := true
		if wait_rem == 0 {
			timeout_value = Timespec{}
		} else if t := self.timers.peek() {
			// If we have a timer, we want to set the timeout to our next
			// timer value. If we have no timer, we wait forever.

			// Determine the time in milliseconds.
			ms_now := u64(self.cached_now.tv_sec) * 1000 + u64(self.cached_now.tv_nsec) / 1_000_000
			ms_next := u64(t.next.tv_sec) * 1000 + u64(t.next.tv_nsec) / 1_000_000
			ms := sat_sub_u64(ms_next, ms_now)

			// Convert to s/ns for the timespec
			sec := ms / 1000
			nsec := (ms % 1000) * 1_000_000
			timeout_value = Timespec{
				tv_sec: i64(sec)
				tv_nsec: i64(nsec)
			}
		} else {
			has_timeout = false
		}

		// Wait for changes. Note that we ALWAYS attempt to get completions
		// back even if are done waiting (wait_rem == 0) because if we have
		// to make a syscall to submit changes, we might as well also check
		// for done events too.
		mut timeout := unsafe { &Timespec(nil) }
		if has_timeout {
			timeout = &timeout_value
		}
		completed := kevent_syscall(self.kqueue_fd, &events[0], usize(changes), &events[0],
			usize(events.len), timeout) or {
			match error_kind(err) {
				// This should never happen because we always have
				// space in our event list. If I'm reading the BSD source
				// right (and Apple does something similar...) then ENOENT
				// is always put into the eventlist if there is space:
				// https://github.com/freebsd/freebsd-src/blob/5a4a83fd0e67a0d7787d2f3e09ef0e5552a1ffb6/sys/kern/kern_event.c#L1668
				.event_not_found {
					panic('unreachable')
				}
				// Any other error is fatal
				else {
					return err
				}
			}
		}

		// Reset changes since they're not submitted
		changes = 0

		// Go through the completed events and queue them.
		for i in 0 .. completed {
			ev := events[i]

			// Zero udata values are internal events that we do nothing
			// on such as the mach port wakeup.
			if ev.udata == 0 {
				continue
			}

			// Ignore any successful deletions. This can only happen
			// from disarms below and in that case we already processed
			// their callback.
			if ev.flags & u16(C.EV_DELETE) != 0 {
				continue
			}

			// This can only be set during changelist processing so
			// that means that this event was never actually active.
			// Therefore, we only decrement the waiters by 1 if we
			// processed an active change.
			if ev.flags & u16(C.EV_ERROR) != 0 {
				// We cannot use c here because c is already dead
				// at this point for this event.
				continue
			}
			wait_rem = sat_sub(wait_rem, 1)

			mut c := unsafe { &KqueueCompletion(voidptr(usize(ev.udata))) }

			// c is ready to be reused rigt away if we're dearming
			// so we mark it as dead.
			c.flags.set_state(.dead)

			result := c.perform(&ev)
			action := c.callback(c.userdata, self, c, result)
			match action {
				.disarm {
					// Mark this event for deletion, it'll happen
					// on the next tick.
					events[changes] = ev
					events[changes].flags = u16(int(C.EV_DELETE))
					events[changes].udata = 0
					changes += 1
					assert changes <= events.len

					self.active -= 1
				}
				// We rearm by default with kqueue so we just have to make
				// sure that the state is correct.
				.rearm {
					c.flags.set_state(.active)
				}
			}
		}

		// If we ran through the loop once we break if we don't care.
		if wait == 0 {
			break
		}
	}
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
pub fn (self &KqueueLoop) now() i64 {
	// If anything overflows we just return the max value.
	max := max_i64

	// Calculate all the values, being careful about overflows in order
	// to just return the maximum value.
	sec := mul_i64(self.cached_now.tv_sec, 1000) or { return max }
	nsec := floor_div_i64(self.cached_now.tv_nsec, 1_000_000)
	return sat_add_i64(sec, nsec)
}

// Update the cached time.
pub fn (mut self KqueueLoop) update_now() {
	if new_time := posix_clock_gettime(C.CLOCK_MONOTONIC) {
		self.cached_now = new_time
	} else {
		// Errors are ignored.
	}
}

// Add a timer to the loop. The timer will execute in "next_ms". This
// is oneshot: the timer will not repeat. To repeat a timer, either
// schedule another in your callback or return rearm from the callback.
pub fn (mut self KqueueLoop) timer(c &KqueueCompletion, next_ms u64, userdata voidptr, cb KqueueCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = KqueueCompletion{
			op: KqueueOperation{
				tag: .timer
				timer: KqueueHeapTimer{
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
pub fn (mut self KqueueLoop) timer_reset(c &KqueueCompletion, c_cancel &KqueueCompletion, next_ms u64, userdata voidptr, cb KqueueCallback) {
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
				*cancel = KqueueCompletion{
					op: KqueueOperation{
						tag: .cancel
						cancel: KqueueCancelOp{
							c: completion
						}
					}
				}
			}
			self.add(cancel)
		}
	}
}

fn (self &KqueueLoop) timer_next(next_ms u64) Timespec {
	// Get the timestamp of the absolute time that we'll execute this timer.
	// There are lots of failure scenarios here in math. If we see any
	// of them we just use the maximum value.
	max := Timespec{
		tv_sec: max_i64
		tv_nsec: max_i64
	}

	next_s := cast_i64(next_ms / 1000) or { return max }
	next_ns := cast_i64((next_ms % 1000) * 1_000_000) or { return max }

	return Timespec{
		tv_sec: add_i64(self.cached_now.tv_sec, next_s) or { return max }
		tv_nsec: add_i64(self.cached_now.tv_nsec, next_ns) or { return max }
	}
}

fn (self &KqueueLoop) done() bool {
	return self.flags.stopped() || (self.active == 0 && self.submissions.empty()
		&& self.completions.empty())
}

enum KqueueStartAction {
	// We have set the kevent out parameter
	kevent
	// We are a timer,
	timer
	// We are a cancellation
	cancel
	// We want to run on the threadpool
	threadpool
	// We have a result code from making a system call now.
	result
}

// Start the completion. This returns true if the Kevent was set
// and should be queued.
fn (mut self KqueueLoop) start(mut c KqueueCompletion, mut ev Kevent) bool {
	mut result := i32(0)
	action := if c.flags.threadpool() {
		KqueueStartAction.threadpool
	} else {
		match c.op.tag {
			.noop {
				c.flags.set_state(.dead)
				return false
			}
			.cancel {
				// Queue the cancel
				KqueueStartAction.cancel
			}
			.accept {
				ev = c.kevent() or { panic('unreachable') }
				KqueueStartAction.kevent
			}
			.connect {
				mut connect_action := KqueueStartAction.result
				for {
					rc := C.connect(c.op.connect.socket, c.op.connect.addr.any(), c.op.connect.addr.get_os_sock_len())
					match posix_errno(rc) {
						// Interrupt, try again
						C.EINTR {
							continue
						}
						// This means the connect is blocked and in progress.
						// We register for the write event which will let us know
						// when it is complete.
						C.EAGAIN, C.EINPROGRESS {
							ev = c.kevent() or { panic('unreachable') }
							connect_action = .kevent
							break
						}
						// Any other error we report. Like the source, this passes
						// the libc return code rather than a negated errno.
						else {
							result = i32(rc)
							connect_action = .result
							break
						}
					}
				}
				connect_action
			}
			.write, .pwrite, .read, .pread, .send, .recv, .sendto, .recvfrom, .machport, .proc {
				ev = c.kevent() or { panic('unreachable') }
				KqueueStartAction.kevent
			}
			.shutdown {
				how := match c.op.shutdown.how {
					.recv { C.SHUT_RD }
					.send { C.SHUT_WR }
					.both { C.SHUT_RDWR }
				}
				// Like the source, the libc return code is the result.
				result = i32(C.shutdown(c.op.shutdown.socket, how))
				KqueueStartAction.result
			}
			.close {
				posix_close(c.op.close.fd)
				result = 0
				KqueueStartAction.result
			}
			.timer {
				// Point back to completion since we need this. In the future
				// we want to use @fieldParentPtr but https://github.com/ziglang/zig/issues/6611
				c.op.timer.c = unsafe { &c }

				// Insert the timer into our heap.
				self.timers.insert(&c.op.timer)

				// We always run timers
				KqueueStartAction.timer
			}
		}
	}

	match action {
		.kevent, .timer {
			// Increase our active count so we now wait for this. We
			// assume it'll successfully queue. If it doesn't we handle
			// that later (see submit)
			self.active += 1
			c.flags.set_state(.active)

			// We only return true if this is a kevent, since other
			// actions can come in here.
			return action == .kevent
		}
		.cancel {
			// We are considered an active completion.
			self.active += 1
			c.flags.set_state(.active)

			self.cancellations.push(c)
			return false
		}
		.threadpool {
			// We need to mark this completion as active no matter
			// what happens below so that we mark is inactive with
			// completion handling.
			self.active += 1
			c.flags.set_state(.active)

			// We need a thread pool otherwise we set an error on
			// our result and queue the completion.
			if isnil(self.thread_pool) {
				// We use EPERM as a way to note there is no thread
				// pool. We can change this in the future if there is
				// a better choice.
				eperm := -1 * i32(C.EPERM)
				c.result = c.syscall_result(eperm)
				self.completions.push(c)
				return false
			}
			mut pool := self.thread_pool

			// Setup our completion state so that the thread can
			// communicate back to our main thread.
			c.task_loop = unsafe { self }
			c.task = ThreadPoolTask{
				callback: kqueue_thread_perform
			}

			// Schedule it, from this point forward its not safe to touch c.
			pool.schedule(ThreadPoolBatch.from(&c.task))

			return false
		}
		// A result is immediately available. Queue the completion to
		// be invoked.
		.result {
			c.result = c.syscall_result(result)
			self.completions.push(c)

			return false
		}
	}
}

fn (mut self KqueueLoop) stop_completion(mut c KqueueCompletion) {
	if c.flags.state() == .active {
		// If there is a result already, then we're already in the
		// completion queue and we can be done. Items in the completion
		// queue can NOT be in the kqueue too.
		if c.result != none {
			return
		}

		// If this completion has a kevent associated with it, then
		// we must remove the kevent. We remove the kevent by adding it
		// to the submission queue (because its the same syscall) but
		// setting the state to deleting.
		if _ := c.kevent() {
			self.active -= 1
			c.flags.set_state(.deleting)
			self.submissions.push(c)
			return
		}
	}

	// Inspect other operations. WARNING: the state can be ANYTHING
	// here so per op be sure to check the state flag.
	match c.op.tag {
		.timer {
			if c.flags.state() == .active {
				// Remove from the heap so it never fires...
				self.timers.remove(&c.op.timer)

				// If we have reset set AND we got a cancellation result,
				// that means that we were canceled so that we can update
				// our expiration time.
				if r := c.op.timer.reset {
					c.op.timer.next = r
					c.op.timer.reset = none
					self.active -= 1
					self.add(c)
					return
				}
			}

			// Add to our completions so we trigger the callback.
			c.result = KqueueResult{
				tag: .timer
				timer: .cancel
			}
			self.completions.push(c)

			// Note the timers state purposely remains ACTIVE so that
			// when we process the completion we decrement the
			// active count.
		}
		else {}
	}
}

// This is the main callback for the threadpool to perform work
// on completions for the loop.
fn kqueue_thread_perform(t &ThreadPoolTask) {
	mut c := unsafe { &KqueueCompletion(voidptr(usize(t) - __offsetof(KqueueCompletion, task))) }

	// Do our task
	c.result = c.perform(unsafe { nil })

	// Add to our completion queue
	mut loop := c.task_loop
	loop.thread_pool_completions.push(c)

	// Wake up our main loop
	loop.wakeup() or {}
}

// Sends an empty message to this loop's mach port so that it wakes
// up if it is blocking on kevent().
fn (mut self KqueueLoop) wakeup() ! {
	self.wakeup_state.wakeup()!
}

// Watch state of this completion. We use this to determine whether
// we're active, adding, deleting, etc. This lets us add and delete
// multiple times before a loop tick and handle the state properly.
pub enum KqueueCompletionStateFlag as u8 {
	// completion is not part of any loop
	dead     = 0
	// completion is in the submission queue
	adding   = 1
	// completion is in the deletion queue
	deleting = 2
	// completion is submitted with kqueue successfully
	active   = 3
}

pub struct KqueueCompletionFlags {
pub mut:
	value u8
}

// Watch state of this completion.
pub fn (f KqueueCompletionFlags) state() KqueueCompletionStateFlag {
	return unsafe { KqueueCompletionStateFlag(f.value & 0b111) }
}

pub fn (mut f KqueueCompletionFlags) set_state(state KqueueCompletionStateFlag) {
	f.value = (f.value & ~u8(0b111)) | u8(state)
}

// Set this to true to schedule this operation on the thread pool.
// This can be set by anyone. If the operation is scheduled on
// the thread pool then it will NOT be registered with kqueue even
// if it is supported.
pub fn (f KqueueCompletionFlags) threadpool() bool {
	return f.value & 0b1000 != 0
}

pub fn (mut f KqueueCompletionFlags) set_threadpool(v bool) {
	if v {
		f.value |= 0b1000
	} else {
		f.value &= ~u8(0b1000)
	}
}

// A completion is a request to perform some work with the loop.
@[heap]
pub struct KqueueCompletion {
pub mut:
	// Operation to execute.
	op KqueueOperation

	// Userdata and callback for when the completion is finished.
	userdata voidptr        = unsafe { nil }
	callback KqueueCallback = kqueue_noop_callback

	//---------------------------------------------------------------
	// Internal fields

	// Intrusive queue field
	next &KqueueCompletion = unsafe { nil }

	// Result code of the syscall. Only used internally in certain
	// scenarios, should not be relied upon by program authors.
	result ?KqueueResult

	flags KqueueCompletionFlags

	// If scheduled on a thread pool, this will be set. This is NOT a
	// reliable way to get access to the loop and shouldn't be used
	// except internally.
	task      ThreadPoolTask
	task_loop &KqueueLoop = unsafe { nil }
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
pub fn (self &KqueueCompletion) state() CompletionState {
	return match self.flags.state() {
		.dead { .dead }
		.adding, .deleting, .active { .active }
	}
}

// Returns a kevent for this completion, if any. Note that the
// kevent isn't immediately useful for all event types. For example,
// "connect" requires you to initiate the connection first.
fn (self &KqueueCompletion) kevent() ?Kevent {
	udata := u64(usize(voidptr(self)))
	return match self.op.tag {
		.noop {
			panic('unreachable')
		}
		.cancel, .close, .timer, .shutdown {
			none
		}
		.accept {
			kevent_init(u64(self.op.accept.socket), i16(C.EVFILT_READ), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.connect {
			kevent_init(u64(self.op.connect.socket), i16(C.EVFILT_WRITE), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.machport {
			// The kevent below waits for a machport to have a message
			// available AND automatically reads the message into the
			// buffer since MACH_RCV_MSG is set.
			slice := self.op.machport.buffer.slice_ptr()
			Kevent{
				ident: u64(self.op.machport.port)
				filter: i16(C.EVFILT_MACHPORT)
				flags: u16(C.EV_ADD | C.EV_ENABLE)
				fflags: mach_rcv_msg
				data: 0
				udata: udata
				ext: [u64(usize(slice.data)), u64(slice.len)]!
			}
		}
		.proc {
			kevent_init(u64(self.op.proc.pid), i16(C.EVFILT_PROC), u16(C.EV_ADD | C.EV_ENABLE),
				self.op.proc.flags, udata)
		}
		.write {
			kevent_init(u64(self.op.write.fd), i16(C.EVFILT_WRITE), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.pwrite {
			kevent_init(u64(self.op.pwrite.fd), i16(C.EVFILT_WRITE), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.send {
			kevent_init(u64(self.op.send.fd), i16(C.EVFILT_WRITE), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.sendto {
			kevent_init(u64(self.op.sendto.fd), i16(C.EVFILT_WRITE), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.read {
			kevent_init(u64(self.op.read.fd), i16(C.EVFILT_READ), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.pread {
			kevent_init(u64(self.op.pread.fd), i16(C.EVFILT_READ), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.recv {
			kevent_init(u64(self.op.recv.fd), i16(C.EVFILT_READ), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
		.recvfrom {
			kevent_init(u64(self.op.recvfrom.fd), i16(C.EVFILT_READ), u16(C.EV_ADD | C.EV_ENABLE),
				0, udata)
		}
	}
}

// Perform the operation associated with this completion. This will
// perform the full blocking operation for the completion.
fn (mut self KqueueCompletion) perform(ev_ &Kevent) KqueueResult {
	match self.op.tag {
		.cancel, .noop, .timer, .shutdown {
			eprintln('libxev_kqueue: perform op=${self.op.tag}')
			panic('unreachable')
		}
		.accept {
			v := posix_accept(self.op.accept.socket, &self.op.accept.addr, &self.op.accept.addr_size,
				self.op.accept.flags) or { return kqueue_result_err(.accept, err) }
			return KqueueResult{
				tag: .accept
				socket: v
			}
		}
		.connect {
			posix_getsockopt_error(self.op.connect.socket) or {
				return kqueue_result_err(.connect, err)
			}
			return KqueueResult{
				tag: .connect
			}
		}
		.write {
			n := posix_write(self.op.write.fd, self.op.write.buffer.bytes()) or {
				return kqueue_result_err(.write, err)
			}
			return kqueue_result_n(.write, n)
		}
		.pwrite {
			n := posix_pwrite(self.op.pwrite.fd, self.op.pwrite.buffer.bytes(), self.op.pwrite.offset) or {
				return kqueue_result_err(.pwrite, err)
			}
			return kqueue_result_n(.pwrite, n)
		}
		.send {
			n := posix_send(self.op.send.fd, self.op.send.buffer.bytes(), 0) or {
				return kqueue_result_err(.send, err)
			}
			return kqueue_result_n(.send, n)
		}
		.sendto {
			n := posix_sendto(self.op.sendto.fd, self.op.sendto.buffer.bytes(), 0, self.op.sendto.addr.any(),
				self.op.sendto.addr.get_os_sock_len()) or { return kqueue_result_err(.sendto, err) }
			return kqueue_result_n(.sendto, n)
		}
		.read {
			if self.op.read.buffer.is_empty_slice() {
				if isnil(ev_) {
					return kqueue_result_kind(.read, .missing_kevent)
				}
				return kqueue_read_result(.read, usize(ev_.data))
			}
			n := posix_read(self.op.read.fd, self.op.read.buffer.slice_ptr()) or {
				return kqueue_result_err(.read, err)
			}
			return kqueue_read_result(.read, n)
		}
		.pread {
			if self.op.pread.buffer.is_empty_slice() {
				// The source reports the missing kevent through the `.read`
				// result field for every read-like operation.
				if isnil(ev_) {
					return kqueue_result_kind(.read, .missing_kevent)
				}
				return kqueue_read_result(.pread, usize(ev_.data))
			}
			n := posix_pread(self.op.pread.fd, self.op.pread.buffer.slice_ptr(), self.op.pread.offset) or {
				return kqueue_result_err(.pread, err)
			}
			return kqueue_read_result(.pread, n)
		}
		.recv {
			if self.op.recv.buffer.is_empty_slice() {
				if isnil(ev_) {
					return kqueue_result_kind(.read, .missing_kevent)
				}
				return kqueue_read_result(.recv, usize(ev_.data))
			}
			n := posix_recv(self.op.recv.fd, self.op.recv.buffer.slice_ptr(), 0) or {
				return kqueue_result_err(.recv, err)
			}
			return kqueue_read_result(.recv, n)
		}
		.recvfrom {
			if self.op.recvfrom.buffer.is_empty_slice() {
				if isnil(ev_) {
					return kqueue_result_kind(.read, .missing_kevent)
				}
				return kqueue_read_result(.recvfrom, usize(ev_.data))
			}
			n := posix_recvfrom(self.op.recvfrom.fd, self.op.recvfrom.buffer.slice_ptr(), 0,
				&self.op.recvfrom.addr, &self.op.recvfrom.addr_size) or {
				return kqueue_result_err(.recvfrom, err)
			}
			return kqueue_read_result(.recvfrom, n)
		}
		// Our machport operation ALWAYS has MACH_RCV set so there
		// is no operation to perform. kqueue automatically reads in
		// the mach message into the read buffer.
		.machport {
			return KqueueResult{
				tag: .machport
			}
		}
		// For proc watching, it is identical to the syscall result.
		.proc {
			if isnil(ev_) {
				return kqueue_result_kind(.proc, .missing_kevent)
			}

			// If we have the exit status, we read it.
			if ev_.fflags & kqueue_note_exit_flags > 0 {
				data := u32(ev_.data)
				if wait_ifexited(data) {
					return KqueueResult{
						tag: .proc
						exit_code: wait_exitstatus(data)
					}
				}
			}

			return KqueueResult{
				tag: .proc
			}
		}
		.close {
			posix_close(self.op.close.fd)
			return KqueueResult{
				tag: .close
			}
		}
	}
}

// Returns the error result for the given result code. This is called
// in the situation that kqueue fails to enqueue the completion or
// a raw syscall fails.
fn (self &KqueueCompletion) syscall_result(r i32) KqueueResult {
	errno := if r >= 0 { 0 } else { int(-r) }
	tag := self.op.tag
	return match tag {
		.noop {
			panic('unreachable')
		}
		.accept {
			match errno {
				0 { KqueueResult{
						tag: tag
						socket: int(r)
					} }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.connect, .machport, .shutdown {
			match errno {
				0 { KqueueResult{
						tag: tag
					} }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.write {
			match errno {
				0 { KqueueResult{
						tag: tag
						n: usize(r)
					} }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				C.EPERM { kqueue_result_kind(tag, .permission_denied) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.pwrite, .send, .sendto, .recvfrom {
			match errno {
				0 { KqueueResult{
						tag: tag
						n: usize(r)
					} }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.read {
			match errno {
				0 { kqueue_read_result(tag, usize(r)) }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				C.EPERM { kqueue_result_kind(tag, .permission_denied) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.pread, .recv {
			match errno {
				0 { kqueue_read_result(tag, usize(r)) }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.proc {
			match errno {
				0 { KqueueResult{
						tag: tag
						exit_code: u32(r)
					} }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				C.ESRCH { kqueue_result_kind(tag, .no_such_process) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.close {
			match errno {
				0 { KqueueResult{
						tag: tag
					} }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				C.EPERM { kqueue_result_kind(tag, .thread_pool_required) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.timer {
			match errno {
				// Success is impossible because timers don't execute syscalls.
				0 { panic('unreachable') }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				else { kqueue_result_err(tag, unexpected_errno(errno)) }
			}
		}
		.cancel {
			match errno {
				0 { KqueueResult{
						tag: tag
					} }
				C.ECANCELED { kqueue_result_kind(tag, .canceled) }
				// Syscall errors should not be possible since cancel
				// doesn't run any syscalls.
				else {
					_ = unexpected_errno(errno)
					panic('unreachable')
				}
			}
		}
	}
}

// The Zig Result union carries each operation's error union. The flat record
// keeps the failing Zig error name in `err`, or the success payload in the
// field the operation uses.
pub struct KqueueResult {
pub mut:
	tag KqueueOperationType
	err ?ErrorKind
	// accept: the accepted socket
	socket int
	// read, write, pread, pwrite, send, recv, sendto, recvfrom: byte count
	n usize
	// timer
	timer KqueueTimerTrigger
	// proc: exit code
	exit_code u32
}

fn kqueue_result_kind(tag KqueueOperationType, kind ErrorKind) KqueueResult {
	return KqueueResult{
		tag: tag
		err: kind
	}
}

fn kqueue_result_err(tag KqueueOperationType, err IError) KqueueResult {
	return KqueueResult{
		tag: tag
		err: error_kind(err)
	}
}

fn kqueue_result_n(tag KqueueOperationType, n usize) KqueueResult {
	return KqueueResult{
		tag: tag
		n: n
	}
}

// The zero-length read path returns EOF for a zero byte count.
fn kqueue_read_result(tag KqueueOperationType, n usize) KqueueResult {
	if n == 0 {
		return KqueueResult{
			tag: tag
			err: .eof
		}
	}
	return KqueueResult{
		tag: tag
		n: n
	}
}

// The struct used for loop wakeup. This is only internal state.
pub struct KqueueWakeup {
pub mut:
	// The mach port that this kqueue always has a filter for. Writing
	// an empty message to this port can be used to wake up the loop
	// at any time. Waking up the loop via this port won't trigger any
	// particular completion, it just forces tick to cycle.
	mach_port        KqueueAsync
	mach_port_buffer [32]u8
}

fn KqueueWakeup.init() !KqueueWakeup {
	mach_port := KqueueAsync.init()!
	return KqueueWakeup{
		mach_port: mach_port
	}
}

fn (mut self KqueueWakeup) deinit() {
	self.mach_port.deinit()
}

fn (mut self KqueueWakeup) setup(kqueue_fd int) ! {
	events := [
		Kevent{
			ident: u64(self.mach_port.port)
			filter: i16(C.EVFILT_MACHPORT)
			flags: u16(C.EV_ADD | C.EV_ENABLE)
			fflags: mach_rcv_msg
			data: 0
			udata: 0
			ext: [u64(usize(&self.mach_port_buffer[0])), u64(self.mach_port_buffer.len)]!
		},
	]!
	n := kevent_syscall(kqueue_fd, &events[0], usize(events.len), &events[0], 0, unsafe { nil })!
	assert n == 0
}

fn (mut self KqueueWakeup) wakeup() ! {
	self.mach_port.notify()!
}

pub enum KqueueOperationType {
	noop
	accept
	connect
	read
	write
	pread
	pwrite
	send
	recv
	sendto
	recvfrom
	close
	shutdown
	timer
	cancel
	machport
	proc
}

// All the supported operations of this event loop. These are always
// backend-specific and therefore the structure and types change depending
// on the underlying system in use. The high level operations are
// done by initializing the request handles.
pub struct KqueueOperation {
pub mut:
	tag      KqueueOperationType
	accept   KqueueAcceptOp
	connect  KqueueConnectOp
	read     KqueueReadOp
	write    KqueueWriteOp
	pread    KqueuePReadOp
	pwrite   KqueuePWriteOp
	send     KqueueWriteOp
	recv     KqueueReadOp
	sendto   KqueueSendToOp
	recvfrom KqueueRecvFromOp
	close    KqueueCloseOp
	shutdown KqueueShutdownOp
	timer    KqueueHeapTimer
	cancel   KqueueCancelOp
	machport KqueueMachPortOp
	proc     KqueueProcOp
}

pub struct KqueueAcceptOp {
pub mut:
	socket    int
	addr      C.sockaddr
	addr_size u32 = u32(sizeof(C.sockaddr))
	flags     u32 = sock_cloexec
}

pub struct KqueueConnectOp {
pub mut:
	socket int
	addr   NetAddress
}

pub struct KqueueReadOp {
pub mut:
	fd     int
	buffer KqueueReadBuffer
}

pub struct KqueueWriteOp {
pub mut:
	fd     int
	buffer KqueueWriteBuffer
}

pub struct KqueuePReadOp {
pub mut:
	fd     int
	buffer KqueueReadBuffer
	offset u64
}

pub struct KqueuePWriteOp {
pub mut:
	fd     int
	buffer KqueueWriteBuffer
	offset u64
}

// Note: this is making our Completion quite large. We can follow
// the pattern of io_uring and require another user-provided pointer
// here for state to move all this stuff out to a pointer.
pub struct KqueueSendToOp {
pub mut:
	fd     int
	buffer KqueueWriteBuffer
	addr   NetAddress
}

pub struct KqueueRecvFromOp {
pub mut:
	fd        int
	buffer    KqueueReadBuffer
	addr      C.sockaddr
	addr_size u32 = u32(sizeof(C.sockaddr))
}

pub struct KqueueCloseOp {
pub mut:
	fd int
}

pub enum ShutdownHow {
	recv
	send
	both
}

pub struct KqueueShutdownOp {
pub mut:
	socket int
	how    ShutdownHow = .both
}

pub struct KqueueCancelOp {
pub mut:
	c &KqueueCompletion = unsafe { nil }
}

pub struct KqueueMachPortOp {
pub mut:
	port   u32
	buffer KqueueReadBuffer
}

pub struct KqueueProcOp {
pub mut:
	pid   int
	flags u32 = kqueue_note_exit_flags
}

pub enum KqueueTimerTrigger {
	// Unused with epoll
	request
	// Timer expired.
	expiration
	// Timer was canceled.
	cancel
}

pub enum BufferKind {
	slice
	array
}

// ReadBuffer are the various options for reading.
pub struct KqueueReadBuffer {
pub mut:
	kind BufferKind
	// Read into this slice.
	//
	// For zero-length slices, the event will notify of read readiness
	// (similar to poll) rather than performing an explicit zero-length
	// read which will always succeed regardless of if the fd is ready
	// or not.
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
fn (self &KqueueReadBuffer) slice_ptr() []u8 {
	return match self.kind {
		.slice { self.slice }
		.array { unsafe { (&self.array[0]).vbytes(self.array.len) } }
	}
}

fn (self &KqueueReadBuffer) is_empty_slice() bool {
	return self.kind == .slice && self.slice.len == 0
}

// WriteBuffer are the various options for writing.
pub struct KqueueWriteBuffer {
pub mut:
	kind BufferKind
	// Write from this buffer.
	slice []u8
	// Write from this array. See ReadBuffer.array for why we support this.
	array     [32]u8
	array_len usize

	// TODO: future will have vectors
}

fn (self &KqueueWriteBuffer) bytes() []u8 {
	return match self.kind {
		.slice { self.slice }
		.array { unsafe { (&self.array[0]).vbytes(int(self.array_len)) } }
	}
}

// Timer that is inserted into the heap.
pub struct KqueueHeapTimer {
pub mut:
	// The absolute time to fire this timer next.
	next Timespec

	// Only used internally. If this is non-null and timer is
	// CANCELLED, then the timer is rearmed automatically with this
	// as the next time. The callback will not be called on the
	// cancellation.
	reset ?Timespec

	// Internal heap fields.
	heap IntrusiveHeapField[KqueueHeapTimer]

	// We point back to completion for now. When issue[1] is fixed,
	// we can juse use that from our heap fields.
	// [1]: https://github.com/ziglang/zig/issues/6611
	c &KqueueCompletion = unsafe { nil }
}

fn kqueue_timer_less(a &KqueueHeapTimer, b &KqueueHeapTimer) bool {
	return a.ns() < b.ns()
}

// Returns the nanoseconds of this timer. Note that maxInt(u64) ns is
// 584 years so if we get any overflows we just use maxInt(u64). If
// any software is running in 584 years waiting on this timer...
// shame on me I guess... but I'll be dead.
fn (self &KqueueHeapTimer) ns() u64 {
	assert self.next.tv_sec >= 0
	assert self.next.tv_nsec >= 0

	max := max_u64
	s_ns := mul_u64(u64(self.next.tv_sec), 1_000_000_000) or { return max }
	return add_u64(s_ns, u64(self.next.tv_nsec)) or { return max }
}

// kevent calls either kevent or kevent64 depending on the
// target platform.
fn kevent_syscall(kq int, changelist &Kevent, changelist_len usize, eventlist &Kevent, eventlist_len usize, timeout &Timespec) !usize {
	// Otherwise, we have to call the kevent64 variant.
	nchanges := cast_c_int(changelist_len) or { return new_error(.overflow) }
	nevents := cast_c_int(eventlist_len) or { return new_error(.overflow) }
	for {
		rc := C.kevent64(kq, changelist, nchanges, eventlist, nevents, 0, &C.timespec(timeout))
		match posix_errno(rc) {
			0 { return usize(rc) }
			C.EACCES { return new_error(.access_denied) }
			C.EFAULT { panic('unreachable') }
			C.EBADF { panic('unreachable') } // Always a race condition.
			C.EINTR { continue }
			C.EINVAL { panic('unreachable') }
			C.ENOENT { return new_error(.event_not_found) }
			C.ENOMEM { return new_error(.system_resources) }
			C.ESRCH { return new_error(.process_not_found) }
			else { panic('unreachable') }
		}
	}
	return 0
}

// kevent_init initializes a Kevent from an posix.Kevent. This is used when
// the "ext" fields are zero.
@[inline]
fn kevent_init(ident u64, filter i16, flags u16, fflags u32, udata u64) Kevent {
	return Kevent{
		ident: ident
		filter: filter
		flags: flags
		fflags: fflags
		data: 0
		udata: udata
		ext: [u64(0), 0]!
	}
}
