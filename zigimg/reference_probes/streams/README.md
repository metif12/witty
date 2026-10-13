# Stream and bitstream source comparison

Run from the repository root with the locked zigimg checkout, Zig 0.15.2 and
V 0.5.2:

```sh
python3 zigimg/verify_streams_reference.py /path/to/zigimg /path/to/zig /path/to/v
python3 zigimg/verify_streams_reference.py /path/to/zigimg /path/to/zig /path/to/v --v-prod
```

The runner hashes the complete zigimg `src` tree before copying it unchanged.
The expected SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`,
from revision `d7b7ab0ba0899643831ef042bd73289510b39906`.
The default native target is `aarch64-macos.14.0`, linked with libc.

The corpus has 37,133 returning cases, 17 isolated checked traps and four
ordinary compile rejections. Its output SHA-256 is
`d5d4aadd97fafef40388dd894267e0b09d6db36b902c2f4356d4fb287eab8eeb`.
The original 36,962 cases retain
`f1aa0b894555ca0ee8864ce10e7605112cc2ccfeaa1ae6b21a07e3573cbc99dc`.
The 171 streaming-constructor cases match independently in ordinary and
production builds, SHA-256
`37175ccb3eb0e9b5b36005a5c2443f6f59b1ee2cbd7de2fd1336c2761a8bcfab`;
`--streaming-only` runs this extension alone.
It compares emitted bytes, values, errors, positions, buffering and underlying
file contents. Cases cover both endian orders, native signed/unsigned and
floating bit representations, aliases, buffered/partial reads and writes,
EOF and shrinking/growing files, closed descriptors, delimiters, seeks,
integer reader/writer helpers and pipe mode transitions.

`init_file_streaming` starts at the descriptor's current position rather than
using positional I/O. The reader initially reports `Streaming` for its size;
observing EOF replaces that error with the discovered size. Backward absolute
seeks remain unavailable. `buffered_len()` exposes bytes waiting in the reader.
The fixtures set the descriptor position through system calls, avoiding V's
stdio buffering. A focused consumer test exchanges bytes through actual pipe
reader/writer adapters.

On Darwin, Zig 0.15.2 implements positional vector writes through `pwrite` and
returns after the first nonempty vector. The translated shim keeps that pending
buffer behavior. A pipe's first positional write switches modes and returns
zero progress; a flush retries the transition. EOF updates the reader's cached
file size. Explicit checked-arithmetic guards retain the source traps when V
production optimization removes assertions. Trap checks reject both successful
returns and domain errors wrapped by an outer panic.

`reader()` and `writer()` return borrowed pointers to live V streams. Keep the
owning stream and its buffer alive while using an adapter. Type markers replace
source compile-time endian arguments; `take_int`/`write_int` expose the native
integer helper operations. Float integer helpers and invalid endian markers
retain ordinary compiler rejections. Bit streams support V native integer and
floating scalars; Zig's additional non-native widths are outside this API.

V slices, GC ownership, error strings and `os.File` replace the source's slice,
allocator, error-set and file representations. Native comparisons establish the
Darwin/POSIX behavior in this corpus. Linux checking and Windows cross builds
do not certify runtime behavior on those platforms.

The later [stream guard proof](../stream_guards/README.md) aligns shared capacity/
toss and addition diagnostics with exact Source messages. Existing output/state
hashes remain unchanged; wider failed cursor representation limits remain.
