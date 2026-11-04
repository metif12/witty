# Native fixed-array pointer addresses

`WriteStream.print_value('*', options, pointer, depth)` now formats nonoptional
pointers to fixed arrays of the 13 supported native scalar types. Pointee/element
aliases and nested fixed arrays use canonical Source spellings, including V
`int` as `i32`. Examples are `[3]u8@1234` and `[2][3]i32@0`. The complete type and
`@` form one write; lowercase hexadecimal digits form the next. Options and depth
are ignored, including maximal width/precision at zero depth.

The type name comes from concrete zero witnesses rather than the pointee. This
avoids V reusing another generic specialization's element metadata. Named locals
also avoid V emitting an invalid bare array initializer as a function argument.
No input memory is read. Zero and synthetic addresses establish formatting only;
they make no pointer validity or dereference claim. The witness can occupy stack
space proportional to the array type in ordinary builds.

The native fixture calls the unchanged public Source body through the locked
image writer. All 13 native element types, array aliases, nested arrays and
single-element arrays are tested together. Four snapshots retain backing,
pending/unused bytes, position, descriptor/file state and original address bits
through caller-buffer mutation and flush. Memory and positional/streaming files,
replaced pipes and closed descriptors are covered. An independent model predicts
the prefix and digit writes and all retained state.

Each mode matches **11,510 complete records**, including **4,364 WriteFailed
records**, and **45 isolated returning controls**. The controls verify failure
state at prefix/digit boundaries and maximal ignored options; these explicit
address cases do not panic. All 190 address samples cover individual bits,
hexadecimal boundaries, zero and maximal addresses. Production V is paired with
Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 11,510 | `61591c5e3af491a87d76c10dda279d757ab7e0a38c540ceb267d6c0a5e86aeb0` |
| Isolated return states | 45 | `cf069937103775dc787dfbeabb74bf6a252a4e7d2c5bff5fab1cce50fb6b1a9a` |

Sixteen external compiler pairs cover native types, nesting, aliases, actual
owned addresses, zero pointers, `Writer.print`, byte encoding beside address
formatting and the remaining language/carrier boundaries. Each owned-address
consumer compares output with its own pointer. Four public regressions and a
portable consumer also check no-read behavior, canonical prefixes, partial writes
and unsupported elements before writer effects. The earlier array-pointer
comparison's address control now succeeds in V; its returning/state hashes remain
unchanged.

Source supports qualified names for records and other elements. This V branch
rejects arrays with record, optional or pointer elements before writes. Present
optional whole-array pointers still hit V's construction/unwrap limits; inline
construction is retained as an exact C-generation rejection, separately from
ordinary checker rejection. Optional array-address formatting, the direct
`print_address` API for arrays, zero-length arrays, broader qualifiers/sentinels,
whole pointer alias construction and arbitrary named element types remain
boundaries. Source requires static formats; V accepts runtime strings and reports
unsupported formats at runtime. Layout/ownership/lifetime equivalence, overlapping
input/output, concurrency and huge successful output are outside the claim.

All 128 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical borrowed-array
and scalar-pointer comparisons retain their record/state hashes in both modes.
Vaxis runtime tests are not rerun.

The runtime diff is confined to the fixed-array pointer `*` branch and its name
helper. Other dispatch, leaf formatters and IO/C remain byte-identical. Whole
Source/library, executable, implementation, fixture/model/helper and input pins
are checked before/after; expected results and bodies freeze before both-mode
proofs. Independent replay checks observations, failures, compiler outcomes and
provenance; every retained archive member is read back before committing.
Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_array_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-array-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
