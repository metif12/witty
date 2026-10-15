# Hexadecimal float writer contracts

`print_float_hex[T](value, letter_case, precision)` translates pinned
Writer.printFloatHex for explicit `f32`/`f64` values and direct aliases.
`print_float_hex_options[T](value, options)` translates printFloatHexOptions and
uses `NumberFormat`. Its mode must be `.hex`. Decimal/scientific modes retain
Source's `reached unreachable code` panic; binary/octal modes retain its `TODO`
panic. These are measured pinned-source boundaries.

The formatter preserves sign bits, including negative zero and NaNs. Case affects
fractional hex digits and NAN/INF; the `0x` prefix and `p` marker stay lower case.
Absent precision trims trailing fraction zeros, except zero is `0x0.0p0`.
Explicit precision rounds to nearest with ties to even, normalizes mantissa
carry and supplies trailing zeros. Precision zero omits the decimal point.
Subnormals retain Source's adjusted exponent. Special values ignore precision.

Direct output retains separate sign, prefix, first digit, decimal point,
fraction, zero padding, exponent marker and decimal exponent writes. The options
method renders into a private **50-byte** fixed writer before touching the
parent, then aligns the completed bytes. Excessive precision can exhaust that
private buffer and panic `attempt to unwrap error: WriteFailed`; very large zero
padding can instead trap with `integer overflow`. Parent writer state remains
unchanged at those private failures. Direct output can return WriteFailed after
partial output, and its failure order is different.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 18,492 | `40940467b0c4025e61f4905771c4810d420ff81bf5835fbdf4d459bd9596b70d` |
| Returning controls | 288 | `03acfd647a36adc653242af869f0edcde560e6e3c23c7ebc8022f2782154629f` |
| Exact panic/state pairs | 312 | `5a7f1e06714fe2444cde2d09c8e808786056f5517070e3cb918f351fcc581424` |

The seven deduplicated groups cover native/alias bit boundaries, all f32/f64
exponent-field values, rounding ties and neighboring values, partial failures,
precision/alignment options, every fill byte and 1,024 deterministic bit patterns.
Writers include borrowed memory, positional and streaming files; empty/full
pending output; zero/short/50/65-byte capacity; starts zero/three; regular,
replaced-pipe and closed descriptors; caller backing changes and flushes.
Maximum-width/precision controls retain finite failures/traps/bypasses and exclude
huge successful padding. The 312 pairs comprise 80 decimal/scientific mode
traps, 80 binary/octal mode traps, 120 private-buffer failures and 32 integer
overflows. All traps remain active in production.

Each returning record has five complete snapshots of backing/pending/unused
bytes, logical position, borrowed views, raw argument carrier/header/type and all
options, descriptor validity/references, caller changes, flush status and complete
file/pipe output. A Python integer/divmod model rounds scaled significands with a
quotient/remainder tie test, independently of Source/V's guard-round-sticky loop.
It also models each writer call, private-buffer failure, scratch effects and pipe
transition. Every trap has one exact diagnostic, empty stdout and identical
retained parent state matching the model before the observer opens its state
file. Modeled trap cases have no prior pipe output.

A 175-record / 20-panic preflight passes before final runs. Per mode, external
compiler controls execute five common accepted consumers, compare eleven paired
ordinary rejections, and measure three wider-float carrier boundaries. Source can
format f16/f80/f128; V carrier declarations reject. Untyped 1.1 is an additional
accepted consumer in both languages, with different actual output: Source keeps
its comptime f128 precision, while V uses f64. Exact 1.5 agrees. This literal
boundary is separate from the explicit native-type equivalence claim.

Three public regressions, all 99 image test files and 17 focused production,
application, Windows and Linux checks pass. Historical duration formatting keeps
38,653 records, 598 returning controls and 288 exact panic/state pairs per mode.
Full/streaming IO keeps 37,133 records, 17 generic traps and four compiler
boundaries per mode. Their hashes remain unchanged. Vaxis runtime tests are not
rerun; its source is unchanged and dependency builds pass. Cross builds establish
compilation only.

Complete Source and selected compiler-library pins remain
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`
and `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole Io.zig/fmt.zig/math.zig/meta.zig/time.zig retain their existing pins. New
whole-file pins cover the invoked float helpers:

| Compiler library | SHA-256 |
| --- | --- |
| math/float.zig | `89498b527221904e328326ab55b8c0755977ac4104e2c3e814e3b0c4c73356d3` |
| math/isnan.zig | `9dee284f974e89bcfc81fd90d45c496663fce6c2567e636aa8ca26598b74524e` |
| math/isinf.zig | `9252e2a7668feb48b0d87ff5b5e40a904a62e61838eb187a979f2f390612b004` |
| math/signbit.zig | `7d9fdef881d5e3dec3462602542a2d25a20b1b638c55b7514f2e08a0a631a9e2` |

Runtime and compiler controls check pins before/after, with versions, helpers,
fixtures, implementation, inputs and consumers retained. Complete unchanged
Source is imported at original visibility. Old IO/C bodies remain byte-identical.
Runtime/probe/model bodies freeze before final comparisons; only EXPECTED
assignments are filled afterward. Development evidence preserves the corrected
private-buffer diagnostic and an initial carrier fixture that V parsed as an
unknown function call; final fixtures explicitly name the missing types.

Evidence covers little-endian 64-bit macOS with the pinned compilers. Other
runtimes/CPUs, big-endian or 32-bit execution, arbitrary devices/short drains,
injected errors/signals, syscall counts/timing, invalid/concurrent header/tag
changes, huge successful allocations/padding, OOM/lifetime, portable ABI,
floating-point exception flags and broader coercion/reflection contracts remain
boundaries. Decimal/scientific float rendering and byte-size formatting remain
unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_float_hex_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-writer-float-hex-20261015/verified-proofs.tar.gz`, with
checksum, per-file manifest and full member read-back before the commit. Failed
development evidence stays separate from final comparisons. Regenerable owned
compiler caches and temporary files are excluded from the archive.
