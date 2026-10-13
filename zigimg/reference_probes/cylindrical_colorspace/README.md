# Cylindrical colorspace source comparison

The pinned source inlines its Lab, Luv and Oklab cylindrical components into
RGB colorspace conversion before the matrix operations. On the pinned Darwin
ReleaseSafe target, this permits the paired sine/cosine intrinsic. V's public
standalone cylindrical methods deliberately retain separate calls to match the
scientific-color consumers. Colorspace entry points now evaluate the two polar
components together through three private V helpers, using the existing native
math primitive for the corresponding build mode. Alpha is copied explicitly.
The RGB conversion, matrix arithmetic and clamp order remain source-shaped.

`verify_cylindrical_colorspace_reference.py` imports unchanged complete Source
at original visibility. Both corresponding modes match **50,832 records**:

| V mode | Source mode | SHA-256 |
| --- | --- | --- |
| Ordinary | Debug | `28d84845b25575f8818f23627bc011f621bb44fd3c0cb8af508eca9a15f8fe71` |
| Production | ReleaseSafe | `3d1e90958a919819ccf65ddc2d0d2abbdb460d34892411d61c2b13e375ce4173` |

Each record compares RGBA output and every retained input bit. The corpus covers
all twelve presets (including default initialization), Lab/Luv/Oklab cylindrical
families, plain/alpha variants, none/clamp behavior, luminance/chroma/angle boundaries
and seeded random inputs. Angles include negative and positive pi multiples,
signed zero, tiny and very large values, infinities and NaNs. Alpha includes
signed zero, out-of-range values and NaN payloads. Arithmetic canonicalizes NaN
payloads only; retained caller inputs compare all bits exactly.

The **5,792-row historical colorspace corpus is now exact in both modes**.
Ordinary retains `262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0`.
Production matches Source ReleaseSafe
`f5cd4a24f8ea84428809ee7d55725c652f38d25add39f402276b1b62949fd5ba`.
All sixteen differences from the preceding checkpoint are closed. Result pins
now require zero corresponding-mode differences; any changed bit or count fails.

The 6,961 scientific-color records retain their ordinary and production hashes,
including their standalone cylindrical roundtrips. The 9,424 HSLuv records retain
both hashes and all constructor/immutable/type-error controls. The 6,208 matrix-copy,
12,419 named-math and 6,467 generic-math hashes remain unchanged. Three V shape
guards remain active in production; six generic matrix required-field omissions
remain a V compiler limitation. Cross-mode comparisons of ordinary V against
Source ReleaseSafe remain separate observations of build-mode effects.

All 61 image and 58 Vaxis test files pass. Seventeen production/platform commands
cover color/math tests, native/Linux application checks, three Windows DLLs, four
Windows matrix test executables and two Linux shared libraries. Four standalone
color runner invocations also pass. Cross builds establish compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven color std.math hashes, the selected SDK math header, compiler versions and
before/after implementation/runner/fixture/input hashes protect the new proof.
No Source implementation or visibility is substituted. The input generator only
constructs cases; the compiled unchanged Source supplies every expected output.

This proves the represented public consumer paths for the pinned native target.
Undefined storage, physical packed/SIMD ABI, floating-point exception flags,
allocation/lifetime, other compiler/SDK math implementations and unrepresented
caller optimizations remain boundaries. The earlier broad-pairing experiment
showed that changing every standalone cylindrical call was insufficient; those
public methods preserve their existing behavior.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_cylindrical_colorspace_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-color-cylindrical-20261013/verified-proofs.tar.gz`, with a
checksum, per-file manifest and complete read-back verification. Before-change
implementation snapshots, original differing inputs and preview observations are
retained. Regenerable task-owned compiler caches/temporaries are excluded.
