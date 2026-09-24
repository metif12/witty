module xev

fn C.accept4(sockfd int, addr voidptr, addrlen &u32, flags int) int

pub const sock_cloexec = u32(int(C.SOCK_CLOEXEC))
pub const sock_nonblock = u32(int(C.SOCK_NONBLOCK))

@[inline]
fn posix_accept_syscall(sock int, addr voidptr, addr_size &u32, flags u32) int {
	return C.accept4(sock, addr, addr_size, int(flags))
}

// Translation of std.os.linux.sockaddr and its in/in6/un variants. Zig
// declares these extern structs itself instead of importing the C headers.
pub struct SockAddr {
pub mut:
	family u16
	data   [14]u8
}

// IPv4 socket address
pub struct SockAddrIn {
pub mut:
	family u16 = u16(int(C.AF_INET))
	port   u16
	addr   u32
	zero   [8]u8
}

// IPv6 socket address
pub struct SockAddrIn6 {
pub mut:
	family   u16 = u16(int(C.AF_INET6))
	port     u16
	flowinfo u32
	addr     [16]u8
	scope_id u32
}

// UNIX domain socket address
pub struct SockAddrUn {
pub mut:
	family u16 = u16(int(C.AF_UNIX))
	path   [108]u8
}

// Translations of the Zig 0.15.2 std.posix epoll and eventfd wrappers, and of
// the raw std.os.linux system calls, that libxev's epoll backend and watchers
// use.

#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/syscall.h>
#include <sys/wait.h>

@[typedef]
pub union C.epoll_data_t {
pub mut:
	ptr voidptr
	fd  int
	u32 u32
	u64 u64
}

pub struct C.epoll_event {
pub mut:
	events u32
	data   C.epoll_data_t
}

fn C.epoll_create1(flags int) int
fn C.epoll_ctl(epfd int, op int, fd int, event &C.epoll_event) int
fn C.epoll_wait(epfd int, events &C.epoll_event, maxevents int, timeout int) int
fn C.eventfd(initval u32, flags int) int

// Translation of std.posix.epoll_create1.
pub fn posix_epoll_create1(flags u32) !int {
	rc := C.epoll_create1(int(flags))
	match posix_errno(rc) {
		0 { return rc }
		C.EINVAL { posix_unreachable() }
		C.EMFILE { return new_error(.process_fd_quota_exceeded) }
		C.ENFILE { return new_error(.system_fd_quota_exceeded) }
		C.ENOMEM { return new_error(.system_resources) }
		else { return unexpected_errno(posix_errno(rc)) }
	}
}

// Translation of std.posix.epoll_ctl. A null event is passed as nil.
pub fn posix_epoll_ctl(epfd int, op u32, fd int, event &C.epoll_event) ! {
	rc := C.epoll_ctl(epfd, int(op), fd, event)
	match posix_errno(rc) {
		0 { return }
		C.EBADF { posix_unreachable() } // always a race condition if this happens
		C.EEXIST { return new_error(.file_descriptor_already_present_in_set) }
		C.EINVAL { posix_unreachable() }
		C.ELOOP { return new_error(.operation_causes_circular_loop) }
		C.ENOENT { return new_error(.file_descriptor_not_registered) }
		C.ENOMEM { return new_error(.system_resources) }
		C.ENOSPC { return new_error(.user_resource_limit_reached) }
		C.EPERM { return new_error(.file_descriptor_incompatible_with_epoll) }
		else { return unexpected_errno(posix_errno(rc)) }
	}
}

// Translation of std.posix.epoll_wait. The events slice is passed as a
// pointer and a length.
// Waits for an I/O event on an epoll file descriptor.
// Returns the number of file descriptors ready for the requested I/O,
// or zero if no file descriptor became ready during the requested timeout milliseconds.
pub fn posix_epoll_wait(epfd int, events &C.epoll_event, events_len usize, timeout i32) usize {
	for {
		// TODO get rid of the @intCast
		rc := C.epoll_wait(epfd, events, int(events_len), timeout)
		match posix_errno(rc) {
			0 { return usize(rc) }
			C.EINTR { continue }
			C.EBADF { posix_unreachable() }
			C.EFAULT { posix_unreachable() }
			C.EINVAL { posix_unreachable() }
			else { posix_unreachable() }
		}
	}
	return 0
}

// Translation of std.posix.eventfd.
pub fn posix_eventfd(initval u32, flags u32) !int {
	rc := C.eventfd(initval, int(flags))
	match posix_errno(rc) {
		0 { return rc }
		C.EINVAL { posix_unreachable() } // invalid parameters
		C.EMFILE { return new_error(.process_fd_quota_exceeded) }
		C.ENFILE { return new_error(.system_fd_quota_exceeded) }
		C.ENODEV { return new_error(.system_resources) }
		C.ENOMEM { return new_error(.system_resources) }
		else { return unexpected_errno(posix_errno(rc)) }
	}
}

// Translation of std.posix.errno (std.os.linux.E.init) for the result of a
// raw std.os.linux system call: the kernel reports failure as -errno. Zig's
// libc branch of posix.errno only recognizes a `-1` result, which such a
// usize result never compares equal to, so the raw branch is used here.
fn linux_errno(rc usize) int {
	signed := isize(rc)
	return if signed > -4096 && signed < 0 { int(-signed) } else { 0 }
}

// std.os.linux issues system calls directly and returns the kernel result.
// glibc's syscall(2) reports failure as -1 with errno set instead, so the
// kernel's -errno result is restored from errno.
fn linux_syscall_result(rc i64) usize {
	if rc == -1 {
		return usize(-i64(C.errno))
	}
	return usize(rc)
}

// Translation of std.os.linux.pidfd_open.
pub fn linux_pidfd_open(pid int, flags u32) usize {
	rc := unsafe { C.syscall(C.SYS_pidfd_open, voidptr(usize(isize(pid))), voidptr(usize(flags))) }
	return linux_syscall_result(rc)
}

// Translation of std.os.linux.P, the id types of waitid.
pub enum LinuxP as u32 {
	all   = 0
	pid   = 1
	pgid  = 2
	pidfd = 3
}

// std.os.linux.siginfo_t. `si_status` is the libc accessor of the field Zig
// names `fields.common.second.sigchld.status`.
@[typedef]
pub struct C.siginfo_t {
pub mut:
	si_status int
}

// Translation of std.os.linux.waitid.
pub fn linux_waitid(id_type LinuxP, id int, infop &C.siginfo_t, flags u32) usize {
	rc := unsafe {
		C.syscall(C.SYS_waitid, voidptr(usize(u32(id_type))), voidptr(usize(isize(id))), voidptr(infop),
			voidptr(usize(flags)), nil)
	}
	return linux_syscall_result(rc)
}

// Translation of std.os.linux.recvmsg (the non-x86 branch, which issues the
// recvmsg system call directly).
pub fn linux_recvmsg(fd int, msg &C.msghdr, flags u32) usize {
	rc := unsafe { C.syscall(C.SYS_recvmsg, voidptr(usize(isize(fd))), voidptr(msg), voidptr(usize(flags))) }
	return linux_syscall_result(rc)
}

// Translation of std.os.linux.timerfd_clockid_t.
pub enum LinuxTimerfdClockid as u32 {
	realtime       = 0
	monotonic      = 1
	boottime       = 7
	realtime_alarm = 8
	boottime_alarm = 9
}

// Translation of std.os.linux.TFD, a packed struct(u32) of timerfd_create
// flags. This is the layout of every architecture except sparc64 and mips.
pub struct LinuxTfd {
pub mut:
	value u32
}

pub fn (f LinuxTfd) nonblock() bool {
	return f.value & (u32(1) << 11) != 0
}

pub fn (mut f LinuxTfd) set_nonblock(v bool) {
	if v {
		f.value |= u32(1) << 11
	} else {
		f.value &= ~(u32(1) << 11)
	}
}

pub fn (f LinuxTfd) cloexec() bool {
	return f.value & (u32(1) << 19) != 0
}

pub fn (mut f LinuxTfd) set_cloexec(v bool) {
	if v {
		f.value |= u32(1) << 19
	} else {
		f.value &= ~(u32(1) << 19)
	}
}

// Translation of std.os.linux.TFD.TIMER, a packed struct(u32) of
// timerfd_settime flags.
pub struct LinuxTfdTimer {
pub mut:
	value u32
}

pub fn (f LinuxTfdTimer) abstime() bool {
	return f.value & 0b01 != 0
}

pub fn (mut f LinuxTfdTimer) set_abstime(v bool) {
	if v {
		f.value |= 0b01
	} else {
		f.value &= ~u32(0b01)
	}
}

pub fn (f LinuxTfdTimer) cancel_on_set() bool {
	return f.value & 0b10 != 0
}

pub fn (mut f LinuxTfdTimer) set_cancel_on_set(v bool) {
	if v {
		f.value |= 0b10
	} else {
		f.value &= ~u32(0b10)
	}
}

// std.os.linux.itimerspec. Callers pass pointers to layout-compatible
// structures, so its fields are not declared.
pub struct C.itimerspec {}

// Translation of std.os.linux.timerfd_create.
pub fn linux_timerfd_create(clockid LinuxTimerfdClockid, flags LinuxTfd) usize {
	rc := unsafe {
		C.syscall(C.SYS_timerfd_create, voidptr(usize(u32(clockid))), voidptr(usize(flags.value)))
	}
	return linux_syscall_result(rc)
}

// Translation of std.os.linux.timerfd_gettime. Witty's Linux targets all have
// the timerfd_gettime system call (not only timerfd_gettime64).
pub fn linux_timerfd_gettime(fd i32, curr_value &C.itimerspec) usize {
	rc := unsafe { C.syscall(C.SYS_timerfd_gettime, voidptr(usize(isize(fd))), voidptr(curr_value)) }
	return linux_syscall_result(rc)
}

// Translation of std.os.linux.timerfd_settime. Witty's Linux targets all have
// the timerfd_settime system call (not only timerfd_settime64). A null
// old_value is passed as nil.
pub fn linux_timerfd_settime(fd i32, flags LinuxTfdTimer, new_value &C.itimerspec, old_value &C.itimerspec) usize {
	rc := unsafe {
		C.syscall(C.SYS_timerfd_settime, voidptr(usize(isize(fd))), voidptr(usize(flags.value)),
			voidptr(new_value), voidptr(old_value))
	}
	return linux_syscall_result(rc)
}

// Translations of the Zig 0.15.2 std.posix mmap wrappers that libxev's
// io_uring backend uses.

#include <sys/mman.h>

// Translation of std.posix.mmap. libc is linked, so the libc branch
// (MAP_FAILED and errno) is used. The returned slice aliases the mapping.
pub fn posix_mmap(ptr voidptr, length usize, prot u32, flags u32, fd int, offset u64) ![]u8 {
	rc := unsafe { C.mmap(ptr, length, int(prot), int(flags), fd, isize(offset)) }
	if rc != C.MAP_FAILED {
		return unsafe { (&u8(rc)).vbytes(int(length)) }
	}
	err := C.errno
	match err {
		0 { posix_unreachable() }
		C.ETXTBSY { return new_error(.access_denied) }
		C.EACCES { return new_error(.access_denied) }
		C.EPERM { return new_error(.permission_denied) }
		C.EAGAIN { return new_error(.locked_memory_limit_exceeded) }
		C.EBADF { posix_unreachable() } // Always a race condition.
		C.EOVERFLOW { posix_unreachable() } // The number of pages used for length + offset would overflow.
		C.ENODEV { return new_error(.memory_mapping_not_supported) }
		C.EINVAL { posix_unreachable() } // Invalid parameters to mmap()
		C.EMFILE { return new_error(.process_fd_quota_exceeded) }
		C.ENFILE { return new_error(.system_fd_quota_exceeded) }
		C.ENOMEM { return new_error(.out_of_memory) }
		C.EEXIST { return new_error(.mapping_already_exists) }
		else { return unexpected_errno(err) }
	}
}

// Translation of std.posix.munmap.
// Deletes the mappings for the specified address range, causing
// further references to addresses within the range to generate invalid memory references.
// Note that while POSIX allows unmapping a region in the middle of an existing mapping,
// Zig's munmap function does not, for two reasons:
// * It violates the Zig principle that resource deallocation must succeed.
// * The Windows function, VirtualFree, has this restriction.
pub fn posix_munmap(memory []u8) {
	match posix_errno(unsafe { C.munmap(memory.data, usize(memory.len)) }) {
		0 { return }
		C.EINVAL { posix_unreachable() } // Invalid parameters.
		C.ENOMEM { posix_unreachable() } // Attempted to unmap a region in the middle of an existing mapping.
		else { posix_unreachable() }
	}
}
