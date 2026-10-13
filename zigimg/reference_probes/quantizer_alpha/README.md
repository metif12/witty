# Custom alpha quantizer getters

Caller colors with an `a` field use `premultiplied_alpha()` followed by the
returned value's `to_u32_rgba()` receiver method. These methods represent Source's
`.to.premultipliedAlpha()` and `.to.u32Rgba()` namespaces. The returned packed
RGBA word supplies RGB directly; the quantizer drops its alpha byte without
premultiplying again. The marker's value and type do not supply the alpha value
for a custom getter. The caller defines premultiplication.

A public `a` marker supports alpha-only records. A private marker works when the
record also supplies `to_u32_rgb() u32`; that getter remains uncalled. The pinned
V compiler checks the fallback's field-presence constraint even after the
reflected alpha branch returns, causing four measured Source-accepted/V-rejected
controls for private alpha-only records. Built-in colors retain their existing
normalization path. Direct color and intermediate aliases work.

A minimal caller protocol is:

```v
struct CustomAlpha {
pub:
    a u8
}
pub fn (value CustomAlpha) premultiplied_alpha() zigimg.Rgba32 {
    return zigimg.Rgba32.rgba(20, 30, 40, 128)
}
```

The method above supplies an already premultiplied value. The quantizer does not
infer its channel values from `a`, nor call its premultiplication method again.
Any represented intermediate with a public RGBA getter can be returned.

`verify_quantizer_alpha_reference.py` compiles the complete unchanged pinned
Source tree at original visibility. Its private Node type is inferred through
the public root. Source Debug compares with ordinary V, and ReleaseSafe with
production V, using Zig 0.15.2, V 0.5.2 and `aarch64-macos.14.0` with libc.
Run from the repository root, then repeat with `--v-prod` and another empty directory:

```sh
python3 zigimg/verify_quantizer_alpha_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Both modes match **19,968 returning/error records**, SHA-256
`7653a7e51e6d1e8e00b5f3d4ef335dbbc93ee434b3e2d6038d2f5def96c0fa41`:

| Returning records | Count |
|---|---:|
| Whole-tree insertion, reduction, palette and lookup | 17,280 |
| Leaf shortcuts, empty-node lookup and valid levels | 2,112 |
| Direct leaf addition at levels 8, 9 and i32 maximum | 576 |

Four distinct records and direct aliases return RGBA32, RGBA64, Colorf32 and a
custom aliased intermediate. Their `a` fields have u8, u16, f32 and bool types.
The custom intermediate records its own getter calls. Pure and two stateful
getter modes exercise eight boundary words, sixteen seeded random words, zero
through five insertions and five palette budgets. Comparisons cover complete
ordered callback phase/word traces, initialized reachable tree fields before
and after reduction, the complete initialized palette, indices/errors and caller
color fields. An RGB getter that panics if called proves alpha selection.

Custom conversion runs at each insertion level and at the leaf, and at every
nonleaf lookup. Premultiplication precedes the returned RGBA getter each time.
Leaf lookup skips both getters and level validation. Invalid nonleaf levels trap
after both conversion stages. Leaf overflow preserves partial component/reference
updates after the callbacks.

**1,200 exact panic/state pairs** match SHA-256
`54f0e42d2d108ae9cabfd20a4ef52a6b0fab07acbb3ada79e90c6bf867558513`:
960 invalid nonleaf lookups, 48 invalid insertions and 192 leaf accumulation
failures, comprising 1,008 casts and 192 overflows. Each pair requires a failing
exit, the exact diagnostic, no stdout, no core file and a nonempty matching
snapshot of callback traces and initialized root fields.

Thirty-two accepted compiler pairs cover quantizer/node insertion and lookup
with four return types and direct aliases. Sixteen rejection pairs cover missing
premultiplication despite an RGB getter, missing intermediate RGBA getters,
unsupported u64 RGBA results and records with neither `a` nor an RGB getter.
Rejections require ordinary compiler diagnostics and exclude compiler crashes,
backend and link failures. Four separate visibility controls measure the private
alpha-only marker limit described above.

All 61 image and 58 Vaxis test files pass, together with eighteen production and
platform checks. The new module regression checks paired callbacks, alpha-byte
discard, direct aliases and the leaf shortcut. Production quantizer/converter/
image-API tests, native/Linux application checks, three Windows dependency
libraries, Windows quantizer tests, two Linux shared libraries and Windows/Linux
builds of the new fixture pass. Cross builds establish compilation coverage only.
The existing RGB 9,984-record/600-failure proof, quantizer 4,594-record/1,134-failure
proof and historical 2,160 tree, 336,128 normalization and 2,816 alias records retain
all hashes in both modes. The RGB runner now accepts four alpha controls.

Private alpha-only markers, arbitrary alias chains, pointer colors, unsupported
getter result types, mutable input receivers, namespace/receiver physical layout,
portable ABI, arena/GC/OOM, factory root relocation and file-platform runtime
remain boundaries. Trace side effects mutate borrowed storage. Roots are
initialized at stable caller addresses; Source factory level-zero relocation,
arena copies, freshly allocated undefined fields and post-deinit state are excluded.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after implementation, fixture, runner, helper, input and
consumer hashes protect this proof. Python generates and partitions cases;
compiled unchanged Source supplies every compared result and snapshot.

Retained artifacts are under
`/Users/alex/.cache/witty-quantizer-alpha-20261013`. They include the previous
implementation's alpha rejection, visibility/offset-check/code-generation
attempts, the comparison before locking goldens, command logs, raw diagnostics
and states, provenance and review files. A separate generic helper avoids V's
removal of intermediate methods referenced only inside a reflected branch.
Completed preview caches were pruned. Earlier checksum-verified archives retain
duplicate expanded evidence removed to recover disk space. The completed proof
archive is verified by reading every member against its per-file manifest.
