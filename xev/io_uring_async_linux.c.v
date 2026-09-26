module xev

// "Wake up" an event loop from any thread using an async completion.
//
// V translation of libxev's src/watcher/async.zig AsyncEventFd, the Async
// implementation of the io_uring backend (pinned 34fa508).

// Async implementation using eventfd (Unix/Linux).
pub struct IoUringAsync {
pub mut:
	// eventfd file descriptor
	fd int
}

// Create a new async. An async can be assigned to exactly one loop
// to be woken up. The completion must be allocated in advance.
pub fn IoUringAsync.init() !IoUringAsync {
	return IoUringAsync{
		// (The source calls the libc eventfd directly on FreeBSD; this file
		// is only compiled for Linux.)

		// Use std.posix if we can.
		fd: posix_eventfd(0, u32(int(C.EFD_CLOEXEC)) | u32(int(C.EFD_NONBLOCK)))!
	}
}

// Clean up the async. This will forcibly deinitialize any resources
// and may result in erroneous wait callbacks to be fired.
pub fn (mut self IoUringAsync) deinit() {
	posix_close(self.fd)
}

// Wait for a message on this async. Note that async messages may be
// coalesced (or they may not be) so you should not expect a 1:1 mapping
// between send and wait.
//
// Just like the rest of libxev, the wait must be re-queued if you want
// to continue to be notified of async events.
//
// You should NOT register an async with multiple loops (the same loop
// is fine -- but unnecessary). The behavior when waiting on multiple
// loops is undefined.
//
// The io_uring backend uses the source's waitPoll. The callback error is a
// WaitError (xev.ReadError).
pub fn (self &IoUringAsync) wait(mut loop IoUringLoop, c &IoUringCompletion, userdata voidptr, cb IoUringWatcherCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = IoUringCompletion{
			// We use a poll operation instead of a read operation
			// because in Kernel 6.15.4, read was regressed for
			// io_uring on eventfd/timerfd and would block forever.
			// However, poll works fine.
			op: IoUringPollOp{
				fd: self.fd
				events: linux_poll_in
			}
			userdata: userdata
		}
	}
	completion.callback = fn [cb] (ud voidptr, l_inner &IoUringLoop, c_inner &IoUringCompletion, r IoUringResult) CallbackAction {
		if r.err == none {
			// We need to read so that we can consume the
			// eventfd value. We only read 8 bytes because
			// we only write up to 8 bytes and we own the fd.
			// We ignore errors here because we expect the
			// read to succeed given we just polled it.
			mut buf := [8]u8{}
			posix_read((c_inner.op as IoUringPollOp).fd, unsafe { (&buf[0]).vbytes(buf.len) }) or {}
		} else {
			// We'll call the callback with the error later.
		}

		return cb(ud, l_inner, c_inner, r.err)
	}
	loop.add(completion)
}

// Notify a loop to wake up synchronously. This should never block forever
// (it will always EVENTUALLY succeed regardless of if the loop is currently
// ticking or not).
//
// The "c" value is the completion associated with the "wait".
//
// Internal details subject to change but if you're relying on these
// details then you may want to consider using a lower level interface
// using the loop directly:
//
//   - linux+io_uring: eventfd is used. If the eventfd write would block
//     (EAGAIN) then we assume success because the eventfd is full.
//
pub fn (self &IoUringAsync) notify() ! {
	// We want to just write "1" in the correct byte order as our host.
	val := u64(1)
	posix_write(self.fd, unsafe { (&u8(&val)).vbytes(8) }) or {
		if error_kind(err) == .would_block {
			return
		}
		return err
	}
}
