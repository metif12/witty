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

The corpus has 36,962 returning cases, 17 isolated checked traps and four
ordinary compile rejections. Its output SHA-256 is
`f1aa0b894555ca0ee8864ce10e7605112cc2ccfeaa1ae6b21a07e3573cbc99dc`.
It compares emitted bytes, values, errors, positions, buffering and underlying
file contents. Cases cover both endian orders, native signed/unsigned and
floating bit representations, aliases, buffered/partial reads and writes,
EOF and shrinking/growing files, closed descriptors, delimiters, seeks,
integer reader/writer helpers and pipe mode transitions.

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
