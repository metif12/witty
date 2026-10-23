# Primitive Writer value dispatch

This is the primitive checkpoint. The subsequent
[float value checkpoint](../writer_value_float/README.md) adds f32/f64 dispatch;
its proof supersedes the float-unrepresented boundary described below. The
[duration/byte-size checkpoint](../writer_value_units/README.md) also adds `D` for
native integers and `B`/`Bi` for unsigned integers, superseding that duration
boundary. The
[character/codepoint checkpoint](../writer_value_text/README.md) adds byte `c` and
Unicode `u`, with an explicit u32-for-u21 carrier adaptation.
The [pointer address checkpoint](../writer_value_address/README.md) adds `*` for
native scalar pointers, optional pointers, slices and aliases, plus opaque
pointers, superseding the corresponding unrepresented boundary below.

`WriteStream.print_value(format, options, value, max_depth)` translates the
represented branches of pinned `std.Io.Writer.printValue`:

| Carrier | Represented formats |
| --- | --- |
| Native u8/u16/u32/u64/usize, i8/i16/int/i64/isize and aliases | empty, `any`, `d`, `b`, `o`, `x`, `X` |
| bool and aliases | empty, `any` |
| Dynamic byte slices and aliases | `s`, `x`, `X`, `b64`, `any` |

Integer dispatch retains unsigned/signed widening, signs, bases, uppercase digits
and padding. Boolean text is aligned normally and ignores precision/depth. Byte
`s` aligns the slice. Hex retains separate nibble writes; base64 retains per-window
writes. These encoded byte forms assert absent precision/width before writer IO,
even when the slice is empty or the supplied option equals zero.

Byte `any` formatting writes `{ ... }` at depth zero, ignoring options. At greater
depth it writes `{ `, each byte as an unsigned decimal using the same options,
separators and ` }`. Empty lists print `{  }`. Element padding and punctuation
remain separate writes, preserving failures after partial opening/element output.
The implementation forwards through non-generic integer helpers so standalone V
consumers retain the required enum/type instantiations. Physical allocation differs.

The scope is explicit. Source's format parameter is compile-time-only; V takes a
runtime string. Invalid/unrepresented formats return an ordinary V unsupported
format error before IO, while Source may reject compilation or support additional
formatters. Only the table's paths claim equivalent returning/trapping behavior.
Floats, character/unicode/duration/byte-size dispatch, pointers, fixed arrays,
optionals, error unions, aggregates, vectors and custom formatter reflection remain
unrepresented by print_value. Their direct existing formatters are separate APIs.
V strings are not implicit byte-slice carriers. General coercion, compile-time
validation, ABI/layout and allocation/lifetime/OOM remain boundaries.

Native fixtures call the original public printValue bodies without changing
Source or visibility. Twenty integer type/alias tags, two bool tags and two byte
slice tags retain raw integer bytes plus a 256-byte carrier and both argument
span descriptors. Five snapshots retain the complete caller backing, position,
unused/pending bytes and headers, descriptor ownership, argument bytes/descriptors,
options, format/type/depth and file/wire contents through caller mutation/flush.
Memory, positional/streaming files, replaced pipes and closed descriptors are
represented. Owned paths/descriptors are cleaned up.

An independent Python integer/string/base64 model dispatches the expected formats,
then models each write boundary. Debug/ordinary and ReleaseSafe/production each
match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 16,308 | `8203d42a2752f0c7daac29017063580b2d879a46202c3a892942147be3dd84f2` |
| Isolated returning controls | 343 | `ec1d20cfe4a1437308688a9aee18632a44969dfa289d93851e93fb9940aab9cd` |
| Exact panic/state pairs | 159 | `da189ef20c753df024c44d68ecb519f3dee1f6d2cd1bf459555e08ef4af65eb1` |

The six groups cover native extrema and aliases, boolean options, slice lengths /
depth including usize.max, failure order, every byte, and ignored options/depth.
Controls include 144 absent-option assertions and 15 integer overflows, huge-width
failures, empty-text center overflow and depth-zero padding bypasses. Returning
WriteFailed observations retain exact state. Every paired trap has one identical
diagnostic, empty stdout and matching retained state observed before writing the observer file.
All remain active in production. Huge successful output is excluded.

Sixteen external compiler pairs pass per mode: four accepted consumers cover
native aliases, boolean options, byte aliases and depth/options copies; six paired
ordinary rejections cover invalid parameter/carrier combinations; six separately
measured boundaries cover runtime format input, an invalid format, duration,
floats, fixed arrays and optionals. The accepted consumers exercise public methods
in separate programs. Source compile errors and V runtime errors are not paired
runtime failure-state proofs.

Three public regressions, all 106 image test files and 17 production/application /
Windows/Linux commands pass. Cross builds prove compilation only. Vaxis source
is unchanged and dependencies build; runtime tests are not rerun. The historical
placeholder suite is rerun in both modes: 10,918 native-compared records, 1,983
V-only model errors and 13 compiler/runtime boundaries retain their prior results
and hashes. Existing runtime files including IO and C remain byte-identical;
writer_value.v is the sole runtime addition.

The Source tree hash remains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
compiler-library hash remains
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole fmt/Io/math/meta/mem/simd and newly reached base64.zig are pinned with prior
path/encoder dependencies. Versions, implementation, shared C helpers, inputs
and fixtures are checked before/after. Runtime/test/fixture bodies freeze before
final comparisons; only EXPECTED assignments change later. Independent replay
checks every observation, exact failure, compiler result, mode, binary and
provenance pin. Failed/superseded observer/consumer runs remain separate from
successful verification. Every retained archive member is read back before commit.

Evidence remains pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid slice descriptors, arbitrary devices/injected short writes, concurrent
mutation, huge successful padding/storage and private allocation/lifetime remain
boundaries. Full Writer.print, further printValue carriers/formats and custom
formatter reflection remain unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-writer-value-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and full member readback. Owned RAM and reserves are
released after committing exact reviewed hashes; regenerable caches are excluded.
