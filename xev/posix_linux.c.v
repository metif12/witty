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
