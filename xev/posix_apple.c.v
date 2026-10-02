module xev

$if macos || ios {
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

	// Translation of std.c.sockaddr and its in/in6/un variants for Darwin. Zig
	// declares these extern structs itself instead of importing the C headers.
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

	// UNIX domain socket
	pub struct SockAddrUn {
	pub mut:
		len    u8 = u8(sizeof(SockAddrUn))
		family u8 = u8(int(C.AF_UNIX))
		path   [104]u8
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
}
