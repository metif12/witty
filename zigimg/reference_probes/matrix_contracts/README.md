# Matrix construction and copy contracts

`verify_matrix_contracts_reference.py` imports unchanged pinned `src/math.zig`
and checks the three named matrices and generic dimensions 1, 2, 3, 4, 5 and 8.
The source requires the `matrix` field. Named V records now enforce this;
public factories initialize storage explicitly, and private arithmetic helpers
construct results from initialized values before overwriting every component.
The colorspace constructor supplies initialized placeholders for the source's
explicitly undefined temporary matrices, then replaces them before use.

The new corpus matches **6,208 returning records** in ordinary V/Source Debug
and production V/Source ReleaseSafe. SHA-256:
`1e940bc5ea0d199b792cd64c703e955fc6aae99f6c37596f2398d72021358525`.
Each record observes every initialized component of direct and flat constructors,
mutated copies, replaced rows and whole fields, caller storage/flat input,
by-value function returns, transposed results, retained originals and identities.
Every cell is a mutation target. Uniform, mixed and seeded random bit patterns
include signed zero, subnormals, infinities, quiet/signaling NaNs and payloads.
Copy observations compare all f32 bits without NaN canonicalization.

Both modes check nine accepted explicit constructors, three required-field
rejection pairs and eighteen immutable cell/whole-field rejection pairs.
Six generic omission controls record Source rejection and V acceptance:
pinned V 0.5.2 ignores `@[required]` on `Matrix[B].matrix`. The annotation states
the source contract, but callers must supply storage themselves. No default
V value is presented as a returning Source observation.

```v
type Rows5 = [5][5]f32

named := zigimg.Float2x2{matrix: [2][2]f32{}}
generic := zigimg.Matrix[Rows5]{matrix: Rows5{}}
identity := zigimg.Matrix.identity[Rows5]()
```

The four unchanged historical corpora retain **31,639 matching records**:

| Corpus | Records | SHA-256 |
| --- | ---: | --- |
| Named math | 12,419 | `23be1b2c20e279a493dda64087e1916b58e6fdbc8bdcb76469c15b7231a4fb31` |
| Generic math | 6,467 | `f303b568d8901d722b61cb805d2ccd212e57c10a758d2b530f15ab4d710e9c0f` |
| Scientific colors | 6,961 | `d97550d49bb60cf224fc60999d3603d6199aa9c99702a7c79b8d7ca9f10e8566` |
| RGB colorspaces | 5,792 | `262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0` |

Named/generic arithmetic uses Source Debug/ReleaseSafe with the corresponding
V mode. Both color histories preserve their original **Source Debug oracle**
against both V modes. Arithmetic comparisons canonicalize NaN payloads, retaining
all other bits. The three V shape guards remain active in production.

Separate unchanged Source ReleaseSafe color controls retain **five scientific
and 32 colorspace differences** against either V mode. Their native hashes are
`0f89855f7a8b779c3c40600a456fe34c9f88e8a006fb1702ce0d1906b7a939a8` and
`f5cd4a24f8ea84428809ee7d55725c652f38d25add39f402276b1b62949fd5ba`;
difference hashes are `0bee6436f84cce99c39d3ce12ea0d2796f72f90536a4632046943507ef73574c`
and `d8037c0389d0cac691c8e1efc9305e75dd348040e77cfefe3de30e3016f1e697`.
The five scientific rows affect HSLuv saturation and returned chroma. Optimized
native binaries import Apple's combined `___sincosf_stret`; Debug and V use
separate calls. Symbol selection is checked, without asserting it explains every
colorspace difference. Exact optimized color parity remains outside this checkpoint.
Full inputs and both differing outputs are retained separately from matching records.

Source/stdlib/compiler versions and before/after implementation, runner, fixture,
corpus-generator, input and consumer hashes protect the proof. Complete Source
SHA-256 is `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The seven inherited color std.math helper hashes are also checked before/after.
Native imports retain original visibility. No Source implementation is substituted.

Session artifacts are retained at
`/Users/alex/.cache/witty-matrix-contracts-20261013/verified-proofs.tar.gz`,
with a SHA-256 checksum, per-file manifest and complete archive read-back.
Earlier fixtures/comparisons and the temporary-disk-space failure have separate
verified archives inside that artifact. Final V/compiler caches and temporaries
are task-owned and excluded from the retained manifest.

Run from the repository root with pinned Zig 0.15.2 and V 0.5.2:

```sh
python3 zigimg/verify_matrix_contracts_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/ordinary
python3 zigimg/verify_matrix_contracts_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --v-prod --workdir /path/to/empty/production
```

Undefined memory, physical layout/padding/SIMD ABI, zero-length arrays, extra
storage alias layers, generic factory forwarding, allocation/lifetime and shapes
outside the represented controls remain boundaries. Retained values establish
copy semantics, without claiming physical record/layout equivalence.
