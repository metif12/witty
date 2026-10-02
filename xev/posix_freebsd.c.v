module xev

#include <sys/event.h>

// Zig 0.15.2 std.c FreeBSD ABI. BSD sockets have the sa_len byte just as
// Darwin sockets do; their AF_UNIX path and native socket flags differ.
pub const sock_cloexec = u32(int(C.SOCK_CLOEXEC))
pub const sock_nonblock = u32(int(C.SOCK_NONBLOCK))

fn C.accept4(sock int, addr voidptr, addr_size &u32, flags int) int

fn posix_accept_syscall(sock int, addr voidptr, addr_size &u32, flags u32) int {
	return C.accept4(sock, addr, addr_size, int(flags))
}

pub struct SockAddr {
pub mut:
	len    u8
	family u8
	data   [14]u8
}

pub struct SockAddrIn {
pub mut:
	len    u8 = u8(sizeof(SockAddrIn))
	family u8 = u8(int(C.AF_INET))
	port   u16
	addr   u32
	zero   [8]u8
}

pub struct SockAddrIn6 {
pub mut:
	len      u8 = u8(sizeof(SockAddrIn6))
	family   u8 = u8(int(C.AF_INET6))
	port     u16
	flowinfo u32
	addr     [16]u8
	scope_id u32
}

pub struct SockAddrUn {
pub mut:
	len    u8 = u8(sizeof(SockAddrUn))
	family u8 = u8(int(C.AF_UNIX))
	path   [104]u8
}

fn wait_exitstatus(status u32) u8 {
	return u8((status & 0xff00) >> 8)
}

fn wait_ifexited(status u32) bool {
	return status & 0x7f == 0
}

pub fn posix_kqueue() !int {
	rc := C.kqueue()
	match posix_errno(rc) {
		0 { return rc }
		C.EMFILE { return new_error(.process_fd_quota_exceeded) }
		C.ENFILE { return new_error(.system_fd_quota_exceeded) }
		else { return unexpected_errno(posix_errno(rc)) }
	}
}
