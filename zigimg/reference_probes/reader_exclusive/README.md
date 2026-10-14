# Exclusive delimiter prefixes and EOF tails

`verify_reader_exclusive_reference.py` compares the unchanged pinned zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and Zig 0.15.2 reader with V 0.5.2.
It calls the public `ReadStream.reader()` adapter and `peekDelimiterExclusive` /
`takeDelimiterExclusive`; V exposes `peek_delimiter_exclusive` and
`take_delimiter_exclusive` on that borrowed adapter.

```sh
python3 zigimg/verify_reader_exclusive_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. Native pairs use Source
Debug / V ordinary and Source ReleaseSafe / V production. `--target` defaults
to `aarch64-macos.14.0`. `--timeout` bounds each command; owned temporary and
compiler-cache directories keep evidence separate from unrelated work.

Both exclusive methods omit a found delimiter. Peeking leaves the cursor in
place; taking advances only over the returned prefix, leaving the delimiter
unread. A delimiter at the cursor therefore succeeds with an empty slice and
repeated takes make no progress. On EndOfStream, a nonempty pending tail becomes
a successful result. An empty tail still returns EndOfStream. ReadFailed and
StreamTooLong propagate without turning a pending prefix into a successful
result. A file buffer filled without finding a delimiter reports StreamTooLong,
even when the actual file ends there. Returned slices borrow the reader storage.
The nullable `takeDelimiter` API is outside this checkpoint.

| Comparison per build mode | Records | Primary calls |
|---|---:|---:|
| Memory, positional files and streaming-initialized regular files | 12,480 | 49,920 |
| Original-file read-ahead followed by controlled pipe replacement | 9,764 | 29,292 |
| Additional returning position controls | 264 | 792 |
| Exact getPos overflow / retained-state pairs | 216 | Separate failed outcomes |

The first matrix uses both APIs, file capacities 0/1/8/32, payload lengths
0/1/7/8/9/31/32/33/64, distinct start offsets zero/one/half-length/length, present and
absent delimiters and relative offsets -1/0/1. Each record performs three
exclusive calls and one relative seek. Memory readers use their whole input;
the capacity axis intentionally repeats those memory cases. Six additional API /
reader-kind combinations cover every delimiter byte 0–255 with input bytes 0–15.
Setup seeks, snapshot queries and fixture operations are excluded from call counts.
Complete initialized caller buffers, copied results, pending bytes, positions,
size/error outcomes and ordered statuses match. SHA-256:
`7b289815904dd705da2bb636af9c4e5ab7c4429fee2696425252b78307d2b65a`.

The replacement matrix has 7,740 ordinary-transition, 756 failed-pending,
756 failed-consumed and 512 every-delimiter records. Capacities 1/8/32, offsets
0/1/7, distinct consumed prefixes 0/1/capacity-1/capacity, seed amounts at and
beyond transition progress, EOF/WouldBlock, optional reseeding and relative
rewinds exercise preserved original bytes and sticky failures. Each record
counts two exclusive calls and one relative seek. Ownership, queued input and
all initialized snapshots match. SHA-256:
`02dba5bcc5d4fc386311542b77fcc805f66406939d817b5614694c51693479d7`.

Native classification separates the 264 returning controls, SHA-256
`e953ff96c5268780593e0fe6c4cb318a897ad823e9ce45f3527aa234c80f9b4a`,
from 216 exact integer-overflow pairs, SHA-256
`87f6fa3b0a377a66c68d279ebaee77ae5448782e91bdfdbf94d73dae93f8a6c0`.
The latter occur in a subsequent public getPos query after delimiter ReadFailed;
they are not delimiter traps. Panic observers omit getPos, require matching
nonempty initialized state and preserve the preceding status. Both exits fail,
stdout is empty, and each diagnostic names exactly integer overflow. The shared
[delimiter fixture](../reader_delimiter/README.md) explains controlled descriptor
replacement and normalized ownership observations.

The C extension creates initialized payloads by rewriting/truncating its own
unlinked O_EXCL/CLOEXEC regular file, then seeking its owned descriptor to zero
before reader construction. It reuses the
shared fixture's owned pipes, descriptor observations and cleanup. It changes no
reader syscall or Source body/visibility. The copied shared header is separately
hashed. Source allocators and inactive storage are excluded; results are copied
before later calls can invalidate their borrowed slices. Unit regressions also
cover live memory borrowing, empty results at a delimiter, EOF tail consumption
and the full-capacity distinction.

An additional 1,024 compiled borrowed-slice records / 1,024 calls per mode
cover both APIs on memory and positional files for every delimiter byte. Mutating
the caller backing storage after a return changes the borrowed result while its
saved copy stays intact. Empty results, positions and full backing spans match.
SHA-256: `def99af9311930c93c027ef930102214cbd493bb9bd692e453b0a5b842588ce2`.

The runner pins complete Source, selected compiler libraries and versions,
production implementation, probe files, shared C fixture, imported helpers and
input bytes. Before/after hashes protect each comparison. Ordinary discovery
changes only golden assignments before the production run. Commands, binaries,
raw output, diagnostics, panic state, provenance and summaries remain retained.
Independent replay validates outputs, native classifications and failure state;
persistent evidence archives are read back member by member.

Other devices, arbitrary constructor/copy/callback sequences, larger requests,
concurrent replacement/reuse, syscall counts, timing/backpressure/signals,
injected errors, OOM/quotas, allocator lifetime, portable ABI, wider V cursor and
sum-type representation, Windows runtime, other CPU selections and big-endian /
32-bit runtime remain boundaries. Platform cross builds establish compilation.
EOF tail semantics reuse the existing inclusive delimiter primitive; its
historical native hashes and the existing full stream and TGA decoder hashes
remain unchanged in both build modes.
