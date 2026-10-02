module xev

// Zig std.os.windows socket ABI used by libxev IOCP.
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
	family   u16 = 23
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

pub enum ShutdownHow as int {
	recv
	send
	both
}

@[noreturn]
fn posix_unreachable() { panic('reached unreachable code') }
