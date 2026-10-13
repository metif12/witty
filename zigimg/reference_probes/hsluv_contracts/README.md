# HSLuv record and ray contracts

`HSLuv` requires hue, saturation and lightness; `HSLuvAlpha` also requires alpha.
The pinned source gives none of these fields a default. V now enforces all seven
requirements. Fields remain publicly mutable, and copies retain independent inline
values. The source's two float4 signature typos remain unchanged: its factory
returns `CIELuvAlpha`, and its float4 function accepts that type.

The HSLuv ray evaluates sine and cosine of the same angle. On the pinned macOS
compiler target, Source Debug uses separate calls and ReleaseSafe selects Apple's
combined intrinsic. A small C primitive wrapper uses the SDK's `__sincosf` in
Darwin V production builds and separate calls otherwise; the ray calculation
remains in V. Public cylindrical conversions retain their independent calls.

`verify_hsluv_contracts_reference.py` imports unchanged complete Source at original
visibility. Both corresponding compiler modes match **9,424 returning records**:

| Mode | Source | SHA-256 |
| --- | --- | --- |
| Ordinary V | Debug | `f07e05a03320b8b6fe232813a45686fd2b21d4ebb7767a812900c0bd11436762` |
| Production V | ReleaseSafe | `e26a6d77e9297e5e9e3224fda48e876eba468443deea92806b181bda37f766af` |

The corpus covers plain/alpha records, every mutable field, copied and replaced
records, by-value returns, unchanged callers, both conversion directions, the
alpha-to-plain view and the wrong-type float4 bridge. Four matrices include
identity, mixed coefficients, zero storage and a singular matrix. Bit patterns
include signed zero, subnormals, infinities, quiet/signaling NaNs and payloads,
seeded random inputs and lightness thresholds. Copy/bridge observations compare
all bits; arithmetic comparisons canonicalize NaN payloads only.

Each mode also checks three accepted constructors/bridge consumers, seven
required-field rejection pairs, seven immutable-field rejection pairs and two
rejection pairs preserving the source's float4 signature errors.

The 6,961-row historical scientific-color corpus now matches its corresponding
Source mode exactly. The ordinary hash remains
`d97550d49bb60cf224fc60999d3603d6199aa9c99702a7c79b8d7ca9f10e8566`; production
matches `0f89855f7a8b779c3c40600a456fe34c9f88e8a006fb1702ce0d1906b7a939a8`.
All five previously recorded scientific production differences are closed.

The 5,792-row colorspace history remains exact in ordinary mode, hash
`262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0`.
Production closes sixteen of its former 32 differences and retains **16
cylindrical-conversion differences**. Source ReleaseSafe hash is
`f5cd4a24f8ea84428809ee7d55725c652f38d25add39f402276b1b62949fd5ba`; V production
hash is `2043e0e258e164d0671082d5a356d5a80c2f993580dee63aae38c8258e6d79cd`.
The remaining difference hash is
`e32e3f667c6a3c4e437f9fd658f7f3e10a3f32f67b835f944d958ca9ae5064d1`.
Every mismatch retains its full input and both outputs; any changed result,
additional mismatch or missing case fails verification.

A broad paired-call preview introduced 109 scientific mismatches while the
Source ReleaseSafe public roundtrips retained separate-call results. This is
consistent with caller-dependent LLVM selection, rather than a uniform rule
for all cylindrical APIs. That preview was discarded. Exact optimized parity
for the remaining colorspace cases is not claimed. Cross-mode observations
(Source ReleaseSafe versus ordinary V) remain separate controls in the matrix
runner; they do not count as corresponding-mode regressions.

All 61 image and 58 Vaxis test files pass, with production color/math tests,
native/Linux application checks, three Windows DLLs, four Windows matrix test
executables and two Linux shared libraries (17 platform commands). Cross builds
establish compilation coverage, not numerical equivalence on those platforms.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven color std.math hashes, the selected SDK math header, compiler versions and
before/after implementation/runner/fixture/input/consumer hashes protect the proof.
Undefined memory, physical packed/SIMD ABI, floating-point exception flags,
allocation/lifetime, other compiler/SDK math implementations and unrepresented
callers remain boundaries. No Source implementation or visibility is substituted.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_hsluv_contracts_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-color-trig-20261013/verified-proofs.tar.gz`, with checksum,
per-file manifest and complete read-back verification. Development observations,
including the initial temporary-space failure, are retained. Regenerable task-owned
compiler caches and temporary files are excluded from the manifest.
