module xev

// Minimal translation of Zig 0.15.2 std.net.Address as libxev uses it: the
// extern union over the platform socket address structures, constructed with
// initIp4 and passed to connect/sendto with getOsSockLen. The sockaddr
// structures are translated per platform in posix_darwin.c.v/posix_linux.c.v.
// `any` and `in` are V type/keyword names, so those fields carry a trailing
// underscore; `any()` returns the pointer libxev takes as `&addr.any`.

$if windows {
	#include <winsock2.h>
} $else {
	#include <netinet/in.h>
	#include <sys/socket.h>
}

fn C.htons(host u16) u16

pub union NetAddress {
pub mut:
	any_ SockAddr
	in_  Ip4Address
	in6  Ip6Address
	un   SockAddrUn
}

// Translation of std.net.Address.initIp4.
pub fn NetAddress.init_ip4(addr [4]u8, port u16) NetAddress {
	return NetAddress{
		in_: Ip4Address.init(addr, port)
	}
}

// any returns `&address.any`, the generic sockaddr view of the union.
pub fn (self &NetAddress) any() voidptr {
	return unsafe { voidptr(&self.any_) }
}

// Translation of std.net.Address.getOsSockLen.
pub fn (self &NetAddress) get_os_sock_len() u32 {
	match int(unsafe { self.any_.family }) {
		C.AF_INET {
			return unsafe { self.in_.get_os_sock_len() }
		}
		C.AF_INET6 {
			return unsafe { self.in6.get_os_sock_len() }
		}
		C.AF_UNIX {
			// Using the full length of the structure here is more portable than returning
			// the number of bytes actually used by the currently stored path.
			// This also is correct regardless if we are passing a socket address to the kernel
			// (e.g. in bind, connect, sendto) since we ensure the path is 0 terminated in
			// initUnix() or if we are receiving a socket address from the kernel and must
			// provide the full buffer size (e.g. getsockname, getpeername, recvfrom, accept).
			//
			// To access the path, std.mem.sliceTo(&address.un.path, 0) should be used.
			return u32(sizeof(SockAddrUn))
		}
		else {
			posix_unreachable()
		}
	}
}

// Translation of std.net.Ip4Address.
pub struct Ip4Address {
pub mut:
	sa SockAddrIn
}

pub fn Ip4Address.init(addr [4]u8, port u16) Ip4Address {
	return Ip4Address{
		sa: SockAddrIn{
			port: C.htons(port)
			addr: unsafe { *(&u32(&addr[0])) }
		}
	}
}

pub fn (self &Ip4Address) get_os_sock_len() u32 {
	return u32(sizeof(SockAddrIn))
}

// Translation of std.net.Ip6Address, reduced to what getOsSockLen uses.
pub struct Ip6Address {
pub mut:
	sa SockAddrIn6
}

pub fn (self &Ip6Address) get_os_sock_len() u32 {
	return u32(sizeof(SockAddrIn6))
}
