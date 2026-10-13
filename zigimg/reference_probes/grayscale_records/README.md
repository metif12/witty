# Grayscale record construction and conversion

All nine pinned grayscale types require `value`. The three alpha variants retain
their source defaults: 255, 65535 and 1.0. V now enforces the required value in
named record construction, while preserving public mutation and independent
inline copies. The represented types are Grayscale1/2/4/8/16,
Grayscale8Alpha/16Alpha, Grayscalef32 and Grayscalef32Alpha.

`verify_grayscale_records_reference.py` imports complete unchanged Source at its
original visibility. Ordinary V/Source Debug and production V/Source ReleaseSafe
both match **10,232 returning observations**, SHA-256
`dc6b5c8e04f277b0bd37a373851c553d46686d67092d95af8f7667b30d96b272`.

The corpus covers default and explicit alpha, all mutable fields, unchanged
records, copied-field mutation, original mutation after copying, by-value returns
and whole-copy replacement. It observes original/copied/returned channel values
and their public `toColorf32` results. Integer boundaries and seeded random values
cover every represented width. Floating cases include signed zero, subnormals,
infinities, quiet/signaling NaNs and payloads. All channel and result bits compare
exactly; no NaN canonicalization is used in this proof.

Each mode also checks nine accepted mutable constructors, nine omitted-value
rejection pairs and twelve immutable-field rejection pairs. Three separate
constructor controls retain the measured width adaptation: Source rejects values
outside u1/u2/u4, while V accepts those values in its u8 record fields.

The three sub-byte `to_colorf32` methods now use explicit checks that remain
active in production. Six isolated width-failure pairs compare the native checked
integer-cast panic with the V conversion check. These failures occur at different
boundaries: Source fails while casting a runtime input for record construction;
V can retain the wider value and fails when the conversion is called. The proof
does not claim equivalent construction or failure timing for invalid channels.

Existing color-model and constructor/getter matrices retain their hashes in both
modes. Matrix-copy, named/generic math and scientific/colorspace comparisons also
retain their corresponding-mode results and compiler controls. All 61 image and
58 Vaxis test files pass, with six production color/math test executables,
native/Linux application checks, three Windows DLLs, four Windows matrix test
executables and two Linux shared libraries (nineteen platform commands).
Cross builds establish compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven std.math files, the SDK math header, compiler versions and before/after
implementation/runner/fixture/input/consumer hashes protect the proof. Undefined
allocator storage, physical sub-byte representation, allocator/lifetime behavior,
unrepresented generic grayscale types and callers remain boundaries. Native
numeric generic factories and their V call-shape/compiler adaptations are covered
by [the subsequent generic proof](../grayscale_generic/README.md).
Source implementation and visibility are unchanged.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_grayscale_records_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-grayscale-records-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete read-back verification. Before-change
implementations and development previews are retained, including the fixture's
initial attempt to print the source's zero-sized method namespace. Regenerable
task-owned compiler caches and temporary files are excluded from the manifest.
