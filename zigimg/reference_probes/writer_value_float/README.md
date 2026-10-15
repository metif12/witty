# Float Writer value dispatch

`WriteStream.print_value(format, options, value, max_depth)` now dispatches
explicit f32/f64 values and aliases through the existing numeric formatters.
The pinned public `std.Io.Writer.printValue` bodies run without Source edits or
visibility changes.

| Format | Formatter |
| --- | --- |
| empty, `any`, `d` | Decimal |
| `e`, `E` | Scientific |
| `x`, `X` | Hexadecimal |

Scalar float formatting ignores depth, including zero and usize.max. Precision,
width, fill and alignment are copied through `FormatOptions.to_number`. Native
width is preserved. Source ignores the requested case in its decimal/scientific
renderer: `E` still produces lowercase `e`, `inf` and `nan`. Hexadecimal `X`
uppercases digits and special values, retaining lowercase `0x` and `p`.

Decimal/scientific rendering uses the existing private 347-byte buffer and
`(float)` fallback before alignment. Hexadecimal options use the private 50-byte
buffer and retain its buffer-failure traps before parent writer IO. This proof
observes public writer state; it does not expose those private stack buffers.

The independent Python model maps the seven specifiers to the separately proved
rational shortest-decimal / decimal-record and bitwise hexadecimal models, then
models write boundaries. It does not obtain expected text from V or Source output.
Five snapshots retain the complete caller backing, position, pending/unused
bytes and headers, descriptor state, raw float bits/span, options/type/format/depth
and file/wire contents through caller mutation and flush. Memory, positional and
streaming files, replaced pipes and closed descriptors are represented. The shared
C observer preserves the established syscall and ownership behavior.

Debug/ordinary and ReleaseSafe/production each pass:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 34,661 | `9b1be2318fe7eaecb3cb3bfd15be586a88ee6706ba3001660808812bf52bc609` |
| Isolated returning controls | 999 | `b242db94e195b810ec1280bed4661a74357720c752b6b00f95f7de3b0dcce6c6` |
| Exact panic/state pairs | 505 | `acf103a3ab3f7bd38253490c4deaad6473f23057ea3028b968573e50b7cdfa7e` |

Fourteen groups cover native/alias boundaries, every f32/f64 exponent field,
hexadecimal rounding ties and neighbors, precision/fallback edges, every fill byte,
seeded raw bits, IO failures and all formats at depths zero/one/usize.max. Controls
retain huge precision/width behavior, overflow, buffer failures and exact
WriteFailed state. Each paired panic requires one exact diagnostic, empty stdout
and matching observer state. These traps remain active in production.

Sixteen external compiler pairs per mode include four common accepted consumers
for aliases/defaults, scientific case, hexadecimal case and copied fallback
options. Six paired ordinary rejections cover bad parameter and carrier types.
Six measured boundaries cover runtime format input, two invalid float specifiers,
f16, fixed arrays and optional floats. Source requires a compile-time format;
V takes a runtime string and returns `unsupported print_value float format` for
unsupported specifiers before output. Those runtime errors are not Source compile
errors. Wider/literal float carriers, general coercions, compile-time validation,
ABI/layout and allocation/lifetime remain outside the equivalence claim.

Three public regressions, all 107 image test files and 17 production/application /
Windows/Linux checks pass. Cross builds establish compilation only. Vaxis source
is unchanged and its dependencies build; its runtime tests are not rerun. The
historical primitive value-dispatch comparison retains 16,308 records, 343
returning controls and 159 exact panic/state pairs per mode with unchanged hashes.
`writer_value.v` changes only by adding the float helper/branch and updating the
unsupported-carrier diagnostic. Existing integer/bool/byte code, all other runtime
files, IO and C remain byte-identical.

The Source tree hash remains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
compiler-library hash remains
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole float/fmt/Io/math/meta/time libraries, existing path/encoder dependencies,
versions, implementations, shared models/helpers, fixtures and inputs are checked
before/after. All 1,336 Ryu table limbs match Source. Runtime/test/fixture/model
bodies freeze before final comparisons; only EXPECTED assignments change later.
Independent replay checks every observation/failure, compiler result, mode, binary
and provenance pin. Superseded development evidence remains separate. Every
retained archive member is read back before committing exact reviewed hashes.

Evidence remains pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge successful
padding/storage and private allocation remain boundaries. Further printValue
formats/carriers, full Writer.print and custom formatter reflection are unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_float_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-writer-value-float-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and full member readback. Stale Zig temporary-cache
cleanup has a retained manifest. Owned RAM and reserves are released after commit;
regenerable caches are excluded.
