# Short, remaining and 64-bit reader discards

`ReadStream.discard_short(usize)` translates pinned Reader.discardShort: it
returns the consumed prefix at EOF and propagates ReadFailed with progress
retained. The proposed buffered cursor is checked for unsigned overflow before
mutation. `discard_remaining()` translates Reader.discardRemaining and returns
the total consumed when the callback reports EOF. `discard_all64(u64)` translates
Reader.discardAll64: it consumes target-usize chunks and reports EndOfStream on
a short chunk. Its zero-count path performs no IO. Existing reader bodies and
C adapters are unchanged; all64 calls the newly checked short-discard path.

A positional file callback can keep returning zero after its cached size is
exhausted. Source's enclosing discard loops then keep running. These methods
preserve that behavior. In particular, `discard_remaining` is not guaranteed to
return for a positional file, and an oversized positional short/all64 discard
can loop. EOF discovered by a streaming read follows the returning path.

## Reproduce

```sh
python3 zigimg/verify_reader_discard_short_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_discard_short_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

Source is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, with Zig 0.15.2
and V 0.5.2. Ordinary pairs Debug with V ordinary; production pairs ReleaseSafe
with `-prod`. Target defaults to `aarch64-macos.14.0`. The runner supplies VEXE
and V_C_ERROR_BUG_REPORT_DISABLED=1, owns temporary directories/caches and retains
argv, inputs, outputs and provenance. Full unchanged Source tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected stdlib, including mem/Reader/Writer/File/posix, SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Selected math/simd/path libraries, versions, implementation, probes, shared
fixtures, directly imported helpers and inputs are checked before/after
comparison. Source bodies, visibility and reader syscalls remain untouched.

## Returning records

Both modes match **24,400 records / 73,200 discard calls / 170,800 primary
calls**. Each record performs three discards, three caller consumptions and one
relative seek; setup, priming and observations are separate calls. Groups contain
20,508 basic, 540 buffered, 1,840 streaming-pipe and 1,512 failed-prefill profiles.
Duplicate specifications are retained once in the first group. Basic profiles
cover memory, positional files and streaming-initialized files, lengths
0/1/7/8/9/31/32/33/127/128/129/257, file capacities 0/1/8/32, distinct start
positions and relative offsets -1/0/1. Counts include 0/1/7/8/31/32/127/128/129/512
and maximum u64 where finite. Positional profiles request only available input;
remaining-discard and oversized positional cases are observed separately below.
Memory cases whose proposed cursor overflows are controls rather than returns.

Buffered profiles peek and optionally toss all read-ahead before discarding.
Streaming pipe profiles cover open/closed writers, capacities 0/1/8/32 and seed
lengths through 257. Failed-prefill profiles retain initialized pending bytes
across unsuccessful positional-to-streaming reconciliation, with capacities 8/32,
start offsets 0/1, initial consumption 1/7, open/closed pipes and priming choices.

Complete initialized storage, saved successful counts, pending spans, logical
positions, size/errors, descriptor ownership and untouched wire bytes match.
Discard never changes caller backing storage. An independent count/progress
model checks every nonreplacement operation, distinguishing physical descriptor
progress from the reported position. Existing relative seeks can rewind buffered
bytes or adjust the reported streaming position without moving the descriptor.
Returning output SHA-256 (joined lines without a trailing newline):
`ecc351a0a2d9bc3950ea56395b793ee57a386872bad3a785cc7a4eeba67a7c7f`.

Inputs are:
`kind|warmup|capacity|start|consume-mode|payloadhex|replacement|consumed|seed|prime|delta|op|count|later-count`.
Kinds 0/1/2 select memory/positional/streaming files; ops 0/1/2 select short,
remaining and all64. Warmup 1 pre-fills before descriptor replacement. Prime 1
peeks the capacity; prime 2 additionally tosses buffered input. Count applies
to the first operation and later-count to the next two; remaining ignores both.
The ten output parts retain initial/primed state, three operation/consumption
pairs, relative seek and wire data. Snapshots contain
`status|position:size-or-error:valid:refs|backinghex|saved-decimal-count|pendinghex`.
Failed calls retain the last successful count in the fixture.

## Controls, bounded loops and consumers

The **204 distinct controls** classify as **102 returning records**, SHA-256
`ca5d8060fc2a563278f156c237cc7e17f6b71d4564f72b9ea6df0d357649f9ef`,
and **102 exact integer-overflow panic/state pairs**, SHA-256
`16372345d783cbd6f5a09a534e2238e5da3b006d4ab3544c483b58176eda1d31`.
Six memory and twelve prefilled streaming controls overflow the proposed cursor
before discard mutation. Another 84 fail in public getPos after priming, before
the requested discard. Both exits fail with empty stdout, one exact message and
matching initialized state. Observers omit getPos and capture preceding/calling
status, size/errors, backing storage, saved output, pending bytes and owned
references before opening state files. Source FullPanic and V at_exit clean up
only owned resources.

Twelve additional paired bounded observations per mode cover positional files
of length 0/7, capacities 0/8 and all three APIs. Short/all64 request length+1;
remaining drains without a bound. The `--loop STATE SPEC` fixture writes a
checkpoint immediately before the first discard. Both owned child processes
reach that checkpoint, remain alive with empty stdout/stderr for at least one
second, then are killed by their parent. State, binary hashes, argv, timings,
exit signals and ownership are independently replayed. This is a bounded
observation, not a proof of indefinite execution. These intentionally terminated
children are recorded separately from successful comparison commands. The
retained `loop_checks.py` harness and receipts are in the checkpoint evidence.

Twenty-one compiled consumer records / 63 discards / 147 primary calls per mode
assert all three results for EOF prefixes, exact/zero/maximum counts, rewind,
buffered and unbuffered streaming drains, 257-byte input, positional read-ahead,
closed-pipe EOF, partial read failure and buffered success after sticky failure.
SHA-256: `7aa3f51f3edab2704ba2268780d6ed7c5f9c01b6c2a35708d6bcdca07b3c6986`.
Three public regression tests accompany the proof. All 73 image and 58 Vaxis
test files pass, with 55 production/application/platform/unit/fixture checks.
Historical callback-discard, buffered-reader and full-stream matrices retain
their previous hashes in both modes.

## Evidence and boundaries

Initial development evidence retains an unsigned-overflow case incorrectly put
in the returning corpus, and a model assertion that treated streaming logical
rewind as descriptor movement. Native and translated outputs agreed in the
model failure. Consumer diagnostics retain expectations corrected for buffered
rewind and position changes during failed reconciliation. All original runners,
outputs and diagnostics remain separate from passing final gates. Production,
probes, runner and helpers remain frozen during final comparisons; only expected
assignments change after ordinary discovery.

Fixtures separately copy/hash the exclusive-payload and descriptor-replacement
helpers. They use initialized unlinked O_EXCL/CLOEXEC files, reset live offsets,
and owned nonblocking pipes/keepers below descriptor 128. Lossless parent-side
compression pins raw and compressed logs. Independent replay checks counts,
progress, native classification, exact retained failures, consumers, bounded
loop observations, binaries, modes and provenance. Evidence is persisted from
a task-owned RAM workspace and every archive member is read back before commit
and release of that volume.

The native comparison uses 64-bit usize; multi-chunk all64 on 32-bit targets is
outside the runtime proof. Remaining-count overflow is checked explicitly but
not reached by these finite fixtures. Arbitrary custom callbacks, overlapping
storage, arbitrary constructor/copy sequences, other devices, larger buffers/
offsets, concurrent reuse, syscall counts, timing/signals beyond the stated
bounded observations, injected errors, OOM/quotas, allocator lifetime, portable
ABI and V representation limits remain boundaries. Existing scalar discard
fallbacks can use different syscall counts from Source's vector trash reader.
Windows/Linux and other CPU, big-endian and 32-bit runtime are outside this
native comparison. Cross builds establish compilation only.
