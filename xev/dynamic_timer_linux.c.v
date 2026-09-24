module xev

// V translation of libxev's src/watcher/timer.zig TimerDynamic, the Timer of
// the dynamic API (pinned 34fa508).

// A timer fires a callback after a specified amount of time. A timer can
// repeat by returning "rearm" in the callback or by rescheduling the
// start within the callback.
//
// The run callback error (RunError) is ErrorSet(Timer.RunError) and the
// cancel callback error (CancelError) is ErrorSet(Timer.CancelError).
pub struct DynamicTimer {
pub mut:
	backend DynamicTimerUnion
}

pub union DynamicTimerUnion {
pub mut:
	// Both candidate Timers are zero-sized, so Union adds a non-zero sized
	// padding entry (`_zig_bug_padding`; V field names cannot start with an
	// underscore). In the source it avoids a Zig 0.13 compiler crash. It is
	// the first field here because C zero-initializes a union through its
	// first member, which cannot be an empty struct.
	zig_bug_padding u8
	io_uring        IoUringTimer
	epoll           EpollTimer
}

pub fn DynamicTimer.init() !DynamicTimer {
	return DynamicTimer{
		backend: match backend() {
			.io_uring {
				DynamicTimerUnion{
					io_uring: IoUringTimer.init()!
				}
			}
			.epoll {
				DynamicTimerUnion{
					epoll: EpollTimer.init()!
				}
			}
		}
	}
}

pub fn (self &DynamicTimer) deinit() {
	match backend() {
		.io_uring { unsafe { self.backend.io_uring.deinit() } }
		.epoll { unsafe { self.backend.epoll.deinit() } }
	}
}

pub fn (self &DynamicTimer) run(mut loop DynamicLoop, c &DynamicCompletion, next_ms u64, userdata voidptr, cb DynamicWatcherCallback) {
	mut completion := unsafe { c }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), r_inner)
			}

			unsafe {
				self.backend.io_uring.run(mut loop.backend.io_uring, &completion.value.io_uring,
					next_ms, userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), r_inner)
			}

			unsafe {
				self.backend.epoll.run(mut loop.backend.epoll, &completion.value.epoll, next_ms,
					userdata, api_cb)
			}
		}
	}
}

pub fn (self &DynamicTimer) reset(mut loop DynamicLoop, c &DynamicCompletion, c_cancel &DynamicCompletion, next_ms u64, userdata voidptr, cb DynamicWatcherCallback) {
	mut completion := unsafe { c }
	mut completion_cancel := unsafe { c_cancel }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)
			completion_cancel.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), r_inner)
			}

			unsafe {
				self.backend.io_uring.reset(mut loop.backend.io_uring, &completion.value.io_uring,
					&completion_cancel.value.io_uring, next_ms, userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)
			completion_cancel.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), r_inner)
			}

			unsafe {
				self.backend.epoll.reset(mut loop.backend.epoll, &completion.value.epoll,
					&completion_cancel.value.epoll, next_ms, userdata, api_cb)
			}
		}
	}
}

pub fn (self &DynamicTimer) cancel(mut loop DynamicLoop, c_timer &DynamicCompletion, c_cancel &DynamicCompletion, userdata voidptr, cb DynamicWatcherCallback) {
	mut completion_timer := unsafe { c_timer }
	mut completion_cancel := unsafe { c_cancel }
	match backend() {
		.io_uring {
			completion_timer.ensure_tag(.io_uring)
			completion_cancel.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), r_inner)
			}

			unsafe {
				self.backend.io_uring.cancel(mut loop.backend.io_uring,
					&completion_timer.value.io_uring, &completion_cancel.value.io_uring, userdata,
					api_cb)
			}
		}
		.epoll {
			completion_timer.ensure_tag(.epoll)
			completion_cancel.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), r_inner)
			}

			unsafe {
				self.backend.epoll.cancel(mut loop.backend.epoll, &completion_timer.value.epoll,
					&completion_cancel.value.epoll, userdata, api_cb)
			}
		}
	}
}
