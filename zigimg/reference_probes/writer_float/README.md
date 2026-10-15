# Decimal and scientific writer formatting

`WriteStream.print_float[T](value, options)` translates Writer.printFloat for
explicit f32/f64 values and aliases. NumberFormat defaults to decimal output;
scientific output selects `.scientific`. Binary, octal and hex modes retain the
unreachable panic before parent output. Case is ignored, including inf/nan.

Rendering finishes in a private 347-byte buffer, even for f32, before alignment
or parent writes. BufferTooSmall substitutes the literal `(float)`, then applies
width/fill/alignment. Precision arithmetic still traps instead of falling back.
Conservative size checks can reject a representation that would visibly fit.
The source's internal buffer choice and fallback/failure order are preserved.

An exact integer-interval conversion model and the prior decimal store model
supply the bytes or fallback. A separate stream model computes alignment and
memory, positional-file, streaming-file, replaced-pipe and closed-file effects.
Five snapshots retain positions, full backing, pending/unused bytes and headers,
raw arguments/options, descriptor ownership and file/wire bytes. Controls compare
one exact panic and state captured before observer IO; all formatter traps occur
before parent output. Returning controls also cover buffered/drain WriteFailed
and partial alignment effects. Owned paths/descriptors are cleaned up.

Six groups cover native/alias boundaries, every exponent, write/failure order,
precision/fallback/options, all 256 fills and deterministic raw bits. File starts,
empty/full prefixes, absent/present width, all alignments and both case settings
are represented. Maximal usize precision/width and invalid modes are separate
controls. Successful huge output and arbitrary short-drain devices are excluded.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 13,976 | `94d8a1b0be822bd6fedc88965d5070b34e387338cebc2709e99f8102aa06a7a7` |
| Returning controls | 309 | `b2ab1802865e39103abe8715305ed2a5863ff424faf19cb69847d94e557904de` |
| Exact panic/state pairs | 143 | `72c6c1a9f5058ad2d62a1e7a9133d377afb5f7d03f8ee7da3b8ad6ee935ee96c` |

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
python3 zigimg/verify_writer_float_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-float-render-20261015/verified-proofs.tar.gz`, with a
checksum, file manifest and complete member readback. Regenerable compiler caches
and temporary files are excluded; owned RAM and reserves are released afterward.
