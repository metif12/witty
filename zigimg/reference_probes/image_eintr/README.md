# Interrupted public image path opens

`verify_image_eintr_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` using Zig 0.15.2 and V 0.5.2:
Debug/ordinary and ReleaseSafe/production, native little-endian
`aarch64-macos.14.0`, linked with libc. These cases require no production changes.

```sh
python3 zigimg/verify_image_eintr_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. `--timeout` bounds commands
(default 600 seconds). Proofs retain complete Source, fixtures/C helper, inputs,
normal and deliberately altered V modules, binaries, commands, raw output,
initialized failure snapshots and provenance. Compiler temporaries use TMPDIR/VTMP.
No Source body or visibility changes. Each fixture runs in an isolated process;
only its calling thread receives the test's SIGUSR1 signals.

**1,680 returning records / 3,360 public calls** match in both modes, SHA-256
`855b29bfcdac9879e3c326cfc1a4a93316af1dbac5fa724da4af9709a4fc6119`.

| Returning records | Count |
|---|---:|
| Interrupted managed/unmanaged writers | 1,632 |
| Interrupted managed/unmanaged detection/reading | 48 |
| **Total** | **1,680** |

Writers cover all seventeen encoder arms, eight initialized 4×2 storage profiles,
default options, capacities 0/8/32, both APIs and one/three signal deliveries per
open. Every public operation repeats twice without resetting the caller buffer.
Each attempt begins with no descriptor referencing the FIFO. A C worker waits,
delivers acknowledged signals with SA_RESTART omitted, then opens an owned
O_RDWR/O_NONBLOCK keeper to release the actual blocking public open. The keeper
is closed after each observation so the next attempt blocks again.

The signal handler only increments a lock-free atomic counter. Worker observations
must report the requested deliveries, no early public return, no opened FIFO inode
references before release and no setup/delivery error. The fixture joins the worker
before inspecting buffers or bytes, restores the previous handler and thread mask,
and checks the handler pointer, SA_RESTART bit and SIGUSR1 blockedness. Timing,
thread/descriptor identities and other signal-action bits are not output records.
No image syscall is intercepted, replaced or injected with a fabricated errno.

Readers cover both public operations, both APIs, all three capacities and both
signal patterns, with an empty FIFO or an eight-byte PNG signature supplied by the
keeper. They return `Unseekable` at the mandatory initial seek after the interrupted
open succeeds, before detection or buffer-capacity validation. Joined observation
finds all supplied input unread and the caller buffer untouched. Writers preserve
native return/error order, initialized image/pixels/active palette, output and
buffer tails. Pinned no-op writers remain no-ops; PNG flushes only its signature.
No final wrapper flush is added.

Four read/write calibration records per binary perform one actual libc open
without retries under the same worker. All return EINTR, SHA-256
`f8b0982971a5d9dbb2ba5befbedab4ebd0ae646dfc20ed216da7d235b89617c5`.
They return before keeper release; signals continue until acknowledged and the
fixture then restores its state. Calibration records are separate from public
comparison observations.

A second control copies all V implementation files and disables exactly the
interrupted-open retry branch in the copy. All **12 records / 24 public calls**
(reading/detection/writing × both APIs × both signal patterns, repeated twice)
return `Unexpected` before codec dispatch and keeper release, with untouched
buffers and no output. Its SHA-256 is
`1f0593c557c9936967d064c271760a0ac2269d94603838600a2f59d6aa7bbb4a`.
All other implementation hashes stay equal. This control demonstrates that the
actual V public retry branch is exercised; it is not a parity result or a change
to production/Source. Exact syscall retry counts are unobserved.

**24 returning controls**, SHA-256
`f58555e192da9baed2431dab4a4100caa79f84584820ce73601ac3e2aeca5fc8`,
and **44 exact panic/state pairs**, SHA-256
`60b7a7c09a3d40b4c7a6c5ef31f1e7cf4aa51d909a559fd9d4a8abc39fc3c1d2`,
cover zero-width PNGs (RGB24/BGR24/invalid storage, capacities 0/8/32) and TGA
one-pixel storage (RGB24/RGBA32/BGR24/BGRA32, capacities 8/32), both APIs and
both signal patterns. Source classifies all controls: 24 PNG cases return
Unsupported; 12 PNG cases assert; all 32 short-storage TGA cases panic. Failed
exits, no stdout, the sole exact native diagnostic and equal initialized snapshots
are required. Signals precede codec validation. Panic snapshots retain both keeper
and public descriptor before process exit, reflecting Source's lack of unwinding;
normal/error snapshots retain only the keeper. Prior output and buffer changes
match. The observer joins/restores the fixture's worker and signal state before
snapshotting; it does not add production panic cleanup.

Rows use ten fields:
`operation|format|storage|option|capacity|managed|shape|attempts|seedHex|signals`.
Operations are write/detect/read (0/1/2); shapes are full/zero-width/zero-height/
one-pixel storage (0/1/2/3). Tested options are zero. Storage initialization and
format numbering match the public FIFO proof. Snapshots contain FIFO kind,
keeper validity, live inode references among descriptors 0–127, normalized drain
result, every caller buffer byte, initialized image dimensions/storage/raw pixels/
active palette, cumulative wire bytes and six signal metrics. Initial snapshots
have no descriptors or worker state. Only fixture-owned FIFO names are removed;
none survive successful completion. Private stream/codec cursors, inactive storage,
allocator effects and raw OS identities are excluded.

Two consumer regressions check repeated PNG/no-op GIF writes and untouched
read/detection failures across both APIs and signal patterns, plus actual EINTR
calibration and restored fixture state. Sixteen exact compiled records / 32 calls
match per mode. All 61 image and 58 Vaxis test files pass with nineteen production,
application, Linux/Windows library, unit and fixture checks. Cross builds establish
compilation only; POSIX tests do not run on Windows. The previous FIFO proof
retains all three hashes (6,960 records, 384 controls, 192 panic/state pairs) in
both actual Source modes. Formatting, diff and Python checks pass.

Full Source/library/DEFLATE/math/SIMD/fs.Dir/libc/version and before/after
implementation/fixture/runner/helper/input hashes protect comparisons. Ordinary
observations supply fixed production hashes; only golden assignments change
afterward. Persistent evidence is independently replayed and archived, with every
member read back. The copied-fixture VMODROOT include rejection, earlier successful ordinary
observations and the failed production calibration remain retained. The production
fixture originally placed FIFO/signal setup calls inside ordinary assertions,
which V omits in production. Explicit setup checks now preserve those calls;
all final comparisons use the corrected fixture.

Other signal handlers/masks/actions, SA_RESTART behavior, exact syscall/interrupt
counts, timing/scheduling equivalence, cancellation, interrupted read/write/close,
controlling-TTY acquisition, close failures, externally changed descriptors/paths,
full-pipe backpressure, resource exhaustion, other options/capacities/images,
Windows runtime, other CPU/vector selections, const/narrow/enum/boxed representations,
physical layouts, big-endian/32-bit runtime and portable ABI remain boundaries.
The proof certifies the stated isolated native FIFO-open behavior.
