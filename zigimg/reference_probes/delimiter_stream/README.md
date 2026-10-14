# Streaming a delimiter prefix into a writer

`verify_delimiter_stream_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and Zig 0.15.2 with V 0.5.2.
These public Source reader methods map to the V reader adapter:

| Source method | V method | EOF without a delimiter |
|---|---|---|
| streamDelimiter | stream_delimiter | EndOfStream after writing and consuming the prefix |
| streamDelimiterEnding | stream_delimiter_ending | Return the number written and consumed |
| streamDelimiterLimit | stream_delimiter_limit | Return the number written and consumed if EOF precedes the limit |

All three append the prefix to a `mut WriteStream`, omit the delimiter and leave
it unread. A delimiter at the cursor returns zero even if the writer is full.
The bounded method adapts `std.Io.Limit` to `usize`; `~usize(0)` means unlimited.
Zero or exhausted bounds return StreamTooLong before checking input, the writer
or EOF. Each buffered span is consumed only after its complete write succeeds.
A partial writer failure can change output while leaving that span unread;
previous successful spans remain consumed. Read failures retain prior output.

```sh
python3 zigimg/verify_delimiter_stream_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a second empty directory. Pairs use Source Debug / V
ordinary and Source ReleaseSafe / V production. Target defaults to
`aarch64-macos.14.0`; `--timeout` bounds each command. VEXE and compiler versions
are pinned; temporary directories and compiler caches are task-owned.

Both modes match **49,500 returning records / 148,500 delimiter-stream calls /
247,500 primary calls**. Each record performs three streaming calls, one relative
reader seek and one writer flush. Setup calls are separate. Groups are 26,775
basic, 1,485 line, 1,080 seek, 11,520 every-delimiter and 8,640 replacement profiles.
Reader constructors cover memory, positional files and streaming-initialized
regular files. Memory uses its whole payload; file capacities are 1/8/32.
Payload lengths 0/1/7/8/9/33/64, present/absent markers, empty/adjacent/trailing
lines, all 256 delimiter bytes, nonzero/end initial offsets and -1/0/1 rewinds
exercise count, EOF and bounds distinctions. Bounded profiles include distinct
zero/one/length/length-plus-one/capacity/capacity-plus-one/unlimited limits.

Writer profiles cover memory, positional/streaming regular files and empty/full
nonblocking output pipes. Capacities 0/1/3/8/32 and empty/full prefills exercise
buffered output, actual writes, retries, flushes and failures. The replacement
profiles retain original-file read-ahead, consume distinct prefixes and switch
owned reader descriptors to open or closed pipes, with zero/capacity/twice-capacity-plus-one seeds.
Complete initialized input/output buffers, pending spans, logical positions,
size/error observations, last successful counts, ownership, actual file output
and remaining pipe bytes match. Full-pipe seed bytes are checked byte by byte
and removed from the displayed wire; any appended bytes remain visible.
SHA-256: `1525e99b06bb47e5f627d13699e1c7c57f0aad1b39a5fd4e05f81858fcf17fdf`.

The native control classification separates **84 returning records**, SHA-256
`1fe9aad4034d0f0c3ff7318ead2bdd934fca35d64da61265a0ecfb8824b2c344`,
from **120 exact panic/state pairs**, SHA-256
`0829ace76ae607860124ece9fbfe5c357d5bb3a1ba8b8394486ae59b19b1320d`.
Twelve zero-capacity/zero-limit profiles and 72 consumed-failure profiles return.
Forty-eight positive zero-capacity file scans panic with exactly reached
unreachable code before reading or writing. Seventy-two failed-prefill profiles
panic with exactly integer overflow when the subsequent public getPos observation
subtracts retained bytes from a smaller transitioned physical position. The
streaming operation has not been called in these latter profiles. Both exits
fail with empty stdout, one exact panic message and matching initialized state.
Observers omit reader getPos, handle size errors and capture buffers, writer
position/pending output, saved count and ownership before opening state files.

Sixteen additional compiled consumer records / 80 primary calls per mode assert
concrete first-call results: marker retention, EOF count/error differences,
zero/exact bounds, full-writer empty prefixes, partial memory writes, buffer-size
dependent reader consumption and read/write failure order. Output SHA-256:
`8646886bfa0458899c21079abdb6aef536ac5059005b946d4a23e1583a2d2f7d`.
Four public V unit
regressions cover these contracts. All 68 image and 58 Vaxis test files pass,
along with 40 production/application/platform/unit/fixture checks. Historical
discard, nullable/exclusive/inclusive delimiter and full stream matrices retain
their previous hashes in both modes.

The wrapper reuses separately copied/hashed
[exclusive payload](../reader_exclusive/README.md),
[reader replacement](../reader_delimiter/README.md) and
[writer replacement](../writer_seek/README.md) fixtures. C creates initialized
unlinked O_EXCL/CLOEXEC regular files and owned nonblocking pipes, resets reader
and writer offsets before construction and fills owned output pipes until
WouldBlock. It neither changes nor intercepts Source reader/writer calls.
Full Source, selected compiler libraries/versions, implementation, probes, shared
headers, directly imported helpers and inputs are checked before/after comparison.
Independent replay exposed duplicate identical control inputs; those were removed
and both suites rerun with 204 distinct control inputs. Only golden assignments
change after the final ordinary discovery. Lossless parent-side
log compression retains raw-byte and compressed-file hashes. Independent replay
checks outputs, native classifications, exact failure state, consumer expectations,
ownership, actual modes and provenance; every archive member is read back.
Initial disk-exhaustion build/test diagnostics and a production fixture setup
failure are retained separately. The unchanged failed fixture binary and input
pass on replay after reclamation, as do the final proofs. Completed disposable caches and fully verified duplicate
expanded checkpoint evidence are reclaimed; original archives remain available.

Arbitrary custom writer callbacks, overlapping reader/writer buffers, concurrent
reuse, other devices, larger requests/buffers/offsets, arbitrary constructor/copy
sequences, syscall counts, timing/signals, injected errors, OOM/quotas, allocator
lifetime, portable ABI, V representation limits, Windows runtime, other CPU
selections and big-endian/32-bit runtime remain boundaries. Cross builds prove
compilation only. Existing method bodies remain unchanged.
