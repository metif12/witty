# Reader discard caches and physical seek transitions

`verify_stream_discard_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and V 0.5.2 on native
little-endian `aarch64-macos.14.0`, linked with libc. Source Debug/V ordinary and
Source ReleaseSafe/V production both execute the complete comparison.

```sh
python3 zigimg/verify_stream_discard_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. Commands default to a 600-second
limit. Evidence retains complete Source, fixtures, C helpers, inputs, binaries,
commands, raw records, panic snapshots and provenance. TMPDIR/VTMP are task-owned.

A regular-file reader caches its 2,048-byte size and seeks to a valid offset.
An owned dup2 replaces its descriptor with a nonblocking pipe; a slice read or
buffered take exercises the streaming transition. The descriptor then either
stays on that pipe, is replaced with another owned regular file, or is invalidated.
Two discard/read pairs keep the same reader and retained caller bytes. Cached
size/error state remains associated with the reader across descriptor replacement.

V previously always read discarded bytes in streaming mode. Source first uses
physical seeking when its size and seek error caches are both clear. Its cached
size can allow a discard to seek past the replacement file's actual EOF. The
first retained mismatch restores an empty regular file after reading one pipe
byte: Source discards one byte successfully at logical position two, while V
returns EndOfStream at one. Original production/binaries/raw records remain
retained. The adapter now preserves the pinned cache-selected positional/streaming
callbacks, physical relative seek, failed-seek cache and subsequent read fallback.
Nonregular size classification also switches to streaming as pinned getSize does,
while preserving an already failed reader mode.

Discard first consumes available read-ahead. Native callbacks leave caller buffer
bytes intact, preserve partial physical progress and return ReadFailed or
EndOfStream through the public API. EOF discovered by an actual read replaces the
cached size with the reader's logical/physical progress; it need not equal the
replacement file's filesystem length. A failed relative seek selects read-based
discard for later calls. Ordinary discard read errors do not overwrite that seek
error cache, preserving later cached backward-seek behavior. BADF in a real
relative seek retains the exact Source unreachable panic in production; bad reads
remain normal errors. Positional and cached-size zero-progress behavior remains
pinned, including the existing overlong-discard loop boundary.

**5,670 returning records / 28,350 primary discard/read operations** match in
both modes, SHA-256
`246d51acc2d05fe89a6e17b65045d2712a2190092ffce3dbda8b2dbea3eea1f7`.

| Returning group | Records |
|---|---:|
| Retained pipe descriptor | 1,134 |
| Restored regular-file descriptor | 4,536 |
| **Total** | **5,670** |

Both slice and take readers cover capacities 0/1/8/32 (take needs capacity at
least one), initial offsets 0/1/7 and one-byte requests. Seeds are offset plus
capacity plus one or 64 bytes. The writer stays open with no refill, stays open
with a 64-byte refill before the second pair, or closes before IO. Restored files
have lengths 0/1/7/32 and a distinct initialized byte pattern. Discard lengths
0/1/7/8/31/32/127/128/129 cross buffer and trash-read boundaries. All supplied data
fits the pipe. Each record has one initial read and two discard/read pairs;
counts exclude setup/initial seek/replacement/seeding/observers.

Restored-file rows use a zero-length second discard: after EOF updates cached size,
a positive discard with clear error caches can enter Source's zero-progress loop.
The suite excludes that loop from its returning cases and preserves the existing
production behavior. All selected initial reads have enough queued input; this
checkpoint focuses on the subsequent discard decisions, partial failures and
continued reads. Source buffering, output/error order, logical positions, cached
sizes and final queued bytes match. Restored regular files seek from offset zero;
kept pipe bytes remain available to the independent pipe observer.

**74 returning controls**, SHA-256
`90fcdce2d152e8ee86ccf2070037b24437d4a22fb3bdcafa0d1b87d1ccf0ba27`,
and **16 exact panic/state pairs**, SHA-256
`7b0280bf2fed359b3beb86648617888810e6ab9405b368328e1da3c767e023e4`,
classify actual invalidation after the first read. Cases cover both APIs,
capacities 1/8/32, offsets 0/1/7 and discard lengths 0/1/7/8/32. Each classification
comes from Source. Buffered operations can still succeed after invalidation;
cached seek errors select ordinary bad-read failures, while uncached relative
seeks on BADF panic. Failed pairs require failed exits, no stdout, one exact native
diagnostic and equal nonempty initialized state. The target is invalid, with only
two keeper endpoints live. Original native traps where V returned normally remain
retained. Observers capture state before opening state files.

Rows contain ten fields:
`operation|capacity|initialOffset|request|seedLength|closedWriter|refillLength|discardLength|restoredLength|invalidateAfterRead`.
Operation is slice (0) or take (1); restoredLength -1 keeps the pipe. Records are
`initial~initialRead|state~rebound|state~firstDiscard|state~firstRead|state~secondDiscard|state~secondRead|state~drain:queuedHex`.
Snapshots are `logical:cachedSize:descriptorValid:pipeRefs|bufferHex|outputHex|pendingHex`.
Endpoint references count matching descriptors 0–127 across both owned pipe
identities once each. Restoring a regular file removes the target from those pipe
references. Raw descriptor/device/inode identities, private mode/error/cursor
fields, inactive storage and allocator effects are excluded.

C creates initialized O_EXCL/CLOEXEC 0600 regular files and unlinks their names
immediately, creates nonblocking pipe endpoints, replaces/invalidates only the
owned target, seeds/closes owned input and observes final pipe bytes. Restored-file
bytes use `(index * 37 + 19) & 255`; pipe input uses `(index * 31 + 7) & 255`.
The restored descriptor starts at physical offset zero. No Source body/visibility
or image syscall is changed/intercepted. Cleanup skips an already invalid target
and closes only owned resources in these controlled cases; no case paths survive.
Controlled replacements/invalidation establish no concurrent race equivalence.
V uses bounded scalar discard reads; Source can use multiple trash vectors.
Syscall counts and timing remain outside this comparison.

Consumer regressions pin successful cached-size seeks beyond actual EOF,
failed-seek cache retention after invalidation, consumed read-ahead, partial
EOF/WouldBlock progress and later recovery. A further regression starts without
a size query, reads one regular-file byte, replaces the descriptor with an empty
live pipe and enters sticky ReadFailed. A nonregular size query returns Streaming
without reviving the reader. Seeding four bytes leaves the next read failed and
all four queued bytes untouched. A retained supplemental native/V fixture checks
the exact record `ReadFailed|Streaming|ReadFailed|0|07|4:07264564` in both modes;
its complete unchanged Source, setup helpers, eight commands, binaries and hashes
are independently checked with the main evidence. Nine compiled consumer records /
45 primary operations match per mode. All 65 image and 58 Vaxis test files pass,
with 31 production/application/Linux/Windows library/unit/fixture checks.
Cross builds establish compilation only. Historical full-stream/baseline/
171-streaming hashes remain unchanged, as do seventeen historical trap pairs and
four compile-rejection pairs. The 3,723 absolute-seek records/54 controls/18 exact
panic-state pairs, 2,139 forward-transition records and 994 guard records/155
exact panic-state pairs retain prior hashes in both actual Source modes.

Formatting, diff and Python checks pass. Complete Source/selected std library/
math/SIMD/fs.Dir/libc/version and before/after implementation/fixture/runner/helper/
input hashes protect comparisons. Ordinary discovery supplies fixed production
goldens; only golden assignments change afterward. Independent replay checks raw
native classifications, exact failures, original EOF/trap mismatches, ownership,
actual modes and provenance. Persistent archives are read back member by member.
An earlier passing archive predates the failed-mode guard and remains retained
separately. All comparisons, consumer/module tests and platform checks were rerun
after that guard; final evidence uses the final implementation hashes.
The shared disk filled during a Windows check. Its exact failed log remains
retained; only this task's completed compiler temporaries were removed, and the
failed/remaining checks were rerun. No unrelated process/cache was changed.

Overlong positional/cached-size loops, larger or additional discard/seek/constructor/
copy sequences, unknown size/error caches beyond those stated, other devices,
prior original-file read-ahead at replacement, concurrent replacement/reuse races,
syscall counts, timing/backpressure/signals, injected errors, OOM/quotas/durability,
Windows runtime, other CPU/vector selections, const/narrow/enum/boxed representations,
physical layouts, big-endian/32-bit runtime and portable ABI remain boundaries.
The proof extends the stated native discard contract without certifying every
translation contract.
