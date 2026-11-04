# Dereferenced aggregate Writer values

Default and `any` `WriteStream.print_value` formats now dereference pointers to
ordinary records, enums and V sum types. The pointee keeps the same options and
depth; the pointer itself does not consume a depth level. Optional pointers and
record/enum pointer aliases follow the same route after unwrapping. Absent
optionals keep aligned `null`. Valid custom `f` methods on nonoptional concrete record
pointers run before the depth cutoff and ignore options as before.

V 0.5.2 reboxes a dereferenced generic sum as its first variant when forwarding
it to another generic formatter. The private pointer helper reflects the active
sum directly and forwards the selected payload instead. This preserves tags,
nested sums and payload recursion without copying private sum storage. The
optional address is extracted before pointee reflection because V cannot parse
that unwrap expression inside the reflected branch. Scalar pointer prefix/digit
writes and explicit address behavior retain their previous contracts.

The native fixture calls the unchanged public Source body through the locked
image writer. Six shapes cover records with signed/boolean fields, enums, tagged
unions, nested unions, empty records and bounded traversal of cyclic records.
Record/enum/empty/node aliases and optional pointer aliases are included; the
sum/nested-sum matrix uses direct and optional pointers. Tags map to V's reflected
type spelling using Source union field names. This does not establish equality
of native union representations, qualified names or copy/lifetime behavior.

Four snapshots retain backing/pending/unused views, positions, descriptor/file
state and captured logical pointee values through caller-buffer mutation and
flush. Memory, positional/streaming files, replaced pipes and closed descriptors
are included. Pointees are valid objects throughout each call; null/invalid
nonoptional pointers are outside the claim. Cycles are bounded by depth or an
earlier memory-writer failure; unbounded successful traversal is not attempted.

The independent model composes record/union field writes, enum vectors, scalar
padding, optional nulls and individual writer operations. Each mode compares
**9,414 records**, including **4,171 records containing WriteFailed**.
**15 external compiler pairs** cover records, aliases, enums, active sum tags,
absence, custom methods, `Writer.print`, invalid/runtime formats and the remaining
explicit aggregate-address boundary.

**42 paired traps and 66 returning controls per mode** preserve option checks,
earlier write failures and exact retained state. Enums forbid options even at
zero depth; outer record/union depth cutoffs suppress unvisited enum checks.
Maximal width overflows only after a visited signed field and its prefix/digits.
Diagnostics remain exactly `reached unreachable code` or `integer overflow`,
including production.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 9,414 | `7ea238f94189833e478e5e9ea8586de17736f8564861659ff6011e06bfb0f24e` |
| Isolated failure/control states | 108 | `7f8d848793b8eb99cbfd7945a39c4866b83170ad2d071a8b4d05f5de047f8856` |

Five public regressions and a portable consumer cover aliases, optional pointers,
active/nested sum tags, cycles, partial writes and custom methods. External
formatter methods must be public. Source formats are static; V validates visited
formats at runtime. Invalid aggregate-pointer formats return before writer effects.

The optional `?f` compiler control now accepts both languages; its original V
rejection is superseded by the [optional pointer custom comparison](../writer_pointer_custom/README.md). Explicit aggregate `*`/`?*`
addresses remain unsupported in this V dispatcher,
returning a runtime error without writes; Source accepts them with qualified
pointee or optional-pointer type prefixes. Direct `print_address` still rejects
aggregate pointees at compile time. Pointer-to-array/string/interface/function
and nested-pointer support, overlapping alias variants, broader qualifiers,
private layout/ABI/ownership/copy/lifetime contracts and arbitrary user-method
behavior retain documented limits. Runtime evidence is pinned little-endian
64-bit macOS; cross builds establish compilation only.

All 125 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical scalar
address/default-pointer and direct-union comparisons retain their hashes in both
modes. Vaxis runtime tests are not rerun.

Source/library, compiler executable, implementation, fixtures, model/helper and
input pins are checked before/after. Bodies and expected results freeze before
final ordinary/production comparisons. Replay verifies observations, failures,
compiler outcomes and provenance; every retained archive member is read back.

```sh
python3 zigimg/verify_writer_aggregate_pointer_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-aggregate-pointer-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
