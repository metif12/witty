module xev

// std.c socket ABI used by the WASI poll backend's libc wrappers.
pub struct SockAddr {
pub mut:
	family u16
	data   [14]u8
}

pub struct SockAddrIn {
pub mut:
	family u16 = 2
	port   u16
	addr   u32
	zero   [8]u8
}

pub struct SockAddrIn6 {
pub mut:
	family   u16 = 10
	port     u16
	flowinfo u32
	addr     [16]u8
	scope_id u32
}

pub struct SockAddrUn {
pub mut:
	family u16 = 1
	path   [108]u8
}

// Flags are supplied only to the generic POSIX helpers; WASI's low-level
// backend uses __wasi_sock_accept directly with fdflags=0.
pub const sock_cloexec = u32(int(C.SOCK_CLOEXEC))
pub const sock_nonblock = u32(int(C.SOCK_NONBLOCK))

fn C.accept4(sock int, addr voidptr, addr_size &u32, flags int) int

fn posix_accept_syscall(sock int, addr voidptr, addr_size &u32, flags u32) int {
	return C.accept4(sock, addr, addr_size, int(flags))
}
