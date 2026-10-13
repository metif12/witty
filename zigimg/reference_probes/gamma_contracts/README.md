# Gamma transfer construction and captured parameters

`NonLinearGammaTransferFunctions` now requires `parameters`, and
`CurveGammaTransferFunctions` requires `gamma`. Source requires an argument to
each factory. Explicit default parameters and zero gamma remain accepted:

```v
nonlinear := zigimg.NonLinearGammaTransferFunctions{
    parameters: zigimg.GammaFunctionsParameters{}
}
curve := zigimg.CurveGammaTransferFunctions{gamma: 2.2}
```

The historical colorspace fixture now supplies explicit default parameters,
matching its existing Source call. No expected values or Source files changed.

`verify_gamma_contracts_reference.py` imports complete unchanged Source at its
original visibility. Source Debug/ordinary V and Source ReleaseSafe/production
V both match **24,192 returning records**, SHA-256
`75aa55611500c1763b7ae71e7150805173730abdca1db0b85e3fc87cb15c3c86`.

Twenty-eight parameter sets cover defaults, four preset parameterizations,
identity and individual zero/signed-zero/negative/infinite/NaN parameter cases.
Thirty-six input patterns include branch thresholds, signed zeros, subnormals,
finite extremes, infinities, quiet/signaling NaNs and seeded raw values. Every
field participates in original/copied mutation, by-value return and whole-copy
replacement. Original/copied/returned parameter bits remain exact.

Transfers capture parameters before caller mutation. All four nonlinear methods,
all four curve methods and both scalar gamma helpers with ordinary/display gamma
compare through original and copied captures. Every non-NaN arithmetic output
bit matches, including signed zero; arithmetic NaNs are canonicalized in both
observers, comparing their occurrence rather than payloads. Parameter-record NaN
payloads are observed without canonicalization.

Each mode passes one default-parameter pair, six mutable-field pairs, six
immutable-field rejection pairs, two complete factories and two omitted-argument
rejection pairs. Two V-only controls preserve immutable captured fields. The
source factory's namespace has no corresponding public storage fields, so these
controls do not claim record-layout or constructor representation equivalence.

Two Source compiler rejections/V acceptances measure the existing runtime
argument adapter. Source factory parameters must be compile-time values; V
constructs a typed value at runtime. The native fixture explicitly evaluates its
parameter generator at compile time, and its initial omitted-comptime diagnostic
is retained. Runtime factory availability, namespace/type identity and physical
representation remain distinct. Arbitrary parameter sets, arithmetic NaN payloads,
allocation/lifetime and unrepresented callers are outside this proof.

The existing 5,792-case colorspace comparison retains its corresponding-mode
hashes with zero differences. All 61 image and 58 Vaxis test files pass.
Twenty-three production/platform checks cover six color/pixel tests,
native/Linux application checks, three Windows DLLs, four Windows matrix
executables, two Linux shared libraries and the new fixture's Windows
ordinary/production and Linux builds. Cross builds establish compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven std.math files, the SDK math header, compiler versions and before/after
implementation/runner/fixture/generated-input/consumer hashes protect the proof.
The cross-platform fixture's generated parameter input and implementation are
also pinned. Source implementation and visibility are unchanged.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_gamma_contracts_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-gamma-contracts-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete read-back verification. Before-change
implementation/fixture and development previews are retained. Regenerable
task-owned caches and temporary files are excluded. The previous checkpoint's
archive was checksum-verified before its task-owned caches were pruned to recover
disk space. Disk exhaustion interrupted final compiler/test runs; their
diagnostics are retained. Four earlier archives were completely read back before
duplicate expanded artifacts were removed. Interrupted checks were rerun after
space recovery, preserving already completed tests and comparisons.
