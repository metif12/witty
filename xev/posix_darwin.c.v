module xev

// Zig supplies SOCK.CLOEXEC and SOCK.NONBLOCK shims on Darwin, which does not
// support them. This numerical value is not ABI-stable. It need only not
// conflict with any other `SOCK` bits.
pub const sock_cloexec = u32(1) << 15
pub const sock_nonblock = u32(1) << 16

// Darwin has no accept4 (std.posix.have_accept4 is false).
@[inline]
fn posix_accept_syscall(sock int, addr voidptr, addr_size &u32, flags u32) int {
	_ = flags
	return C.accept(sock, addr, addr_size)
}

pub struct C.sockaddr_in {
mut:
	sin_len    u8
	sin_family u8
	sin_port   u16
	sin_addr   C.in_addr
}

// Darwin socket address structures start with their length.
@[inline]
fn sockaddr_in_init_len(mut sa C.sockaddr_in) {
	sa.sin_len = u8(sizeof(C.sockaddr_in))
}

// Translation of std.c.W.EXITSTATUS for Darwin.
fn wait_exitstatus(x u32) u8 {
	v := x >> 8
	assert v <= 0xff // @intCast safety check
	return u8(v)
}

// Translation of std.c.W.IFEXITED for Darwin.
fn wait_ifexited(x u32) bool {
	return x & 0o177 == 0
}

// Translation of std.posix.kqueue.
pub fn posix_kqueue() !int {
	rc := C.kqueue()
	match posix_errno(rc) {
		0 { return rc }
		C.EMFILE { return new_error(.process_fd_quota_exceeded) }
		C.ENFILE { return new_error(.system_fd_quota_exceeded) }
		else { return unexpected_errno(posix_errno(rc)) }
	}
}
