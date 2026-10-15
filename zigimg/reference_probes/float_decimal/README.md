# Decimal-record buffer formatting

`FloatDecimal64` translates the represented u64 specialization of pinned
`std.fmt.float.FloatDecimal`. Its public mutable mantissa/exponent/sign fields are
required in ordinary direct construction. `format_float_scientific(mut buffer,
value, precision)` and `format_float_decimal(...)` translate formatScientific /
formatDecimal for that carrier. They accept an already-decimal significand and
exponent. Binary conversion and Writer.printFloat are covered by the later
[rendering](../float_render/README.md) and [writer](../writer_float/README.md)
comparisons; byte-size formatting remains unported.
`float_format_min_buffer_size` is 53.

Both helpers require at least 53 input bytes, including special-value calls.
Normal mantissas must be below 10^17; Source asserts this during digit counting.
Exponent 2147483647 instead selects inf for zero mantissa or nan otherwise,
preserving sign and ignoring precision. Special values bypass the mantissa bound.
Normal output uses lower-case e, no positive exponent sign and unpadded exponents.
Decimal precision retains Source's rounding-up rule for discarded digits >=5.
The returned view borrows the beginning of the supplied span; the caller retains
all buffer headers and record values. Ordinary BufferTooSmall failures leave the
buffer unchanged. Safety panics can retain partial writes.

The complete supplied buffer is observable, including scratch bytes beyond the
returned view. The port preserves right-to-left paired digit stores, provisional
points, truncation and zero fills. It also preserves checked arithmetic and
conservative size guards. In particular, pinned isPowerOf10 returns true only for
zero, so the commented carry-normalization branch is not taken after rounding
up. The translation retains that behavior and its overflow order.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 11,922 | `406ad01113cd33d0fbc8e666d47e2ee81a41b494dff304a5505c0b43e3c4242c` |
| Returning controls | 502 | `e5f56f06ea471e70433a8259183a2cb403ae1571907f11ff15710011af524508` |
| Exact panic/state pairs | 480 | `0f0a5720b6566a040a684b9aad2036dcd3d742077e0872aa9bf4332a1bf83ebc` |

Six deduplicated groups cover decimal digit/carry boundaries, size/precision
thresholds, every exponent from -324 through 308, 1,024 deterministic mantissas,
every caller mutation mask, and special-value bypasses. Both APIs and signs,
absent/zero/large precision, borrowed subspans with untouched guards, and buffer
extents through 347 bytes are covered. Controls include every short extent 0..52,
17-digit limits, maximal usize precision and i32 exponent extremes. The traps
comprise 334 checked overflows, 130 assertion failures and 16 bounds failures
with exact index/length diagnostics. Bounds/overflow traps can occur after digit /
point / exponent-marker writes. All remain active in production.

Each return contains ready/output/caller/argument snapshots: the full backing,
returned view header/bytes, configuration, original record and retained copy.
Caller backing mutation proves borrowing; argument mutation proves independent
records and stable output. A Python string/integer model independently computes
rounding and decimal text, then models the required store order and checked
arithmetic. Every failure has empty stdout, one exact panic diagnostic and saved
state matching both implementations/model before observer IO. A 157-record /
26-panic preflight passes before final runs.

Per mode, three common accepted consumers execute exact output. Eleven paired
ordinary rejections cover required/immutable fields and invalid types. Separate
controls retain three representation boundaries: V's returned byte view permits
mutation while Source's []const u8 rejects it; a V direct record alias can omit
required fields while Source rejects that construction; Source's u128 decimal
record formats a 101-bit significand while V's u128 carrier declaration rejects.
These are not claimed equivalent. Public direct record initialization remains
required; alias enforcement, constness and wider carriers remain limits.

Three public regressions, all 100 image test files and 17 focused production,
application, Windows and Linux checks pass. The historical hex float suite keeps
18,492 records, 288 returning controls and 312 exact panic/state pairs per mode.
Full/streaming IO keeps 37,133 records, 17 generic traps and four compiler
boundaries per mode. Historical hashes remain unchanged. Vaxis runtime tests are
not rerun; its source is unchanged and dependency builds pass. Cross builds
establish compilation only.

The public compiler-library bodies run unchanged at original visibility. Complete
Source is retained unchanged for provenance, with SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected library SHA-256 remains
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole fmt/float.zig is newly pinned at
`c660e0ba8697da2d832ecf0cd90ab39aceac7f0ac5c1173d139ce0b66392be12`.
Whole fmt.zig/math.zig/meta.zig/Io.zig retain their existing pins. Runtime and
compiler controls check pins before/after, alongside versions, implementation,
fixtures, helpers, inputs and consumers. All existing module bodies, including
IO/C, remain byte-identical to the preceding checkpoint. New implementation /
probe / model bodies freeze before final comparisons; only EXPECTED assignments
are filled afterward. Development evidence retains a fixture exit-hook namespace
error; final probes use the builtin hook.

Evidence covers little-endian 64-bit macOS and the pinned compilers. Other
runtimes/widths, portable record/optional/array ABI, reflection, generalized
coercions, invalid/concurrently changed headers, allocator lifetime/OOM, huge
buffers and unrepresented consumers remain boundaries. Physical allocation is
unmeasured; returned element constness differs from Source. Binary-to-decimal Ryu
conversion/tables, generic u128 formatting and the remaining writer formatters
are outside this checkpoint.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_float_decimal_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-float-decimal-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and full member read-back before the commit. Failed
development evidence is separate. Regenerable owned compiler caches and temporary
files are excluded from the archive.
