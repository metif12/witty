# Writable writer reservations

Six methods map the pinned fixed/file Writer APIs:

| V method | Behavior |
| --- | --- |
| `rebase(preserve, minimum_len)` | Make space, retaining the buffered tail during file drains. |
| `writable_slice_greedy(minimum_len)` | Borrow all available space without advancing. |
| `writable_slice_greedy_preserve(preserve, minimum_len)` | Borrow all available space while preserving the tail during a drain. |
| `writable_slice(len)` | Reserve exactly len bytes and advance. |
| `writable_slice_preserve(preserve, len)` | Reserve exactly len bytes while preserving the tail during a drain. |
| `ensure_unused_capacity(count)` | Make space without advancing or returning a view. |

```v
mut output := writer.writable_slice_preserve(2, 3)!
output[0] = 17
output[1] = 18
output[2] = 19
```

Returned slices alias caller storage. Saved headers keep their original offset
and length, including after rebasing; later IO can overwrite their bytes. Keep
the writer and backing storage alive. Initialize exact reservations before IO.

If enough unused space exists, every method bypasses rebase and ignores preserve.
Zero requests therefore work even with empty buffers and invalid descriptors.
A fixed writer returns `WriteFailed` without mutation when space is insufficient.
File writers temporarily hide the preserved tail, drain once, move that tail
with overlap-safe semantics and restore its length. A normal drain error restores
the hidden length before returning. Positional pipes retain the zero-progress
transition to streaming and the failure/reset of a nonzero positional seek.

Capacity validation happens after the drain and tail restoration. An oversized
file request can emit a prefix before trapping; preserve above total capacity
traps with integer overflow at that phase. Explicit checks retain these exact
messages and states in production. The greedy post-rebase addition and capacity
checks also follow Source order. Existing writer/reader/C helper bodies are
unchanged; one private drain helper supports the six new methods.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 10,818 | `f34b9fbd77dc63c6c68894affbeaadb1855435bc3e13414ad215d31c7f149afb` |
| Returning boundary controls | 318 | `c87d75747b74c4728d76b6da0af797f1476ce5e717dc571cf10b249cd7184d5c` |
| Exact panic/state pairs | 690 | `411d6eb7ca06c8222fad9d120e9e42c8b76702a1e30300635f2a5a9303c47cab` |

Each returning record invokes one reservation method, then mutates caller storage
and any saved view, and optionally flushes. Setup and observation getters are
separate. Groups contain 7,746 reservation profiles and 3,072 every-byte XOR
profiles; duplicate inputs are retained once. All six methods are exercised.
Memory and positional/streaming file writers cover capacities 0/1/8/16, starts
0/3, empty/partial/full prefixes, zero/fit/oversized requests, preservation up to
usize maximum, and owned regular/pipe/closed descriptor bindings.

Every snapshot retains logical position, pending/spare spans, initialized backing
bytes, saved view offsets/lengths/bytes, ownership and file contents. Pipe data is
retained too. An independent model checks every complete returning record,
including file drains, tail moves, aliases, mode transitions and wire bytes.
Empty-buffer offsets are normalized to zero; absolute addresses are not compared.

A separate 48-record corpus per mode uses the same frozen probe binaries to
check overlapping moves with four/five preserved bytes from a six-byte prefix,
all three preservation methods, caller/view mutations and optional flushes.
Every record matches Source and the independent model, SHA-256 `fe4524c21e484d60cfd9b409b4322bc71ed602d519fe1889b78b2b4022874cbe`.

The 690 panic pairs contain 504 subtraction overflows and 186 capacity failures.
Both processes have empty stdout, one exact message and identical retained state.
Independent reconstruction includes regular-file bytes emitted before the trap
and restored buffer lengths. Pipe output before a panic is not observed. Observers capture bytes before opening their output and clean up
owned resources through FullPanic/at_exit. The other 318 controls return matching
errors or success and are fully modeled.

Twenty-seven paired compile rejections per mode cover negative, boolean and
above-usize literals at every count/preserve argument position. An external
aliased-usize consumer builds/runs all six methods and checks stored bytes and
position. General caller coercions remain outside these finite controls.

Three regressions cover aliased exact/greedy reservations, fixed-buffer failure
and file tail preservation/output. All 84 image test files and 17 focused
production/application/Windows/Linux checks pass. Historical writer buffer
(18,780 records, 308 exact failures), writer seek (6,912 records, 196 returning
controls, 60 exact failures) and full/streaming IO (37,133 records, 17 generic
traps, four compile boundaries) retain their hashes in both modes. Generic traps
do not establish exact state. Vaxis source is unchanged; dependency builds pass.
Cross builds establish compilation only.

Full unchanged Source, versions and selected libraries, implementation, probes,
directly imported helpers, shared owned writer fixture and inputs are pinned
before/after. Source bodies/visibility/syscalls are untouched. Initialized,
unlinked files with reset offsets, pipes and keepers are owned. Final bodies
remain frozen; only EXPECTED assignments change after ordinary discovery.
Independent replay checks records, models, failures, compile controls, ownership,
binaries, modes and provenance. Lossless parent compression pins raw/compressed
output. Proofs are persisted from an owned RAM workspace and every retained
archive member is read back before commit and release.

```sh
python3 zigimg/verify_writer_reserve_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_reserve_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime uses little-endian 64-bit macOS. Custom vtables/growing buffers, arbitrary
record states, larger buffers/offsets, partial native drains, syscall counts,
other devices, injected errors, timing/signals, concurrent reuse, expired backing
storage, OOM/quotas, allocator lifetime and portable ABI remain boundaries.
Windows/Linux, other CPU, big-endian and 32-bit runtime are not established by
cross compilation. Fixed-array reservations and other reader/writer APIs still
need translation.
