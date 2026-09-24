module xev

// "Wake up" an event loop from any thread using an async completion.
//
// V translation of libxev's src/watcher/async.zig AsyncDynamic, the Async of
// the dynamic API (pinned 34fa508).

// Watcher callbacks of the dynamic API. Zig generates a callback per comptime
// Userdata type and function; V passes the caller's untyped userdata pointer
// and captures the watcher callback in a closure. The error is the watcher's
// error set member (the union of the candidates' error sets), if any.
pub type DynamicWatcherCallback = fn (ud voidptr, l &DynamicLoop, c &DynamicCompletion, r ?ErrorKind) CallbackAction

// The error that can come in the wait callback (WaitError) is
// ErrorSet(Async.WaitError).
pub struct DynamicAsync {
pub mut:
	backend DynamicAsyncUnion
}

pub union DynamicAsyncUnion {
pub mut:
	io_uring IoUringAsync
	epoll    EpollAsync
}

pub fn DynamicAsync.init() !DynamicAsync {
	return DynamicAsync{
		backend: match backend() {
			.io_uring {
				DynamicAsyncUnion{
					io_uring: IoUringAsync.init()!
				}
			}
			.epoll {
				DynamicAsyncUnion{
					epoll: EpollAsync.init()!
				}
			}
		}
	}
}

pub fn (mut self DynamicAsync) deinit() {
	match backend() {
		.io_uring { unsafe { self.backend.io_uring.deinit() } }
		.epoll { unsafe { self.backend.epoll.deinit() } }
	}
}

pub fn (self &DynamicAsync) notify() ! {
	match backend() {
		.io_uring { unsafe { self.backend.io_uring.notify()! } }
		.epoll { unsafe { self.backend.epoll.notify()! } }
	}
}

pub fn (self &DynamicAsync) wait(mut loop DynamicLoop, c &DynamicCompletion, userdata voidptr, cb DynamicWatcherCallback) {
	mut completion := unsafe { c }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), r_inner)
			}

			unsafe {
				self.backend.io_uring.wait(mut loop.backend.io_uring, &completion.value.io_uring,
					userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), r_inner)
			}

			unsafe {
				self.backend.epoll.wait(mut loop.backend.epoll, &completion.value.epoll, userdata,
					api_cb)
			}
		}
	}
}
