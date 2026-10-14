# Forward stream transitions after descriptor replacement

`verify_stream_transition_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and V 0.5.2 on native
little-endian `aarch64-macos.14.0`, linked with libc. Both Source Debug/V ordinary
and Source ReleaseSafe/V production execute the full comparison.

```sh
python3 zigimg/verify_stream_transition_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. Commands default to a 600-second
limit. Evidence retains complete Source, fixtures, C helpers, inputs, binaries,
commands, raw records and provenance. Compiler temporaries use owned TMPDIR/VTMP.

An initialized regular-file stream seeks to a valid offset, then a controlled
dup2 replaces only its owned descriptor with a pipe endpoint. The stream keeps
its logical state and the reader's cached regular-file size. Native positional
IO returns Unseekable. A reader switches to streaming, resets physical progress
to zero, tries a relative seek and, when the pipe rejects that seek, discards
input until it reaches the previous offset. A writer at a nonzero offset fails
its required seek and keeps failure mode. No stream is reconstructed after dup2.

V previously returned ReadFailed without reconciling the reader offset, retained
the old position and allowed subsequent reads to continue from the pipe start.
The original comparison retains all records/binaries and the old production
files; the first mismatch is offset one with no queued input. Both read shims now
report a distinct nonzero transition result to the adapter. The adapter performs
the pinned relative-seek/forward-discard behavior, preserves consumed progress,
records EOF size when encountered during discard, and keeps subsequent native
reads failed after an incomplete transition. Cached seek errors remain available
through the public seek route. Existing writer transitions remain unchanged.

A second retained comparison found eighteen buffered refill differences: after
a short read was fully consumed, V appended into unused tail capacity while
Source's native refill reset the exhausted buffer and used its whole capacity.
`peek` now preserves that reset, including production. A named read count avoids
mixing a buffer-end update with a refill that can reset stream state.

**2,139 returning records / 4,278 primary read/write operations** match in both
modes, SHA-256
`a5fb388fa0b56a2886ffab8bca89af550c69db9782719e267d8353b10a1e450a`.

| Record group | Count |
|---|---:|
| Direct slice readers | 1,068 |
| Buffered take readers | 783 |
| Single write calls | 144 |
| Write-all calls | 144 |
| **Total** | **2,139** |

Reader capacities are 0/1/8/32; offsets are 0/1/7/127/128/129 within the initialized
2,048-byte regular file; requests are 0/1/7 bytes, with take requests bounded by
capacity. Seed lengths are distinct values from zero, one, offset minus one,
offset, offset plus request, and offset plus request/capacity/three. The pipe
writer either remains open with no extra input, remains open and gets a known
refill before the second call, or closes before the first call. All supplied
input fits the pipe; both endpoints are nonblocking so incomplete input yields
an actual WouldBlock rather than waiting. EOF and WouldBlock are separately
observed through native results and cached size. Partial output, retained prefixes,
read-ahead and queued bytes match. A failed nonzero transition remains failed
after new input arrives, leaving that input queued. Zero-offset read failures can
retry normally. Buffered take commits output only on success; slice failures can
leave a native partial prefix in caller output.

Writer cases cover the same offsets/capacities/lengths, write versus writeAll,
and optional explicit flush after each call. Each record performs two primary
operations with retained buffers. The primary-operation count excludes setup,
seeks, optional flushes and observer calls. Zero-progress mode transitions,
nonzero seek failure, later buffered appends, pending bytes, logical positions,
flush errors and emitted bytes retain their native behavior. A failed writer can
still accept bytes that fit its caller buffer before another failing flush.

Rows contain eight fields:
`operation|capacity|offset|request|seedLength|closedWriter|refillLength|flush`.
Operations are slice read (0), buffered take (1), single write (2), and writeAll
(3). A record is `initial~status:result|afterFirst~status:result|afterSecond~drain:queuedHex`.
Snapshots are `logical:cachedSize-or-dash:descriptorValid:pipeRefs|bufferHex|outputHex|pendingHex`.
Only initialized bytes and public stream effects are observed. Live endpoint
references are counted among descriptors 0–127 using the two owned pipe identities;
Darwin assigns different identities to its read/write ends, while platforms may
share them. Each matching descriptor counts once. Original reference-normalization
failure evidence is retained separately from final comparisons.

C creates a private O_EXCL/CLOEXEC 0600 regular file with initialized bytes and
immediately unlinks its name. It creates a nonblocking pipe, replaces only the
owned file descriptor, seeds/refills/closes the owned writer and drains the owned
reader after both operations. It does not intercept positional/streaming IO,
replace library functions, or change Source bodies/visibility. Both fixtures call
the real pinned image ReadStream/WriteStream APIs; C cleanup closes only owned
handles. No case paths survive. Raw descriptor/inode identities, private cursors,
mode/error internals, inactive storage and allocator effects are excluded.
These are controlled descriptor replacements, with no concurrency or reuse-race
claim. V discards through bounded scalar reads while the pinned native reader can
use multiple trash vectors; syscall counts and timing are outside the observation
contract. Offset values cross the 128-byte discard boundary.

Consumer regressions pin successful slice/buffered offset reconciliation, EOF/
WouldBlock failure progress, sticky retries and whole-buffer refill. Nine exact
compiled consumer records / eighteen primary operations match per mode. All 63
image and 58 Vaxis test files pass, with 25 production/application/Linux/Windows
library/unit/fixture checks and focused consumer checks. Cross builds establish
compilation only. The historical 37,133-record full stream suite retains its
full/baseline/171-streaming hashes, seventeen historical trap pairs and four
compile-rejection pairs in both actual Source modes. The 994 stream guard records
and 155 exact panic/state pairs retain their hashes. The prior terminal proof
retains all returning/control/panic/calibration/mutation hashes in both modes.
Historical checks retain their original scopes.

Formatting, diff and Python checks pass. Complete Source, selected std library,
math/SIMD/fs.Dir/libc/version and before/after implementation/fixture/runner/helper/
input hashes protect comparisons. Ordinary discovery supplies fixed production
goldens; only golden assignments change afterward. Independent replay checks raw
records, native classifications, original offset and refill mismatches, ownership,
actual compiler modes and provenance. Persistent archives are read back member
by member. Earlier pipe-reference normalization and POSIX-section selection
failures remain retained; no production change was applied by that failed edit.

Concurrent replacement/reuse races, other devices/terminal disciplines, syscall
counts, timing/backpressure/signal interruptions, offsets beyond the stated matrix,
additional seek sequences and prior buffered data at replacement, injected errno,
OOM/quotas/durability, Windows runtime, other CPU/vector selections, const/narrow/
enum/boxed representations, physical layouts, big-endian/32-bit runtime and
portable ABI remain boundaries. This proof extends native stream behavior within
its stated scope; it does not certify completion of every translation contract.
