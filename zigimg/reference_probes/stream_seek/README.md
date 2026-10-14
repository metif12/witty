# Absolute reader seeks after streaming transitions

`verify_stream_seek_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and V 0.5.2 on native
little-endian `aarch64-macos.14.0`, linked with libc. Source Debug/V ordinary and
Source ReleaseSafe/V production both execute the complete comparison.

```sh
python3 zigimg/verify_stream_seek_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. Commands default to a 600-second
limit. Evidence retains complete Source, fixtures, C helpers, inputs, binaries,
commands, raw outputs, panic snapshots and provenance. TMPDIR/VTMP are task-owned.

An initialized regular-file reader caches its 2,048-byte size and seeks to a
valid offset. An owned dup2 replaces its descriptor with a nonblocking pipe.
One slice read or buffered take exercises the positional-to-streaming transition,
then two absolute-seek/read pairs use the same reader and retained buffer.
The writer can close before IO or receive a known refill before the second pair.
All queued data fits the pipe. EOF and WouldBlock occur through actual IO.

V previously implemented absolute streaming seeks by changing its logical cursor.
Source tries a relative seek when no error is cached, then discards forward from
the descriptor when seeking is unavailable. The first retained mismatch seeks
one byte forward on an empty live pipe: Source returns ReadFailed at position
zero while V returns success at position one. Original production files, binaries
and every raw record remain retained.

Absolute forward seeks now preserve Source's discard, cache and buffer behavior.
A successful forward seek clears read-ahead even for a zero delta. With read-ahead,
Source calculates the delta from the logical position but discards from the live
descriptor, then clears the buffer. Its resulting position can therefore exceed
the requested target; that pinned behavior is preserved. Discard does not overwrite
the caller buffer. Incomplete seeks retain consumed progress and buffered bytes,
return native ReadFailed/EndOfStream, and cache the error without making ordinary
streaming reads permanently failed. Buffered reads can still succeed immediately
after a failed seek. Backward seeks reuse cached errors; otherwise they perform
the real absolute seek. BADF in either real seek reaches the exact unreachable
panic, including production. Constructor and initial-transition seek-error caches
now match the pinned implementation. The source-specific public seekBy workaround
and writer behavior remain unchanged.

**3,723 returning records / 18,615 primary seek/read operations** match in both
modes, SHA-256
`f365c69739adcd9fa283f598ebae0e7b44d9373990dc31c5b59fd00cd52b17a9`.

| Returning group | Records |
|---|---:|
| Slice reads and absolute seeks | 2,172 |
| Buffered take and absolute seeks | 1,551 |
| **Total** | **3,723** |

Capacities are 0/1/8/32, initial offsets 0/1/7 and requests 0/1/7, with take requests
bounded by capacity. Seed lengths include zero, the initial offset, offset minus
one, offset plus request, and offset plus request/capacity/seventeen, deduplicated.
The writer stays open with no refill, stays open with a 32-byte refill, or closes
before IO. Targets include zero, the initial offset, offset plus request, that
value plus one, offset plus capacity/nine, and the rejected cached-size boundary
2,048. Each record has one initial read and two seek/read pairs. Counts exclude
setup, initial regular-file seek, replacement, seeding, invalidation and observers.
Initialized buffers/output, pending bytes, logical position, cached size and final
queued bytes match. Size-boundary rejection precedes any descriptor seek.

**54 returning controls**, SHA-256
`8b8a116ddcdf4dd8bb4dc21b5683c93c1b241e7d3c93d886b2b4846f3a42ed54`,
and **18 exact panic/state pairs**, SHA-256
`9ba3deb229406c324040ccad45fa2942e76a058be21954b7a9b34e455fc5d932`,
classify actual descriptor invalidation after the first read. Cases cover both
read APIs, capacities 1/8/32, initial offsets 0/1/7 and targets 0/1/7/2,048. Source
classifies every case. An uncached real seek on the closed descriptor panics;
cached errors or the size guard can return before another seek, and buffered
bytes can remain readable. Failed pairs require failed exits, no stdout, one exact
native diagnostic and equal nonempty initialized state. The closed descriptor is
invalid, and only the two keeper endpoints remain live. Observers capture state
before opening the observer file, preventing its descriptor reuse from changing
the recorded ownership. Original backward/forward native traps where V returned
normally remain retained separately from final observations.

Rows contain nine fields:
`operation|capacity|initialOffset|request|seedLength|closedWriter|refillLength|target|invalidateAfterRead`.
Operation is slice read (0) or buffered take (1). Normal records are
`initial~initialRead|state~firstSeek|state~firstRead|state~secondSeek|state~secondRead|state~drain:queuedHex`.
Snapshots are `logical:cachedSize:descriptorValid:pipeRefs|bufferHex|outputHex|pendingHex`.
Pipe references count matching descriptors among 0–127 across both owned endpoint
identities, counting each descriptor once. Raw descriptor/device/inode identities,
private mode/error/cursor fields, inactive storage and allocator effects are excluded.

C creates an initialized O_EXCL/CLOEXEC 0600 regular file, immediately unlinks it,
creates nonblocking pipe endpoints, replaces or invalidates only the owned target,
seeds/closes the owned writer and drains the owned reader after all operations.
It does not intercept seek/read/close calls or change Source bodies/visibility.
Fixtures call the real pinned image ReadStream and reader APIs. Cleanup skips an already
invalid target and closes only owned resources in these controlled cases; no case
paths survive. Controlled replacements/invalidation establish
no concurrency or reuse-race equivalence. V uses bounded scalar discard reads;
Source can use multiple trash vectors. Syscall counts and timing remain outside
this comparison. The original V fixture build lacking its global-variable flag
is retained; all final fixtures explicitly enable globals.

Consumer regressions pin zero-delta/forward read-ahead clearing and partial
EOF/WouldBlock seeks with readable retained bytes. Nine compiled consumer records /
45 primary operations match per mode. All 64 image and 58 Vaxis test files pass,
with 28 focused production/application/Linux/Windows library/unit/fixture checks.
Cross builds establish compilation only. Historical full-stream, baseline and
171-streaming hashes remain unchanged, as do seventeen historical trap pairs and
four compile-rejection pairs in both actual Source modes. The 2,139 forward
transition records and 994 guard records/155 exact panic-state pairs retain
all prior hashes. Historical checks retain their original scopes.

Formatting, diff and Python checks pass. Complete Source, selected std library,
math/SIMD/fs.Dir/libc/version and before/after implementation/fixture/runner/helper/
input hashes protect comparisons. Ordinary discovery supplies fixed production
goldens; only golden assignments change afterward. Independent replay verifies
raw native classifications, exact panic/state pairs, original cursor/trap mismatches,
ownership, actual modes and provenance. Persistent archives are read back member
by member.

Other devices, successful OS seeks after a streaming transition, prior original-file
read-ahead at replacement, additional seekBy/constructor/copy sequences, offsets
outside this matrix, concurrent replacement/reuse races, syscall counts, timing/
backpressure/signals, injected errors, OOM/quotas/durability, Windows runtime, other
CPU/vector selections, const/narrow/enum/boxed representations, physical layouts,
big-endian/32-bit runtime and portable ABI remain boundaries. This proof extends
the stated native seek contract without certifying every translation contract.
