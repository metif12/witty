# Predefined colors for custom targets

`predefined_colors[T]()` now follows the source conversion path for built-in
RGB(A) types and aliases. Caller-defined types supply a public static
`T.from_color(value Colorf32) T`, the V counterpart of Source's `T.from.color`.
The callback receives the canonical red/green/blue/white/black/cyan/magenta/yellow
Colorf32 values with opaque alpha. Its returned values are preserved, including
custom channel mappings and alpha choices.

```v
pub struct TaggedColor {
pub:
    tag u32
}

pub fn TaggedColor.from_color(value zigimg.Colorf32) TaggedColor {
    return TaggedColor{tag: u32(value.r == 1)}
}

colors := zigimg.predefined_colors[TaggedColor]()
```

`verify_predefined_generic_reference.py` imports complete unchanged Source at
its original visibility. Source Debug/ordinary V and Source ReleaseSafe/
production V both match **4,352 returning records**, SHA-256
`6978b2a5f30c126670686d36fb0ebac319823591d12fb008e34bc0a6d3d0c11c`.

Seventeen target cases cover all eleven built-in color types, two built-in
aliases and four public custom conversion factories. Every canonical color and
replacement color covers independent copies, original replacement, by-value
returns and whole-copy replacement. A custom fixed-array target also mutates
one copied element while preserving the original. Observations retain all
represented channel/tag/array values, floating bits, signed zero and a custom
NaN payload. The final original constant is observed again after mutation.

Seventeen accepted mutable-copy compiler pairs and seventeen read-only constant
rejection pairs pass in each mode. Two unsupported factory pairs reject missing
conversion and an incorrect return type. No source private factories are exposed
or modified. Custom types with RGB-shaped fields still use their own factory;
the proof's swizzled target verifies that distinction.

Source exposes compile-time namespace constants. V returns a typed value with
read-only fields and evaluates its factories at runtime. A separate Source
compiler rejection/V acceptance pair measures that difference with a callback
which increments runtime state. Two V factory calls observe sixteen callbacks,
with retained output `16|1|8|9|16`. Runtime side effects and initialization timing
do not have matching Source constant semantics. The returning proof uses pure
factories; it does not claim arbitrary compile-time/runtime evaluation parity.
Namespace/value layout, allocation/lifetime, arbitrary callback types and
unrepresented callers remain boundaries.

The existing 31,167 color-model and 35,362 constructor/getter observations retain
their hashes in both modes. All 61 image and 58 Vaxis test files pass, together
with twenty-three production/platform checks: six color/pixel tests,
native/Linux application checks, three Windows DLLs, four Windows matrix
executables, two Linux shared libraries, and the new fixture's Windows
ordinary/production and Linux builds. Cross builds establish compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven std.math files, the SDK math header, compiler versions and before/after
implementation/runner/fixture/input/consumer hashes protect the proof.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_predefined_generic_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-predefined-generic-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete read-back verification. Before-change
implementation and the development preview are retained. Regenerable task-owned
caches and temporary files are excluded. Earlier checkpoint archives were
checksum-verified before pruning their task-owned caches; the compact-enum
archive was completely read back before removing duplicate expanded artifacts.
