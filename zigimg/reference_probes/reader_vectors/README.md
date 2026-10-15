# Scatter reader vectors

`ReadStream.read_vec(mut destinations [][]u8) !usize` transfers pending bytes
across destination slices, then invokes at most one reader callback. It returns
the byte count, including a buffered prefix. EOF after a copied prefix returns
that count; ReadFailed still returns an error and preserves the partial writes.
`read_vec_all` repeats until every destination is filled, or returns the read
error with its partial progress retained. Empty destinations need no IO.
Both APIs restore temporary destination headers on normal and error returns.
Caller storage remains borrowed and must stay alive while the method uses it.

The mapping follows pinned Reader.readVec/readVecAll and fs.File.Reader.
POSIX callbacks use at most 16 nonempty vectors, with reader storage appended
for read-ahead when a slot remains. On macOS, positional preadv uses only its
first vector; streaming readv scatters across the vectors. Windows uses the
first destination through the existing scalar path. A positional file becoming
an unseekable pipe exposes Source's zero-progress mode transition, including
at offset zero. The original private one-destination helper is renamed
read_vec_one; its body and original two-vector C helper remain unchanged for
the existing looping slice, flate and TGA paths.

Pinned writableVectorPosix has a boundary at exactly 16 nonempty destinations
and a nonempty internal buffer: it resets the internal cursor/end, then traps
while appending slot 16. A further destination, including an empty one, makes
the input loop stop before that append. The V mapping preserves both behaviors
and the explicit trap in production. Panic does not unwind destination-header
defers: a destination partially filled from pending input can retain its
shortened header at that failure. Ordinary and IO-error returns restore it.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 10,476 | `69dc9cba6c055b4eb57ffcbbf7a5deb1df8f8bae431d2eaef2fd917247062856` |
| Returning controls | 370 | `6ee504eef56d51ea0a87055fa830b6b16c70c13fcff1d799ace488cb1d764225` |
| Exact panic/state pairs | 110 | `c6b0b03d6bba78dfae2e0f72e63e85f248fe10d6ce24eeca4cdd9153e913c12f` |
| Additional partial-header panic/state pairs | 48 | `8e13c34a4296a6e50b0cf3af2621e8df73bb54a1dfb18b78c6fd63f28e877599` |

Each returning record attempts three vector reads, three caller tosses and one
relative seek: 31,428 vector reads / 73,332 primary calls per mode. Setup,
priming and observations are separate. Groups contain 9,216 basic, 108 relative
seek and 1,152 descriptor-replacement records. Layouts include empty vectors,
zero-length entries, gaps, overlapping destinations and the 15/16/17-vector
boundary. Memory, positional and streaming files, capacities 0/1/8/32,
complete/truncated input, repeated operations, buffered input, open/closed
nonblocking replacement pipes and sticky transition failures retain Source's
bytes, positions, metadata, output result and wire data.

The independent scatter model checks all nonreplacement memory/positional
records and streaming-file records with zero relative delta, including aliased
destination writes, guards, callback vector limits, read-ahead and EOF progress.
Other streaming seeks and replacement behavior compare full Source records;
general checks cover every returning record's initialized spans, ownership,
header restoration, result bounds, empty-vector calls and caller consumption.
There are 62 slot-capacity and 48 getPos integer-overflow panic/state pairs in
the main controls. The position failures follow priming before the vector call.
Every failed process has empty stdout, one exact message and identical retained
initialized state. Observers omit getPos, capture state before opening the state
file and clean up owned resources via Source FullPanic or V at_exit.

The separate cache-side header controls reuse the frozen comparison binaries.
A 12-byte first destination and fifteen one-byte destinations force the slot
trap after pending input advances that first header by 1, 7 or 8 bytes; fully
consumed input checks the unchanged header. Both operations, positional/streaming
files, starts 0/1 and open/closed replacements are included. An independent
expected-state calculation checks every destination byte and header, unchanged
reader backing, cursor/end reset, retained result and descriptor ownership.
These controls, inputs, logs and hashes are retained in the proof archive.

Three regressions cover memory partial EOF/header restoration, streaming scatter
read-ahead through the reader adapter, and the zero-progress pipe transition.
All 80 image test files and 17 focused production/application/Windows/Linux
checks pass. Historical allocated reads (27,585 records, 96 returning controls,
168 exact panic/state pairs) and full/streaming reads (37,133 records, 17 generic
trap controls and four compile boundaries) retain their previous hashes in both
modes. The historical generic traps do not claim exact retained-state coverage.
Vaxis runtime tests are not rerun; its source is unchanged and dependency builds
pass. Windows/Linux builds establish compilation only.

The first production regression build exposed V's requirement for an explicit
unsafe zero-initialization of a pointer array. Its original body/diagnostics
and interrupted concurrent checks are retained separately. After that correction,
ordinary discovery was rerun on the final frozen production/probe/runner/helper
bodies; only EXPECTED assignments changed afterward. Earlier ordinary results
are development evidence, excluded from the final gate.

The runner pins the full unchanged Source tree, compiler versions and selected
libraries, implementation, probes, directly imported verification helpers,
shared C fixtures and input bytes before/after execution. Source bodies,
visibility and syscalls are untouched. Files are initialized, unlinked, owned
and start at reset offsets; replacement pipes and keepers are owned. Independent
replay checks all records, models, controls, exact failures, ownership, binary
hashes, actual build modes and provenance. Parent-side lossless compression pins
raw and compressed output. Evidence is archived from an owned RAM workspace;
every retained member is read back before commit and release. The initial disk
reservation failure and this task's reserve recovery are retained separately.

```sh
python3 zigimg/verify_reader_vectors_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_reader_vectors_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime comparison uses little-endian 64-bit macOS. Destination vectors may
alias each other; aliasing the reader's pending input with destinations is
excluded because Source uses nonoverlapping memcpy. Invalid or concurrently
mutated headers, custom vtables, arbitrary reader construction, larger lengths /
offsets, usize totals beyond V's array carrier, syscall counts, injected errors,
other devices, timing/signals, OOM/quotas, allocator lifetime, portable layout/ABI
and remaining V representation limits remain boundaries. Linux native preadv,
Windows scalar behavior, other CPU, big-endian and 32-bit runtime are not proved
by cross compilation. Remaining reader/writer methods still need translation.
