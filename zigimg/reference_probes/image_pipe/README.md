# Public image APIs on POSIX pipes and invalid descriptors

`verify_image_pipe_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` using Zig 0.15.2 and V 0.5.2:
Debug/ordinary and ReleaseSafe/production, native little-endian
`aarch64-macos.14.0`, linked with libc.

```sh
python3 zigimg/verify_image_pipe_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. `--timeout` bounds commands.
Evidence retains Source, fixtures/C helper, inputs, binaries, commands, raw output,
initialized failure snapshots and provenance. Compiler temporaries use TMPDIR/VTMP.

The first invalid reader descriptor reached Source's `std.posix.fstat` BADF
unreachable check; V returned `Unseekable` instead. The POSIX size shim now reports
BADF separately, and `ReadStream.get_end_pos` preserves the native
`reached unreachable code` panic before setting a cached error. Cached size/error
and streaming-reader paths still precede a new stat call. The guard is explicit
and remains active in production. The Windows size branch is unchanged.

**7,344 returning records / 14,688 public calls** match in both modes, SHA-256
`a289309d0b9f3819b79af0d483252020eec5487ffe6c288125cf34abed124f82`.

| Returning records | Count |
|---|---:|
| Managed/unmanaged encoding on live pipes | 6,528 |
| Encoding with supplied descriptor -1 | 408 |
| Managed/unmanaged detection/reading on live pipes | 408 |
| **Total** | **7,344** |

Writers cover all seventeen encoder arms, eight initialized 4×2 storage profiles,
three existing option variants, capacities 0/1/3/8/16/32/128/1024 and both public
handle APIs. Pipes start with `xyz` already delivered. Each wrapper is invoked
twice without resetting its caller buffer; each invocation creates a fresh
positional writer. The initial positional-to-streaming zero-progress transition
is consequently retried by the codec again on the second call. Actual pipe bytes,
retained caller buffer and initialized pixels/palette are compared.

The pinned no-op writers leave only the caller prefix on the pipe. PNG flushes
only its eight-byte signature. Other encoders preserve their native success,
unsupported/error order, partial delivery and pending bytes discarded with a
private wrapper stream. The public wrapper adds no final flush. Descriptor -1
writer cases use RGB24/BGR24/invalid storage, capacities 0/8/32/1024 and both APIs;
validation and buffering can precede the first failing OS write.

Reader cases seed all seventeen samples from the public read proof, including
XBM. Both public operations and managed/unmanaged APIs use capacities
0/1/8/32/128/1024. Their mandatory initial seek returns `Unseekable` before
signature detection, allocation or pipe consumption. A nonblocking external read
after the call verifies all input remains available. The second call uses the
same still-live pipe after observation has drained it and preserves the same
failure and untouched caller buffer. No public XBM loop or decode is reached.

**384 returning controls**, SHA-256
`6fb1a7e8675b13e3f2fbe08e65643bb40c8bafd11a07c44a51d7a49d9fbd0885`,
and **600 exact panic/state pairs**, SHA-256
`d9e4437c60c4e11f123c626559f9668f8ceb40d749a35ab0387a6ee4fb3adb07`,
cover native-classified invalid readers, zero extents and short stored pixels:

- 408 invalid reader pairs cover both public operations, all sample inputs,
  capacities zero through 1024 and both managed states. Source stat failure
  precedes the buffer-capacity check and codec selection; input remains unread.
- 96 invalid PNG header pairs preserve the generated-header assertion.
- 96 short TGA pixel/row pairs preserve prior header/pixel delivery and retained
  caller buffers. The other 96 short-storage and 288 zero-extent cases return,
  including unsupported formats and raw whole-slice writes.

Every failure requires failed exits, no stdout, the sole exact native message and
equal nonempty snapshots. Observers drain the owned pipe into initialized state
before creating the state file; supplied invalid descriptor -1 cannot be reused by
that observer. Private wrapper cursor/pending length and codec state are not
exposed. Snapshots include descriptor validity, all caller buffer bytes, initialized
source image dimensions/storage/raw pixels/active palette, cumulative actual pipe
bytes and the normalized drain result. Initial snapshots do not drain the pipe.
Inactive storage, pointer/descriptor identities and allocator effects are excluded.
Source bodies and visibility stay unchanged. The C fixture only creates/validates/
seeds/observes owned pipes; it does not replace Source image or stream operations.

Two consumer regressions pin repeated Farbfeld-shaped pipe rejection without
consumption, and repeated PNG calls that leave signature bytes in an eight-byte
buffer while appending a signature on each call. Six exact compiled records /
twelve calls match per mode. Pipes keep their borrowed endpoints open. Read ends
are nonblocking; writes remain blocking and every supplied payload is small enough
for the pipe. An empty live pipe is distinguished from EOF and read errors.

All 61 image and 58 Vaxis test files pass with production image/file tests and
nineteen application/platform/unit/fixture checks. Historical 37,133 stream records,
17 trap pairs and four ordinary compiler rejection pairs pass in both actual
Source optimization modes. Full, original and 171-case streaming hashes remain
`d5d4aadd97fafef40388dd894267e0b09d6db36b902c2f4356d4fb287eab8eeb`,
`f1aa0b894555ca0ee8864ce10e7605112cc2ccfeaa1ae6b21a07e3573cbc99dc`,
and `37175ccb3eb0e9b5b36005a5c2443f6f59b1ee2cbd7de2fd1336c2761a8bcfab`.
Cross builds establish compilation only. Formatting, diff and Python checks pass.

The original native stat panic versus V return, equal initialized retained bytes,
and initial fixture include-path rejection remain preserved separately. Full
Source/library/DEFLATE/math/SIMD/version and before/after implementation/fixture/
runner/helper/input hashes protect final comparisons. Ordinary observations supply
fixed native hashes for production and reproduction. Persistent evidence is
independently replayed and archived with every member read back.

Path/FIFO APIs, custom streams, full-pipe backpressure, nonblocking writers,
reader closure/SIGPIPE, OS races or other failures, allocation/OOM/GC/lifetime,
larger images, other CPU/vector selections, const/narrow/enum/boxed representations,
physical layouts, big-endian/32-bit runtime and portable ABI remain boundaries.
This proof certifies the stated POSIX handle behavior; no other-target runtime is
claimed.
