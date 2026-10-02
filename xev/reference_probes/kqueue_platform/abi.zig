const std = @import("std");
comptime {
 if (@sizeOf(std.c.Kevent) != 64) @compileError("Kevent size");
 if (@offsetOf(std.c.Kevent, "_ext") != 32) @compileError("Kevent ext offset");
 if (@sizeOf(std.c.sockaddr) != 16) @compileError("sockaddr size");
 if (@sizeOf(std.c.sockaddr.in) != 16) @compileError("sockaddr_in size");
 if (@sizeOf(std.c.sockaddr.in6) != 28) @compileError("sockaddr_in6 size");
 if (@sizeOf(std.c.sockaddr.un) != 106) @compileError("sockaddr_un size");
 if (@intFromEnum(std.c.UMTX_OP.WAIT_UINT_PRIVATE) != 15) @compileError("wait opcode");
 if (@intFromEnum(std.c.UMTX_OP.WAKE_PRIVATE) != 16) @compileError("wake opcode");
}
export fn abi_verified() void {}
