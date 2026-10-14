# Public image APIs on POSIX FIFO paths

`verify_image_fifo_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` using Zig 0.15.2 and V 0.5.2:
Debug/ordinary and ReleaseSafe/production, native little-endian
`aarch64-macos.14.0`, linked with libc. These cases need no production changes.

```sh
python3 zigimg/verify_image_fifo_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. `--timeout` bounds commands.
Retained evidence includes Source, fixtures/C helper, inputs, binaries, commands,
raw output, initialized failure snapshots and provenance. Compiler temporaries
use TMPDIR/VTMP. No Source body or visibility is changed.

**6,960 returning records / 13,920 public calls** match in both modes, SHA-256
`2ce3c5e6de4d0a2a90d245b03f6ba970531f6a2b51172c9c359f3c675f24d722`.

| Returning records | Count |
|---|---:|
| Managed/unmanaged encoding through FIFO paths | 6,528 |
| Managed/unmanaged detection/reading through FIFO paths | 432 |
| **Total** | **6,960** |

Writers cover all seventeen encoder arms, eight initialized 4×2 storage profiles,
three existing option variants, capacities 0/1/3/8/16/32/128/1024 and both public
path APIs. Every FIFO starts with `xyz` already queued. Each wrapper is invoked
twice without resetting its caller buffer. The wrapper opens and closes its own
file each time; each call constructs a fresh positional writer whose first
nonempty syscall falls back to streaming. Codec retries preserve partial delivery,
error order and buffered bytes discarded with the wrapper. No final wrapper flush
is added.

Creating/truncating an existing FIFO does not discard its queued prefix. Pinned
no-op writers retain only that prefix, while PNG flushes its eight-byte signature
once per call. Regular-file path truncation remains separately covered by the
public image file proof. Actual cumulative FIFO output and retained caller buffers
are compared, including successful and unsupported/error returns.

Readers seed all seventeen samples from the public read proof plus an empty FIFO.
Both public operations, managed/unmanaged APIs and capacities 0/1/8/32/128/1024
are covered. The mandatory initial seek returns `Unseekable` before signature
selection, buffer-capacity checks or allocation. External observation verifies
that the full input remains unread and the initialized buffer remains untouched.
The second call opens the same FIFO after observation has drained it and retains
the same error. XBM never reaches its inherited detector loop.

**384 returning controls**, SHA-256
`95348a62e060bd57f7b8af123ffecda2c1a14eeaad82fe85ab16cd30f14f3f34`,
and **192 exact panic/state pairs**, SHA-256
`4f311214683495c1ae413d51e585051cb7c3cd773bd1bff1593b8c48238f82ce`,
cover zero extents and one stored pixel for PNG/TGA, RGB24/RGBA32/BGR24/BGRA32,
three options, capacities 0/1/8/32 and both public path APIs. Every control is
classified by Source. Ninety-six invalid PNG headers and ninety-six short TGA
pixel/row cases panic. The other 96 short-storage and 288 zero-extent cases return.
Failed exits, no stdout, the sole exact native message and equal nonempty snapshots
are required. Prior delivery, initialized pixels/palette and retained buffers match.

The fixture creates an owned named FIFO and keeps one O_RDWR/O_NONBLOCK descriptor
open, allowing the actual public blocking path opens to finish without another
process. Public writers remain blocking and each payload fits the pipe; readers
never consume data before their failing seek. The C helper only creates, seeds,
validates and observes owned OS resources. It does not replace image/stream APIs.
The empty live FIFO is distinguished from EOF and a read failure.

Snapshots include FIFO kind, keeper validity, live references to its inode among
fixture descriptors 0–127, all caller buffer bytes, initialized image dimensions/
storage/raw pixels/active palette, cumulative FIFO bytes and normalized drain
result. Isolated fixture descriptors stay below 128. Initial snapshots do not
drain. Success and returned errors retain just the keeper, proving temporary
public path descriptors close on both calls. Panic snapshots retain the keeper
and the still-open public descriptor before process exit, matching Source's lack
of panic unwinding. Observers snapshot before opening their state file, then
unlink their owned FIFO. No FIFO names survive successful proof completion.
Private wrapper cursor/pending length, codec state, inactive storage, descriptor/
inode identities and allocator effects are unobserved.

Two consumer regressions pin repeated rejected read/detection without consumption,
closed temporary descriptors, prefix-preserving path writes, repeated PNG
signatures and the pinned no-op GIF writer. Eight exact compiled records /
sixteen calls match per mode. All 61 image and 58 Vaxis test files pass with
production image/file tests and nineteen application/platform/unit/fixture checks.
Windows stubs only permit fixture/test compilation; POSIX tests do not run there.
Linux/Windows cross builds establish compilation only.

The previous public pipe proof also retains its 7,344 returning records, 384
returning controls and 600 exact panic/state pairs in both actual Source modes.
Its three hashes remain
`a289309d0b9f3819b79af0d483252020eec5487ffe6c288125cf34abed124f82`,
`6fb1a7e8675b13e3f2fbe08e65643bb40c8bafd11a07c44a51d7a49d9fbd0885`,
and `d9e4437c60c4e11f123c626559f9668f8ceb40d749a35ab0387a6ee4fb3adb07`.
Formatting, diff and Python checks pass. Full Source/library/DEFLATE/math/SIMD/
version and before/after implementation/fixture/runner/helper/input hashes protect
comparisons. Ordinary observations supply the fixed production/reproduction
hashes; only golden assignments change afterward. Persistent evidence is
independently replayed and archived with every member read back.

Full-pipe backpressure, opens without a keeper, nonblocking public writers,
reader closure/SIGPIPE, path races/symlinks/permissions/missing files and other OS
failures, allocation/OOM/GC/lifetime, larger images, custom streams, other CPU/
vector selections, const/narrow/enum/boxed representations, physical layouts,
big-endian/32-bit runtime and portable ABI remain boundaries. This proof certifies
the stated native POSIX FIFO path behavior; no other-target runtime is claimed.
