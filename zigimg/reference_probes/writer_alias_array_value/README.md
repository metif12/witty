# Aliased pointer array contents

Fixed arrays of pointers to byte aliases now format as pointers under `any`.
For an array with two `&Byte` elements, `Byte = u8`, and pointer bits `0x1234` /
`0x5678`, output is `{ u8@1234, u8@5678 }`. Previously the byte formatter read
pointer storage as bytes and printed `{ 52, 18 }`. Whole-pointer aliases, nested
arrays, pointers to fixed arrays, slice controls and named print arguments compose
with the corrected route. Real scalar byte aliases retain byte formatting.

`io_value_array` now checks `$pointer` before testing the unaliased byte type.
In V 0.5.2, the latter test also matches pointers to byte aliases. The three-line
branch requires `any` and delegates to the existing slice formatter. Removing it
reconstructs the previous runtime exactly; all other bodies and C are unchanged.
The formatter reads pointer values from valid arrays, never their scalar targets.
Synthetic pointer bits prove formatting only, not valid pointee access.

Unchanged public pinned Source methods and an independent writer-state model
match **27,776 full records per mode**, including **16,491 WriteFailed records**.
Thirteen native scalar pointees plus opaque controls, six carrier forms,
flat/nested/whole-pointer aliases, 190 pointer bit patterns, recursive depth,
leaf width/precision/alignment/fill and memory/file/pipe/closed-descriptor states
retain four snapshots. These include input pointer bits, backing/buffered/unused
bytes, position and descriptor/file state through caller-buffer mutation and flush.

**72 isolated returning controls per mode** check alias/whole-pointer/nested /
pointed arrays, depth zero and padded leaves, including failures between opening
braces, type vectors, digits, separators and closing braces. No controls panic.
Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 27,776 | `40cf7300901517ec96b3515e881271f6b75a4ad8815dee9c9c9dcc6e48ef6136` |
| Isolated return states | 72 | `064039233f823f128ff586ce5a43211e6fdf3010ac4d6801d91163992c1ac1ec` |

Fourteen external compiler pairs cover all native aliases, the original mismatch,
whole-pointer/nested/pointed/slice carriers, print, preserved byte formats and
invalid/runtime formats. Five public regressions and a portable consumer verify
original caller storage, target/pointer-order changes, exact partial failures,
unchanged scalar byte formats and invalid byte formats rejected before writes.

Fresh before/after consumers select an isolated parent-commit library or the
current repository explicitly and verify imported source paths in compiler output.
They reproduce old numeric bytes and corrected pointer names in both modes. The
previous checkpoint's standalone consumer labeled `current` lived beside its
baseline library and resolved that neighbor; it is not current-code evidence for
this fix. The new consumer lives outside either library directory. The native
comparison fixtures also have no neighboring `zigimg` module.

All 139 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical fixed scalar
array values and scalar pointee-alias addresses retain record/control/state hashes
in both modes. Vaxis runtime tests are not rerun.

Source/library, executable, implementation, fixture/model/helper and input pins
are checked before/after. Expected outputs freeze before final runs. Independent
replay checks observations, failures, compiler outcomes, before/after library
identity and provenance; every retained archive member is read back before commit.
Completed proof caches and archive-backed duplicates were reclaimed with verified
archives retained when disk space became tight.

Optional fixed-array element declaration limits, deeper pointer indirection,
aggregate/function/array pointees, qualifiers/sentinels and broader representation
contracts remain boundaries. Source requires static formats; V accepts runtime
strings. Allocation/layout/ownership/lifetime contracts, overlapping input/output,
concurrency and huge successful output remain outside the claim. Runtime evidence
is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_alias_array_value_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-alias-array-value-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
