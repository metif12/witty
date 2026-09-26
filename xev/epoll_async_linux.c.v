module xev

// "Wake up" an event loop from any thread using an async completion.
//
// V translation of libxev's src/watcher/async.zig AsyncEventFd, the Async
// implementation of the epoll backend (pinned 34fa508). Only its Linux
// branches and the `waitPoll` wait (used by io_uring and epoll) apply.

#include <poll.h>

// Watcher callbacks. Zig generates a callback per comptime Userdata type and
// function; V passes the caller's untyped userdata pointer and captures the
// watcher callback in a closure. The error is the watcher's error set member,
// if any.
pub type EpollWatcherCallback = fn (ud voidptr, l &EpollLoop, c &EpollCompletion, r ?ErrorKind) CallbackAction

// Async implementation using eventfd (Unix/Linux).
//
// The error that can come in the wait callback (WaitError) is a ReadError.
pub struct EpollAsync {
pub mut:
	// eventfd file descriptor
	fd int
}

// Create a new async. An async can be assigned to exactly one loop
// to be woken up. The completion must be allocated in advance.
pub fn EpollAsync.init() !EpollAsync {
	// Use std.posix if we can. (The FreeBSD branch calls eventfd directly.)
	fd := posix_eventfd(0, u32(int(C.EFD_CLOEXEC)) | u32(int(C.EFD_NONBLOCK)))!
	return EpollAsync{
		fd: fd
	}
}

// Clean up the async. This will forcibly deinitialize any resources
// and may result in erroneous wait callbacks to be fired.
pub fn (mut self EpollAsync) deinit() {
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
// This is AsyncEventFd.waitPoll, the `wait` of the epoll backend.
pub fn (self &EpollAsync) wait(mut loop EpollLoop, c &EpollCompletion, userdata voidptr, cb EpollWatcherCallback) {
	// The callback is declared before the completion is assigned so that it
	// is not nested in the assignment's `unsafe` block.
	callback := fn [cb] (ud voidptr, l_inner &EpollLoop, c_inner &EpollCompletion, r EpollResult) CallbackAction {
		if r.err == none {
			// We need to read so that we can consume the
			// eventfd value. We only read 8 bytes because
			// we only write up to 8 bytes and we own the fd.
			// We ignore errors here because we expect the
			// read to succeed given we just polled it.
			mut buf := [8]u8{}
			_ := posix_read((c_inner.op as EpollPollOp).fd, unsafe { (&buf[0]).vbytes(buf.len) }) or { 0 }
		} else {
			// We'll call the callback with the error later.
		}

		return cb(ud, l_inner, c_inner, r.err)
	}

	mut completion := unsafe { c }
	unsafe {
		*completion = EpollCompletion{
			// We use a poll operation instead of a read operation
			// because in Kernel 6.15.4, read was regressed for
			// io_uring on eventfd/timerfd and would block forever.
			// However, poll works fine.
			op:       EpollPollOp{
				fd:     self.fd
				events: u32(int(C.POLLIN))
			}
			userdata: userdata
			callback: callback
		}
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
pub fn (self &EpollAsync) notify() ! {
	// We want to just write "1" in the correct byte order as our host.
	val := u64(1)
	_ := posix_write(self.fd, unsafe { (&u8(&val)).vbytes(int(sizeof(u64))) }) or {
		match error_kind(err) {
			.would_block { return }
			else { return err }
		}
	}
}
