# Nonexhaustive enum reads

`ReadStream.take_enum_nonexhaustive[T, E]` maps pinned
`std.Io.Reader.takeEnumNonexhaustive`. It reads the enum's declared native-width
integer in the requested byte order and accepts unnamed tags. A complete tag
is consumed; an incomplete tag stays pending. File refill and sticky failure
state follow the existing `take_enum` decoder, which remains unchanged.

V uses the explicit `@[nonexhaustive]` marker already recognized by take_enum.
The new method checks that marker before reading, including through direct
aliases and PNG compression/filter method types. Non-enum/pointer arguments and
invalid endian markers are rejected at compile time. Source also rejects
exhaustive enums at compile time; V instead compiles them and traps with
`take_enum_nonexhaustive requires @[nonexhaustive]` before any input is touched,
in both ordinary and production modes. This is a measured constraint adaptation,
not compile-time nonexhaustive enforcement. Other attributes do not satisfy the
marker check and may coexist with the marker.

Debug/ordinary and ReleaseSafe/production each match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Returning records | 20,544 | `f28f743fc7ed5ca768a1102674633e3c2cab23b659fc9d269d6a38f53d81540c` |
| Returning controls | 130 | `07aae54851aa7c227b8c2b4105f0488c803b03706fadbd122d47aa8c34f080da` |
| Exact panic/state pairs | 148 | `cabf29d02f8f7d04505814a867875ba9f7c3cf904de44bef2897bfb27a8e8be3` |

Each returning record attempts three enum reads, three caller tosses and one
relative seek: 61,632 enum reads / 143,808 primary calls per mode. Setup, priming
and observations are separate. Groups contain 4,800 basic, 2,112 tag-boundary,
12,288 every-byte and 1,344 descriptor-replacement records. Twenty enum bindings
cover signed/unsigned 8/16/32/64-bit types, their direct aliases, both PNG method
types and their aliases. Four endian bindings cover direct/aliased BigEndian
and LittleEndian markers.

The matrix includes every byte value, named/unnamed tags, signed endpoints,
high unsigned bits, complete/truncated input, buffered input, caller consumption,
relative seeks and repeated reads. Memory, positional/streaming files and owned
open/closed nonblocking replacement pipes preserve values, retained output,
read-ahead, pending bytes, positions, size metadata and wire data. The independent
model checks signed values/bit representations and consumption order for all
nonreplacement records and replacement calls already satisfied by pending input.
Other replacement refill/failure records compare full Source observations.
General checks cover every record's initialized spans, ownership, retained output
and caller tosses. The 148 exact failures comprise 36 capacity checks before the
read and 112 getPos overflow observations after priming before the enum call.
Every failed process has empty stdout, one exact message and identical initialized
state. Observers omit getPos, capture state before opening output and clean up
owned resources through Source FullPanic or V at_exit.

Separate controls retain four paired compile rejections per mode for integer,
pointer, struct and invalid endian arguments. Three exhaustive types (direct,
aliased and carrying an unrelated attribute) are rejected by Source; each V
consumer builds and traps before consuming either empty or nonempty memory
input. All six retained V states preserve position zero and the original bytes.
A positive consumer confirms that an unrelated attribute can coexist with the
required marker. Source accepts a chained enum alias; pinned V rejects it through
the method's one-level unaliased type check. Source rejects a nonexhaustive u7
tag because its bit width is not a whole byte. V has no corresponding u7 enum
carrier; that Source-only compile rejection is retained separately.

A positive-only `enum ... as int { zero }` control preserves bits 0xffffffff,
int(-1) and position four in both modes. Source widens that i32 tag to i64(-1);
V widens it to i64(4294967295), because its C enum has an unsigned compatible type
when every declared member is nonnegative. Conversion through int before widening
preserves the signed interpretation. Main signed i32 fixtures declare negative
members and do not have this difference. Constructor/literal and enum ABI limits
from the [checked-enum comparison](../reader_enum/README.md) still apply; this
entry point adds no compiler-wide construction or exhaustiveness rules.

Three regressions cover every byte through a direct alias and reader adapter,
signed/endian/incomplete tags, and unnamed PNG tags. All 81 image test files and
17 focused production/application/Windows/Linux checks pass. Historical checked
enum reads (33,504 records and 352 controls) and vector reads (10,476 records and
480 controls) keep their previous hashes in both modes. Vaxis runtime tests are
not rerun; its source is unchanged and dependency builds pass. Cross builds
establish compilation only.

The initial attribute experiments retain failed attempts to express a static
attribute constraint and the accepted runtime guard separately from passing API
gates. After ordinary/production regression checks, final implementation/probe/
runner/direct-helper bodies stayed frozen; only EXPECTED assignments changed
after ordinary discovery. The full unchanged Source tree, compiler versions and
selected libraries (including meta.zig/enums.zig), implementation, probes, directly
imported helpers, shared C fixtures and inputs are pinned before/after execution.
Source bodies/visibility/syscalls are untouched. Files are initialized, unlinked,
owned and start at reset offsets; replacement pipes and keepers are owned.
Independent replay checks records, models, exact state, compiler/runtime controls,
ownership, binaries, actual modes and provenance. Parent-side lossless compression
pins raw and compressed output. Evidence is archived from an owned RAM workspace;
every retained archive member is read back before commit and release.

```sh
python3 zigimg/verify_reader_enum_nonexhaustive_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_reader_enum_nonexhaustive_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```

Runtime comparison uses little-endian 64-bit macOS. Static exhaustive-type
rejection, arbitrary Source integer widths, chained aliases, enum construction /
constant conversion, positive-only int enum widening, layout/ABI, custom Reader
vtables, arbitrary record construction, larger buffers/offsets, concurrent reuse,
other devices, syscall counts, injected errors, timing/signals, OOM/quotas,
allocator lifetime and remaining V representation limits remain boundaries.
Windows/Linux, other CPU, big-endian and 32-bit runtime are not proved by cross
compilation. Remaining reader/writer methods still need translation.
