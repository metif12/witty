# Endian integer slice reads

`ReadStream.read_slice_endian[T, E](mut destination, endian)` translates pinned
Reader.readSliceEndian for V's native integer carriers and aliases. It reads
into the caller's storage, then converts each element from the requested byte
order to native order only after the entire read succeeds. EndOfStream and
ReadFailed retain the consumed reader progress and copied raw destination
prefix, with no byte swapping. An empty destination succeeds without IO.
Existing reader bodies and C adapters are unchanged.

The mapping covers u8/u16/u32/u64, i8/i16/int/i64 and usize/isize, including
aliases, with BigEndian/LittleEndian markers and marker aliases. A borrowed byte
view exposes the destination's storage to the existing readSliceAll path.
Byte swapping operates on representations, preserving signed high bits. The V
array byte-span limit is checked before creating that view; spans above maximum
int trap with Reader byte span exceeds V array length. Source can represent
larger slices. This carrier boundary is outside the finite runtime corpus.

## Reproduce

```sh
python3 zigimg/verify_reader_slice_endian_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_slice_endian_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

Source is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, with Zig 0.15.2
and V 0.5.2. Ordinary pairs Debug with V ordinary; production pairs ReleaseSafe
with `-prod`. Target defaults to `aarch64-macos.14.0`. The runner pins VEXE and
V_C_ERROR_BUG_REPORT_DISABLED=1 and owns temporary directories/caches. Full
unchanged Source tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected stdlib, including mem/Reader/Writer/File/posix, SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Selected math/simd/path libraries, versions, implementation, probes, shared
fixtures, directly imported helpers and inputs are checked before/after
comparison. Source bodies, visibility and reader syscalls remain untouched.

## Returning records

Both modes match **50,088 records / 150,264 slice reads / 350,616 primary
calls**. Each record performs three reads into the same destination, three
caller consumptions and one relative seek. Setup, priming and observations are
separate calls. Groups contain 26,880 basic, 6,144 every-byte, 15,552 prefilled
and 1,512 caller-consumption profiles, with duplicate inputs retained once.

Twenty native/alias carriers run both endian markers and marker aliases through
memory, positional files and streaming-initialized files. Basic profiles cover
lengths 0/1/7/8/9/17, file capacities 0/1/8, distinct starting positions and
zero/one/three-element slices. Every byte runs through u8/i8/u16/i16, both orders
and all reader kinds. Prefills cover capacities 8/32, offsets 0/1, consumption
1/7, open/closed pipes, seed/priming/toss choices and relative offsets -1/0/1.
Caller-consumption profiles cover partial/full pending-byte consumption,
capacities through 32, relative seek and destination offsets 0/1/2.

Destinations are native typed arrays with two extra elements. Every byte starts
at a distinct initialized pattern; only the selected slice may change. Complete
reader backing storage, destination bytes including guards, pending spans,
logical positions, size/errors, owned references and untouched wire bytes match.
An independent model checks every nonreplacement result, copied byte count,
reader progress, complete successful conversion and unswapped failed prefix.
It tracks physical streaming descriptor progress separately from buffered and
logical rewind. Zero-length reads and destination guards are checked for all
records, including replacement failures.

Returning output SHA-256 (joined lines without a trailing newline):
`0da1d967c4527eeb5e937d9a146fb8afd8e7e68450540c473cf80436f35cb59c`.
Inputs are:
`kind|warmup|capacity|start|consume-mode|payloadhex|replacement|consumed|seed|prime|delta|type|endian|count|offset`.
Types 0–9 are u8/u16/u32/u64/i8/i16/i32/i64/usize/isize; 10–19 select aliases.
Endian 0/1 selects big/little and 2/3 their marker aliases. Count and offset are
in elements. The ten output parts retain initial/primed state, three read/caller
consumption pairs, relative seek and wire data. Snapshots contain
`status|position:size-or-error:valid:refs|reader-backinghex|destinationhex|pendinghex`.
Destination storage is reused, so failed later reads can partially replace a
previous successful result.

## Controls and consumers

The **1,344 distinct controls** classify as **672 returning records**, SHA-256
`9c90e60d49724bff739101761fa79a06250c8d84422df53fb94dbe5764eee3c6`,
and **672 exact integer-overflow panic/state pairs**, SHA-256
`49f3e328eb978aba67ee9db6d12d44f2a233339b19f818cf4be2b493dac91942`.
They cover widths 1/2/8, aliases, both orders, capacities 8/32, offsets 0/1,
consumption 1/7, open/closed pipes, seed boundaries and counts 0/1/3. Traps occur
in public getPos after priming, before the requested slice read. Both exits fail
with empty stdout, one exact message and matching initialized state. Observers
omit getPos and capture preceding status, size/errors, backing/destination
storage, pending spans and owned references before opening state files. Source
FullPanic and V at_exit clean up only owned resources.

Twenty-one compiled consumer records / 63 reads / 147 primary calls per mode
assert all three results for signed values, aliases, high bits, partial elements,
zero-count EOF/no-read behavior, read-ahead, zero-capacity readers, destinations
larger than the reader buffer, rewind, guard offsets, pipe EOF/ReadFailed and
buffered success followed by an unswapped sticky-failure tail. SHA-256:
`ddbcf558a7a5491a150cb8b9fdc450579610fa036290df5a023cf4f853a9ec7e`.
Six paired compile rejections per mode check floats, float aliases, booleans,
strings and invalid integer endian arguments/aliases. Three public regressions
accompany the proof. All 74 image and 58 Vaxis test files pass, with 58 production/
application/platform/unit/fixture checks. Historical integer, buffered-reader
and full-stream matrices retain their hashes in both modes.

## Evidence and boundaries

An initial Vaxis run passed 57 files and segfaulted in the layout fixture
using temporary widget receivers and inline fallible assertions. An isolated
debug build passed. The fixture now uses named widgets and results; production
layout code is unchanged. The full rerun reached its 600-second limit after 45 files passed without
failures. The remaining 13 files were verified in a separate batch; all 58 files
are covered, while the single full invocation did not complete. Eight additional
isolated repetitions pass in each mode. Initial diagnostics are retained separately.

Consumer development diagnostics retain an expectation of read-ahead without
priming, and an incorrectly transcribed byte pair in a sticky pending case.
Native and translated records agreed; the final consumers explicitly prime the
read-ahead case and assert the correct pair. V fmt required a second pass to expand fixture
match branches; both comparisons and consumers were rerun against the final
formatted fixture. Original scripts, inputs, outputs and diagnostics remain separate from passing gates. Production/probe/runner/
helper bodies stay frozen during final comparisons; only expected assignments
change after ordinary discovery.

Fixtures separately copy/hash the exclusive-payload and descriptor-replacement
helpers. They use initialized unlinked O_EXCL/CLOEXEC files, reset live offsets,
and owned nonblocking pipes/keepers below descriptor 128. Lossless parent-side
compression pins raw and compressed logs. Independent replay checks destination
bytes, progress, native classifications, exact failures, consumers, ownership,
binaries, modes and provenance. Evidence is persisted from a task-owned RAM
workspace and every retained archive member is read back before commit and
release of that volume.

Source's recursive byte swapping of aggregate fields, arbitrary-width integers
and allocator-based slice reads remain outside this native integer mapping.
Other types can have different Source support depending on the selected endian;
the six compile checks establish only the stated rejected cases. Other callbacks,
overlap between input/output, arbitrary constructor/copy sequences, other devices,
larger slices/offsets, concurrent reuse, syscall counts, timing/signals, injected
errors, OOM/quotas, allocator lifetime, portable ABI and V representation limits
remain boundaries. The native comparison uses little-endian 64-bit carriers.
Windows/Linux and other CPU, big-endian and 32-bit runtime remain outside the
proof. Cross builds establish compilation only.
