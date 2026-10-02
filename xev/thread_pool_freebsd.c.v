module xev

#include <sys/umtx.h>

fn C._umtx_op(obj voidptr, op int, value usize, timeout_size voidptr, timeout voidptr) int

// Zig 0.15.2 std.Thread.Futex.FreebsdImpl, instantiated with timeout=null
// by libxev's thread pool. These are native private umtx operations, not a
// polling or condition-variable substitute.
fn thread_pool_freebsd_futex_wait(ptr &ThreadPoolAtomic[u32], expect u32) {
	rc := C._umtx_op(voidptr(&ptr.raw), int(C.UMTX_OP_WAIT_UINT_PRIVATE), usize(expect),
		unsafe { nil }, unsafe { nil })
	match posix_errno(rc) {
		0 {} // notified, value changed, or spurious wake
		C.EINTR {} // spurious wake
		else { panic('unreachable') }
	}
}

fn thread_pool_freebsd_futex_wake(ptr &ThreadPoolAtomic[u32], max_waiters u32) {
	rc := C._umtx_op(voidptr(&ptr.raw), int(C.UMTX_OP_WAKE_PRIVATE), usize(max_waiters),
		unsafe { nil }, unsafe { nil })
	match posix_errno(rc) {
		0 {}
		C.EFAULT {} // source allows an invalid address in wake
		else { panic('unreachable') }
	}
}
