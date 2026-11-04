# Optional pointer element addresses

`print_address` and value-format `*` now name optional native scalar and opaque
pointer elements in slices and fixed arrays. Examples are `?*u8@1234`,
`?*anyopaque@0` and `[2]?*i32@1234`. Whole-pointer aliases work in slices;
whole-slice/array aliases, nested array names, optional outer slices and named
`Writer.print` arguments compose with the existing routes. Absent outer slices
retain aligned `null`.

The optional-name helper binds a zero payload witness to the existing pointer-name
helper, or names the opaque type directly. It never unwraps an element, reads a
pointer target or interprets an optional layout. Addresses retain the original
storage bits, including empty/nonempty synthetic slices. The canonical name plus
`@` is one write, followed by lowercase hexadecimal digits. Present values ignore
format options and depth. Other runtime bodies and C remain byte-identical;
removing the two new branches and restoring the guard reconstructs the previous
implementation exactly.

Unchanged public pinned Source methods and an independent writer-state model
match **29,708 full records per mode**, including **17,788 WriteFailed records**.
The 13 native scalar pointees plus opaque pointers, direct/value/optional-outer
routes, aliases, 190 addresses, lengths zero/one/three, capacities, maximal options,
and memory/file/pipe/closed-descriptor states retain four snapshots. Observations
include backing/buffered/unused bytes, position, descriptor/file state and input
headers through caller-buffer mutation and flush.

**120 isolated returning controls per mode** check slice/array prefix and digit
failures, maximal addresses, null padding and maximal null width in finite memory.
No controls panic. Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 29,708 | `486a7844ffec45d037c2fdbdc083b49504ae5429f5052ab3f50b08834fb8c5d6` |
| Isolated return states | 120 | `3c0c6712eb19f69e3b12adb8007c72825eccdd55391b047b7613a61d7a72d8dd` |

Thirteen external compiler pairs cover all native/opaque slice and fixed-array
names, owned storage and mutation, aliases, nested arrays, print/optionals,
unchanged default contents, unsupported names and runtime/static formats. Owned
consumers compare their own addresses; they do not compare raw addresses across
processes. Four public regressions and a portable consumer check no-read behavior,
unchanged caller bytes/storage, pointer/target mutation, partial writes and nulls.

V 0.5.2 generates invalid C declarations for optional **whole-pointer aliases inside
fixed arrays** (`[2]?Element`, `type Element = &u8`): the alias is used before its
declaration. The isolated array-element-alias pair retains that C-generation
failure in both modes. Concrete fixed-array elements (`[2]?&u8`) and optional
pointer aliases in dynamic slices pass. Named array aliases avoid V's inline
array-pointer cast parser limit. Local variables avoid broken assertion rendering
for inline optional pointer unwrapping; these are fixture compiler constraints.

All 137 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical pointer-slice
and optional-scalar-array address suites retain their record/control/state hashes
in both modes. Their former optional-pointer rejection controls now check positive
V results, as do the four other affected historical drivers. Vaxis runtime tests
are not rerun.

Source/library, compiler executable, implementation, fixture/model/helper and
input pins are checked before/after. Expected bodies and outputs freeze before
final runs. Independent replay checks observations, failure states, compiler
outcomes and provenance; every retained archive member is read back before commit.

Aliases of pointee types, deeper indirection, aggregate/function/array pointees,
optional whole-array pointers, bare optional addresses, qualifiers/sentinels and
broader representation contracts remain boundaries. Source requires static
formats; V accepts runtime strings and rejects unsupported represented names
before writes. General allocation/layout/ownership/lifetime contracts, overlapping
input/output, concurrency and huge successful output remain outside the claim.
Zero witnesses can use stack space proportional to the array type. Synthetic
addresses prove formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_optional_pointer_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-optional-pointer-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
