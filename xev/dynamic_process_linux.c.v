module xev

// Process management, such as waiting for process exit.
//
// V translation of libxev's src/watcher/process.zig ProcessDynamic, the
// Process of the dynamic API (pinned 34fa508).

// The callback of Process.wait. The error is a WaitError
// (ErrorSet(Process.WaitError)); on success the exit code is supplied.
pub type DynamicProcessCallback = fn (ud voidptr, l &DynamicLoop, c &DynamicCompletion, r ?ErrorKind, exit_code u32) CallbackAction

pub struct DynamicProcess {
pub mut:
	backend DynamicProcessUnion
}

pub union DynamicProcessUnion {
pub mut:
	io_uring IoUringProcess
	epoll    EpollProcess
}

pub fn DynamicProcess.init(fd int) !DynamicProcess {
	return DynamicProcess{
		backend: match backend() {
			.io_uring {
				DynamicProcessUnion{
					io_uring: IoUringProcess.init(fd)!
				}
			}
			.epoll {
				DynamicProcessUnion{
					epoll: EpollProcess.init(fd)!
				}
			}
		}
	}
}

pub fn (mut self DynamicProcess) deinit() {
	match backend() {
		.io_uring { unsafe { self.backend.io_uring.deinit() } }
		.epoll { unsafe { self.backend.epoll.deinit() } }
	}
}

pub fn (self &DynamicProcess) wait(mut loop DynamicLoop, c &DynamicCompletion, userdata voidptr, cb DynamicProcessCallback) {
	mut completion := unsafe { c }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r_inner ?ErrorKind, exit_code u32) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), r_inner, exit_code)
			}

			unsafe {
				self.backend.io_uring.wait(mut loop.backend.io_uring, &completion.value.io_uring,
					userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r_inner ?ErrorKind, exit_code u32) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), r_inner, exit_code)
			}

			unsafe {
				self.backend.epoll.wait(mut loop.backend.epoll, &completion.value.epoll, userdata,
					api_cb)
			}
		}
	}
}
