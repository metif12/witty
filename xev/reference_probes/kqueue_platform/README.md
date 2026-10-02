# Kqueue target selection and native ABI probe

`main.v` imports the production xev module and exercises the same
single-candidate API selection as the locked libxev `34fa508` source. Generate
FreeBSD C with pinned V 0.5.2 and the repository before `@vlib` on the module
path, using `-gc none -os freebsd -o probe.c`. Append `abi_asserts.h` to that
C file, then compile it to an object with Zig 0.15.2 `cc -target aarch64-freebsd`.
The original FreeBSD 14.0 `lib/libprocstat/libprocstat.h` from freebsd-src
`releng/14.0` is also required on the include path by V's runtime module; it is
not included in Zig's otherwise complete FreeBSD SDK.

`abi.zig` independently checks the untouched Zig standard-library Kevent,
socket layout and futex operation constants. Compile it with Zig 0.15.2
`build-obj -target aarch64-freebsd`; neither probe requires executing FreeBSD.

The object compilation verifies actual target-native headers, pointer
userdata, four extension words, eventfd and private umtx declarations. The
native macOS `main_darwin`, kqueue, async, process and thread-pool tests cover
the shared implementation. iOS and FreeBSD full termio checks cover target
selection; no iOS SDK or native FreeBSD runtime execution is claimed.
