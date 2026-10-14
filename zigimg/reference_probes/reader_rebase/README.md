# Public reader rebasing

`ReadStream.rebase(capacity usize)` translates pinned `std.Io.Reader.rebase`
for the memory and file variants of the locked `io.ReadStream`.
Enough room from the cursor makes it a no-op. Fixed memory returns EndOfStream
without moving bytes when that room is insufficient, even if moving could make
room. File readers move pending bytes to the beginning of the caller's buffer,
reset the buffer cursor/end and then assert capacity. The explicit V panic
preserves that assertion in production. Rebasing consumes no input and performs
no refill, including after EOF or a failed streaming transition. Existing peek
and fill_more use the public operation.

The unchanged Source and V agree in Debug/ordinary and ReleaseSafe/production:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 13,626 | `e6efc4fa8584b25d60117d83fef6c5c076feab4ccde687d1cc988e8043ef6ca0` |
| Returning controls | 40 | `cf834fc7c956bcea92c0dbd4ab5564a5f1e5d1e9aa98cb2967fa575597b1d963` |
| Exact panic/state pairs | 70 | `f286aebbca3601dba4a2d5021693ab2f2c2de02f83c0372dd6cdae259bd5cd4b` |

Each returning record attempts three rebases, three caller tosses and one
relative seek: 40,878 rebases / 95,382 primary calls per mode. Setup, priming
and observations are separate. Groups contain 12,690 basic, 72 prefilled and
864 descriptor-replacement records. Coverage includes empty buffers, capacities
0/1/4/8, partial/full consumption, short input, signed relative seeks, zero,
exact and excessive requests, and the largest 64-bit usize request. Memory,
positional files and streaming files are compared. Owned open/closed nonblocking
pipes exercise pending bytes, EOF, ReadFailed and sticky transition failures.

The independent model checks the physical cursor/end via pointer offsets within
initialized storage, the complete backing buffer including untouched suffixes,
pending input, retained output, logical position, size/errors and descriptor
ownership after each operation. Fixed failures retain earlier successful output.
Every successful rebase preserves logical position, pending input and file
metadata. With no replacement priming, the seeded pipe bytes must all remain
unread. Other replacement cases compare the complete remaining wire to Source.

There are 54 capacity panic/state pairs and 16 getPos integer-overflow pairs.
The former retain the already compacted bytes and reset cursor/end, including
an oversize request with no pending data. The latter fail in the public position
observation after priming, before calling rebase. Each failed process has empty
stdout, one exact panic message and an identical initialized state file. Observers
omit getPos, capture state before opening an output file, and clean up owned
resources through Source FullPanic or V at_exit.

Three V regressions check fixed EOF/no movement, conditional file compaction and
subsequent reads, and successful rebasing after sticky failure without reading
the pipe. Existing buffered-reader, fill-more, sentinel and full-stream matrices
retain their hashes in both modes. All 78 image test files and 17 focused
production/application/Windows/Linux checks pass. Vaxis runtime tests are not
rerun; its source is unchanged and its dependency builds pass.

The runner pins the full unchanged Source tree, compiler versions and selected
libraries, implementation, probes, directly imported verification helpers,
shared C helpers and input bytes before/after execution. It neither edits Source
bodies/visibility nor intercepts reader syscalls. Production/probe/runner/helper
bodies stay frozen after ordinary discovery; only EXPECTED assignments change.
Independent replay verifies records, models, failures, modes, ownership and
provenance. Lossless parent-side compression pins raw and compressed logs.
Evidence is archived from an owned RAM workspace and every retained member is
read back before committing and releasing it.

```sh
python3 zigimg/verify_reader_rebase_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_reader_rebase_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime comparison uses little-endian 64-bit macOS. Custom Reader vtables,
direct defaultRebase calls, invalidated borrowed views, arbitrary record
construction/mutation, concurrent reuse, other devices, larger buffers/offsets,
syscall counts, injected errors, timing/signals, OOM/quotas, allocator lifetime,
integer argument coercions, portable ABI and remaining V representation limits
are outside this proof. Windows/Linux builds establish compilation; other CPU,
big-endian and 32-bit runtime are not measured.
