# Quantizer inline roots, contexts and retained mutation state

`verify_quantizer_contracts_reference.py` imports unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and compares Source Debug with ordinary
V, then Source ReleaseSafe with production V:

```sh
python3 zigimg/verify_quantizer_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default native target is
64-bit little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds
commands; `TMPDIR` and `VTMP` select compiler temporaries. Artifacts retain the
unchanged complete Source tree, fixtures, binaries, inputs, outputs, compiler
consumers, commands and provenance.

The quantizer root is now an inline node, matching Source's value record. Copies
preserve independent root scalar metadata and borrowed child pointers. Node copies
also retain independent scalar fields and shared children. Palette contexts require
their palette field; copied context counters remain independent and their palette
storage stays shared. Complete context/inline-root constructor pairs pass, and both
compilers reject direct palette omission. Source's required arena field remains a
separate GC constructor adaptation.

Both modes match **4,594 returning/error records**:

| Returning records | Count |
|---|---:|
| Every byte over four average divisors | 1,024 |
| Average boundary controls | 93 |
| Valid ordered leaf additions | 168 |
| Level registration | 35 |
| Node reset and registration order | 56 |
| Wrapping removal and child clearing | 63 |
| Leaf shortcuts, fallback and missing palette indices | 1,098 |
| Palette writing, budgets, contexts and borrowed output | 797 |
| Quantizer/node/context copies and factory scalar controls | 1,260 |
| **Total** | **4,594** |

Return SHA-256: `5a383dd64249c960f2d3698bc7a6fefc693daba1f196c3b462aab7c9594332ab`.

**1,134 exact panic/state pairs** cover 30 division-by-zero failures, 584 narrowing
casts, 284 arithmetic failures and 236 exact level/palette bounds. Names and exact
diagnostics join initialized snapshots in SHA-256
`b69ded40574ad13007fb9d03ff10b0f6ac7a43334fb207ffad0d249e7fe593dc`.
Each pair requires an unsuccessful exit, the exact diagnostic, no stdout, a
nonempty matching snapshot and no core dump.

Snapshots include context counters, all initialized fields/child/next links of
five caller-owned nodes, all eight quantizer level heads and the entire initialized
RGBA palette. Canonical node IDs use address identity and fixed caller order, with
null represented separately; no raw addresses or physical padding are compared.
The initial fixture used V's pointed-value equality and misidentified equal nodes;
the retained diagnostic and corrected pointer-ID comparison record that failure.

Leaf additions preserve red/green/blue/reference assignment order. Invalid node
initialization resets fields before its registration cast/bounds failure. Wrapping
removeLeaves sums and child clearing precede makePalette's negative cast or leaf
subtraction failure. Palette capacity checks precede color division/casts and
palette/node/context assignments. Leaf lookup bypasses color-level validation;
nonleaf lookup preserves bit selection, first-child fallback and ColorNotFound.
Node palette traversal still visits children of leaf nodes unless the budget's
leaf return skips them. The bounded graph cannot reach usize leaf-sum overflow;
its guard is retained without a manufactured runtime observation.

Caller-owned quantizers are constructed with an initialized Source arena and their
inline root initialized at the caller's stable address. Factory controls observe
root scalars and null level heads one through seven. The factory's captured level-
zero root pointer, returned-record address relocation and its lifetime are excluded;
reduction skips level zero in both implementations. Copied arenas are not allocated
through or deinitialized twice. Private contexts, uninitialized newly allocated
Source nodes, freed arena storage and post-deinit state are excluded.

The model partitions cases; unchanged compiled Source supplies every record and
snapshot. These new controls use Rgb24 and bounded caller graphs. The unchanged
historical matrix retains 2,160 tree/palette/index cases (FNV
`fb25faff7d5b5837`), 336,128 normalization cases (FNV `2e3cf0cdc340afc4`) and
2,816 alias records (SHA-256
`9c9d1fc6249abb82c5ce2d642655a4f6b6b7789e7ad540a9c65993a47cea09d3`) in both modes.

All 61 image and 58 Vaxis test files pass, along with production quantizer/converter/
image-API tests, unchanged historical GIF/image-API/compression assertions in both
modes, native/Linux application checks, three Windows DLLs, both Windows quantizer
test executables and two Linux shared libraries. Cross builds provide build coverage.

GC/arena/OOM/allocation/deinit, newly allocated undefined storage, broader generic
color-method namespaces, record relocation/pointer lifetime, larger graph extents,
file-platform runtime, physical layout and portable ABI remain boundaries. Source
private Node/Context types are inferred from public fields/function types; visibility
and implementation are unchanged. Complete Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Before/after dependency/fixture/input/consumer/runner/implementation hashes and
compiler-version pins protect the comparison.
