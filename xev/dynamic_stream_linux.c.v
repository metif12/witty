module xev

// V translation of libxev's src/watcher/stream.zig for the dynamic API
// (pinned 34fa508): GenericStream's dynamic branch, which enables the dynamic
// branches of the Closeable, Pollable, Readable, and Writeable stream mixins
// with the `read`/`write` methods, no thread pool, and the backend type name
// "Stream". The dynamic WriteQueue, WriteRequest, and PollEvent are in
// dynamic_linux.c.v.

// The callback of Stream.close. The error is a CloseError.
pub type DynamicStreamCloseCallback = fn (ud voidptr, l &DynamicLoop, c &DynamicCompletion, s DynamicStream, r ?ErrorKind) CallbackAction

// The callback of Stream.poll. The error is a PollError; on success the
// polled event is supplied.
pub type DynamicStreamPollCallback = fn (ud voidptr, l &DynamicLoop, c &DynamicCompletion, s DynamicStream, r ?ErrorKind, event DynamicPollEvent) CallbackAction

// The callback of Stream.read. The error is a ReadError; on success the byte
// count is supplied.
pub type DynamicStreamReadCallback = fn (ud voidptr, l &DynamicLoop, c &DynamicCompletion, s DynamicStream, b DynamicReadBuffer, r ?ErrorKind, n usize) CallbackAction

// The callback of Stream.write and Stream.queueWrite. The error is a
// WriteError; on success the byte count is supplied.
pub type DynamicStreamWriteCallback = fn (ud voidptr, l &DynamicLoop, c &DynamicCompletion, s DynamicStream, b DynamicWriteBuffer, r ?ErrorKind, n usize) CallbackAction

// Creates a generic stream type that supports read, write, close, poll. This
// can be used for any file descriptor that would exhibit normal blocking
// behavior on read/write. This should NOT be used for local files because
// local files have some special properties; you should use xev.File for that.
pub struct DynamicStream {
pub mut:
	backend DynamicStreamUnion
}

pub union DynamicStreamUnion {
pub mut:
	io_uring IoUringStream
	epoll    EpollStream
}

pub fn DynamicStream.init_fd(fd int) DynamicStream {
	return DynamicStream{
		backend: match backend() {
			.io_uring {
				DynamicStreamUnion{
					io_uring: IoUringStream.init_fd(fd)
				}
			}
			.epoll {
				DynamicStreamUnion{
					epoll: EpollStream.init_fd(fd)
				}
			}
		}
	}
}

pub fn (self &DynamicStream) deinit() {
	match backend() {
		.io_uring { unsafe { self.backend.io_uring.deinit() } }
		.epoll { unsafe { self.backend.epoll.deinit() } }
	}
}

// Pollable: if all candidate backends do not support poll, our dynamic
// type cannot support poll. Both the io_uring and the epoll Stream have poll.
pub fn (self DynamicStream) poll(mut loop DynamicLoop, c &DynamicCompletion, event DynamicPollEvent, userdata voidptr, cb DynamicStreamPollCallback) {
	mut completion := unsafe { c }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, s_inner IoUringStream, r_inner ?ErrorKind, event_inner IoUringPollEvent) CallbackAction {
				// The event is only meaningful when there is no error.
				mut ev := DynamicPollEvent.read
				if r_inner == none {
					ev = DynamicPollEvent.from_io_uring(event_inner)
				}
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), DynamicStream.init_fd(s_inner.fd),
					r_inner, ev)
			}

			unsafe {
				self.backend.io_uring.poll(mut loop.backend.io_uring, &completion.value.io_uring,
					event.to_io_uring(), userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, s_inner EpollStream, r_inner ?ErrorKind, event_inner EpollPollEvent) CallbackAction {
				// The event is only meaningful when there is no error.
				mut ev := DynamicPollEvent.read
				if r_inner == none {
					ev = DynamicPollEvent.from_epoll(event_inner)
				}
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), DynamicStream.init_fd(s_inner.fd),
					r_inner, ev)
			}

			unsafe {
				self.backend.epoll.poll(mut loop.backend.epoll, &completion.value.epoll,
					event.to_epoll(), userdata, api_cb)
			}
		}
	}
}

pub fn (self DynamicStream) close(mut loop DynamicLoop, c &DynamicCompletion, userdata voidptr, cb DynamicStreamCloseCallback) {
	mut completion := unsafe { c }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, s_inner IoUringStream, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), DynamicStream.init_fd(s_inner.fd),
					r_inner)
			}

			unsafe {
				self.backend.io_uring.close(mut loop.backend.io_uring, &completion.value.io_uring,
					userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, s_inner EpollStream, r_inner ?ErrorKind) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), DynamicStream.init_fd(s_inner.fd),
					r_inner)
			}

			unsafe {
				self.backend.epoll.close(mut loop.backend.epoll, &completion.value.epoll, userdata,
					api_cb)
			}
		}
	}
}

pub fn (self DynamicStream) read(mut loop DynamicLoop, c &DynamicCompletion, buf DynamicReadBuffer, userdata voidptr, cb DynamicStreamReadCallback) {
	mut completion := unsafe { c }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, s_inner IoUringStream, b_inner IoUringReadBuffer, r_inner ?ErrorKind, n_inner usize) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), DynamicStream.init_fd(s_inner.fd),
					DynamicReadBuffer.from_io_uring(b_inner), r_inner, n_inner)
			}

			unsafe {
				self.backend.io_uring.read(mut loop.backend.io_uring, &completion.value.io_uring,
					buf.to_io_uring(), userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, s_inner EpollStream, b_inner EpollReadBuffer, r_inner ?ErrorKind, n_inner usize) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), DynamicStream.init_fd(s_inner.fd),
					DynamicReadBuffer.from_epoll(b_inner), r_inner, n_inner)
			}

			unsafe {
				self.backend.epoll.read(mut loop.backend.epoll, &completion.value.epoll,
					buf.to_epoll(), userdata, api_cb)
			}
		}
	}
}

pub fn (self DynamicStream) write(mut loop DynamicLoop, c &DynamicCompletion, buf DynamicWriteBuffer, userdata voidptr, cb DynamicStreamWriteCallback) {
	mut completion := unsafe { c }
	match backend() {
		.io_uring {
			completion.ensure_tag(.io_uring)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, s_inner IoUringStream, b_inner IoUringWriteBuffer, r_inner ?ErrorKind, n_inner usize) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), DynamicStream.init_fd(s_inner.fd),
					DynamicWriteBuffer.from_io_uring(b_inner), r_inner, n_inner)
			}

			unsafe {
				self.backend.io_uring.write(mut loop.backend.io_uring, &completion.value.io_uring,
					buf.to_io_uring(), userdata, api_cb)
			}
		}
		.epoll {
			completion.ensure_tag(.epoll)

			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, s_inner EpollStream, b_inner EpollWriteBuffer, r_inner ?ErrorKind, n_inner usize) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), DynamicStream.init_fd(s_inner.fd),
					DynamicWriteBuffer.from_epoll(b_inner), r_inner, n_inner)
			}

			unsafe {
				self.backend.epoll.write(mut loop.backend.epoll, &completion.value.epoll,
					buf.to_epoll(), userdata, api_cb)
			}
		}
	}
}

// The callback's completion is derived from the backend completion of the
// request exactly like the other callbacks, although that completion is not
// inside a dynamic Completion.
pub fn (self DynamicStream) queue_write(mut loop DynamicLoop, q &DynamicWriteQueue, req &DynamicWriteRequest, buf DynamicWriteBuffer, userdata voidptr, cb DynamicStreamWriteCallback) {
	mut write_queue := unsafe { q }
	mut request := unsafe { req }
	match backend() {
		.io_uring {
			api_cb := fn [cb] (ud_inner voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, s_inner IoUringStream, b_inner IoUringWriteBuffer, r_inner ?ErrorKind, n_inner usize) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_io_uring(l_inner),
					DynamicCompletion.from_io_uring(c_inner), DynamicStream.init_fd(s_inner.fd),
					DynamicWriteBuffer.from_io_uring(b_inner), r_inner, n_inner)
			}

			// Ensure our WriteQueue has the correct tag, since it is
			// regularly zero-initialized and our zero-init picks
			// an arbitrary backend.
			write_queue.ensure_tag(.io_uring)

			// Initialize our request since it is usually undefined.
			// (V has no undefined; the member gets its zero value.)
			unsafe {
				*request = DynamicWriteRequest{
					io_uring: IoUringWriteRequest{}
				}
			}
			unsafe {
				self.backend.io_uring.queue_write(mut loop.backend.io_uring,
					&write_queue.value.io_uring, &request.io_uring, buf.to_io_uring(), userdata,
					api_cb)
			}
		}
		.epoll {
			api_cb := fn [cb] (ud_inner voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, s_inner EpollStream, b_inner EpollWriteBuffer, r_inner ?ErrorKind, n_inner usize) CallbackAction {
				return cb(ud_inner, DynamicLoop.from_epoll(l_inner),
					DynamicCompletion.from_epoll(c_inner), DynamicStream.init_fd(s_inner.fd),
					DynamicWriteBuffer.from_epoll(b_inner), r_inner, n_inner)
			}

			// Ensure our WriteQueue has the correct tag, since it is
			// regularly zero-initialized and our zero-init picks
			// an arbitrary backend.
			write_queue.ensure_tag(.epoll)

			// Initialize our request since it is usually undefined.
			// (V has no undefined; the member gets its zero value.)
			unsafe {
				*request = DynamicWriteRequest{
					epoll: EpollWriteRequest{}
				}
			}
			unsafe {
				self.backend.epoll.queue_write(mut loop.backend.epoll, &write_queue.value.epoll,
					&request.epoll, buf.to_epoll(), userdata, api_cb)
			}
		}
	}
}
