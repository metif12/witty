# Quantizer RGB getter widths

Custom RGB getters can return native `u8`, `u16` or `u32`. The quantizer widens
narrow results to u32 before unpacking RGB, matching the pinned Source's implicit
unsigned conversion into `Rgb24.from.u32Rgb()`. An eight-bit getter supplies only
blue; a sixteen-bit getter supplies green and blue. The high byte of u32 is ignored.
Direct aliases of the caller color work. Conversion still runs at each tree level.

The previous V constraint accepted only methods declared to return u32. Two
additional private structural interfaces admit u8/u16 without accepting signed,
wide, boolean or floating results. Existing alpha selection precedes this RGB
path. A private alpha marker also works with a narrow RGB getter, and that getter
stays uncalled. Private alpha-only records remain a separate V visibility limit.

`verify_quantizer_getter_width_reference.py` compiles the complete unchanged
pinned Source tree at its original visibility. Private Node is inferred through
the public root field. Source Debug compares with ordinary V, and ReleaseSafe
with production V, using Zig 0.15.2, V 0.5.2 and `aarch64-macos.14.0` with libc.
Run from the repository root, then repeat with `--v-prod` and another empty directory:

```sh
python3 zigimg/verify_quantizer_getter_width_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Both modes match **15,012 returning/error records**, SHA-256
`a42d9d71684d4e710d460a54f48c1fd93de9452e830855e65a2081939e4807fd`:

| Returning records | Count |
|---|---:|
| Whole-tree insertion, reduction, palette and lookup | 12,960 |
| Leaf shortcuts, empty-node lookup and valid levels | 1,584 |
| Direct leaf addition at levels 8, 9 and i32 maximum | 432 |
| Zero-channel additions at u32 component limits | 36 |

Three records and direct aliases cover all supported result widths, eight boundary
words, sixteen seeded words, three pure/stateful modes, zero through five additions
and five palette budgets. Comparisons observe delivered getter-word traces,
initialized reachable tree fields before/after reduction, the full initialized
palette, returned indices/errors and caller fields. Narrowing belongs to the
caller getter; Source supplies every compared conversion and tree observation.

**864 exact panic/state pairs** match SHA-256
`23c05fb50943d60a7dbf64fcff1ac189ed1811815ab5549cd08fdb5fbbc3a068`:
720 invalid nonleaf lookups, 36 invalid additions and 108 leaf accumulation failures,
comprising 756 casts and 108 overflows. Each requires a failing exit, exact panic,
no stdout/core file and a nonempty matching getter/root snapshot. Zero channels
preserve Source's successful partial additions instead of creating false overflow
expectations. Leaf lookup skips the getter and level validation.

Twenty-four accepted compiler pairs cover quantizer/node insertion and lookup for
native widths and direct color aliases. Twenty-eight rejection pairs cover i8,
i16, i32, i64, u64, bool and f32 results; rejections must be ordinary compiler errors,
with the expected diagnostic and no compiler crash, backend or link failure.
Eight additional pairs build and execute private-alpha consumers with u8/u16 RGB
getters that panic if called. They pass without invoking that getter.

Twelve separate controls measure an existing result-alias limitation: Source
accepts aliases of the getter's integer return type, while V's structural-interface
match rejects those signatures. This differs from aliasing the caller color,
which works. Arbitrary alias chains, non-native Zig integer widths, private
alpha-only markers, pointer colors, mutable input receivers, physical layout,
portable ABI, arena/GC/OOM, factory root relocation and file-platform runtime
remain boundaries. Roots are initialized at stable caller addresses. Freshly
allocated undefined fields, copied arenas and post-deinit state are excluded.

All 61 image and 58 Vaxis test files pass, with eighteen production/platform
checks. The new module regression checks mixed u8/u16 insertion, direct aliases,
palette/index order, direct leaf conversion and the leaf shortcut. Production
quantizer/converter/image-API tests, native/Linux application checks, three Windows
libraries, Windows quantizer tests, two Linux shared libraries and Windows/Linux
builds of the new fixture pass. Cross builds establish compilation coverage only.
Existing RGB 9,984-record/600-failure and alpha 19,968-record/1,200-failure hashes
remain unchanged in both modes, as do the historical 2,160 tree, 336,128 normalization
and 2,816 alias records. The tree mutation and built-in normalization code is unchanged.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after implementation, fixture, runner, helper, input and
consumer hashes protect the comparison. Python generates and partitions inputs;
compiled unchanged Source supplies every compared result and snapshot.

Retained evidence is under
`/Users/alex/.cache/witty-quantizer-getter-width-20261013`: the Source-accepted/
V-rejected baseline, comparison before locking goldens, commands, raw outputs,
diagnostics and states, provenance and review files. Completed compiler caches
were pruned. Earlier checksum-verified archives retain expanded duplicate proof
files removed to recover disk space. The completed archive is verified by reading
back each member against the per-file manifest.
