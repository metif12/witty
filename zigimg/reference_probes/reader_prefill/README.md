# Original-file read-ahead and checked reader positions

`verify_reader_prefill_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and V 0.5.2 on native
little-endian `aarch64-macos.14.0`, linked with libc. Source Debug/V ordinary and
Source ReleaseSafe/V production both execute the full comparison.

```sh
python3 zigimg/verify_reader_prefill_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. The default command limit is
600 seconds. Evidence retains complete Source, fixtures, helpers, inputs, binaries,
commands, raw records, panic snapshots and provenance. TMPDIR/VTMP are task-owned.

A reader caches an initialized regular file's 2,048-byte size, fills its complete
caller buffer and consumes a selected prefix before its descriptor is replaced
with an owned nonblocking pipe. Slice, take or peek reads retain that original
read-ahead. Each record performs two reads separated by the pinned public seekBy
workaround. Optional new input arrives before the second read. Position and size
queries, complete caller/output/pending bytes, descriptor ownership and queued
pipe input are observed after each stage.

An incomplete buffered transition can preserve original pending bytes while
resetting physical progress and consuming fewer pipe bytes than that pending
span. The read returns ReadFailed. A subsequent public getPos query subtracts
pending length from physical progress: Source traps with `integer overflow`, while
V previously wrapped the subtraction. The retained witness reported
`18446744073709551609` in V with seven original bytes pending and zero physical
progress. The adapter now explicitly checks that subtraction in production.
Original binaries, all matching returning records and the native trap/V return
with equal initialized state after removing the wrapped position remain retained.

The read itself and the position query are separate operations. Panic observers
omit getPos to avoid repeating the failing query. They record the completed read's
status, cached size, live owned endpoints, initialized buffers and pending bytes
before opening state files. No Source bodies or visibility are changed.

**11,016 returning records / 33,048 primary read/relative-seek operations** match
per mode, SHA-256
`ad50b8ebce3e3330db7e29937de9116ef3d56a1d6c136337efffc0ff1d5cd1c7`.

| Returning group | Records |
|---|---:|
| Slice reads | 4,104 |
| Buffered take | 3,456 |
| Buffered peek | 3,456 |
| **Total** | **11,016** |

Capacities are 1/8/32, initial offsets 0/1/7 and distinct consumed prefixes
0/1/capacity-1/capacity. Requests include zero, one, remaining read-ahead and the
next byte; slice requests also exceed capacity, while take/peek remain within it.
Pipe seeds are capacity or offset+capacity+request+capacity+3 bytes. The keeper
writer stays open with no refill, stays open with a 64-byte refill or closes before
reading. Relative offsets are -capacity/-1/0/1/capacity/capacity+1. Each record
counts two reads and one relative seek; setup, initial seek/prefill/consumption,
replacement and observer queries are excluded.

Slice reads can copy the original prefix into output before switching to pipe
input. Take/peek commit output only on success. A successful transition clears
old read-ahead; an incomplete one can retain original bytes and sticky failure.
Those retained bytes remain accessible without native IO. Additional pipe input
then stays queued when failure prevents another refill. The public seekBy
workaround can move within retained read-ahead or clear it and adjust physical
progress, including a failed reader, without reviving native reads. These
returning behaviors already matched V and need no further production changes.

**264 returning controls**, SHA-256
`f5a0289faff11059b3c0e97d22acc89ae70eea6a5f377f9f0da73f73f2e1c536`,
and **216 exact position-panic/state pairs**, SHA-256
`c7b00399cd5c848b7ce2694e3ae5f948b8c1e2652ccb04c84dcd1c1f817c6846`,
classify 480 retained-buffer cases from Source. Controls cover take/peek,
capacities 8/32, offsets 0/1/7, consumed prefixes 1/capacity-1, a request one byte
larger than remaining read-ahead, distinct seeds 0/pending-1/pending/offset+capacity-1,
both actual EOF and WouldBlock, and relative offsets -1/0/1. Open writers provide
64-byte refill if the first position query returns. Returning controls reach all
later stages. Failed pairs require failed exits, no stdout, one exact native
diagnostic and equal nonempty initialized state. Every failed snapshot records
ReadFailed, a valid target and either three pipe references or two after the
keeper writer closes. This is checked position arithmetic, not a descriptor trap.

Rows contain nine fields:
`api|capacity|initialOffset|consumedPrefix|request|seedLength|closedWriter|refillLength|relativeOffset`.
API 0 uses readSliceAll, 1 uses take and 2 uses peek. Records are
`original~rebound|state~firstRead|state~seekBy|state~secondRead|state~drain:queuedHex`.
Snapshots are `logical:cachedSize:descriptorValid:pipeRefs|bufferHex|outputHex|pendingHex`.
Panic snapshots omit logical position and start with the preceding operation's
status: `status|cachedSize:descriptorValid:pipeRefs|bufferHex|outputHex|pendingHex`.

C creates/unlinks an initialized private O_EXCL/CLOEXEC 0600 regular file, creates
nonblocking pipe endpoints, replaces only the owned target, seeds/closes owned
input and observes final queued bytes. Original file bytes use
`(index * 37 + 19) & 255`, and pipe bytes use `(index * 31 + 7) & 255`, so their
origins remain distinguishable. Endpoint references count matching descriptors
0–127 across both owned identities once each. Raw identities, private mode/error/
cursor fields, inactive storage and allocator effects are excluded. No stream
syscall is replaced or intercepted. Cleanup closes only owned resources; no case
paths survive. Controlled replacement establishes no concurrent race equivalence.
V's bounded scalar transition discard and Source's trash vectors are compared by
public effects; syscall counts and timing remain outside the proof.

Three consumer regressions and nine compiled records / 27 primary operations per
mode pin mixed original/pipe output, preserved pending bytes, valid failure
positions, sticky retries and the pinned seekBy workaround. The first test run's
compound byte-read assertions remain retained; final tests store byte reads in
locals before checking positions. All 67 image and 58 Vaxis test files pass, with
37 production/application/Linux/Windows library/unit/fixture checks. Cross builds
establish compilation only. Historical full-stream/baseline/171-streaming hashes
remain unchanged; seventeen historical trap pairs and four compile boundaries
still pass. Writer-seek, discard, absolute-seek, forward-transition and guard
matrices retain all previous returning/control/panic-state hashes in both actual
Source modes.

Formatting, diff and Python checks pass. Complete Source, selected compiler
libraries, math/SIMD/fs.Dir/libc, versions, before/after implementation, fixtures,
runner, helpers and inputs are hashed. Only golden assignments change after
ordinary discovery. Independent replay checks raw native classifications, exact
failures, the original wrapped position, ownership and actual modes. Persistent
archives are read back member by member.

Other devices, larger offsets/requests/buffers, additional constructor/copy/seek
sequences, concurrent replacement/reuse races, timing/backpressure/signals,
injected errors, OOM/quotas/durability, Windows runtime, other CPU/vector selections,
V representation/layout limits, big-endian/32-bit runtime and portable ABI remain
boundaries. This proof establishes the stated native read-ahead and position
contracts without certifying every translation contract.
