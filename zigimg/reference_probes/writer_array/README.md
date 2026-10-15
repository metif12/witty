# Fixed-array reservations and preserved byte writes

`WriteStream.writable_array[A]()` maps pinned Writer.writableArray. A selects
an inline or directly named fixed byte array, including a u8 element alias.
The method makes space, advances by the array length and returns a borrowed
pointer carried in `WriterArray[A].value`. It uses the same record adaptation
as [reader arrays](../reader_array/README.md) for V's fallible pointer results.

```v
type HeaderBytes = [4]u8
mut header := writer.writable_array[HeaderBytes]()!
unsafe { (*header.value)[0] = 17 }
writer.write_byte_preserve(2, 18)!
```

Initialize reservations before subsequent IO. The pointer aliases caller storage;
caller writes and pointer writes are visible in both directions. Copies of the
record share the pointer. Saved pointers retain their original offsets across
cursor changes and later drains, whose writes can overwrite those bytes. Keep
the writer and backing storage alive. The initialized generic shape derives the
length/type; larger shapes and scratch-storage limits remain outside this proof.

`write_byte_preserve(preserve, byte)` maps Writer.writeBytePreserve. With unused
space, it ignores preserve and writes/advances directly. A full fixed writer
returns `WriteFailed`. Full file writers rebase, preserve their pending tail,
then store/advance only after success. Drain errors retain their progress and
restore hidden tail lengths. Capacity/overflow checks follow the drain and stay
active in production. Existing reader/writer/C helper bodies remain unchanged.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 13,358 | `e5db48f196afa5bcc2d45ee0e0a0ebc5d342d0bc6d6b6cef6ebe06c50b8ee038` |
| Returning boundary controls | 525 | `02a353de2b7abfa8168fb9da5701109078266178a08522585ef38a085262a798` |
| Exact panic/state pairs | 385 | `1f4939e19df4fa48761377959820224c67e63314c8a91f9a8629626c437bc5a3` |

Each record invokes one new method: 8,456 array reservations and 4,902 preserved
byte writes per mode. Setup/observation are separate. Groups contain 3,101 array,
4,134 byte, 5,355 every-byte alias and 768 every-byte write profiles. Duplicate
inputs are retained once. Inline/named lengths 1/2/4/8/16/32 and a two-byte array
with an aliased element cover 13 type selections. Every byte value is written
through all three writer kinds; every XOR byte is exercised on saved arrays.

Memory and positional/streaming files cover capacities 0/1/8/16/32, starts 0/3,
empty/one-byte/partial/full prefixes, fit/oversized array requests, preservation
through usize maximum, overlapping tail moves and owned regular/pipe/closed
bindings. Caller-buffer mutation, saved-pointer mutation and optional flushes
retain complete initialized backing bytes, pending/spare spans, logical position,
saved offsets/lengths/bytes, ownership, file contents and pipe output. An
independent model checks every complete returning record, including rebasing,
mode transitions, failure restoration and output. Empty-buffer offsets are
normalized to zero; absolute addresses are not compared.

The 385 exact failures contain 253 capacity traps and 132 subtraction overflows.
Both processes have empty stdout, one exact message and identical retained state.
Independent reconstruction includes regular-file bytes emitted before trapping
and restored pending lengths. Pipe output before a panic is not observed.
Observers capture state before opening output and clean up owned resources via
FullPanic/at_exit. The other 525 controls return matching success/errors and are
fully modeled.

Five paired compile rejections per mode cover negative/boolean arguments and
above-usize preserve. Zig also rejects byte literal 256. Pinned V ordinary warns,
accepts it and writes zero; V production rejects it. Separate mode-specific
controls verify the diagnostic and ordinary output instead of treating this as
matching coercion behavior.

Ten V array-type rejections cover dynamic arrays, scalars, strings, wider byte
elements, pointer elements, nested arrays, pointers to arrays, a len-field struct,
zero-length arrays and chained aliases. Source acceptance/run controls separately
establish zero-length reservation on an empty fixed writer and a chained array
alias. V has no zero-length fixed arrays and its one-level reflection rejects
chained aliases. An external consumer in both languages/modes checks inline,
named and element-aliased arrays, copied pointer records, two-way mutation,
aliased preserve/byte arguments and final bytes/position. These controls do not
establish arbitrary caller coercions or representation equivalence.

Three public regressions cover array borrowing/cursor updates, fixed-buffer
failure and preserved file output. All 85 image test files and 17 focused
production/application/Windows/Linux checks pass. Historical reservations
(10,818 records, 318 returning controls, 690 exact failures) and full/streaming IO
(37,133 records, 17 generic traps, four compile boundaries) retain their hashes
in both modes. Historical generic traps do not establish exact state. Vaxis
source is unchanged; dependency builds pass. Cross builds establish compilation.

Full unchanged Source, versions/selected libraries, implementation, probes,
directly imported helpers, shared owned writer fixture and inputs are pinned
before/after. Source bodies/visibility/syscalls are untouched. Initialized,
unlinked files with reset offsets, pipes and keepers are owned. Final implementation/probe/runtime-runner/direct-helper bodies remain frozen;
only runtime-runner EXPECTED assignments change after ordinary discovery.
Compiler diagnostics retain the initial expectations before discovering V's
mode-dependent literal handling, separately from final passing controls. The final compiler driver is frozen
and rerun in both modes after those diagnostics.
Independent replay checks records, models, failures, compile controls, ownership,
binaries, modes and provenance. Lossless parent compression pins raw/compressed
output. Proofs are archived from an owned RAM workspace and every retained
archive member is read back before commit and release.

```sh
python3 zigimg/verify_writer_array_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_writer_array_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime uses little-endian 64-bit macOS. Custom/growing vtables, arbitrary record
states, larger shapes/buffers/offsets, uninitialized/expired backing bytes,
partial native drains, syscall counts, other devices, injected errors,
concurrent reuse, timing/signals, OOM/quotas, allocator lifetime and portable ABI
remain boundaries. Windows/Linux, other CPU, big-endian and 32-bit runtime are
not established by cross compilation. Other reader/writer methods remain unported.
