# Custom RGB quantizer getters

The quantizer accepts caller structs without a field named `a` when they provide
`pub fn (value Color) to_u32_rgb() u32`. This receiver method represents Source's
`value.to.u32Rgb()` namespace. RGB comes from the packed getter result, including
when unrelated `r`, `g` and `b` fields exist; the high byte is ignored.
Direct aliases work. Built-in RGB(A) normalization keeps its existing path.

Custom getters run at each insertion level and once at the leaf, and at each
nonleaf lookup level. Leaf lookup returns the stored index without calling the
getter or validating the level. Conversion precedes an invalid-level trap.
Stateful getters therefore retain Source's changing traversal and callback order.

`verify_quantizer_custom_reference.py` compiles the complete unchanged pinned
Source tree at its original visibility. It infers the private Node type from the
public root field. Debug compares with ordinary V, and ReleaseSafe with production
V, using Zig 0.15.2, V 0.5.2 and `aarch64-macos.14.0` with libc.

Run from the repository root, then repeat with `--v-prod` and another empty directory:

```sh
python3 zigimg/verify_quantizer_custom_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Both modes match **9,984 returning/error records**, SHA-256
`b1194bf0c773e7d84e65679dfbe39601590d009286e8c7450223920a357e1095`:

| Returning records | Count |
|---|---:|
| Whole-tree insertion, reduction, palette and lookup | 8,640 |
| Leaf shortcuts, empty-node lookup and valid levels | 1,056 |
| Direct leaf addition at levels 8, 9 and i32 maximum | 288 |

The matrix uses two distinct records, their direct aliases, eight boundary words,
sixteen seeded random words, three pure/stateful getter modes, zero through five
insertions and five palette budgets. It compares the complete ordered getter
trace, initialized reachable tree fields before/after reduction, the complete
initialized palette, returned indices/errors and caller color fields.

**600 exact panic/state pairs** match SHA-256
`22b5beca09fb157bc0ee4f44a92a8e31d87e558320fe98b1aeac611167cd534f`.
There are 480 invalid nonleaf lookups, 24 invalid insertion levels and 96 leaf
accumulation failures: 504 exact cast failures and 96 integer overflows. Each
requires a failing exit, the exact diagnostic, no stdout, no core file and a
nonempty matching snapshot of the getter trace and initialized root fields.
Ordered partial red/green/blue/reference updates remain visible.

Sixteen accepted compiler pairs cover quantizer/node insertion and lookup with
both record shapes and direct aliases. Four missing-getter pairs reject in both
languages with ordinary compiler errors. Four custom-alpha controls compile in
Source and explicitly reject in V: a custom field named `a` selects Source's
premultiplication namespace and must not silently use the RGB getter.

All 61 image and 58 Vaxis test files pass, together with eighteen production and
platform checks. These include production quantizer/converter/image-API tests,
native/Linux application checks, three Windows dependency libraries, two Linux
shared libraries, Windows quantizer tests in both modes and Windows/Linux builds
of this fixture. Cross builds establish compilation coverage only.
The historical 2,160 tree cases, 336,128 normalization cases and 2,816 alias records
retain their hashes in both modes. The existing 4,594 quantizer contract records
and 1,134 exact panic/state pairs also retain both hashes.

Custom alpha namespaces, arbitrary alias chains, getter return types other than
u32, pointer colors, namespace/receiver physical layout, portable ABI, arena/GC
allocation and OOM remain boundaries. Getter side effects in this proof mutate
borrowed trace storage; mutation of the input record through a mutable receiver
is outside this value-color protocol. Caller-owned roots are initialized at
stable addresses. Source factory root relocation, arena copies, uninitialized
allocated fields, post-deinit state and file-platform runtime are excluded.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner checks versions and hashes the implementation, fixtures, itself,
generated inputs and compiler consumers before/after comparison. Python generates
and partitions cases; compiled unchanged Source supplies every compared result.

Retained artifacts are under
`/Users/alex/.cache/witty-quantizer-custom-20261013`. They include the previous
implementation's custom-getter rejection, an initial fixture mutability failure,
the pre-golden comparison, command logs, raw diagnostics/states, provenance and
review files. Completed preview compiler caches were removed. Prior verified
archives retain duplicate expanded evidence pruned to recover disk space.
The completed proof archive is checked against its per-file manifest by reading
back every member.
