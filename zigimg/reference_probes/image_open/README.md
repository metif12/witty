# Public image open flags, creation modes and exec inheritance

`verify_image_open_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` using Zig 0.15.2 and V 0.5.2:
Debug/ordinary and ReleaseSafe/production, native little-endian
`aarch64-macos.14.0`, linked with libc.

```sh
python3 zigimg/verify_image_open_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. `--timeout` bounds ordinary
commands. Loop controls wait at most ten seconds for descriptor readiness, require
another half-second of live execution, then kill only their own process. Evidence
retains Source, fixtures/C helper, inputs, binaries, commands, raw output, initialized
failure/ready snapshots and provenance. Compiler temporaries use TMPDIR/VTMP.

The first live PNG path descriptor had FD_CLOEXEC in Source but not V. An actual
fork/exec of the fixture confirmed that Source's owned descriptor disappeared
while V's survived. Both public reader operations showed the same difference
while the inherited XBM detector loop kept their file open. The original binary,
writer panic states and four read/detection loop pairs remain separately retained.
Normal creation modes, truncation and alias behavior already matched.

The shared POSIX opener now calls open with the pinned fs.Dir default flags:
read-only or write-only/create/truncate, O_CLOEXEC where defined, O_LARGEFILE where
defined, and O_NOCTTY for default readers. The descriptor gets its flags at the
actual open; no subsequent flag-setting interval is introduced. Creation requests
0666 and lets the caller's umask apply. The saved syscall errno is translated by
the existing path-error mapping, and interrupted opens retry. Private path streams
use only the raw descriptor and close it directly on return/error; they attach no
stdio buffer and add no wrapper flush. Public borrowed-file ownership stays with
the caller. Windows path opening and closing keep their previous behavior.

**9,792 returning records / 19,584 public calls** match in both modes, SHA-256
`666e219554bee00361c39fc88e367143b44f1f7656813dee05e7e4af736121e0`.
All seventeen encoder arms, eight initialized 4×2 storage profiles, capacities
0/8/32, both APIs, four path kinds and umasks 000/022/077 are covered. The paths
are newly created files, existing files, relative symlinks to existing files and
hard links to existing files. Existing files start with 256 initialized bytes and
mode 0640. Each wrapper repeats twice without resetting its caller buffer.

New files use 0666 filtered by the supplied umask; existing files keep 0640.
Creation/truncation occurs before codec validation, including pinned no-op writers.
Links keep their kind, and both aliases expose the same rewritten/truncated bytes.
Returning snapshots compare no remaining owned path descriptor, target/link kind,
permissions, all caller buffer bytes, initialized image/pixels/active palette and
all target/backing bytes. Private stream cursors, pending lengths, codec state,
inactive storage and allocator effects remain unobserved.

**144 returning controls**, SHA-256
`aed2f32a9dd98f56f7ea0340764fff5445837c0a291a893bf5b8913500bf2c66`,
and **72 exact panic/state pairs**, SHA-256
`0fda43a6d11c4659af35eeb7c1a2a0b9431afb9beed8184bd9b85955b2dfa902`,
cover zero-width PNGs with RGB24/BGR24/invalid storage, capacities 0/8/32, both APIs,
all four path kinds and all three umasks. Source classifies every control. BGR24
and invalid storage return Unsupported before the generated-header assertion;
RGB24 reaches that assertion after opening/truncating the path. The sole native
panic is `reached unreachable code`. Failed exits, no stdout and equal nonempty
initialized states are required. Writer panic states verify close-on-exec,
write-only access, blocking mode and actual absence of that file in an exec child.
The still-open parent descriptor and all caller/image/disk state are retained.

**48 bounded reader-loop pairs**, ready-state SHA-256
`7aedf0063107a514c81a1573d529f2011fb0420febbbee72e2f5c9bfcceb1e77`,
cover reading/detection, managed/unmanaged paths, capacities 32/128, existing files,
symlinks and hard links, and umasks 000/022. Input is the initialized define line
from the earlier XBM loop proof. The native detector repeatedly peeks without
consuming that line. A fixture watcher observes the opened descriptor's flags and
exec behavior; both parents remain alive after readiness with no stdout/stderr,
then are killed. Ready states verify close-on-exec, read-only access, blocking mode
and retained file kind/0640 permissions. These loops are separate from returning
observations and do not certify successful XBM decoding.

C only creates/observes owned resources and invokes real fork/exec; it does not
replace image, file or stream operations. Observers locate the owned target inode
among descriptors 3–127 before opening any state/observation file. Descriptor,
process and inode identities are excluded. Exec children check the inherited
number against the parent's device/inode before opening paths and report only
whether that owned file survived. All argv storage is prepared before fork; the
fork child executes only exec/_exit. Watchers report flags before writing their
ready file, and buffer/codec state is deliberately omitted from asynchronous ready
snapshots. Fixture umasks are local to each isolated process and restored before
normal cleanup/state-file creation. Loops remove only their own known paths after
termination. No case directories survive completed comparisons.

A consumer regression pins open flags, access modes, creation permissions and raw
descriptor buffered writes/reads across all twelve path/umask combinations.
Twenty-four focused public PNG records / 48 calls match per mode. All 61 image
and 58 Vaxis test files pass with production image/file tests and nineteen
application/platform/unit/fixture checks. Historical path-error and FIFO suites
retain all their previous returning/control/failure hashes in both actual Source
optimization modes. Formatting, diff and Python checks pass.

Full Source/library/DEFLATE/math/SIMD/fs.Dir/libc/version and before/after
implementation/fixture/runner/helper/input hashes protect final comparisons.
Ordinary observations supply fixed production/reproduction hashes; only their
golden assignments change afterward. Persistent evidence is independently replayed
and archived with every member read back.

Controlling-TTY acquisition, other open flags, close errors, signals/EINTR injection,
concurrent external descriptor/namespace mutation, other modes/ACLs/umasks/encodings,
quotas/OOM/disk exhaustion, full-pipe backpressure, other CPU/vector selections,
const/narrow/enum/boxed representations, physical layouts, big-endian/32-bit runtime
and portable ABI remain boundaries. The watcher observes the owned descriptor
while it is live; no timing/race equivalence is claimed. Linux/Windows cross builds
establish compilation only, and Windows path/runtime parity remains unclaimed.
