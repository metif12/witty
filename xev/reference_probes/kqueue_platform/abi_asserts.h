// Include after the generated V C declarations. Target-native headers define
// Kevent; the V socket records mirror the pinned Zig 0.15.2 std.c declarations.
#if defined(__FreeBSD__)
_Static_assert(sizeof(xev__Kevent) == 64, "FreeBSD Kevent size matches Zig std.c");
_Static_assert(offsetof(xev__Kevent, ext) == 32, "FreeBSD Kevent ext offset");
_Static_assert(UMTX_OP_WAIT_UINT_PRIVATE == 15, "FreeBSD futex wait opcode");
_Static_assert(UMTX_OP_WAKE_PRIVATE == 16, "FreeBSD futex wake opcode");
#endif
_Static_assert(sizeof(xev__SockAddr) == 16, "BSD sockaddr size");
_Static_assert(sizeof(xev__SockAddrIn) == 16, "BSD sockaddr_in size");
_Static_assert(sizeof(xev__SockAddrIn6) == 28, "BSD sockaddr_in6 size");
_Static_assert(sizeof(xev__SockAddrUn) == 106, "BSD sockaddr_un size");
