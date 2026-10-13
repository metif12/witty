# RGB colorspace record contracts

The pinned `RgbColorspace` record requires all ten fields: four chromaticities,
two conversion matrices and four transfer callbacks. V now requires the same
represented fields. Callback storage retains the V `_fn` suffix because the
corresponding method names already exist. `RgbColorspaceInitArgs` remains a
separate defaultable record, with zero chromaticities and identity transfer
callbacks. The factory explicitly initializes every required field.

`verify_colorspace_records_reference.py` imports complete unchanged Source at
original visibility. Both corresponding modes match **7,920 returning records**:

| V mode | Source mode | SHA-256 |
| --- | --- | --- |
| Ordinary | Debug | `20d49e2104dc25aa362ce0ffc8347fa7b074c17c154fe7c5f5531412f9eba1ad` |
| Production | ReleaseSafe | `20d49e2104dc25aa362ce0ffc8347fa7b074c17c154fe7c5f5531412f9eba1ad` |

Three construction forms cover explicit records, custom factory arguments and
default factory arguments. Six operations cover unchanged records, copied-field
mutation, original-field mutation after copying, whole-field replacement and
by-value return, whole-record replacement, and argument mutation after factory
construction. All ten fields receive boundary and seeded random cases, including
wrapping callback selectors. Matrices retain independent inline storage.

Each observation retains original, copied and returned chromaticities and
matrices, then calls all four transfer methods. Logged callback identifiers and
raw argument bits establish callback choice, RGB channel order and invocation
count. Alpha bypasses the callbacks and retains its exact bits. Inputs include
signed zero, subnormals, infinities and NaNs. Chromaticities, alpha and retained
input bits compare exactly; matrix and RGB arithmetic canonicalize NaN payloads
only. The source's undefined temporary factory matrices are replaced before use
and are excluded from observations.

Each mode also checks three accepted consumers, ten omitted-field rejection
pairs and ten immutable-binding rejection pairs against the native compiler.
Default factory arguments remain accepted, while direct record construction
must name every field.

The 6,208 matrix-copy, 12,419 named-math, 6,467 generic-math, 6,961 scientific-color,
5,792 colorspace, 9,424 HSLuv and 50,832 cylindrical colorspace records retain their
corresponding-mode hashes and frontend controls. All 61 image and 58 Vaxis test
files pass, along with seventeen production/platform commands and four standalone
color-runner invocations. Cross builds establish compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven color std.math files, the SDK math header, compiler versions and before/after
implementation, runner, fixture, input and consumer hashes protect the proof.
Undefined storage, physical ABI and callback pointer addresses, floating-point
exception flags, allocation/lifetime, other compiler/SDK implementations and
unrepresented callers remain boundaries. Generic matrix omissions remain the
measured V compiler adaptation described in the matrix contract proof.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_colorspace_records_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-colorspace-records-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete read-back verification. The before-change
implementation, development previews and two wrong-working-directory launch
failures remain retained. Regenerable task-owned compiler caches and temporary
files are excluded from the manifest.
