# Byte-size writer formatting

`ByteSizeUnits` and `WriteStream.print_byte_size(value, units, options)` translate
pinned Writer.printByteSize for u64 values and decimal/binary units. FormatOptions
supplies precision, width, alignment and fill. Rendering finishes in a private
56-byte buffer before parent writes; output then uses align_buffer_options.

Magnitude follows Source's integer log2: floor(log2(value) / 9) for decimal and
floor(log2(value) / 10) for binary. These are the pinned rules, including SI
thresholds at powers of 512. Decimal 511 prints `511B`, 512 prints `0.512kB`,
262144 prints `0.262144MB`, and u64.max prints `0.01844674407370955ZB`.
Binary u64.max rounds through f64 to `16EiB`. Precision is ignored only for zero
or magnitude zero: values below 512 for decimal, 1024 for binary. The source's
comment about every value below 1kB does not describe its decimal implementation.

Integer-to-f64 conversion and division each round before decimal rendering.
All reachable pow results are exact binary64 integers: 1000^0..7 and 1024^0..6.
The translation uses those exact finite scales instead of importing general pow.
Zero selects `0B` before scaling. Magnitude-zero output uses integer formatting;
other values use the existing Ryu decimal path, then append the unit suffix.

The private buffer retains conservative float guards and checked arithmetic.
A BufferTooSmall render becomes the exact panic `attempt to unwrap error:
BufferTooSmall`, never the `(float)` fallback used by print_float. A number can
fit the buffer while its suffix cannot: the pinned compiler's fixed-array slices
report the absolute end (57 or 58) against length 56. The port preserves both
diagnostics. Formatter panics occur before parent writes; writer failures can
retain partial payload or alignment.

The independent model rounds exact integer fractions to nearest/even binary64
for both conversions, without host float arithmetic. It passes those bits to the
prior independently verified shortest-decimal and store models, adds suffixes,
and computes alignment/stream effects separately. Six deduplicated groups cover
all binary exponent edges and unit boundaries, binary64 rounding midpoints,
small values 0..1049, precision/private-buffer thresholds, all 256 fills and
1,024 seeded u64 values per unit system. Five snapshots retain position, complete
backing, pending/unused bytes and headers, descriptor ownership, immutable input
bytes/options and file/wire bytes. Positional and streaming files, pipes replacing
open descriptors, closed files, empty/full prefixes and caller mutation are covered.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 26,852 | `695d9fd9a35408f76d5c3596e20117380d1a7d6afe701ccf815e0794800888e3` |
| Returning controls | 529 | `656d59be5013bf4529d54f2c87f90aa0845940cd4944f4b2c8e8a9b8a3990e0b` |
| Exact panic/state pairs | 188 | `761bb009c1af43804015165e29134a4916b887b29206fb9cf576a043f668eb4d` |

There are 78 arithmetic overflow, 60 private BufferTooSmall unwrap and 50 suffix
bounds trap pairs per mode. All retain one exact diagnostic, empty stdout and
matching state captured before observer IO. Returning controls include maximal
precision bypasses and partial memory/file WriteFailed; huge successful padding
and outputs beyond the bounded file/wire observer are excluded.

A 150-record / 20-trap preflight passes before final comparisons. Fifteen external
compiler pairs pass per mode: four common accepted consumers cover copied options,
zero/precision bypasses, enum order and unsigned/alias coercions; ten paired
rejections cover invalid values, units and option types. One measured boundary
remains: Source requires units at comptime, while V accepts a runtime enum.
This runtime convenience is not claimed equivalent to Source's comptime contract.

Three public regressions, all 102 image test files and 17 focused production,
application, Windows and Linux checks pass. The historical native-float writer
proof retains 13,976 records, 309 returning controls and 143 exact trap/state pairs
per mode. Full/streaming IO keeps 37,133 records, 17 generic traps and four compiler
boundaries. All hashes remain unchanged. Generic stream traps do not prove exact
state. Vaxis source remains unchanged; its dependencies build and its runtime
tests are not rerun. Cross builds establish compilation only.

Original public compiler-library bodies execute unchanged at original visibility.
Complete pinned zigimg Source SHA-256 remains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b` and selected
compiler libraries remain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole math/log2.zig, math/pow.zig, math/modf.zig, math/frexp.zig, math/scalbn.zig,
math/ldexp.zig and math/copysign.zig are newly pinned with the previously invoked
math/float, isnan/isinf/signbit, fmt/float, math/meta/fmt/Io and time bodies. Exact
pins live in the runner. Versions, Source, implementation, fixtures, helpers,
inputs and consumers are checked before/after. Only the added byte-size IO block
changes old runtime files; C and existing formatters remain byte-identical.
Runtime/probe/model bodies freeze before discovery; only EXPECTED assignments
are filled afterward. Independent replay checks every observation, compiler
outcome, mode, binary and provenance record. Every retained archive member is
read back before committing the reviewed file hashes.

Failed development evidence retains the corrected suffix index/length and private
render panic classifications separately; it cannot satisfy successful checks.
Evidence is limited to the pinned compilers on little-endian 64-bit macOS.
Other runtimes/widths, arbitrary short devices, huge successful output/storage,
allocation/lifetime/OOM, portable ABI/reflection, floating exception flags,
invalid/concurrent headers and broader coercions remain boundaries. V private
fixed-array slices copy and physical allocation is unmeasured. General pow and
the remaining formatting dispatcher/custom formatter APIs remain outside this
checkpoint; the pre-existing PNG information helper is unchanged.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_byte_size_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-writer-byte-size-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and complete member readback before commit. Owned
regenerable caches are excluded; RAM and reserves are released afterward.

The final dependency review also pins transitive math/isfinite.zig, reached by
ldexp. The byte-size matrices and compiler controls were rerun with that pin
checked before/after; output and failure hashes remain unchanged. Runtime files
and module/platform checks are unchanged. The earlier artifact is retained in
`before-isfinite/verified-proofs.tar.gz` beside the refreshed final archive.
