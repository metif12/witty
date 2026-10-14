# Bounded and unbounded delimiter discard

`verify_delimiter_discard_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and Zig 0.15.2 with V 0.5.2.
The public Source reader methods map to three V adapter methods:

| Source method | V method | Found delimiter | EOF without delimiter |
|---|---|---|---|
| discardDelimiterExclusive | discard_delimiter_exclusive | Return prefix count; leave delimiter unread | Return consumed count |
| discardDelimiterInclusive | discard_delimiter_inclusive | Consume and count delimiter | Return EndOfStream after consuming prefix |
| discardDelimiterLimit | discard_delimiter_limit | Return prefix count; leave delimiter unread | Return consumed count if reached before limit |

The bounded V method takes a `usize` limit, adapting Source's `std.Io.Limit`.
`~usize(0)` represents unlimited scanning. A zero limit returns StreamTooLong
before touching input. Reaching any positive limit also returns StreamTooLong
before checking the next byte or EOF: a delimiter exactly at the bound stays
unread, and consuming exactly an unterminated payload's length still fails.
Errors preserve prior consumption. Positive scans cross arbitrary numbers of
buffer fills; they do not return StreamTooLong merely because a line exceeds
the buffer capacity. The implementation uses the existing peek/toss primitives
and scans the full available buffered span after ensuring one byte is present.

```sh
python3 zigimg/verify_delimiter_discard_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. Pairs use Source Debug / V
ordinary and Source ReleaseSafe / V production. Native target defaults to
`aarch64-macos.14.0`; `--timeout` bounds each command. VEXE, temporary directories
and compiler caches are pinned or task-owned. No Source body, visibility or
reader syscall is changed or intercepted.

| Comparison per mode | Returning records | Primary calls |
|---|---:|---:|
| Memory, positional files and streaming-initialized regular files | 43,932 | 175,728 |
| Original-file read-ahead and controlled pipe replacement | 29,292 | 87,876 |
| Additional returning controls | 1,444 | Separate control calls |
| Exact zero-capacity panic/state pairs | 16 failed pairs | Separate failed outcomes |

Each first-matrix record performs three discards and one relative seek. All three
APIs cover capacities 1/2/8/32, arithmetic payload lengths
0/1/7/8/9/31/32/33/64, distinct zero/one/half-length/end offsets, present/absent
markers and relative offsets -1/0/1. Bounded scans use distinct values from
zero/one/payload-length-minus-one/payload-length/payload-length-plus-one/capacity/
capacity-plus-one/unlimited. Empty, newline-only, consecutive/newline-terminated
and unterminated payloads also run; every delimiter byte is covered for each
reader kind and API. Memory uses its whole input, so its capacity axis repeats
those cases. Complete initialized buffers, ordered statuses, pending bytes,
logical positions, size/error observations and returned counts match. Counts
are encoded as initialized eight-byte little-endian values for comparisons;
a saved count remains intact on later errors. SHA-256:
`4872caee7f98f0efa3b85dba01bd3fda3554168a5b84c5b3ce3767eddb2f40d7`.

The replacement matrix performs two discards and one relative seek per record:
23,220 ordinary-transition, 2,268 failed-pending, 2,268 failed-consumed and 1,536
every-delimiter profiles. Capacities 1/8/32, original offsets 0/1/7, distinct
consumed prefixes, EOF/WouldBlock, optional reseeding and relative rewinds cover
both ordinary and sticky failures. Bounded profiles use zero/one/capacity-plus-one/
unlimited. Initialized buffers, saved counts, pending spans, positions, cached
sizes, normalized ownership and queued input match. SHA-256:
`c632666b0a2f9a886d3e02beb7138135ffc2766a9dc502a20173a0c4cffc859b`.

Native classification separates 1,444 returning controls, SHA-256
`b35f6109eaae70e8c1c2edfcbc9934380d13748c94a20c947ceeaf0dc2066928`,
from 16 exact zero-capacity pairs, SHA-256
`56df6f9d04465d0a390565032b5bdc4c2eef27d8aca8555c29b93579f1b205ff`.
The 1,440 position profiles all return: these discard scans consume pending
prefixes before further IO, unlike the earlier returning-slice APIs. Four file
zero-capacity/zero-limit controls return StreamTooLong without IO. The 16 positive
zero-capacity scans panic before a read, in both positional and streaming
constructors and for empty/nonempty files. Both exits fail, stdout is empty,
each diagnostic is exactly reached unreachable code and initialized state
matches. Observers omit getPos, handle size errors and capture calling status,
valid descriptors and the two owned pipe keepers before opening state files.

Thirteen additional compiled consumer records / 52 calls per mode assert concrete
counts and positions for retained/consumed delimiters, EOF prefixes, exact/zero
bounds and long scans through capacities 1/2/8. They use the same frozen binaries.
SHA-256: `e4ca5e7adae3cad5e5ef72a1f4e4a17ad53f009e27e428770f57fb6f95de05cc`.
Unit regressions cover the same source distinctions through public V calls.

The C wrapper reuses separately copied/hashed
[exclusive payload setup](../reader_exclusive/README.md) and
[delimiter replacement fixture](../reader_delimiter/README.md). It creates
initialized unlinked O_EXCL/CLOEXEC files, resets owned payload offsets before
reader construction and operates only on owned nonblocking pipes/descriptors.
Full Source, selected compiler libraries/versions, implementation, probes,
shared headers, directly imported helpers and input bytes are checked before/after
comparison. Only golden assignments change after ordinary discovery. Raw commands,
binaries, output, diagnostics, state, provenance and summaries are retained.
Large stdout logs use lossless parent-side compression with checked raw-byte and
compressed-file hashes. Independent replay checks outputs, native classifications,
exact failure states, ownership, actual build modes and provenance; persistent
archives are read back member by member.

Existing nullable, exclusive and inclusive delimiter and full stream hashes
remain unchanged in both modes. All module tests and platform builds pass;
cross builds establish compilation only. Other devices, larger requests/offsets/
buffers, arbitrary constructor/copy/callback sequences, delimiter writer-streaming
callbacks, concurrent reuse, syscall counts, timing/signals, injected errors,
OOM/quotas, allocator lifetime, portable ABI, V representation limits, Windows
runtime, other CPU selections and big-endian/32-bit runtime remain boundaries.
