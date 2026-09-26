module xev

// V translation of libxev's src/backend/io_uring.zig (pinned 34fa508). Zig's
// `Xev(.io_uring, io_uring)` API types carry an `IoUring` prefix in this
// module. The Operation and Result tagged unions are represented as flat
// records with a tag so that operation payloads have stable addresses inside a
// completion (the kernel reads them through the submitted SQE).

// The callback of the main Loop operations. Higher level interfaces may
// use a different callback mechanism.
pub type IoUringCallback = fn (userdata voidptr, loop &IoUringLoop, completion &IoUringCompletion, result IoUringResult) CallbackAction

// A callback that does nothing and immediately disarms. This
// implements xev.Callback and is the default value for completions.
pub fn io_uring_noop_callback(_ voidptr, _ &IoUringLoop, _ &IoUringCompletion, _ IoUringResult) CallbackAction {
	return .disarm
}

// Watcher callbacks. Zig generates a callback per comptime Userdata type and
// function; V passes the caller's untyped userdata pointer and captures the
// watcher callback in a closure. The error is the watcher's error set member,
// if any. Loop.cancel uses the same shape with a CancelError.
pub type IoUringWatcherCallback = fn (ud voidptr, l &IoUringLoop, c &IoUringCompletion, r ?ErrorKind) CallbackAction

// True if this backend is available on this platform.
pub fn io_uring_available() bool {
	// (The source first returns false when not targeting Linux; this file is
	// only compiled for Linux.)

	// Perform a harmless syscall to determine if we have io_uring support.
	// We should really only be checking for a subset of possible errors
	// to determine if io_uring is available but there isn't really a strong
	// course of action for any other error so we just mark it as unavailable.
	//
	// Also, this is a bit expensive -- we could get away with a single
	// io_uring_register syscall to check for availability but that involves
	// manually handling errors vs. the tried and true Zig stdlib here.
	mut ring := LinuxIoUring.init(256, 0) or { return false }
	ring.deinit()

	return true
}

// Loop flags, a Zig packed struct.
pub struct IoUringLoopFlags {
pub mut:
	value u8 = 0b001
}

// True if the "now" field is outdated and should be updated
// when it is used.
pub fn (f IoUringLoopFlags) now_outdated() bool {
	return f.value & 0b001 != 0
}

// Whether the loop is stopped or not.
pub fn (f IoUringLoopFlags) stopped() bool {
	return f.value & 0b010 != 0
}

// Whether we're in a run or not (to prevent nested runs).
pub fn (f IoUringLoopFlags) in_run() bool {
	return f.value & 0b100 != 0
}

fn (mut f IoUringLoopFlags) set(mask u8, v bool) {
	if v {
		f.value |= mask
	} else {
		f.value &= ~mask
	}
}

pub fn (mut f IoUringLoopFlags) set_now_outdated(v bool) {
	f.set(0b001, v)
}

pub fn (mut f IoUringLoopFlags) set_stopped(v bool) {
	f.set(0b010, v)
}

pub fn (mut f IoUringLoopFlags) set_in_run(v bool) {
	f.set(0b100, v)
}

@[heap]
pub struct IoUringLoop {
pub mut:
	ring LinuxIoUring

	// The number of active completions. This DOES NOT include completions that
	// are queued in the submissions queue.
	active usize

	// Our queue of submissions that failed to enqueue.
	submissions IntrusiveQueue[IoUringCompletion]

	// Cached time
	cached_now Timespec

	flags IoUringLoopFlags
}

// Initialize the event loop. "entries" is the maximum number of
// submissions that can be queued at one time. The number of completions
// always matches the number of entries so the memory allocated will be
// 2x entries (plus the basic loop overhead).
pub fn IoUringLoop.init(options Options) !IoUringLoop {
	// std.math.cast(u13, options.entries)
	if options.entries > 0x1fff {
		return new_error(.too_many_entries)
	}
	entries := u16(options.entries)

	mut result := IoUringLoop{
		// TODO(mitchellh): add an init_advanced function or something
		// for people using the io_uring API directly to be able to set
		// the flags for this.
		ring: LinuxIoUring.init(entries, 0)!
	}
	result.update_now()

	return result
}

pub fn (mut self IoUringLoop) deinit() {
	self.ring.deinit()
}

// Run the event loop. See RunMode documentation for details on modes.
pub fn (mut self IoUringLoop) run(mode RunMode) ! {
	match mode {
		.no_wait { self.tick_(.no_wait)! }
		.once { self.tick_(.once)! }
		.until_done { self.tick_(.until_done)! }
	}
}

// Stop the loop. This can only be called from the main thread.
// This will stop the loop forever. Future ticks will do nothing.
// All completions are safe to read/write once any outstanding
// `run` or `tick` calls are returned.
pub fn (mut self IoUringLoop) stop() {
	self.flags.set_stopped(true)
}

// Returns true if the loop is stopped. This may mean there
// are still pending completions to be processed.
pub fn (self &IoUringLoop) stopped() bool {
	return self.flags.stopped()
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
pub fn (mut self IoUringLoop) now() i64 {
	if self.flags.now_outdated() {
		self.update_now()
	}

	// If anything overflows we just return the max value.
	max := max_i64

	// Calculate all the values, being careful about overflows in order
	// to just return the maximum value.
	sec := mul_i64(self.cached_now.tv_sec, 1000) or { return max }
	nsec := floor_div_i64(self.cached_now.tv_nsec, 1_000_000)
	return sat_add_i64(sec, nsec)
}

// Update the cached time.
pub fn (mut self IoUringLoop) update_now() {
	if new_time := posix_clock_gettime(C.CLOCK_MONOTONIC) {
		self.cached_now = new_time
		self.flags.set_now_outdated(false)
	} else {
		// Errors are ignored.
	}
}

// Tick the loop. The mode is comptime in the source so it can avoid function
// calls and runtime branching; here it is a runtime parameter.
fn (mut self IoUringLoop) tick_(mode RunMode) ! {
	// We can't nest runs.
	if self.flags.in_run() {
		return new_error(.nested_runs_not_allowed)
	}
	self.flags.set_in_run(true)
	defer {
		self.flags.set_in_run(false)
	}

	// The total number of events we're waiting for.
	wait := match mode {
		// until_done is one because we need to wait for at least one
		// (if we have any).
		.until_done { u32(1) }
		.once { u32(1) }
		.no_wait { u32(0) }
	}

	mut cqes := [128]IoUringCqe{}
	for {
		// If we're stopped then the loop is fully over.
		if self.flags.stopped() {
			break
		}

		// We always note that our "now" value is outdated even if we have
		// no completions to execute.
		self.flags.set_now_outdated(true)

		if self.active == 0 && self.submissions.empty() {
			break
		}

		// If we have no queued submissions then we do the wait as part
		// of the submit call, because then we can do exactly once syscall
		// to get all our events.
		if self.submissions.empty() {
			_ = self.ring.submit_and_wait(wait) or {
				if error_kind(err) == .signal_interrupt {
					continue
				}
				return err
			}
		} else {
			// We have submissions, meaning we have to do multiple submissions
			// anyways so we always just do non-waiting ones.
			self.submit() or {
				if error_kind(err) == .signal_interrupt {
					continue
				}
				return err
			}
		}

		// Wait for completions...
		count := self.ring.copy_cqes(&cqes[0], usize(cqes.len), wait) or {
			// EINTR means our blocking syscall was interrupted by some
			// process signal. We just retry when we can. See signal(7).
			if error_kind(err) == .signal_interrupt {
				continue
			}
			return err
		}

		for i in 0 .. int(count) {
			cqe := cqes[i]
			// A zero user_data is a null completion pointer (`orelse continue`).
			if cqe.user_data == 0 {
				continue
			}
			mut c := unsafe { &IoUringCompletion(voidptr(usize(cqe.user_data))) }
			self.active -= 1
			c.flags.set_state(.dead)
			match c.invoke(mut self, cqe.res) {
				.disarm {}
				.rearm { self.add(c) }
			}
		}

		// Subtract our waiters. If we reached zero then we're done.
		match mode {
			.no_wait {
				break
			}
			.once {
				if count > 0 {
					break
				}
			}
			.until_done {}
		}
	}
}

// Submit all queued operations. This never does an io_uring submit
// and wait operation.
//
// The errors are the source's explicit SubmitError set: Unexpected,
// SystemResources, FileDescriptorInvalid, FileDescriptorInBadState,
// CompletionQueueOvercommitted, SubmissionQueueEntryInvalid, BufferInvalid,
// RingShuttingDown, OpcodeNotSupported, SignalInterrupt.
pub fn (mut self IoUringLoop) submit() ! {
	_ = self.ring.submit()!

	// If we have any submissions that failed to submit, we try to
	// send those now. We have to make a copy so that any failures are
	// resubmitted without an infinite loop.
	mut queued := self.submissions
	self.submissions = IntrusiveQueue[IoUringCompletion]{}
	for {
		c := queued.pop() or { break }
		self.add_(c, true)
	}
}

// Add a timer to the loop. The timer will initially execute in "next_ms"
// from now and will repeat every "repeat_ms" thereafter. If "next_ms" is
// zero then the timer will invoke on the next loop tick.
//
// If next_ms is too large of a value that it doesn't fit into the
// kernel time structure, the maximum sleep value will be used for your
// system (this is at least 45 days on a 32-bit system, and thousands of
// years on a 64-bit system).
pub fn (mut self IoUringLoop) timer(c &IoUringCompletion, next_ms u64, userdata voidptr, cb IoUringCallback) {
	mut completion := unsafe { c }
	next := self.timer_next(next_ms)
	unsafe {
		*completion = IoUringCompletion{
			op: IoUringTimerOp{
				next: next
			}
			userdata: userdata
			callback: cb
		}
	}

	self.add(completion)
}

// Reset a timer to trigger in next_ms.
//
// Important: c and c_cancel must NEVER be undefined. If you are using
// timer_reset you should always initial c to the zero value ".{}".
//
// If the timer completion "c" is dead, this is equivalent to calling
// "timer" and "c_cancel" is not used. You can verify this scenario by
// checking "c_cancel.state()" after this call.
//
// If the timer completion "c" is active, and "c_cancel" is also active,
// it is assumed that c_cancel is already resetting the timer. The
// "next_ms" time is updated but otherwise the cancellation continues
// and reset works.
//
// If the timer completion "c" is active, and "c_cancel" is dead,
// "c" is cancelled and restarted to trigger in next_ms.
//
// There is no guarantee that c_cancel will ever be used. Check the
// resulting state to know if you can reclaim its memory or not.
pub fn (mut self IoUringLoop) timer_reset(c &IoUringCompletion, c_cancel &IoUringCompletion, next_ms u64, userdata voidptr, cb IoUringCallback) {
	mut completion := unsafe { c }
	mut cancel := unsafe { c_cancel }
	if completion.state() == .dead {
		self.timer(completion, next_ms, userdata, cb)
		return
	}

	// Update the reset time for the timer to the desired time
	// along with all the callbacks.
	if mut completion.op is IoUringTimerOp {
		completion.op.reset = self.timer_next(next_ms)
	} else {
		panic('completion: completion is not a timer operation')
	}
	completion.userdata = userdata
	completion.callback = cb

	// If the cancellation is active, we assume its for this timer
	// and do nothing.
	if cancel.state() == .active {
		return
	}

	assert cancel.state() == .dead && completion.state() == .active

	// Note: we COULD use IORING_TIMEOUT_UPDATE here with the
	// IORING_TIMEOUT_REMOVE op. We don't right now because it complicates
	// our logic and ups our required kernel version to 5.11 while this
	// works good enough. If there is a compelling reason to use
	// IORING_TIMEOUT_UPDATE, I'm open to hearing it.

	unsafe {
		*cancel = IoUringCompletion{
			op: IoUringTimerRemoveOp{
				timer: completion
			}
		}
	}
	self.add(cancel)
}

fn (mut self IoUringLoop) timer_next(next_ms u64) LinuxKernelTimespec {
	// Get the timestamp of the absolute time that we'll execute this timer.
	// There are lots of failure scenarios here in math. If we see any
	// of them we just use the maximum value.
	max := LinuxKernelTimespec{
		sec: max_i64
		nsec: max_i64
	}

	next_s := cast_i64(next_ms / 1000) or { return max }
	next_ns := cast_i64((next_ms % 1000) * 1_000_000) or { return max }

	if self.flags.now_outdated() {
		self.update_now()
	}

	return LinuxKernelTimespec{
		sec: add_i64(self.cached_now.tv_sec, next_s) or { return max }
		nsec: add_i64(self.cached_now.tv_nsec, next_ns) or { return max }
	}
}

// Add a completion to the loop. This does NOT start the operation!
// You must call "submit" at some point to submit all of the queued
// work.
pub fn (mut self IoUringLoop) add(completion &IoUringCompletion) {
	self.add_(completion, false)
}

// Internal add function. The only difference is try_submit. If try_submit
// is true, then this function will attempt to submit the queue to the
// ring if the submission queue is full rather than filling up our FIFO.
@[inline]
fn (mut self IoUringLoop) add_(completion &IoUringCompletion, try_submit bool) {
	mut c := unsafe { completion }

	// The completion at this point is active no matter what because
	// it is going to be queued.
	c.flags.set_state(.active)

	mut sqe := self.ring.get_sqe() or {
		// error.SubmissionQueueFull, the only get_sqe error.
		mut retry := unsafe { &IoUringSqe(nil) }

		// If the queue is full and we're in try_submit mode then we
		// attempt to submit. This is used during submission flushing.
		if try_submit {
			mut submitted := true
			self.submit() or { submitted = false }
			if submitted {
				// Submission succeeded but we may still fail (unlikely)
				// to get an SQE...
				retry = self.ring.get_sqe() or {
					// error.SubmissionQueueFull
					unsafe { &IoUringSqe(nil) }
				}
			}
		}

		if isnil(retry) {
			// Add the completion to our submissions to try to flush later.
			self.submissions.push(c)
			return
		}
		retry
	}

	// Increase active to the amount in the ring.
	self.active += 1

	// Setup the submission depending on the operation
	match mut c.op {
		// Do nothing with noop completions.
		IoUringNoopOp {
			c.flags.set_state(.dead)
			self.active -= 1
			return
		}
		IoUringAcceptOp {
			sqe.prep_accept(c.op.socket, &c.op.addr, &c.op.addr_size,
				c.op.flags)
		}
		IoUringCloseOp {
			sqe.prep_close(c.op.fd)
		}
		IoUringConnectOp {
			sqe.prep_connect(c.op.socket, c.op.addr.any(), c.op.addr.get_os_sock_len())
		}
		IoUringPollOp {
			sqe.prep_poll_add(c.op.fd, c.op.events)
		}
		IoUringReadOp {
			match c.op.buffer.kind {
				.array {
					sqe.prep_read(c.op.fd, c.op.buffer.slice_ptr(),
						// offset is a u64 but if the value is -1 then it uses
						// the offset in the fd.
						u64(i64(-1)))
				}
				.slice {
					sqe.prep_read(c.op.fd, c.op.buffer.slice,
						// offset is a u64 but if the value is -1 then it uses
						// the offset in the fd.
						u64(i64(-1)))
				}
			}
		}
		IoUringPReadOp {
			match c.op.buffer.kind {
				.array {
					sqe.prep_read(c.op.fd, c.op.buffer.slice_ptr(), c.op.offset)
				}
				.slice {
					sqe.prep_read(c.op.fd, c.op.buffer.slice, c.op.offset)
				}
			}
		}
		IoUringRecvOp {
			match c.op.buffer.kind {
				.array {
					sqe.prep_recv(c.op.fd, c.op.buffer.slice_ptr(), 0)
				}
				.slice {
					sqe.prep_recv(c.op.fd, c.op.buffer.slice, 0)
				}
			}
		}
		IoUringRecvMsgOp {
			sqe.prep_recvmsg(c.op.fd, c.op.msghdr, 0)
		}
		IoUringSendOp {
			match c.op.buffer.kind {
				.array {
					sqe.prep_send(c.op.fd, c.op.buffer.bytes(), 0)
				}
				.slice {
					sqe.prep_send(c.op.fd, c.op.buffer.slice, 0)
				}
			}
		}
		IoUringSendMsgOp {
			if _ := c.op.buffer {
				panic('TODO: sendmsg with buffer')
			}

			sqe.prep_sendmsg(c.op.fd, c.op.msghdr, 0)
		}
		IoUringShutdownOp {
			sqe.prep_shutdown(c.op.socket, match c.op.how {
				.both { u32(int(C.SHUT_RDWR)) }
				.send { u32(int(C.SHUT_WR)) }
				.recv { u32(int(C.SHUT_RD)) }
			})
		}
		IoUringTimerOp {
			sqe.prep_timeout(&c.op.next, 0, ioring_timeout_abs)
		}
		IoUringTimerRemoveOp {
			sqe.prep_timeout_remove(u64(usize(voidptr(c.op.timer))), 0)
		}
		IoUringWriteOp {
			match c.op.buffer.kind {
				.array {
					sqe.prep_write(c.op.fd, c.op.buffer.bytes(),
						// offset is a u64 but if the value is -1 then it uses
						// the offset in the fd.
						u64(i64(-1)))
				}
				.slice {
					sqe.prep_write(c.op.fd, c.op.buffer.slice,
						// offset is a u64 but if the value is -1 then it uses
						// the offset in the fd.
						u64(i64(-1)))
				}
			}
		}
		IoUringPWriteOp {
			match c.op.buffer.kind {
				.array {
					sqe.prep_write(c.op.fd, c.op.buffer.bytes(), c.op.offset)
				}
				.slice {
					sqe.prep_write(c.op.fd, c.op.buffer.slice, c.op.offset)
				}
			}
		}
		IoUringCancelOp {
			sqe.prep_cancel(u64(usize(voidptr(c.op.c))), 0)
		}
	}

	// Our sqe user data always points back to the completion.
	// The prep functions above reset the user data so we have to do this
	// here.
	sqe.user_data = u64(usize(voidptr(c)))
}

// Submits a completion cancelation request.
// Results in error.NotFound if the completion couldn't be located because
// it was already completed or an invalid Completion was provided.
pub fn (mut self IoUringLoop) cancel(c &IoUringCompletion, c_cancel &IoUringCompletion, userdata voidptr, cb IoUringWatcherCallback) {
	mut completion := unsafe { c_cancel }
	unsafe {
		*completion = IoUringCompletion{
			op: IoUringCancelOp{
				c: c
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
				return cb(ud, l_inner, c_inner, r.err)
			}
		}
	}
	self.add(completion)
}

pub enum IoUringCompletionStateFlag as u8 {
	// completion is not part of any loop
	dead   = 0
	// completion is registered with epoll
	active = 1
}

// Completion flags, a Zig packed struct.
pub struct IoUringCompletionFlags {
pub mut:
	value u8
}

pub fn (f IoUringCompletionFlags) state() IoUringCompletionStateFlag {
	return unsafe { IoUringCompletionStateFlag(f.value & 0b1) }
}

pub fn (mut f IoUringCompletionFlags) set_state(state IoUringCompletionStateFlag) {
	f.value = (f.value & ~u8(0b1)) | u8(state)
}

// A completion represents a single queued request in the ring.
// Completions must have stable pointers.
//
// For the lowest overhead, these can be created manually and queued
// directly. The API over the individual fields isn't the most user-friendly
// since it is tune for performance. For user-friendly operations,
// use the higher-level functions on this structure or the even
// higher-level abstractions like the Timer struct.
@[heap]
pub struct IoUringCompletion {
pub mut:
	// Operation to execute. This is only safe to read BEFORE the completion
	// is queued. After being queued (with "add"), the operation may change.
	op IoUringOperation = IoUringNoopOp{}

	// Userdata and callback for when the completion is finished.
	userdata voidptr         = unsafe { nil }
	callback IoUringCallback = io_uring_noop_callback

	// Internally set
	next  &IoUringCompletion = unsafe { nil }
	flags IoUringCompletionFlags
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
pub fn (self &IoUringCompletion) state() CompletionState {
	return match self.flags.state() {
		.dead { .dead }
		.active { .active }
	}
}

// Invokes the callback for this completion after properly constructing
// the Result based on the res code.
fn (mut self IoUringCompletion) invoke(mut loop IoUringLoop, res i32) CallbackAction {
	// The errno matches are statements: V's checker would otherwise type the
	// C errno constants from the expected result type.
	tag := self.op.tag()
	errno := int(-res)
	mut result := io_uring_result_ok(tag)
	match tag {
		.noop {
			panic('unreachable')
		}
		.accept {
			if res >= 0 {
				result = IoUringAcceptResult{
					socket: int(res)
				}
			} else {
				match errno {
					C.ECANCELED { result = io_uring_result_kind(tag, .canceled) }
					C.EAGAIN { result = io_uring_result_kind(tag, .again) }
					else { result = io_uring_result_err(tag, unexpected_errno(errno)) }
				}
			}
		}
		.close {
			if res < 0 {
				result = io_uring_result_err(tag, unexpected_errno(errno))
			}
		}
		.connect {
			if res < 0 {
				match errno {
					C.ECANCELED { result = io_uring_result_kind(tag, .canceled) }
					C.ECONNREFUSED { result = io_uring_result_kind(tag, .connection_refused) }
					C.ETIMEDOUT { result = io_uring_result_kind(tag, .timed_out) }
					C.EHOSTUNREACH { result = io_uring_result_kind(tag, .host_unreachable) }
					else { result = io_uring_result_err(tag, unexpected_errno(errno)) }
				}
			}
		}
		.poll {
			if res < 0 {
				result = io_uring_result_err(tag, unexpected_errno(errno))
			}
		}
		.read {
			result = self.read_result(.read, res)
		}
		.pread {
			result = self.read_result(.pread, res)
		}
		.recv {
			result = self.read_result(.recv, res)
		}
		.recvmsg {
			result = self.read_result(.recvmsg, res)
		}
		.send, .sendmsg {
			if res >= 0 {
				result = io_uring_result_n(tag, usize(res))
			} else {
				match errno {
					C.ECANCELED { result = io_uring_result_kind(tag, .canceled) }
					C.EPIPE { result = io_uring_result_kind(tag, .broken_pipe) }
					C.ECONNRESET { result = io_uring_result_kind(tag, .connection_reset_by_peer) }
					else { result = io_uring_result_err(tag, unexpected_errno(errno)) }
				}
			}
		}
		.shutdown {
			if res < 0 {
				match errno {
					C.ECANCELED { result = io_uring_result_kind(tag, .canceled) }
					else { result = io_uring_result_err(tag, unexpected_errno(errno)) }
				}
			}
		}
		.timer {
			// If we have reset set, that means that we were canceled so
			// that we can update our expiration time.
			if mut self.op is IoUringTimerOp {
				if r := self.op.reset {
					self.op.next = r
					self.op.reset = none
					return .rearm
				}
			}

			if res >= 0 {
				result = IoUringTimerResult{
					timer: .request
				}
			} else {
				match errno {
					C.ETIME {
						result = IoUringTimerResult{
							timer: .expiration
						}
					}
					C.ECANCELED {
						result = IoUringTimerResult{
							timer: .cancel
						}
					}
					else { result = io_uring_result_err(tag, unexpected_errno(errno)) }
				}
			}
		}
		.timer_remove {
			if res < 0 {
				match errno {
					C.ENOENT {
						result = io_uring_result_kind(tag, .not_found)
					}
					C.EBUSY {
						result = io_uring_result_kind(tag, .expiration_in_progress)
					}
					// Okay, I don't know why this might happen. It appears to
					// happen when the timer you're attempting to cancel has
					// already expired, but I can't reproduce this in a unit
					// test. If this isn't safe to ignore or someone can find
					// the meaning of this, I'd be curious.
					C.ETIME {}
					else {
						result = io_uring_result_err(tag, unexpected_errno(errno))
					}
				}
			}
		}
		.write {
			if res >= 0 {
				result = io_uring_result_n(tag, usize(res))
			} else {
				match errno {
					C.ECANCELED {
						result = io_uring_result_kind(tag, .canceled)
					}
					// If a write is interrupted, we retry it automatically.
					C.EINTR {
						return .rearm
					}
					else {
						result = io_uring_result_err(tag, unexpected_errno(errno))
					}
				}
			}
		}
		.pwrite {
			if res >= 0 {
				result = io_uring_result_n(tag, usize(res))
			} else {
				match errno {
					C.ECANCELED { result = io_uring_result_kind(tag, .canceled) }
					else { result = io_uring_result_err(tag, unexpected_errno(errno)) }
				}
			}
		}
		.cancel {
			if res < 0 {
				match errno {
					C.ENOENT { result = io_uring_result_kind(tag, .not_found) }
					C.EALREADY { result = io_uring_result_kind(tag, .expiration_in_progress) }
					else { result = io_uring_result_err(tag, unexpected_errno(errno)) }
				}
			}
		}
	}

	return self.callback(self.userdata, loop, self, result)
}

// The ReadError!usize result of a read-like operation. `op` is comptime in
// the source.
fn (self &IoUringCompletion) read_result(op IoUringOperationType, res i32) IoUringResult {
	if res > 0 {
		return io_uring_result_n(op, usize(res))
	}

	if res == 0 {
		// The source checks @hasField(@TypeOf(active), "buffer"): recvmsg
		// has no buffer.
		mut buffer := IoUringReadBuffer{}
		match op {
			.read { buffer = (self.op as IoUringReadOp).buffer }
			.pread { buffer = (self.op as IoUringPReadOp).buffer }
			.recv { buffer = (self.op as IoUringRecvOp).buffer }
			else { return io_uring_result_kind(op, .eof) }
		}

		// If we receieve a zero byte read, it is an EOF _unless_
		// the requestesd buffer size was zero (weird).
		return match buffer.kind {
			.slice {
				if buffer.slice.len == 0 {
					io_uring_result_n(op, 0)
				} else {
					io_uring_result_kind(op, .eof)
				}
			}
			.array {
				io_uring_result_kind(op, .eof)
			}
		}
	}

	errno := int(-res)
	match errno {
		C.ECANCELED { return io_uring_result_kind(op, .canceled) }
		C.ECONNRESET { return io_uring_result_kind(op, .connection_reset_by_peer) }
		else { return io_uring_result_err(op, unexpected_errno(errno)) }
	}
}

pub enum IoUringOperationType {
	// Do nothing. This operation will not be queued and will never
	// have its callback fired. This is NOT equivalent to the io_uring
	// "nop" operation.
	noop

	// Accept a connection on a socket.
	accept

	// Close a file descriptor.
	close

	// Initiate a connection on a socket.
	connect

	// Poll a fd. Only oneshot mode is supported today.
	poll

	// Read
	read

	// PRead
	pread

	// Receive a message from a socket.
	recv

	// Send a message on a socket.
	send

	// Send a message on a socket using sendmsg (i.e. UDP).
	sendmsg

	// Recieve a message on a socket using recvmsg (i.e. UDP).
	recvmsg

	// Shutdown all or part of a full-duplex connection.
	shutdown

	// PWrite
	pwrite

	// Write
	write

	// A oneshot or repeating timer. For io_uring, this is implemented
	// using the timeout mechanism.
	timer

	// Cancel an existing timer.
	timer_remove

	// Cancel an existing operation.
	cancel
}

// The result type based on the operation type: the source's `Result`
// tagged union. For a callback, the result tag will ALWAYS match the
// operation tag. Each variant carries the operation's error union as the
// failing error name in `err`, or its success payload.
pub type IoUringResult = IoUringAcceptResult
	| IoUringCancelResult
	| IoUringCloseResult
	| IoUringConnectResult
	| IoUringNoopResult
	| IoUringPReadResult
	| IoUringPWriteResult
	| IoUringPollResult
	| IoUringReadResult
	| IoUringRecvMsgResult
	| IoUringRecvResult
	| IoUringSendMsgResult
	| IoUringSendResult
	| IoUringShutdownResult
	| IoUringTimerRemoveResult
	| IoUringTimerResult
	| IoUringWriteResult

pub struct IoUringNoopResult {
pub mut:
	err ?ErrorKind
}

pub struct IoUringAcceptResult {
pub mut:
	err ?ErrorKind
	socket int
}

pub struct IoUringCloseResult {
pub mut:
	err ?ErrorKind
}

pub struct IoUringConnectResult {
pub mut:
	err ?ErrorKind
}

pub struct IoUringPollResult {
pub mut:
	err ?ErrorKind
}

pub struct IoUringReadResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringPReadResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringRecvResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringSendResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringSendMsgResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringRecvMsgResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringShutdownResult {
pub mut:
	err ?ErrorKind
}

pub struct IoUringPWriteResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringWriteResult {
pub mut:
	err ?ErrorKind
	n usize
}

pub struct IoUringTimerResult {
pub mut:
	err ?ErrorKind
	timer IoUringTimerTrigger
}

pub struct IoUringTimerRemoveResult {
pub mut:
	err ?ErrorKind
}

pub struct IoUringCancelResult {
pub mut:
	err ?ErrorKind
}

// The tag of the active result variant.
pub fn (self IoUringResult) tag() IoUringOperationType {
	return match self {
		IoUringNoopResult { .noop }
		IoUringAcceptResult { .accept }
		IoUringCloseResult { .close }
		IoUringConnectResult { .connect }
		IoUringPollResult { .poll }
		IoUringReadResult { .read }
		IoUringPReadResult { .pread }
		IoUringRecvResult { .recv }
		IoUringSendResult { .send }
		IoUringSendMsgResult { .sendmsg }
		IoUringRecvMsgResult { .recvmsg }
		IoUringShutdownResult { .shutdown }
		IoUringPWriteResult { .pwrite }
		IoUringWriteResult { .write }
		IoUringTimerResult { .timer }
		IoUringTimerRemoveResult { .timer_remove }
		IoUringCancelResult { .cancel }
	}
}

// io_uring_result_kind builds the `tag` result variant carrying an error.
fn io_uring_result_kind(tag IoUringOperationType, kind ErrorKind) IoUringResult {
	match tag {
		.noop {
			return IoUringNoopResult{
				err: kind
			}
		}
		.accept {
			return IoUringAcceptResult{
				err: kind
			}
		}
		.close {
			return IoUringCloseResult{
				err: kind
			}
		}
		.connect {
			return IoUringConnectResult{
				err: kind
			}
		}
		.poll {
			return IoUringPollResult{
				err: kind
			}
		}
		.read {
			return IoUringReadResult{
				err: kind
			}
		}
		.pread {
			return IoUringPReadResult{
				err: kind
			}
		}
		.recv {
			return IoUringRecvResult{
				err: kind
			}
		}
		.send {
			return IoUringSendResult{
				err: kind
			}
		}
		.sendmsg {
			return IoUringSendMsgResult{
				err: kind
			}
		}
		.recvmsg {
			return IoUringRecvMsgResult{
				err: kind
			}
		}
		.shutdown {
			return IoUringShutdownResult{
				err: kind
			}
		}
		.pwrite {
			return IoUringPWriteResult{
				err: kind
			}
		}
		.write {
			return IoUringWriteResult{
				err: kind
			}
		}
		.timer {
			return IoUringTimerResult{
				err: kind
			}
		}
		.timer_remove {
			return IoUringTimerRemoveResult{
				err: kind
			}
		}
		.cancel {
			return IoUringCancelResult{
				err: kind
			}
		}
	}
}

// io_uring_result_ok builds the successful `tag` variant with an empty
// payload, which the completion handler then fills in.
fn io_uring_result_ok(tag IoUringOperationType) IoUringResult {
	match tag {
		.noop {
			return IoUringNoopResult{}
		}
		.accept {
			return IoUringAcceptResult{}
		}
		.close {
			return IoUringCloseResult{}
		}
		.connect {
			return IoUringConnectResult{}
		}
		.poll {
			return IoUringPollResult{}
		}
		.read {
			return IoUringReadResult{}
		}
		.pread {
			return IoUringPReadResult{}
		}
		.recv {
			return IoUringRecvResult{}
		}
		.send {
			return IoUringSendResult{}
		}
		.sendmsg {
			return IoUringSendMsgResult{}
		}
		.recvmsg {
			return IoUringRecvMsgResult{}
		}
		.shutdown {
			return IoUringShutdownResult{}
		}
		.pwrite {
			return IoUringPWriteResult{}
		}
		.write {
			return IoUringWriteResult{}
		}
		.timer {
			return IoUringTimerResult{}
		}
		.timer_remove {
			return IoUringTimerRemoveResult{}
		}
		.cancel {
			return IoUringCancelResult{}
		}
	}
}

fn io_uring_result_err(tag IoUringOperationType, err IError) IoUringResult {
	return io_uring_result_kind(tag, error_kind(err))
}

// io_uring_result_n builds the byte-count result variant for `tag`.
fn io_uring_result_n(tag IoUringOperationType, n usize) IoUringResult {
	match tag {
		.read {
			return IoUringReadResult{
				n: n
			}
		}
		.pread {
			return IoUringPReadResult{
				n: n
			}
		}
		.recv {
			return IoUringRecvResult{
				n: n
			}
		}
		.send {
			return IoUringSendResult{
				n: n
			}
		}
		.sendmsg {
			return IoUringSendMsgResult{
				n: n
			}
		}
		.recvmsg {
			return IoUringRecvMsgResult{
				n: n
			}
		}
		.pwrite {
			return IoUringPWriteResult{
				n: n
			}
		}
		.write {
			return IoUringWriteResult{
				n: n
			}
		}
		else {
			panic('io_uring_result_n: ${tag} has no byte count')
		}
	}
}

// io_uring_result_bytes returns the byte count of a read or write result.
fn io_uring_result_bytes(r IoUringResult) usize {
	return match r {
		IoUringReadResult { r.n }
		IoUringPReadResult { r.n }
		IoUringRecvResult { r.n }
		IoUringSendResult { r.n }
		IoUringSendMsgResult { r.n }
		IoUringRecvMsgResult { r.n }
		IoUringPWriteResult { r.n }
		IoUringWriteResult { r.n }
		else { panic('io_uring_result_bytes: ${r.tag()} has no byte count') }
	}
}

// All the supported operations of this event loop. These are always
// backend-specific and therefore the structure and types change depending
// on the underlying system in use. The high level operations are
// done by initializing the request handles.
pub type IoUringOperation = IoUringAcceptOp
	| IoUringCancelOp
	| IoUringCloseOp
	| IoUringConnectOp
	| IoUringNoopOp
	| IoUringPReadOp
	| IoUringPWriteOp
	| IoUringPollOp
	| IoUringReadOp
	| IoUringRecvMsgOp
	| IoUringRecvOp
	| IoUringSendMsgOp
	| IoUringSendOp
	| IoUringShutdownOp
	| IoUringTimerOp
	| IoUringTimerRemoveOp
	| IoUringWriteOp

// The tag of the active operation variant.
pub fn (self IoUringOperation) tag() IoUringOperationType {
	return match self {
		IoUringNoopOp { .noop }
		IoUringAcceptOp { .accept }
		IoUringCloseOp { .close }
		IoUringConnectOp { .connect }
		IoUringPollOp { .poll }
		IoUringReadOp { .read }
		IoUringPReadOp { .pread }
		IoUringRecvOp { .recv }
		IoUringSendOp { .send }
		IoUringSendMsgOp { .sendmsg }
		IoUringRecvMsgOp { .recvmsg }
		IoUringShutdownOp { .shutdown }
		IoUringPWriteOp { .pwrite }
		IoUringWriteOp { .write }
		IoUringTimerOp { .timer }
		IoUringTimerRemoveOp { .timer_remove }
		IoUringCancelOp { .cancel }
	}
}

pub struct IoUringNoopOp {}

pub struct IoUringAcceptOp {
pub mut:
	socket    int
	addr      SockAddr
	addr_size u32 = u32(sizeof(SockAddr))
	flags     u32 = sock_cloexec
}

pub struct IoUringCloseOp {
pub mut:
	fd int
}

pub struct IoUringConnectOp {
pub mut:
	socket int
	addr   NetAddress
}

pub struct IoUringPollOp {
pub mut:
	fd     int
	events u32 = linux_poll_in
}

// The read and recv operations.
pub struct IoUringReadOp {
pub mut:
	fd     int
	buffer IoUringReadBuffer
}

pub struct IoUringPReadOp {
pub mut:
	fd     int
	buffer IoUringReadBuffer
	offset u64
}

// The write and send operations.
pub struct IoUringWriteOp {
pub mut:
	fd     int
	buffer IoUringWriteBuffer
}

pub struct IoUringSendMsgOp {
pub mut:
	fd     int
	msghdr &C.msghdr = unsafe { nil }

	// Optionally, a write buffer can be specified and the given
	// msghdr will be populated with information about this buffer.
	buffer ?IoUringWriteBuffer

	// Do not use this, it is only used internally.
	iov [1]C.iovec
}

pub struct IoUringRecvMsgOp {
pub mut:
	fd     int
	msghdr &C.msghdr = unsafe { nil }
}

pub struct IoUringShutdownOp {
pub mut:
	socket int
	how    ShutdownHow = .both
}

pub struct IoUringRecvOp {
pub mut:
	fd     int
	buffer IoUringReadBuffer
}

pub struct IoUringSendOp {
pub mut:
	fd     int
	buffer IoUringWriteBuffer
}

pub struct IoUringPWriteOp {
pub mut:
	fd     int
	buffer IoUringWriteBuffer
	offset u64
}

pub struct IoUringTimerOp {
pub mut:
	next LinuxKernelTimespec

	// Only used internally. If this is non-null and timer is
	// CANCELLED, then the timer is rearmed automatically with this
	// as the next time. The callback will not be called on the
	// cancellation.
	reset ?LinuxKernelTimespec
}

pub struct IoUringTimerRemoveOp {
pub mut:
	timer &IoUringCompletion = unsafe { nil }
}

pub struct IoUringCancelOp {
pub mut:
	c &IoUringCompletion = unsafe { nil }
}

// ReadBuffer are the various options for reading.
pub struct IoUringReadBuffer {
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
fn (self &IoUringReadBuffer) slice_ptr() []u8 {
	return match self.kind {
		.slice { self.slice }
		.array { unsafe { (&self.array[0]).vbytes(self.array.len) } }
	}
}

// WriteBuffer are the various options for writing.
pub struct IoUringWriteBuffer {
pub mut:
	kind BufferKind
	// Write from this buffer.
	slice []u8
	// Write from this array. See ReadBuffer.array for why we support this.
	array     [32]u8
	array_len usize

	// TODO: future will have vectors
}

// bytes returns the active buffer (`buf.array[0..buf.len]` for arrays) as a
// slice that aliases the completion.
fn (self &IoUringWriteBuffer) bytes() []u8 {
	return match self.kind {
		.slice { self.slice }
		.array { unsafe { (&self.array[0]).vbytes(int(self.array_len)) } }
	}
}

pub enum IoUringTimerTrigger {
	// Timer completed due to linked request completing in time.
	request

	// Timer expired.
	expiration

	// Timer was canceled.
	cancel
}
