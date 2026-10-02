module xev

#include <sys/eventfd.h>

// libxev 34fa508 src/watcher/async.zig AsyncEventFd instantiated for kqueue.
// The source directly calls FreeBSD eventfd and deliberately has a TODO for
// handling creation errors; the returned descriptor is preserved verbatim.
fn C.eventfd(initval u32, flags u32) int

pub type KqueueWatcherCallback = fn (ud voidptr, l &KqueueLoop, c &KqueueCompletion, r ?ErrorKind) CallbackAction

pub struct KqueueAsync {
pub mut:
	fd int
}

pub fn KqueueAsync.init() !KqueueAsync {
	return KqueueAsync{
		fd: C.eventfd(0, 0x100000 | 0x4)
	}
}

pub fn (mut self KqueueAsync) deinit() {
	posix_close(self.fd)
}

pub fn (self &KqueueAsync) wait(mut loop KqueueLoop, c &KqueueCompletion, userdata voidptr, cb KqueueWatcherCallback) {
	mut completion := unsafe { c }
	unsafe {
		*completion = KqueueCompletion{
			op:       KqueueReadOp{
				fd:     self.fd
				buffer: KqueueReadBuffer(ReadBufferArray{})
			}
			userdata: userdata
			callback: fn [cb] (ud voidptr, l_inner &KqueueLoop, c_inner &KqueueCompletion, result KqueueResult) CallbackAction {
				if result.err == none {
					assert (result as KqueueReadResult).n > 0
				}
				return cb(ud, l_inner, c_inner, result.err)
			}
		}
	}
	loop.add(completion)
}

pub fn (self &KqueueAsync) notify() ! {
	// @bitCast(u64(1)) in the source uses host byte order, including big endian.
	value := u64(1)
	mut bytes := [8]u8{}
	unsafe { vmemcpy(&bytes[0], &value, 8) }
	posix_write(self.fd, bytes[..]) or {
		if error_kind(err) == .would_block { return }
		return err
	}
}
