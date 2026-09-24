module xev

fn C.accept4(sockfd int, addr voidptr, addrlen &u32, flags int) int

pub const sock_cloexec = u32(int(C.SOCK_CLOEXEC))
pub const sock_nonblock = u32(int(C.SOCK_NONBLOCK))

@[inline]
fn posix_accept_syscall(sock int, addr voidptr, addr_size &u32, flags u32) int {
	return C.accept4(sock, addr, addr_size, int(flags))
}

pub struct C.sockaddr_in {
mut:
	sin_family u16
	sin_port   u16
	sin_addr   C.in_addr
}

@[inline]
fn sockaddr_in_init_len(mut sa C.sockaddr_in) {
	_ = sa
}
