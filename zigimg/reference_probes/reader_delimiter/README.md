# Delimiter failure cursors and buffered rewinds

`verify_reader_delimiter_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and V 0.5.2 on native
little-endian `aarch64-macos.14.0`, linked with libc. Both Source Debug/V ordinary
and Source ReleaseSafe/V production execute the complete comparison.

```sh
python3 zigimg/verify_reader_delimiter_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. Commands default to a 600-second
limit. Evidence retains complete Source, fixtures, helpers, inputs, binaries,
commands, raw records, panic snapshots and provenance. TMPDIR/VTMP are task-owned.

A reader fills its caller buffer from an initialized 2,048-byte regular file and
consumes a selected prefix before an owned pipe replaces its descriptor. Peek or
take delimiter reads then share the same reader across a relative seek and retry.
Some cases first prime an incomplete buffered transition and consume all retained
original bytes. Native failure remains sticky, while those consumed bytes can
still be recovered through the pinned public seekBy workaround.

Source's failed refill returns before resetting a consumed buffer when tail space
remains. V previously reset that cursor before checking failure. Both could report
the same position immediately after the error, but a later relative seek exposed
the difference. The old comparison retains **252 differing records**. Its first
mismatch is `0|8|0|1|0|7|0|0|-1|1|1`: Source recovers original byte 16 (hex) as pending
data after seekBy(-1); V loses it. With delimiter 22 (decimal), Source's next peek
returns that byte, while V returns ReadFailed. The reset now respects failure mode
in ordinary and production builds. Full-buffer rebasing still follows Source.

**9,764 returning records / 29,292 primary operations** match per mode, SHA-256
`9e48675c882667881e058bbe10c41bad83a4ce6eb134448970df3da78fc31f35`.

| Returning group | Records |
|---|---:|
| Original read-ahead and ordinary transitions | 7,740 |
| Failed transition with pending original bytes | 756 |
| Failed transition after consuming original bytes | 756 |
| Both APIs across every delimiter byte | 512 |
| **Total** | **9,764** |

Cases cover peek/take, capacities 1/8/32, offsets 0/1/7, distinct consumed prefixes
0/1/capacity-1/capacity and markers in original data, pipe data and neither.
Ordinary seeds are capacity or offset+2*capacity+3. Primed failures use capacities
8/32, consumed prefixes 1/capacity-1 and seed length equal to pending length.
Keepers remain open with no refill, remain open with 64-byte refill or close before
IO. Relative offsets are -1/0/1. Every byte 0–255 also runs through both APIs.
Each record counts two delimiter calls and one relative seek; setup, initial
seek/prefill/consumption, optional failure priming/consumption and observers are
excluded. Returned bytes are copied before later operations invalidate borrowed
slices; the last successful copy remains after an error.

**264 returning controls**, SHA-256
`e953ff96c5268780593e0fe6c4cb318a897ad823e9ce45f3527aa234c80f9b4a`,
and **216 exact position-panic/state pairs**, SHA-256
`87f6fa3b0a377a66c68d279ebaee77ae5448782e91bdfdbf94d73dae93f8a6c0`,
classify 480 cases from Source. Controls cover both APIs, capacities 8/32,
offsets 0/1/7, consumed prefixes 1/capacity-1, absent delimiter zero, distinct seed
lengths 0/pending-1/pending/offset+capacity-1, actual EOF/WouldBlock and relative
offsets -1/0/1. A delimiter ReadFailed and subsequent getPos arithmetic panic are
separate outcomes. Failed pairs require failed exits, no stdout, one exact
`integer overflow` diagnostic and equal nonempty initialized state. Observers
omit getPos, record the preceding ReadFailed and snapshot before opening state
files. The target stays valid; there are three pipe references, or two after the
keeper writer closes.

Rows contain eleven fields:
`api|capacity|offset|consumedPrefix|delimiter|seedLength|closedWriter|refillLength|relativeOffset|primeFailure|consumePrimedBytes`.
API 0 peeks and API 1 takes. Records are
`original~rebound|state~primed-status|state~firstDelimiter|state~seekBy|state~secondDelimiter|state~drain:queuedHex`.
Snapshots are `logical:cachedSize:descriptorValid:pipeRefs|bufferHex|copiedResultHex|pendingHex`.
Panic snapshots start with the preceding status and omit logical position.

C creates/unlinks initialized private O_EXCL/CLOEXEC regular files, creates
nonblocking pipe endpoints, replaces only the owned target, seeds/closes owned
input and observes final queued bytes. Original bytes use `(index*37+19)&255`;
pipe bytes use `(index*31+7)&255`. Only initialized caller/output/pending bytes and
public stream effects are compared. References count descriptors 0–127 across
both owned pipe identities once each. Raw identities, private modes/errors/cursors,
inactive allocations and allocator effects are excluded. No Source body/visibility
or stream syscall is changed/intercepted. Cleanup closes owned resources; no case
paths survive. Controlled replacement establishes no concurrent race equivalence.

Consumer regressions cover EOF/WouldBlock rewinds, recovered peek/take results,
sticky retries and StreamTooLong without consuming queued input. Nine compiled
records / 27 primary operations match per mode. All 68 image and 58 Vaxis test
files pass, with 40 production/application/Linux/Windows library/unit/fixture
checks. Cross builds establish compilation only. Historical stream, original
read-ahead, writer-seek, discard, absolute-seek, transition and guard matrices keep
their previous hashes. The 87,419 XBM records / 181,446 calls and 24 bounded detector
loop pairs retain their returning and ready-state hashes in both modes.

Formatting/diff/Python checks pass. Complete Source, selected compiler libraries,
math/SIMD/fs.Dir/libc/version and implementation/fixture/runner/helper/input hashes
protect comparisons. Only golden assignments change after ordinary discovery.
Independent replay checks raw classifications, exact failures, both original
cursor/result mismatches, ownership and actual modes. Completed checks were reused
when the CLI interrupted later jobs; partial writer-check logs remain retained
separately. The XBM output save also hit a full shared disk; that failure remains
retained. Final XBM stdout logs are losslessly compressed, decoded during
independent replay and checked against raw-byte and compressed-file hashes. Only
this task's completed compiler caches were removed. Persistent archives are read
back member by member.

Larger buffers/offsets, other devices, additional constructor/copy/stream-callback
sequences, concurrent reuse, syscall counts, timing/backpressure/signals, injected
errors, OOM/quotas/durability, Windows runtime, other CPU/vector selections,
V representation/layout limits, big-endian/32-bit runtime and portable ABI remain
boundaries. This proof establishes the stated delimiter contracts without
certifying every translation contract.
