# Checked enum reads

`ReadStream.take_enum[T, E]` translates pinned `std.Io.Reader.takeEnum`.
The enum's declared backing width determines how many bytes are taken, and
BigEndian/LittleEndian markers select byte order. Validation follows the read:
an unknown exhaustive tag consumes its whole integer and returns InvalidEnumTag.
An incomplete integer returns EndOfStream without consuming the pending prefix.
File refill/failure state follows the existing take operation.

V has no intrinsic nonexhaustive enum property. This method recognizes the
explicit `@[nonexhaustive]` attribute and accepts all tag bit patterns for those
types. PNG's existing PngCompressionMethod and PngFilterMethod carry that marker;
their earlier utility-reader behavior is unchanged. Explicit native-width V
enum declarations correspond to Source's explicit enum backing types. Default
enum widths, constructor rules and other operations need their own mapping.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 33,504 | `afa3ea7a87cb13544863b2957f1c31b1af7d211b98704b7845e1451a359be955` |
| Returning controls | 160 | `483ff19b2f300d286be8c7310b561a4f7ca1b1f285422957d7687ce7fc7c4f3d` |
| Exact panic/state pairs | 192 | `3cef7fe799e64aa751e283552ed5f446b810246a17241986874cfeb59e330c7f` |

Each returning record attempts three enum reads, three caller tosses and one
relative seek: 100,512 tag reads / 234,528 primary calls per mode. Setup, priming
and observations are separate. Groups contain 8,928 basic, 3,840 tag-boundary,
18,432 every-byte and 2,304 descriptor-replacement records. The fixture dispatches
36 enum bindings: signed/unsigned 8/16/32/64-bit exhaustive and nonexhaustive
types, their direct aliases, both PNG method types and their aliases. Four
endian bindings cover direct and aliased BigEndian/LittleEndian markers.

The matrix includes every byte value, named/unnamed tags, signed endpoints,
high unsigned bits, complete and truncated integers, empty input, partial caller
consumption, relative seeks and repeated reads. Memory, positional and streaming
files use initialized storage. Owned open/closed nonblocking replacement pipes
cover pending input, EOF, ReadFailed, sticky transition failures and retained
wire bytes. The independent model checks signed values and bit representations,
tag membership, validation/consumption order, buffered and ordinary file input,
retained output, pending bytes, logical position, caller tosses and descriptor
ownership. Replacement refill state also compares byte-for-byte to Source.

There are 64 capacity panic/state pairs and 128 getPos integer-overflow pairs.
Capacity checks precede tag validation. The position failures occur after
priming, before the enum call. Each failed process has empty stdout, one exact
panic message and an identical initialized state file. Observers omit getPos,
capture state before opening an output file, and clean up owned resources
through Source FullPanic or V at_exit.

Three paired compiler rejections cover integer/pointer tag types and invalid
endian types in each mode. Source accepts a chained enum alias, while pinned V
rejects it through the method's one-level unaliased type check. Source also
accepts an i8 enum member with the literal value 127; pinned V rejects that
declaration in both modes. For a nonexhaustive enum, Source accepts the constant
unnamed tag 3 in both modes; V warns, builds and runs in ordinary mode but rejects
the constant cast in production, even inside unsafe. Dynamic unnamed values
returned by take_enum pass in both modes. These are separately measured compiler
and construction differences, not invalid-tag runtime equivalence claims.

A separate positive-only `enum ... as int { zero }` control preserves the input
bits `0xffffffff`, a narrowed int value of -1 and reader position 4 in both
modes. Source widens its i32 tag to i64(-1), while V widens that enum to
i64(4294967295): its C enum has an unsigned compatible type when all declared
members are nonnegative. Converting through int before widening preserves the
signed interpretation. The main signed 32-bit fixtures declare negative members
and do not have this widening difference. This V enum representation boundary
is retained separately from the matching read matrix.

Development experiments retain the original signed-maximum declaration and
constant-cast diagnostics separately. The first compile-consumer fixture used
reserved one-letter V type names; corrected consumers use descriptive names.
Those original bodies/logs are retained and excluded from passing gates.
Final production/probe/runner/direct-helper bodies stay frozen after ordinary
discovery; only EXPECTED assignments change.

Three regressions cover consumed invalid tags followed by successful reads,
signed/endian/truncated tags and unnamed custom/PNG tags. All 79 image test files
and 17 focused production/application/Windows/Linux checks pass. Existing integer
and PNG header matrices retain their hashes in both modes. Vaxis runtime tests
are not rerun; its source is unchanged and its dependency builds pass.

The runner pins the full unchanged Source tree, compiler versions and selected
libraries (including meta.zig/enums.zig), implementation, probes, directly
imported verification helpers, shared C helpers and input bytes before/after
execution. Source bodies/visibility and reader syscalls are untouched. Fixtures
use initialized unlinked owned files, reset offsets and owned nonblocking pipes
and keepers. Independent replay checks records, models, classifications, exact
failures, compiler controls, ownership, binaries, modes and provenance. Lossless
parent-side compression pins raw and compressed output. Evidence is archived
from an owned RAM workspace and every retained member is read back before
committing and releasing it.

```sh
python3 zigimg/verify_reader_enum_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_reader_enum_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime comparison uses little-endian 64-bit macOS. Source's separate
takeEnumNonexhaustive entry point and compile-time nonexhaustive enforcement
remain unported. Arbitrary Source integer widths, chained aliases, enum
construction/constant conversions, positive-only int enum widening, layout/ABI,
custom Reader vtables, larger buffers/offsets, concurrent reuse, other devices,
syscall counts, injected errors,
timing/signals, OOM/quotas, allocator lifetime and remaining V representation
limits are outside this proof. Windows/Linux builds establish compilation;
other CPU, big-endian and 32-bit runtime are not measured.
