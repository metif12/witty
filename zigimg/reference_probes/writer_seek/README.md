# Writer seek failures and cached state

`verify_writer_seek_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and V 0.5.2 on native
little-endian `aarch64-macos.14.0`, linked with libc. Source Debug/V ordinary and
Source ReleaseSafe/V production both run the complete comparison.

```sh
python3 zigimg/verify_writer_seek_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. The default command limit is
600 seconds. Evidence retains complete Source, fixtures, helpers, inputs, binaries,
commands, raw records, panic snapshots and provenance. TMPDIR/VTMP are task-owned.

A writer starts on an owned regular file, seeks to an initial offset and has its
descriptor replaced with an owned nonblocking pipe's write end. A write or
writeAll, two seekTo calls, another write and a final flush retain the same writer
and caller buffer. Cases keep the pipe, restore an initialized regular file before
the first seek, or restore it between the two seeks. Controls invalidate the
descriptor before either seek. Replacement and invalidation affect only owned
handles, with no concurrent descriptor reuse.

Public seekTo flushes first. A failed flush returns Unexpected and leaves pending
bytes in place; it prevents the native seek. An uncached streaming seek on a bad
descriptor instead reaches Source's `reached unreachable code` panic. V previously
used a different panic message. That diagnostic now agrees in production as well
as ordinary builds. The original binaries, matching returning records and differing
panic diagnostics with equal retained state remain in the evidence.

Successful flushing can deliver bytes before a pipe seek fails. The cached
Unseekable then survives restoration of a regular descriptor. Later seeks still
flush pending data before returning that cached error. Restored streaming writes
start at the descriptor's actual offset zero, even when the writer's accumulated
logical position differs. Positional writes continue to use the writer's offset.
A failed nonzero positional-to-streaming transition remains sticky after restoring
a regular file. Writes that fit available buffer capacity can still append pending
bytes; subsequent flushing fails. These existing behaviors match Source without
further production changes.

**6,912 returning records / 34,560 primary operations** match per mode, SHA-256
`d699081654bf91d58ed1b37d948405fc432272988d3e3bef8c01202ff3bc277a`.

| Returning group | Records |
|---|---:|
| Retained pipe descriptor | 2,304 |
| Regular descriptor before first seek | 2,304 |
| Regular descriptor between seeks | 2,304 |
| **Total** | **6,912** |

Cases cover write/writeAll, positional/streaming constructors, capacities 0/1/8/32,
initial offsets 0/1/7, initial write lengths 0/1/7/33, first targets 0/1/7/32 and
second targets 0/1/7. Each record counts two writes, two seeks and a final flush;
setup, initial seek, replacement and observers are excluded. The pipe has room for
all selected output, and its keeper write end stays open. Native mode transitions,
including a single write's zero progress, are retained. Initialized caller bytes,
pending spans, logical positions, status/count order, regular-file contents and
delivered pipe bytes match.

**196 returning controls**, SHA-256
`15eabc88c22536fbf718742ae2fd76bb2e61afcd3f0ebb351413dc40b752689b`,
and **60 exact panic/state pairs**, SHA-256
`37687c2f4d80e44ec97553c62627a60667b3e48ef1017963da213a196785dbd7`,
classify 256 actual descriptor invalidations. Controls cover both write APIs and
constructors, capacities 0/1/8, initial offsets 0/1, distinct lengths 0/1/capacity+1,
first targets 0/7 and both invalidation phases. Source classifies every case.
Buffered writes, flush failures, positional seeks and cached errors can return
normally. Failed pairs require failed exits, no stdout, one exact native diagnostic
and equal nonempty initialized state: the target is invalid and only the two
keeper pipe endpoints remain. Observers snapshot before opening state files.

Rows contain nine fields:
`api|streamingConstructor|capacity|initialOffset|firstWriteLength|firstTarget|secondTarget|binding|invalidation`.
API 0 uses write, API 1 uses writeAll. Binding 0 retains the pipe, 1 restores before
the first seek, and 2 restores between seeks. Invalidation 1 or 2 closes the target
at the corresponding phase, overriding binding. Records are
`initial~firstWrite|state~rebound|state~firstSeek|state~rebound|state~secondWrite|state~secondSeek|state~flush|state~drain:pipeHex`.
Snapshots are `logical:descriptorValid:pipeRefs|bufferHex|pendingHex|regularFileHex`.

C creates initialized O_EXCL/CLOEXEC 0600 regular files and immediately unlinks
their names, creates nonblocking pipe endpoints, replaces/closes only the owned
target and observes file/pipe bytes. Restored files contain 32 bytes with pattern
`(index * 37 + 19) & 255`; first writes use `(index * 31 + 7) & 255`, and second
writes use D1/D2/D3. File observation uses pread without moving the descriptor's
offset. Normalized endpoint references count descriptors 0–127 across both owned
pipe identities once each. Raw identities, private modes/error/cursor fields,
inactive storage and allocator effects are excluded. No Source body/visibility or
stream syscall is changed/intercepted. Cleanup closes owned resources; no case
paths survive. The initial V fixture variable-redefinition failure remains retained.

Three consumer regressions and nine compiled records / 45 operations per mode
pin flush precedence, cached errors after restoration, delivered bytes and sticky
failure with pending bytes. All 66 image and 58 Vaxis test files pass, with 34
production/application/Linux/Windows library/unit/fixture checks. Cross builds
establish compilation only. Historical full-stream/baseline/171-streaming hashes
remain unchanged; seventeen historical trap pairs and four compile boundaries
still pass.
The discard, absolute-seek, forward-transition and guard matrices retain all prior
return/control/panic-state hashes in both actual Source modes.

Formatting, diff and Python checks pass. Complete Source, selected compiler
libraries, math/SIMD/fs.Dir/libc, versions, before/after implementation, fixtures,
runner, helpers and inputs are hashed. Only golden assignments change after
ordinary discovery. Independent replay checks raw native classifications, exact
failures, the original diagnostic mismatch, ownership and actual modes. Persistent
archives are read back member by member.

Larger offsets/writes, full-pipe backpressure and partial native writes, other
devices or error caches, original-file pending data before replacement, additional
constructor/copy/seek sequences, concurrent reuse races, syscall counts, timing,
signals, injected errors, OOM/quotas/durability, Windows runtime, other CPU/vector
selections, V representation/layout limits, big-endian/32-bit runtime and portable
ABI remain boundaries. This proof establishes the stated native writer-seek
contract, without certifying every translation contract.
