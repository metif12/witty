# Binary float conversion and buffer rendering

`float_to_decimal[T]` translates the pinned 64-bit full-table Ryu backend for
explicit f32/f64 values and aliases. `render_float[T](mut buffer, value, options)`
connects that record to the existing decimal/scientific buffer formatters.
`FloatRenderOptions` defaults to scientific mode and absent precision;
`float_format_buffer_size[T](mode)` returns 53 for scientific output and 55/347
for decimal f32/f64. The minimum supplied span remains 53 bytes.

The port uses exact two-limb integer multiplication for Source's u128 products.
All 326 power-of-five and 342 inverse-power pairs (1,336 limbs) match original
Source constants before/after comparison. Both compiler modes select Source's
Backend64_TablesFull. ReleaseSmall's separate backend is outside this proof.
The pinned lower endpoint uses fraction != 0 or exponent == 0; its exponent-one
case is retained. Shortest selection, endpoint inclusion and binary ties to even
precede the already-translated decimal precision rounding. Signed zero, signed
infinity, NaN payload/sign, subnormals and extrema retain their records.

The independent model constructs legal intervals with exact integer fractions,
searches the shortest decimal significand and selects the nearest candidate
with even tie handling. It uses neither Ryu tables nor a host float string as its
oracle. Candidate generation uses host powers of ten only to choose nearby bit
patterns. It then uses the previously verified decimal store model for visible
text, scratch stores, returned headers, mutation, errors and retained state.
Every binary exponent is covered with four significand edge/seed variants and
both rendering modes. Other groups cover aliases, special values, decimal-power
neighbors, deterministic raw bits, precision/buffer thresholds and every caller
mutation mask. Explicit caller mutation proves the result borrows its subspan.

The native fixture invokes the original public render body at original visibility.
It reconstructs finite conversion records from full-precision scientific text;
V exposes its conversion record directly. For zero/special records it invokes
original binaryToDecimal with a fixture backend that panics on every table
access; those early-return branches need no tables. Private Source backends are
never exposed or changed. This is a finite comparison, not exhaustive IEEE space.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 28,340 | `c20232f55f25e1f8389ec824430e05ecda9de8ecc1ba8cf1ec78284ca12387c8` |
| Returning controls | 184 | `b8d4b40ae6921c25b6fff0292df05e28609f99e5e9d0f05a4e0695f55c84cfc5` |
| Exact panic/state pairs | 146 | `a778191c50a02c212278e602f0b821edb57a69ead075fa3089e76a12461fe06d` |

A 151-record / 10-trap rendering preflight and 150-record / 10-trap writer
preflight pass before final runs. Per mode, four accepted external consumers and
six paired ordinary compiler rejections pass. Five separate compiler boundaries
measure Source's const output versus V's mutable view, Source f16/f80/f128
versus missing V carriers, and Source comptime buffer sizes versus V's runtime
function result being rejected as a fixed-array length. Constants may call that
V function for runtime initialization; this does not supply a comptime length.
Untyped literal precision, generalized coercions and wider formats stay outside
the explicit native-type claim.

Three public regressions and all 101 image test files pass. Seventeen production,
application, Windows and Linux checks pass; cross builds establish compilation
only. Vaxis source is unchanged and dependency libraries build; its runtime tests
are not rerun. The historical decimal-record suite keeps 11,922 records, 502
returning controls and 480 exact panic/state pairs per mode. Full/streaming IO
keeps 37,133 records, 17 generic traps and four compiler boundaries. All historical
hashes remain unchanged; generic stream traps do not prove exact state.

Complete pinned zigimg Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler libraries remain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole fmt/float.zig remains
`c660e0ba8697da2d832ecf0cd90ab39aceac7f0ac5c1173d139ce0b66392be12`.
All invoked library pins, versions, unchanged Source, implementation, fixtures,
helpers and inputs are checked before/after. Runtime/probe/model bodies freeze
before discovery; only EXPECTED assignments change afterward. Independent replay
checks every observation, compiler outcome, table limb, mode and retained proof.
Every retained archive member is read back before the reviewed files are committed.
Failed/superseded development evidence stays separate from successful checks.

Evidence covers the pinned compilers on little-endian 64-bit macOS. Other runtime
platforms/widths, ReleaseSmall, f16/f80/f128/u128 carriers, portable ABI/reflection,
allocation/lifetime/OOM, floating exception flags and invalid/concurrent header
mutation remain boundaries. V fixed-array slices copy private storage and its
returned bytes are mutable; allocation and Source constness are not equivalent.
Generic byte-size and remaining writer formatters are outside this checkpoint.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_float_render_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-float-render-20261015/verified-proofs.tar.gz`, with a
checksum, file manifest and complete member readback. Regenerable compiler caches
and temporary files are excluded; owned RAM and reserves are released afterward.
