module xev

// V translation of the parts of Zig 0.15.2 std.os.linux.IoUring
// (lib/std/os/linux/IoUring.zig), std.os.linux.io_uring_sqe
// (lib/std/os/linux/io_uring_sqe.zig), and the io_uring structures, syscalls,
// and IORING_* constants of lib/std/os/linux.zig that libxev's io_uring
// backend reaches. The std type is named LinuxIoUring (with LinuxIoUringSq and
// LinuxIoUringCq) so that it does not clash with the libxev backend types.
//
// The Zig slices over the mmap-ed rings (`[]u32`, `[]linux.io_uring_sqe`,
// `[]linux.io_uring_cqe`) are kept as a pointer and a length because V arrays
// cannot alias the kernel's memory. Zig's atomics on the ring head/tail use the
// C `__atomic_*` builtins with the same orderings (see thread_pool.v); Zig's
// `.unordered` has no C equivalent and uses the next-stronger relaxed order.

#include <sys/syscall.h>

// io_uring_params.flags

// io_context is polled
pub const ioring_setup_iopoll = u32(1) << 0

// SQ poll thread
pub const ioring_setup_sqpoll = u32(1) << 1

// app defines CQ size
pub const ioring_setup_cqsize = u32(1) << 3

// attach to existing wq
pub const ioring_setup_attach_wq = u32(1) << 5

// IO submission data structure (Submission Queue Entry)
pub enum IoringOp as u8 {
	nop
	readv
	writev
	fsync
	read_fixed
	write_fixed
	poll_add
	poll_remove
	sync_file_range
	sendmsg
	recvmsg
	timeout
	timeout_remove
	accept
	async_cancel
	link_timeout
	connect
	fallocate
	openat
	close
	files_update
	statx
	read
	write
	fadvise
	madvise
	send
	recv
	openat2
	epoll_ctl
	splice
	provide_buffers
	remove_buffers
	tee
	shutdown
	renameat
	unlinkat
	mkdirat
	symlinkat
	linkat
	msg_ring
	fsetxattr
	setxattr
	fgetxattr
	getxattr
	socket
	uring_cmd
	send_zc
	sendmsg_zc
	read_multishot
	waitid
	futex_wait
	futex_wake
	futex_waitv
	fixed_fd_install
	ftruncate
	bind
	listen
	recv_zc
}

// io_uring_sqe.timeout_flags (rw_flags in the Zig struct)
pub const ioring_timeout_abs = u32(1) << 0

// Magic offsets for the application to mmap the data it needs
pub const ioring_off_sq_ring = u64(0)
pub const ioring_off_cq_ring = u64(0x8000000)
pub const ioring_off_sqes = u64(0x10000000)

// io_sqring_offsets.flags

// needs io_uring_enter wakeup
pub const ioring_sq_need_wakeup = u32(1) << 0

// kernel has cqes waiting beyond the cq ring
pub const ioring_sq_cq_overflow = u32(1) << 1

// io_uring_enter flags
pub const ioring_enter_getevents = u32(1) << 0
pub const ioring_enter_sq_wakeup = u32(1) << 1

// io_uring_params.features flags
pub const ioring_feat_single_mmap = u32(1) << 0

// std.os.linux.NSIG (non-MIPS)
const linux_nsig = 65

// std.os.linux.POLL.IN
pub const linux_poll_in = u32(0x001)

// The timespec struct used by the kernel.
pub struct LinuxKernelTimespec {
pub mut:
	sec  i64
	nsec i64
}

// IO submission data structure (Submission Queue Entry)
pub struct IoUringSqe {
pub mut:
	opcode       IoringOp
	flags        u8
	ioprio       u16
	fd           i32
	off          u64
	addr         u64
	len          u32
	rw_flags     u32
	user_data    u64
	buf_index    u16
	personality  u16
	splice_fd_in i32
	addr3        u64
	resv         u64
}

pub fn (mut sqe IoUringSqe) prep_rw(op IoringOp, fd int, addr u64, len usize, offset u64) {
	assert len <= max_u32 // @intCast safety check
	unsafe {
		*sqe = IoUringSqe{
			opcode: op
			flags: 0
			ioprio: 0
			fd: fd
			off: offset
			addr: addr
			len: u32(len)
			rw_flags: 0
			user_data: 0
			buf_index: 0
			personality: 0
			splice_fd_in: 0
			addr3: 0
			resv: 0
		}
	}
}

pub fn (mut sqe IoUringSqe) prep_read(fd int, buffer []u8, offset u64) {
	sqe.prep_rw(.read, fd, u64(usize(buffer.data)), usize(buffer.len), offset)
}

pub fn (mut sqe IoUringSqe) prep_write(fd int, buffer []u8, offset u64) {
	sqe.prep_rw(.write, fd, u64(usize(buffer.data)), usize(buffer.len), offset)
}

pub fn (mut sqe IoUringSqe) prep_accept(fd int, addr voidptr, addrlen &u32, flags u32) {
	// `addr` holds a pointer to `sockaddr`, and `addr2` holds a pointer to socklen_t`.
	// `addr2` maps to `sqe.off` (u64) instead of `sqe.len` (which is only a u32).
	sqe.prep_rw(.accept, fd, u64(usize(addr)), 0, u64(usize(addrlen)))
	sqe.rw_flags = flags
}

pub fn (mut sqe IoUringSqe) prep_connect(fd int, addr voidptr, addrlen u32) {
	// `addrlen` maps to `sqe.off` (u64) instead of `sqe.len` (which is only a u32).
	sqe.prep_rw(.connect, fd, u64(usize(addr)), 0, u64(addrlen))
}

pub fn (mut sqe IoUringSqe) prep_recv(fd int, buffer []u8, flags u32) {
	sqe.prep_rw(.recv, fd, u64(usize(buffer.data)), usize(buffer.len), 0)
	sqe.rw_flags = flags
}

pub fn (mut sqe IoUringSqe) prep_recvmsg(fd int, msg &C.msghdr, flags u32) {
	sqe.prep_rw(.recvmsg, fd, u64(usize(msg)), 1, 0)
	sqe.rw_flags = flags
}

pub fn (mut sqe IoUringSqe) prep_send(fd int, buffer []u8, flags u32) {
	sqe.prep_rw(.send, fd, u64(usize(buffer.data)), usize(buffer.len), 0)
	sqe.rw_flags = flags
}

pub fn (mut sqe IoUringSqe) prep_sendmsg(fd int, msg &C.msghdr, flags u32) {
	sqe.prep_rw(.sendmsg, fd, u64(usize(msg)), 1, 0)
	sqe.rw_flags = flags
}

pub fn (mut sqe IoUringSqe) prep_close(fd int) {
	unsafe {
		*sqe = IoUringSqe{
			opcode: .close
			flags: 0
			ioprio: 0
			fd: fd
			off: 0
			addr: 0
			len: 0
			rw_flags: 0
			user_data: 0
			buf_index: 0
			personality: 0
			splice_fd_in: 0
			addr3: 0
			resv: 0
		}
	}
}

pub fn (mut sqe IoUringSqe) prep_timeout(ts &LinuxKernelTimespec, count u32, flags u32) {
	sqe.prep_rw(.timeout, -1, u64(usize(ts)), 1, u64(count))
	sqe.rw_flags = flags
}

pub fn (mut sqe IoUringSqe) prep_timeout_remove(timeout_user_data u64, flags u32) {
	unsafe {
		*sqe = IoUringSqe{
			opcode: .timeout_remove
			flags: 0
			ioprio: 0
			fd: -1
			off: 0
			addr: timeout_user_data
			len: 0
			rw_flags: flags
			user_data: 0
			buf_index: 0
			personality: 0
			splice_fd_in: 0
			addr3: 0
			resv: 0
		}
	}
}

pub fn (mut sqe IoUringSqe) prep_poll_add(fd int, poll_mask u32) {
	sqe.prep_rw(.poll_add, fd, u64(usize(unsafe { nil })), 0, 0)
	// Poll masks previously used to comprise of 16 bits in the flags union of
	// a SQE, but were then extended to comprise of 32 bits in order to make
	// room for additional option flags. To ensure that the correct bits of
	// poll masks are consistently and properly read across multiple kernel
	// versions, poll masks are enforced to be little-endian.
	// https://www.spinics.net/lists/io-uring/msg02848.html
	sqe.rw_flags = mem_native_to_little_u32(poll_mask)
}

pub fn (mut sqe IoUringSqe) prep_cancel(cancel_user_data u64, flags u32) {
	sqe.prep_rw(.async_cancel, -1, cancel_user_data, 0, 0)
	sqe.rw_flags = flags
}

pub fn (mut sqe IoUringSqe) prep_shutdown(sockfd int, how u32) {
	sqe.prep_rw(.shutdown, sockfd, 0, how, 0)
}

// std.mem.nativeToLittle(u32, x)
@[inline]
fn mem_native_to_little_u32(x u32) u32 {
	$if big_endian {
		return ((x & 0xff) << 24) | ((x & 0xff00) << 8) | ((x >> 8) & 0xff00) | (x >> 24)
	} $else {
		return x
	}
}

// IO completion data structure (Completion Queue Entry)
pub struct IoUringCqe {
pub mut:
	// io_uring_sqe.data submission passed back
	user_data u64

	// result code for this event
	res   i32
	flags u32

	// Followed by 16 bytes of padding if initialized with IORING_SETUP_CQE32, doubling cqe size
}

// Filled with the offset for mmap(2)
pub struct IoSqringOffsets {
pub mut:
	// offset of ring head
	head u32

	// offset of ring tail
	tail u32

	// ring mask value
	ring_mask u32

	// entries in ring
	ring_entries u32

	// ring flags
	flags u32

	// number of sqes not submitted
	dropped u32

	// sqe index array
	array u32

	resv1     u32
	user_addr u64
}

pub struct IoCqringOffsets {
pub mut:
	head         u32
	tail         u32
	ring_mask    u32
	ring_entries u32
	overflow     u32
	cqes         u32
	flags        u32
	resv         u32
	user_addr    u64
}

pub struct IoUringParams {
pub mut:
	sq_entries     u32
	cq_entries     u32
	flags          u32
	sq_thread_cpu  u32
	sq_thread_idle u32
	features       u32
	wq_fd          u32
	resv           [3]u32
	sq_off         IoSqringOffsets
	cq_off         IoCqringOffsets
}

// Translation of std.os.linux.io_uring_setup.
pub fn linux_io_uring_setup(entries u32, p &IoUringParams) usize {
	return linux_syscall_result(unsafe {
		C.syscall(C.SYS_io_uring_setup, voidptr(usize(entries)), voidptr(p))
	})
}

// Translation of std.os.linux.io_uring_enter.
pub fn linux_io_uring_enter(fd int, to_submit u32, min_complete u32, flags u32, sig voidptr) usize {
	return linux_syscall_result(unsafe {
		C.syscall(C.SYS_io_uring_enter, voidptr(usize(isize(fd))), voidptr(usize(to_submit)),
			voidptr(usize(min_complete)), voidptr(usize(flags)), sig, voidptr(usize(linux_nsig / 8)))
	})
}

// @atomicLoad(u32, ptr, order)
@[inline]
fn io_uring_atomic_load_u32(ptr &u32, order ThreadPoolAtomicOrder) u32 {
	mut ret := u32(0)
	C.__atomic_load(ptr, &ret, int(order))
	return ret
}

// @atomicStore(u32, ptr, value, order)
@[inline]
fn io_uring_atomic_store_u32(ptr &u32, value u32, order ThreadPoolAtomicOrder) {
	mut val := value
	C.__atomic_store(ptr, &val, int(order))
}

// std.math.isPowerOfTwo
@[inline]
fn is_power_of_two_u16(int_ u16) bool {
	assert int_ > 0
	return (int_ & (int_ - 1)) == 0
}

pub struct LinuxIoUring {
pub mut:
	fd       int = -1
	sq       LinuxIoUringSq
	cq       LinuxIoUringCq
	flags    u32
	features u32
}

// A friendly way to setup an io_uring, with default linux.io_uring_params.
// `entries` must be a power of two between 1 and 32768, although the kernel will make the final
// call on how many entries the submission and completion queues will ultimately have,
// see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L8027-L8050.
// Matches the interface of io_uring_queue_init() in liburing.
pub fn LinuxIoUring.init(entries u16, flags u32) !LinuxIoUring {
	mut params := IoUringParams{
		flags: flags
		sq_thread_idle: 1000
	}
	return LinuxIoUring.init_params(entries, mut params)!
}

// A powerful way to setup an io_uring, if you want to tweak linux.io_uring_params such as submission
// queue thread cpu affinity or thread idle timeout (the kernel and our default is 1 second).
// `params` is passed by reference because the kernel needs to modify the parameters.
// Matches the interface of io_uring_queue_init_params() in liburing.
pub fn LinuxIoUring.init_params(entries u16, mut p IoUringParams) !LinuxIoUring {
	if entries == 0 {
		return new_error(.entries_zero)
	}
	if !is_power_of_two_u16(entries) {
		return new_error(.entries_not_power_of_two)
	}

	assert p.sq_entries == 0
	assert p.cq_entries == 0 || p.flags & ioring_setup_cqsize != 0
	assert p.features == 0
	assert p.wq_fd == 0 || p.flags & ioring_setup_attach_wq != 0
	assert p.resv[0] == 0
	assert p.resv[1] == 0
	assert p.resv[2] == 0

	res := linux_io_uring_setup(u32(entries), p)
	match linux_errno(res) {
		0 {}
		C.EFAULT {
			return new_error(.params_outside_accessible_address_space)
		}
		// The resv array contains non-zero data, p.flags contains an unsupported flag,
		// entries out of bounds, IORING_SETUP_SQ_AFF was specified without IORING_SETUP_SQPOLL,
		// or IORING_SETUP_CQSIZE was specified but linux.io_uring_params.cq_entries was invalid:
		C.EINVAL {
			return new_error(.arguments_invalid)
		}
		C.EMFILE {
			return new_error(.process_fd_quota_exceeded)
		}
		C.ENFILE {
			return new_error(.system_fd_quota_exceeded)
		}
		C.ENOMEM {
			return new_error(.system_resources)
		}
		// IORING_SETUP_SQPOLL was specified but effective user ID lacks sufficient privileges,
		// or a container seccomp policy prohibits io_uring syscalls:
		C.EPERM {
			return new_error(.permission_denied)
		}
		C.ENOSYS {
			return new_error(.system_outdated)
		}
		else {
			return unexpected_errno(linux_errno(res))
		}
	}
	fd := int(res)
	assert fd >= 0
	// errdefer posix.close(fd)
	mut ok := false
	defer {
		if !ok {
			posix_close(fd)
		}
	}

	// Kernel versions 5.4 and up use only one mmap() for the submission and completion queues.
	// This is not an optional feature for us... if the kernel does it, we have to do it.
	// The thinking on this by the kernel developers was that both the submission and the
	// completion queue rings have sizes just over a power of two, but the submission queue ring
	// is significantly smaller with u32 slots. By bundling both in a single mmap, the kernel
	// gets the submission queue ring for free.
	// See https://patchwork.kernel.org/patch/11115257 for the kernel patch.
	// We do not support the double mmap() done before 5.4, because we want to keep the
	// init/deinit mmap paths simple and because io_uring has had many bug fixes even since 5.4.
	if (p.features & ioring_feat_single_mmap) == 0 {
		return new_error(.system_outdated)
	}

	// Check that the kernel has actually set params and that "impossible is nothing".
	assert p.sq_entries != 0
	assert p.cq_entries != 0
	assert p.cq_entries >= p.sq_entries

	// From here on, we only need to read from params, so pass `p` by value as immutable.
	// The completion queue shares the mmap with the submission queue, so pass `sq` there too.
	mut sq := LinuxIoUringSq.init(fd, p)!
	defer {
		if !ok {
			sq.deinit()
		}
	}
	mut cq := LinuxIoUringCq.init(fd, p, sq)!
	defer {
		if !ok {
			cq.deinit()
		}
	}

	// Check that our starting state is as we expect.
	assert unsafe { *sq.head } == 0
	assert unsafe { *sq.tail } == 0
	assert sq.mask == p.sq_entries - 1
	// Allow flags.* to be non-zero, since the kernel may set IORING_SQ_NEED_WAKEUP at any time.
	assert unsafe { *sq.dropped } == 0
	assert sq.array_len == usize(p.sq_entries)
	assert sq.sqes_len == usize(p.sq_entries)
	assert sq.sqe_head == 0
	assert sq.sqe_tail == 0

	assert unsafe { *cq.head } == 0
	assert unsafe { *cq.tail } == 0
	assert cq.mask == p.cq_entries - 1
	assert unsafe { *cq.overflow } == 0
	assert cq.cqes_len == usize(p.cq_entries)

	ok = true
	return LinuxIoUring{
		fd: fd
		sq: sq
		cq: cq
		flags: p.flags
		features: p.features
	}
}

pub fn (mut self LinuxIoUring) deinit() {
	assert self.fd >= 0
	// The mmaps depend on the fd, so the order of these calls is important:
	self.cq.deinit()
	self.sq.deinit()
	posix_close(self.fd)
	self.fd = -1
}

// Returns a pointer to a vacant SQE, or an error if the submission queue is full.
// We follow the implementation (and atomics) of liburing's `io_uring_get_sqe()` exactly.
// However, instead of a null we return an error to force safe handling.
// Any situation where the submission queue is full tends more towards a control flow error,
// and the null return in liburing is more a C idiom than anything else, for lack of a better
// alternative. In Zig, we have first-class error handling... so let's use it.
// Matches the implementation of io_uring_get_sqe() in liburing.
pub fn (mut self LinuxIoUring) get_sqe() !&IoUringSqe {
	head := io_uring_atomic_load_u32(self.sq.head, .acquire)
	// Remember that these head and tail offsets wrap around every four billion operations.
	// We must therefore use wrapping addition and subtraction to avoid a runtime crash.
	next := self.sq.sqe_tail + 1
	if usize(next - head) > self.sq.sqes_len {
		return new_error(.submission_queue_full)
	}
	sqe := unsafe { &self.sq.sqes[self.sq.sqe_tail & self.sq.mask] }
	self.sq.sqe_tail = next
	return sqe
}

// Submits the SQEs acquired via get_sqe() to the kernel. You can call this once after you have
// called get_sqe() multiple times to setup multiple I/O requests.
// Returns the number of SQEs submitted, if not used alongside IORING_SETUP_SQPOLL.
// If the io_uring instance is uses IORING_SETUP_SQPOLL, the value returned on success is not
// guaranteed to match the amount of actually submitted sqes during this call. A value higher
// or lower, including 0, may be returned.
// Matches the implementation of io_uring_submit() in liburing.
pub fn (mut self LinuxIoUring) submit() !u32 {
	return self.submit_and_wait(0)!
}

// Like submit(), but allows waiting for events as well.
// Returns the number of SQEs submitted.
// Matches the implementation of io_uring_submit_and_wait() in liburing.
pub fn (mut self LinuxIoUring) submit_and_wait(wait_nr u32) !u32 {
	submitted := self.flush_sq()
	mut flags := u32(0)
	if self.sq_ring_needs_enter(&flags) || wait_nr > 0 {
		if wait_nr > 0 || (self.flags & ioring_setup_iopoll) != 0 {
			flags |= ioring_enter_getevents
		}
		return self.enter(submitted, wait_nr, flags)!
	}
	return submitted
}

// Tell the kernel we have submitted SQEs and/or want to wait for CQEs.
// Returns the number of SQEs submitted.
pub fn (mut self LinuxIoUring) enter(to_submit u32, min_complete u32, flags u32) !u32 {
	assert self.fd >= 0
	res := linux_io_uring_enter(self.fd, to_submit, min_complete, flags, unsafe { nil })
	match linux_errno(res) {
		0 {}
		// The kernel was unable to allocate memory or ran out of resources for the request.
		// The application should wait for some completions and try again:
		C.EAGAIN {
			return new_error(.system_resources)
		}
		// The SQE `fd` is invalid, or IOSQE_FIXED_FILE was set but no files were registered:
		C.EBADF {
			return new_error(.file_descriptor_invalid)
		}
		// The file descriptor is valid, but the ring is not in the right state.
		// See io_uring_register(2) for how to enable the ring.
		C.EBADFD {
			return new_error(.file_descriptor_in_bad_state)
		}
		// The application attempted to overcommit the number of requests it can have pending.
		// The application should wait for some completions and try again:
		C.EBUSY {
			return new_error(.completion_queue_overcommitted)
		}
		// The SQE is invalid, or valid but the ring was setup with IORING_SETUP_IOPOLL:
		C.EINVAL {
			return new_error(.submission_queue_entry_invalid)
		}
		// The buffer is outside the process' accessible address space, or IORING_OP_READ_FIXED
		// or IORING_OP_WRITE_FIXED was specified but no buffers were registered, or the range
		// described by `addr` and `len` is not within the buffer registered at `buf_index`:
		C.EFAULT {
			return new_error(.buffer_invalid)
		}
		C.ENXIO {
			return new_error(.ring_shutting_down)
		}
		// The kernel believes our `self.fd` does not refer to an io_uring instance,
		// or the opcode is valid but not supported by this kernel (more likely):
		C.EOPNOTSUPP {
			return new_error(.opcode_not_supported)
		}
		// The operation was interrupted by a delivery of a signal before it could complete.
		// This can happen while waiting for events with IORING_ENTER_GETEVENTS:
		C.EINTR {
			return new_error(.signal_interrupt)
		}
		else {
			return unexpected_errno(linux_errno(res))
		}
	}
	return u32(res)
}

// Sync internal state with kernel ring state on the SQ side.
// Returns the number of all pending events in the SQ ring, for the shared ring.
// This return value includes previously flushed SQEs, as per liburing.
// The rationale is to suggest that an io_uring_enter() call is needed rather than not.
// Matches the implementation of __io_uring_flush_sq() in liburing.
pub fn (mut self LinuxIoUring) flush_sq() u32 {
	if self.sq.sqe_head != self.sq.sqe_tail {
		// Fill in SQEs that we have queued up, adding them to the kernel ring.
		to_submit := self.sq.sqe_tail - self.sq.sqe_head
		mut tail := unsafe { *self.sq.tail }
		mut i := usize(0)
		for i < usize(to_submit) {
			unsafe {
				self.sq.array[tail & self.sq.mask] = self.sq.sqe_head & self.sq.mask
			}
			tail += 1
			self.sq.sqe_head += 1
			i += 1
		}
		// Ensure that the kernel can actually see the SQE updates when it sees the tail update.
		io_uring_atomic_store_u32(self.sq.tail, tail, .release)
	}
	return self.sq_ready()
}

// Returns true if we are not using an SQ thread (thus nobody submits but us),
// or if IORING_SQ_NEED_WAKEUP is set and the SQ thread must be explicitly awakened.
// For the latter case, we set the SQ thread wakeup flag.
// Matches the implementation of sq_ring_needs_enter() in liburing.
pub fn (mut self LinuxIoUring) sq_ring_needs_enter(flags &u32) bool {
	assert unsafe { *flags } == 0
	if (self.flags & ioring_setup_sqpoll) == 0 {
		return true
	}
	if (io_uring_atomic_load_u32(self.sq.flags, .monotonic) & ioring_sq_need_wakeup) != 0 {
		unsafe {
			*flags |= ioring_enter_sq_wakeup
		}
		return true
	}
	return false
}

// Returns the number of flushed and unflushed SQEs pending in the submission queue.
// In other words, this is the number of SQEs in the submission queue, i.e. its length.
// These are SQEs that the kernel is yet to consume.
// Matches the implementation of io_uring_sq_ready in liburing.
pub fn (mut self LinuxIoUring) sq_ready() u32 {
	// Always use the shared ring state (i.e. head and not sqe_head) to avoid going out of sync,
	// see https://github.com/axboe/liburing/issues/92.
	return self.sq.sqe_tail - io_uring_atomic_load_u32(self.sq.head, .acquire)
}

// Returns the number of CQEs in the completion queue, i.e. its length.
// These are CQEs that the application is yet to consume.
// Matches the implementation of io_uring_cq_ready in liburing.
pub fn (mut self LinuxIoUring) cq_ready() u32 {
	return io_uring_atomic_load_u32(self.cq.tail, .acquire) - unsafe { *self.cq.head }
}

// Copies as many CQEs as are ready, and that can fit into the destination `cqes` slice.
// If none are available, enters into the kernel to wait for at most `wait_nr` CQEs.
// Returns the number of CQEs copied, advancing the CQ ring.
// Provides all the wait/peek methods found in liburing, but with batching and a single method.
// The rationale for copying CQEs rather than copying pointers is that pointers are 8 bytes
// whereas CQEs are not much more at only 16 bytes, and this provides a safer faster interface.
// Safer, because you no longer need to call cqe_seen(), avoiding idempotency bugs.
// Faster, because we can now amortize the atomic store release to `cq.head` across the batch.
// See https://github.com/axboe/liburing/issues/103#issuecomment-686665007.
// Matches the implementation of io_uring_peek_batch_cqe() in liburing, but supports waiting.
//
// The `cqes` slice is passed as a pointer and a length.
pub fn (mut self LinuxIoUring) copy_cqes(cqes &IoUringCqe, cqes_len usize, wait_nr u32) !u32 {
	count := self.copy_cqes_ready(cqes, cqes_len)
	if count > 0 {
		return count
	}
	if self.cq_ring_needs_flush() || wait_nr > 0 {
		_ = self.enter(0, wait_nr, ioring_enter_getevents)!
		return self.copy_cqes_ready(cqes, cqes_len)
	}
	return 0
}

fn (mut self LinuxIoUring) copy_cqes_ready(cqes &IoUringCqe, cqes_len usize) u32 {
	ready := self.cq_ready()
	count := u32(usize_min(cqes_len, usize(ready)))
	head := unsafe { *self.cq.head } & self.cq.mask

	// before wrapping
	n := usize_min(self.cq.cqes_len - usize(head), usize(count))
	unsafe {
		vmemcpy(cqes, &self.cq.cqes[head], isize(n * sizeof(IoUringCqe)))
	}

	if usize(count) > n {
		// wrap self.cq.cqes
		w := usize(count) - n
		unsafe {
			vmemcpy(&cqes[n], &self.cq.cqes[0], isize(w * sizeof(IoUringCqe)))
		}
	}

	self.cq_advance(count)
	return count
}

// Matches the implementation of cq_ring_needs_flush() in liburing.
pub fn (mut self LinuxIoUring) cq_ring_needs_flush() bool {
	return (io_uring_atomic_load_u32(self.sq.flags, .monotonic) & ioring_sq_cq_overflow) != 0
}

// For advanced use cases only that implement custom completion queue methods.
// Matches the implementation of cq_advance() in liburing.
pub fn (mut self LinuxIoUring) cq_advance(count u32) {
	if count > 0 {
		// Ensure the kernel only sees the new head value after the CQEs have been read.
		io_uring_atomic_store_u32(self.cq.head, unsafe { *self.cq.head } + count, .release)
	}
}

pub struct LinuxIoUringSq {
pub mut:
	head      &u32 = unsafe { nil }
	tail      &u32 = unsafe { nil }
	mask      u32
	flags     &u32 = unsafe { nil }
	dropped   &u32 = unsafe { nil }
	array     &u32 = unsafe { nil }
	array_len usize
	sqes      &IoUringSqe = unsafe { nil }
	sqes_len  usize
	mmap      []u8
	mmap_sqes []u8

	// We use `sqe_head` and `sqe_tail` in the same way as liburing:
	// We increment `sqe_tail` (but not `tail`) for each call to `get_sqe()`.
	// We then set `tail` to `sqe_tail` once, only when these events are actually submitted.
	// This allows us to amortize the cost of the @atomicStore to `tail` across multiple SQEs.
	sqe_head u32
	sqe_tail u32
}

// io_uring_mmap_ptr returns a pointer to the given byte offset of a ring mmap.
@[inline]
fn io_uring_mmap_ptr(mmap []u8, offset u32) voidptr {
	return unsafe { &u8(mmap.data) + offset }
}

pub fn LinuxIoUringSq.init(fd int, p IoUringParams) !LinuxIoUringSq {
	assert fd >= 0
	assert (p.features & ioring_feat_single_mmap) != 0
	size := u32_max(p.sq_off.array + p.sq_entries * u32(sizeof(u32)), p.cq_off.cqes +
		p.cq_entries * u32(sizeof(IoUringCqe)))
	mmap := posix_mmap(unsafe { nil }, usize(size), u32(int(C.PROT_READ)) | u32(int(C.PROT_WRITE)),
		u32(int(C.MAP_SHARED)) | u32(int(C.MAP_POPULATE)), fd, ioring_off_sq_ring)!
	// errdefer posix.munmap(mmap)
	mut ok := false
	defer {
		if !ok {
			posix_munmap(mmap)
		}
	}
	assert usize(mmap.len) == usize(size)

	// The motivation for the `sqes` and `array` indirection is to make it possible for the
	// application to preallocate static linux.io_uring_sqe entries and then replay them when needed.
	size_sqes := p.sq_entries * u32(sizeof(IoUringSqe))
	mmap_sqes := posix_mmap(unsafe { nil }, usize(size_sqes), u32(int(C.PROT_READ)) | u32(int(C.PROT_WRITE)),
		u32(int(C.MAP_SHARED)) | u32(int(C.MAP_POPULATE)), fd, ioring_off_sqes)!
	// errdefer posix.munmap(mmap_sqes)
	defer {
		if !ok {
			posix_munmap(mmap_sqes)
		}
	}
	assert usize(mmap_sqes.len) == usize(size_sqes)

	array := unsafe { &u32(io_uring_mmap_ptr(mmap, p.sq_off.array)) }
	sqes := unsafe { &IoUringSqe(mmap_sqes.data) }
	// We expect the kernel copies p.sq_entries to the u32 pointed to by p.sq_off.ring_entries,
	// see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L7843-L7844.
	assert p.sq_entries == unsafe { *(&u32(io_uring_mmap_ptr(mmap, p.sq_off.ring_entries))) }
	ok = true
	return LinuxIoUringSq{
		head: unsafe { &u32(io_uring_mmap_ptr(mmap, p.sq_off.head)) }
		tail: unsafe { &u32(io_uring_mmap_ptr(mmap, p.sq_off.tail)) }
		mask: unsafe { *(&u32(io_uring_mmap_ptr(mmap, p.sq_off.ring_mask))) }
		flags: unsafe { &u32(io_uring_mmap_ptr(mmap, p.sq_off.flags)) }
		dropped: unsafe { &u32(io_uring_mmap_ptr(mmap, p.sq_off.dropped)) }
		array: array
		array_len: usize(p.sq_entries)
		sqes: sqes
		sqes_len: usize(p.sq_entries)
		mmap: mmap
		mmap_sqes: mmap_sqes
	}
}

pub fn (mut self LinuxIoUringSq) deinit() {
	posix_munmap(self.mmap_sqes)
	posix_munmap(self.mmap)
}

pub struct LinuxIoUringCq {
pub mut:
	head     &u32 = unsafe { nil }
	tail     &u32 = unsafe { nil }
	mask     u32
	overflow &u32 = unsafe { nil }
	cqes     &IoUringCqe = unsafe { nil }
	cqes_len usize
}

pub fn LinuxIoUringCq.init(fd int, p IoUringParams, sq LinuxIoUringSq) !LinuxIoUringCq {
	assert fd >= 0
	assert (p.features & ioring_feat_single_mmap) != 0
	mmap := sq.mmap
	cqes := unsafe { &IoUringCqe(io_uring_mmap_ptr(mmap, p.cq_off.cqes)) }
	assert p.cq_entries == unsafe { *(&u32(io_uring_mmap_ptr(mmap, p.cq_off.ring_entries))) }
	return LinuxIoUringCq{
		head: unsafe { &u32(io_uring_mmap_ptr(mmap, p.cq_off.head)) }
		tail: unsafe { &u32(io_uring_mmap_ptr(mmap, p.cq_off.tail)) }
		mask: unsafe { *(&u32(io_uring_mmap_ptr(mmap, p.cq_off.ring_mask))) }
		overflow: unsafe { &u32(io_uring_mmap_ptr(mmap, p.cq_off.overflow)) }
		cqes: cqes
		cqes_len: usize(p.cq_entries)
	}
}

pub fn (mut self LinuxIoUringCq) deinit() {
	_ = self
	// A no-op since we now share the mmap with the submission queue.
	// Here for symmetry with the submission queue, and for any future feature support.
}

@[inline]
fn u32_max(a u32, b u32) u32 {
	return if a > b { a } else { b }
}
