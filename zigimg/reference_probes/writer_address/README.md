# Pointer address formatting

`WriteStream.print_address(value)` translates the represented native-type paths
of pinned Writer.printAddress. It accepts pointers and dynamic slices of native
u8/u16/u32/u64/usize, i8/i16/int/i64/isize, f32/f64 and bool, including scalar,
pointer and slice aliases. Plain voidptr represents Source's opaque pointer.
Single optional pointers to native scalars are supported too.

Ordinary pointers/slices print the Source child type, `@`, then the address in
lowercase hexadecimal, without `0x` or padding. V int maps to Source i32; usize /
isize keep their Source names. Slices print their data address independently of
length. Optional pointers print their pointer type (`*u8@...`), with `0` for none.
Opaque pointers print `anyopaque@...`. The formatter never dereferences a target.
The type prefix and digits are separate writes, preserving Source's failure order.
A fixed 16-byte native-address digit buffer avoids a pinned V reachability issue
with indirectly instantiated print_int / FormatCase. Private allocation differs.

The equivalent type-name subset is explicit. Source supports compound and
qualified pointees that V does not represent here. Nested/optional-nested and
fixed-array pointees, f16 and V string carriers are measured separate compiler
boundaries. Optional const pointers print `*const u8` in Source but `*u8` for V's
unqualified pointer; that output is not claimed equivalent. Struct, enum, function,
sentinel, qualified and arbitrary nominal type names remain outside this stage.
Direct non-pointer values are rejected. Broader coercions/ABI remain boundaries.

The fixtures supply deterministic synthetic pointer bits and never read through
those pointers. Source uses allowzero/align(1) for non-optional pointers/slices;
optional addresses are naturally aligned or null. Slice descriptors retain lengths
0..3; raw argument bytes, operation/type and lengths remain unchanged. This proves
address formatting, not allocation validity or the right to dereference arbitrary
integers. An additional accepted consumer uses live borrowed storage and checks
that its printed address equals the actual slice data pointer.

An independent integer/string model computes each prefix and hex representation,
then models the two write boundaries and memory, positional-file, streaming-file,
replaced-pipe and closed-descriptor effects. Five snapshots retain parent position,
full backing, pending/unused bytes and headers, descriptor ownership, immutable
argument bytes/descriptors and file/wire contents through mutation and flush.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 30,217 | `a2aefc70efc8bdc2c5dbf7892897e1676ce1952a2e6dba77026f263a67211dc5` |
| Isolated returning controls | 3,234 | `8af6ead77a0b0a4b3784ac1677e9c67f67226b9fa53037e6307b3cc1be55422e` |

The 33,451 returning observations per mode include 11,460 primary WriteFailed
states: 10,115 corpus cases and 1,345 isolated controls. These ordinary errors
retain exact state; no valid represented address case is expected to panic.
Five groups cover all seven represented pointer/alias/slice forms, all 13 scalar
types, zero/maximal addresses, every binary exponent edge and adjacent integer,
every prefix/digit capacity through 24, every caller mask and seeded addresses.
Controls repeat failure contexts in fresh processes. Owned files/descriptors are
cleaned up. A 125-record preflight passes before the full comparisons.

Sixteen external compiler pairs pass per mode: four common accepted consumers
cover native/alias/optional pointers and live borrowed slices; six paired ordinary
rejections cover invalid values; six boundaries retain compound/wide/string
pointees, nested optional pointers and optional const spelling. The fixed-array
pointer versus dynamic slice distinction is preserved in the Source consumers.

Three public regressions, all 103 image test files and 17 production/application /
Windows/Linux checks pass. Historical byte-size output keeps 26,852 records, 529
controls and 188 exact panic/state pairs per mode. Full/streaming IO keeps 37,133
records, 17 generic traps and four compiler boundaries. All hashes remain unchanged;
generic stream traps do not prove exact state. Vaxis source is unchanged and its
dependencies build; runtime tests are not rerun. Cross builds prove compilation.

Public Source bodies run unchanged at original visibility. Complete Source hash
remains `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler libraries remain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Existing whole Io/fmt/math/meta/time pins are checked before/after, with versions,
implementation, fixtures, shared C helpers, input and consumer hashes. Old runtime
bodies differ only by the added address IO block; C is unchanged. Runtime/probe /
model bodies freeze before discovery; only EXPECTED assignments change later.
Independent replay checks all observations, failures, compiler outcomes, modes,
binaries and provenance. Every retained archive member is read back before commit.

Development evidence separately retains generic type-access/inference failures,
optional code-generation errors, fixture construction and concrete-slice mistakes.
The final implementation uses free helpers, converts an optional payload directly
to usize and rejects unsupported compound types. These failed/superseded runs do
not satisfy successful checks. Evidence is the pinned compilers on little-endian
64-bit macOS. Other runtime platforms/widths, allocation validity/lifetime/OOM,
private stack versus GC storage, portable ABI, compiler type-name reflection,
arbitrary devices, injected short IO and concurrent headers remain boundaries.
Formatting dispatch and custom formatter APIs remain unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_address_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-writer-address-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and full member readback. Regenerable owned caches
are excluded. RAM and reserves are released after committing reviewed hashes.
