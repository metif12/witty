# Writer buffer access and cursor tracking

`WriteStream.unused_capacity_slice()` returns the borrowed bytes after pending
output, and `unused_capacity_len()` returns their usize length. Neither reserves
space nor drains the writer. `advance(count)` marks caller-initialized bytes as
pending; `undo(count)` rewinds pending output without changing the stored bytes.
These map pinned Writer.unusedCapacitySlice/unusedCapacityLen/advance/undo.

```v
mut space := writer.unused_capacity_slice()
space[0] = 17
writer.advance(1)
writer.undo(1)
```

Both views and caller storage share the same backing buffer. Saved slice headers
retain their original offset and length across cursor changes; later writes and
drains can overwrite their bytes. Keep the writer and its backing storage alive.
The caller initializes reserved bytes before advancing. Existing reader, writer
and C helper bodies remain unchanged.

Advance checks usize addition overflow, then capacity, before updating the
cursor. Undo checks subtraction underflow before updating it. Explicit checks
preserve the exact integer-overflow and capacity traps in V production builds.
Zero updates work with empty, full and closed-descriptor writers. These four
methods do not invoke a drain or rebase callback.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 18,780 | `ffd1e1efba45cba2338d104b5c38056127462b68fceb276955f8b302a0ed36e4` |
| Exact panic/state pairs | 308 | `4d07ca84c311b5dee2c4966301333f4e6778ccccacecea15a6577f15351446d3` |

Each record borrows two slices, queries capacity once, advances once and undoes
once: 37,560 slice borrows / 18,780 capacity queries / 37,560 cursor updates per
mode. There are another 12,492 explicit write/flush calls. Setup, prefix writes,
initial seeking and observation getters are separate. Groups contain 14,184
buffer profiles and 4,596 every-byte mutation profiles; duplicate inputs are
retained once.

Memory, positional/streaming files, capacities 0/1/8/16, starts 0/1/7, empty /
partial/full prefixes, zero/full/intermediate cursor counts, head/tail mutations,
all XOR byte values and owned pipe/closed-descriptor replacements retain Source's
initialized backing bytes, current spare/pending spans, saved view offsets and
bytes, logical position, descriptor ownership, file contents and pipe data.
The fixture mutates caller storage, a saved view, and the current spare view.
Optional writes/flushes verify that advanced output is emitted and undo excludes
rewound bytes. Closed-descriptor profiles finish without subsequent IO, so they
exercise buffer access and cursor changes on that state directly.

The independent model checks every buffer-only phase for every record. It checks
15,396 complete records, including ordinary file output, memory prefix failures,
flushes, positional first-vector behavior on macOS and closed-descriptor buffer
operations. For the other 3,384 pipe-output records, it checks all phases before
output; subsequent full states and wire bytes compare to Source with general
span/ownership checks. Saved spans are validated against their original offset
and the current backing buffer in every snapshot. Empty-buffer offsets are
normalized to zero; no claim compares absolute addresses.

The 308 failures comprise 111 capacity checks and 197 checked integer overflows.
Oversized advances, usize maximum, subtraction past zero and undo after filling
to capacity trap at the same phase, with no cursor or byte mutation. Both failed
processes have empty stdout, one exact message and identical initialized state.
Independent reconstruction checks the complete pre-call state, including saved
views and owned references. Observers capture bytes before opening state output
and clean up owned resources via FullPanic/at_exit.

Six paired compile rejections per mode cover negative, boolean and oversized
literal counts for both cursor methods. An external consumer using an aliased
usize count builds/runs in both languages and checks the borrowed bytes and
positions. These controls do not claim general argument-coercion equivalence.

Three regressions cover two-way borrowing through the writer adapter, full /
rewound/empty cursors and caller-written file output. All 83 image test files and
17 focused production/application/Windows/Linux checks pass. Historical writer
seeks (6,912 records, 196 returns, 60 exact failures), LEB128 writes (24,072
records, 840 exact failures) and full/streaming IO (37,133 records, 17 generic
trap controls, four compile boundaries) retain their hashes in both modes.
Historical generic traps do not establish exact state. Vaxis runtime tests are
not rerun; its source is unchanged and dependency builds pass. Cross builds
establish compilation only.

The full unchanged Source tree, compiler versions and selected libraries,
implementation, probes, directly imported verification helpers, shared owned
writer-fixture header and inputs are pinned before/after execution. Source
bodies/visibility/syscalls are untouched. Initialized unlinked files with reset
offsets, replacement pipes and keepers are owned. Final implementation/probe/
runner/direct-helper bodies remain frozen; only EXPECTED assignments change
after ordinary discovery. Independent replay checks records, models, aliases,
exact failures, compile controls, ownership, binaries, actual modes and provenance.
Parent-side lossless compression pins raw/compressed output. Evidence is persisted
from an owned RAM workspace and every retained archive member is read back before
commit and release.

```sh
python3 zigimg/verify_writer_buffer_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_buffer_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime comparison uses little-endian 64-bit macOS. Arbitrary constructed record
states, uninitialized bytes, view use after backing storage expires, custom
vtables, caller coercions outside the retained controls, larger buffers/offsets,
syscall counts, other devices, concurrent reuse, timing/signals, injected errors,
OOM/quotas, allocator lifetime, portable ABI and remaining V representation
limits remain boundaries. Windows/Linux, other CPU, big-endian and 32-bit runtime
are not established by cross compilation. Writable reservation/rebase APIs and
other reader/writer methods still need translation.
