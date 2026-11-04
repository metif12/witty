# Native pointer slice addresses

`print_address` and value-format `*` now accept flat slices of native scalar
pointers and whole-pointer element aliases. Opaque pointer slices also accept
value-format `*`, reusing their existing direct address spelling. Examples are
`*u8@1234`, `*i32@0` and `*anyopaque@1`. Whole-slice aliases, optional outer `?*`
and named `Writer.print` arguments compose with these routes. Absent outer slices
retain aligned `null`.

The direct pointer-element branch binds a zero witness to the existing name
helper; the value dispatcher routes pointer/opaque slices to that API. The
original slice data address is retained for empty/nonempty slices and arbitrary
address bits. No element or target is read. Type plus `@` is one write, followed
by lowercase hexadecimal digits; options/depth are ignored for present values.
The existing scalar, array, optional and default-content branches keep their bodies.

Unchanged public pinned Source methods and an independent writer-state model
match **29,708 full records per mode**, including **17,608 WriteFailed records**.
All 13 native scalar pointees plus opaque pointers, direct/value/optional-outer
routes, whole-pointer aliases, 190 addresses, lengths zero/one/three, capacities,
maximal options, memory/file/pipe/closed-descriptor states and four snapshots
retain backing/buffered/unused bytes, position, descriptor/file state and observed
input headers through caller-buffer mutation and flush.

**90 isolated returning controls per mode** check prefix/digit failures, all
three routes, maximal addresses and null padding. Maximal null width fails in
finite memory while retaining the fill prefix. No controls panic. Production V
is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 29,708 | `d312157816e1c18f008f2ccb999d95ff67150ddec3fcdb502628e9c2e21203f2` |
| Isolated return states | 90 | `d17bf73fb9a7852593c7feb64d630fc4a62ed4379f44f0baddd7d2a1e1ebe476` |

Eleven external compiler pairs cover native/opaque routes, pointer/whole-slice
aliases, owned storage and mutations, print/optionals, unchanged default contents,
pointee aliases/deeper indirection/optional elements, and invalid/runtime formats.
Owned consumers check their own addresses. Four public regressions and a portable
consumer verify no-read behavior, unchanged caller bytes/storage, target and
pointer-order changes, partial writes, aliases, print and optional nulls.

All 136 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical pointer-element
array addresses and scalar-pointer values retain their record/control/state hashes
in both modes. The former flat-pointer-slice rejection control now accepts V.
Vaxis runtime tests are not rerun.

Only the pointer-element branch in `io_address_slice` and pointer/opaque dispatch
in `io_value_slice` change the runtime. Removing them reconstructs the previous
implementation exactly; all other bodies and C remain byte-identical. Source /
library, compiler executable, implementation, fixture/model/helper and input pins
are checked before/after. Expected bodies and outputs freeze before final runs.
Independent replay checks observations, failure states, compiler outcomes and
provenance; every retained archive member is read back before commit.

Optional pointer elements, aliases of pointee types, deeper pointer indirection,
aggregate/function/array pointees, bare optional addresses, qualifiers/sentinels
and broader representation contracts remain boundaries. Source requires static
formats; V accepts runtime strings and rejects unsupported represented names
before writes. Named aliases avoid inline optional constructor limits. General
allocation/layout/ownership/lifetime contracts, overlapping input/output,
concurrency and huge successful output remain outside the claim. Synthetic
addresses prove formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_pointer_slice_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-pointer-slice-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
