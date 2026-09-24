module xev

// Minimal translation of Zig 0.15.2 std.net.Address as libxev uses it: an
// extern union over the platform socket address structures, constructed with
// initIp4 and passed to connect/sendto with getOsSockLen. The union storage is
// the platform sockaddr_storage.

#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/un.h>

pub struct C.sockaddr_storage {}

pub struct C.sockaddr {
mut:
	sa_family u16
}

pub struct C.in_addr {
mut:
	s_addr u32
}

pub struct C.sockaddr_in6 {}

pub struct C.sockaddr_un {}

fn C.htons(host u16) u16

pub struct NetAddress {
pub mut:
	storage C.sockaddr_storage
}

// Translation of std.net.Address.initIp4 and Ip4Address.init.
pub fn NetAddress.init_ip4(addr [4]u8, port u16) NetAddress {
	mut result := NetAddress{}
	unsafe {
		mut sa := &C.sockaddr_in(&result.storage)
		sockaddr_in_init_len(mut sa)
		sa.sin_family = C.AF_INET
		sa.sin_port = C.htons(port)
		sa.sin_addr.s_addr = *(&u32(&addr[0]))
	}
	return result
}

// any returns a pointer to the generic sockaddr view of the union.
pub fn (self &NetAddress) any() voidptr {
	return voidptr(&self.storage)
}

// Translation of std.net.Address.getOsSockLen.
pub fn (self &NetAddress) get_os_sock_len() u32 {
	family := unsafe { int((&C.sockaddr(&self.storage)).sa_family) }
	match family {
		C.AF_INET {
			return u32(sizeof(C.sockaddr_in))
		}
		C.AF_INET6 {
			return u32(sizeof(C.sockaddr_in6))
		}
		C.AF_UNIX {
			// Using the full length of the structure here is more portable than returning
			// the number of bytes actually used by the currently stored path.
			// This also is correct regardless if we are passing a socket address to the kernel
			// (e.g. in bind, connect, sendto) since we ensure the path is 0 terminated in
			// initUnix() or if we are receiving a socket address from the kernel and must
			// provide the full buffer size (e.g. getsockname, getpeername, recvfrom, accept).
			return u32(sizeof(C.sockaddr_un))
		}
		else {
			posix_unreachable()
		}
	}
}
