# Slice-of-fixed-array value addresses

`WriteStream.print_value('*', options, slices, depth)` now accepts slices whose
elements are fixed arrays of the 13 supported native scalar types. The route
uses the verified direct address API: it writes the canonical element type plus
`@`, then lowercase hexadecimal address digits. It preserves the original slice
storage, ignores options/depth and never reads the elements, including empty
slices and synthetic addresses. Nested arrays, element aliases and whole slice
aliases use the same route. V `int` is spelled `i32`.

Present optional slices unwrap with `?*` and keep those address rules. Absent
values retain aligned `null`, with ordinary null padding and failure order.
`Writer.print` composes both carriers, including named arguments and sizes.
Bare `*` on an optional slice remains unsupported; use `?*` to unwrap it.

The native fixture calls the unchanged public Source body through the locked
image writer. Nine carrier forms cover plain/aliased/nested/single arrays, whole
slice aliases, present/absent optional slices and optional whole aliases. All
native element types, 190 address samples, empty/nonempty headers, options,
depth and memory/file/pipe/closed-descriptor states are exercised. Four snapshots
retain backing/pending/unused bytes, position, descriptor/file state and observed
input address/length through caller-buffer mutation and flush. An independent
model predicts address writes, null alignment and all retained state.

Each mode matches **37,551 complete records**, including **16,067 WriteFailed
records**, plus **135 isolated returning controls**. Controls verify type/digit
boundaries, maximal ignored present options, absent alignment with binary fill
and finite memory failures under maximal null widths. These cases do not panic.
Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 37,551 | `88b5d86c2fb938f3e4c80dcfa956c006cf5e565c7251e4ea1a5777fbbea0a9db` |
| Isolated return states | 135 | `c994569308e1a37cae4c084cdfce0dfec82e74da26ac0acbdde9d3913b8627dc` |

Twenty external compiler pairs cover all native elements, aliases, nesting,
owned addresses, zero-data/empty slices, print composition, optional construction
and return values, direct API agreement and remaining language boundaries. Owned
consumers compare with their own input address. Five public regressions and a
portable consumer additionally verify storage/header identity, no-read behavior,
partial writes, null alignment and unsupported elements before effects.

V's inline `?[][N]T(...)` constructor has a parser limit. Named fixed-array element
types work; a function returning the raw optional slice type also works and is
checked separately. Concrete fixtures avoid generic constructor temporary-type
reuse. A named local array avoids V treating an inline fixed-array argument as a
Result value. Source slices are explicitly typed to prevent compile-time bounds
from changing them into array pointers. No private optional layout is used.

All 130 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical direct
array-address, recursive scalar-slice and optional-value comparisons retain their
record/state hashes in both modes. Vaxis runtime tests are not rerun.

The runtime diff is exactly the two-line fixed-array element dispatch in
`io_value_slice`. The direct API, other dispatcher branches, leaf formatters and
IO/C remain byte-identical. Whole Source/library, executable, implementation,
fixture/model/helper and input pins are checked before/after; expected results
and bodies freeze before both-mode proofs. Independent replay checks observations,
failures, compiler outcomes and provenance; every retained archive member is
read back before committing.

Record/optional/pointer array elements, slices of optional scalars, by-value fixed
arrays, bare optional addresses, whole optional-array pointers and broader
named/qualified element types remain boundaries. Source requires static formats;
V accepts runtime strings and reports unsupported formats at runtime. General
allocation/layout/ownership/lifetime contracts, overlapping input/output,
concurrency and huge successful output are outside the claim. The name witnesses
can use stack space proportional to the fixed-array type. Synthetic addresses
prove formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_slice_array_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-slice-array-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
