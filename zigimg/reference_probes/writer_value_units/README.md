# Duration and byte-size Writer value dispatch

`WriteStream.print_value(format, options, value, max_depth)` dispatches the pinned
public `std.Io.Writer.printValue` duration and byte-size branches:

| Carrier | Formats |
| --- | --- |
| Native signed/unsigned integers and aliases | `D` |
| Native unsigned integers and aliases | `B`, `Bi` |

Duration output preserves sign, year/week/day/hour/minute units, truncated
millisecond precision and the existing private 24-byte representation before
alignment. Some signed durations require 25 bytes and trap before touching the
parent writer, as in Source. Precision and scalar depth are ignored.

Byte-size output preserves Source's integer-logarithm SI/IEC magnitude thresholds,
u64-to-f64 rounding, decimal precision, suffixes and private 56-byte buffer failure
order before alignment. Zero and magnitude-zero values bypass floating precision.
`B` chooses decimal units; `Bi` chooses binary units. Scalar depth is ignored.
The four added dispatch lines forward to existing formatters; their bodies,
preexisting dispatch paths and all other runtime/C files remain byte-identical.

Source's implicit u64 parameter coercion rejects signed byte-size carriers at
compile time, even when a runtime value is positive. V returns its existing
unsupported integer format error before output for these inputs. Those outcomes
are separate compiler/runtime boundaries, not paired runtime failures. Source
requires compile-time specifiers; V accepts runtime strings. Character/codepoint,
custom reflection, optional/aggregate paths, non-native integer/literal carriers,
general coercions, ABI/layout and allocation/lifetime remain outside this proof.

The Source fixture calls unchanged public methods at their original visibility.
Twenty native/alias integer tags preserve raw bits. Five snapshots retain complete
backing, position, pending/unused bytes and headers, descriptor ownership, raw
argument bits/span, options/type/format/depth and file/wire contents through caller
mutation and flush. Memory, positional/streaming files, replaced pipes and closed
descriptors are represented. Private formatter stack buffers are not observed.
The shared C observer retains established syscall/ownership behavior.

Independent Python models provide duration decomposition, exact rational
integer/binary64 rounding and shortest-decimal rendering, then model writer
boundaries. Expected output is not obtained from V or native process output.
Debug/ordinary and ReleaseSafe/production each pass:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 59,122 | `591dd92bc2f3c00f8490fa87c78b82b917ead851dfde7d301223554ea1b7aa9f` |
| Isolated returning controls | 1,127 | `f1e054f6157516bf322846930d93b0be366153a05d03b4d23b8d74be063501b0` |
| Exact panic/state pairs | 476 | `90720fdc8a87c4f9292451b108ac8c357a17e116696b4f46afe6283dc29c7bbb` |

Fourteen groups cover native/alias extrema, unit and magnitude boundaries,
every fractional thousandth, precision/private-buffer edges, all fill bytes,
seeded values, IO failures and unsigned carrier/depth combinations. Controls
retain huge width/precision behavior, overflow, private-buffer failures and exact
WriteFailed state. Each paired trap requires one exact diagnostic, empty stdout
and matching retained state; all remain active in production.

Sixteen external compiler pairs per mode include four common accepted consumers
for signed/unsigned aliases, copied zero-byte-size options and native usize binary
formatting. Six paired ordinary rejections cover bad parameters and unrepresented
carriers. Six measured boundaries cover runtime specifiers, signed byte sizes,
invalid units, non-native integers, custom durations and optionals. Source compile
errors are not equivalent to V runtime errors.

Three public regressions, all 108 image test files and 17 production/application /
Windows/Linux checks pass. Cross builds establish compilation only. Vaxis source
is unchanged and its dependencies build; its runtime tests are not rerun. Both
historical value-dispatch comparisons retain their hashes in both modes:
primitive dispatch has 16,308 records, 343 controls and 159 panic/state pairs;
float dispatch has 34,661 records, 999 controls and 505 panic/state pairs.

Whole Source and selected compiler libraries, float/math/fmt/Io/time/path/encoder
pins, all 1,336 Ryu table limbs, versions, shared models/helpers, implementations,
fixtures and inputs are checked before/after. Runtime/test/fixture/model bodies
freeze before final comparisons; only EXPECTED assignments change later.
Independent replay checks every observation/failure, compiler outcome, mode,
binary and provenance pin. A corrected development consumer originally expected
byte-slice format validation at compile time; it is retained separately and does
not satisfy successful checks. Every retained archive member is read back before
committing exact reviewed hashes.

Evidence remains pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge successful
output/storage and private allocation remain boundaries. Further printValue
formats/carriers, full Writer.print and custom formatter reflection are unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_units_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-writer-value-units-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and full member readback. Owned RAM and reserves are
released after commit; regenerable caches are excluded.
