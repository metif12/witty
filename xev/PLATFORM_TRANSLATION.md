# Windows and WASI source translation

These targets translate Ghostty's locked libxev `34fa50878aec6e5fa8f532867001ab3c36fae23e`, not the current libxev release. The archive's Zig package hash is `libxev-0.0.0-86vtc4IcEwCqEYxEYoN_3KXmc6A9VLcm22aVImfvecYs`, verified against Ghostty `6c0e02d`'s `pkg/libxev/build.zig.zon`.

| Original | V counterpart |
| --- | --- |
| `src/backend/iocp.zig` | `iocp_windows.c.v` |
| `src/backend/wasi_poll.zig` | `wasi_poll.v` |
| `src/windows.zig` | IOCP native declarations, source error handling and process helpers |
| `src/watcher/{stream,timer,async,process}.zig` | `iocp_*`, `wasi_*` |
| `src/{main,api,dynamic}.zig` single-candidate platform projection | `main_windows.c.v`, `main_default.c.v` |
| `src/ThreadPool.zig` with Zig 0.15.2 `std.Thread` and `std.Thread.Futex` | common pool plus `thread_pool_spawn_*`, `thread_pool_wasi.*` |

The implemented backend operation tables, intrusive queues, cancellation paths, timer heap, callback/rearm behavior and platform error mappings are retained. Windows uses SDK OVERLAPPED/WSABUF/job-object structures and completion ports. WASI uses the original subscription/event wire layout and `poll_oneoff`. The original shared stream and timer watcher algorithms are instantiated with each backend's operations; the process and async watchers use their original platform-specific implementations.

Some upstream cases deliberately remain unsupported: IOCP cancellation of operations outside its implemented stop switch panics; stream polling on IOCP/WASI is a source compile error; WASI's Process and threaded Async watcher are empty source types. The WASI thread-pool spawn configuration from libxev omits Zig's required allocator, so the translated call retains the source's immediate allocator-required panic. These inherited cases are not replacement stubs.

Pinned-source quirks are preserved: IOCP `now()` returns its cached nanoseconds, positional read/write offsets use the source's checked low-word cast, positional completion errors carry its read/write tags, timers compare strictly before cached time, and WASI batch removal uses the original `len == 0` branch despite its reserved timeout slot. WASI event error fields are treated as in the original backend.

Windows requires `ws2_32`, `mswsock`, and `ntdll`; ConPTY requires the Windows 10 RS5 API declarations. The `wasm_threads` V define represents Zig's WASM atomics target feature; on WASI it adds `-matomics -mbulk-memory`, selects atomic wakeups/futex instructions, and removes the nonthreaded async watcher API. Default WASI uses plain wakeup values and the source single-threaded futex behavior.

Validation on macOS: native existing Darwin default-loop and thread-pool tests; source-derived WASI batch capacity/swap and ABI tests; Windows and both WASI feature variants typecheck with pinned V 0.5.2. Generated Windows backend C compiles to x86-64 Windows COFF with Zig 0.15.2 and its MinGW SDK. Windows runtime tests were not executed. WASI runtime tests were not executed because no WASI engine is installed; compiling full generated WASI C additionally encounters pinned V's unconditional pthread dependency, which the WASI SDK does not supply. These checks establish translation/type/ABI coverage rather than native execution parity.

Generic File/TCP/UDP watcher APIs omitted by the pre-existing translation are outside the audited missing backend finding and remain separate dependency-audit follow-up items.
