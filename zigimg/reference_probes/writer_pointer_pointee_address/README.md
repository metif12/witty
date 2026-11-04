# Scalar pointee aliases in Writer addresses

Pointer element address names now accept aliases of all 13 native scalar pointee
types. For example, `type Number = int` gives `*i32@1234` for `[]&Number` and
`[3]*i32@1234` for a pointer to `[3]&Number`. Whole-pointer aliases, nested arrays,
array/slice aliases, optional pointer slice elements, optional outer slices and
named `Writer.print` arguments compose with these names. Opaque pointers retain
their existing spelling.

The pointer-name helper binds `$zero(P.pointee_type)` to a separate scalar
generic. That generic checks indirection/options and the native scalar whitelist,
then reuses `io_address_type_name`. This preserves unaliased pointee metadata
without reading an element or target. Generic `&T` rebinding, chained reflected
properties and recursive pointee reflection do not reliably preserve that metadata
in V 0.5.2. The helper keeps its single-indirection limit.

Unchanged public pinned Source methods and an independent writer-state model
match **46,648 full records per mode**, including **25,541 WriteFailed records**.
Four routes, all native scalar aliases plus an opaque control, flat/nested/whole
pointer aliases, 190 addresses, lengths zero/one/three, capacities, maximal options
and memory/file/pipe/closed-descriptor states retain four snapshots. Observations
include original input headers, backing/buffered/unused bytes, position, descriptor
and file state through caller-buffer mutation and flush. Present values ignore
options/depth and write the canonical name plus `@` separately from hexadecimal
digits.

**120 isolated returning controls per mode** check the same alias carriers through
prefix/digit failures, nested names, zero/maximal addresses and optional outer
nulls. No controls panic. Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 46,648 | `af5874c78f78c35fbe9777c43bd2762a0d5cad1db4dd6c1d6cbcd7f22d069a27` |
| Isolated return states | 120 | `58237ce908ed88f6fd398cb875fa16f70f91aa4f25dc5cb9cce1eb5c913e8a53` |

Fourteen external compiler pairs cover native alias matrices, owned array/slice
storage and mutation, print/optionals, native default contents, scalar/optional
pointer slices, unsupported carriers and runtime/static formats. Owned consumers
check their own addresses. Five public regressions and a portable consumer check
caller bytes/storage, no-read behavior, target/pointer-order changes and partial
writes. Historical pointer-element, pointer-slice and optional-pointer drivers
promote their former pointee-alias rejection controls to positive results.

V still emits invalid declarations for optional pointer elements whose pointees
are aliases inside fixed arrays (`[2]?&Number`). An isolated compiler pair
reproduces the declaration-order failure with a length-only consumer that does not
call the formatter. Optional pointer slices with aliased pointees pass. The prior
limit for fixed arrays of optional whole-pointer aliases also remains.

Broader content formatting of aliased pointer arrays retains a separate existing
mismatch: `[&Byte(0x1234), &Byte(0x5678)]!`, `Byte = u8`, prints `{ 52, 18 }` under
`any`, rather than Source's pointer names. Retained consumers reproduce identical
output with the previous and current implementations in both modes. The address
routes do not unwrap or format those contents. This checkpoint does not claim
content-format parity for aliased pointer elements.

All 138 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical native
pointer-slice and optional-pointer address suites retain their record/control /
state hashes in both modes. Vaxis runtime tests are not rerun.

Only the private pointer-name helper and its new scalar helper change the runtime.
Restoring that section reconstructs the previous implementation exactly; other
bodies and C remain byte-identical. Source/library, compiler executable,
implementation, fixture/model/helper and input pins are checked before/after.
Expected bodies and outputs freeze before final runs. Independent replay checks
observations, failure states, compiler outcomes and provenance; every retained
archive member is read back before commit.

Deeper pointer indirection, aggregate/function/array pointees, optional whole-array
pointers, bare optional addresses, qualifiers/sentinels and broader representation
contracts remain boundaries. Source requires static formats; V accepts runtime
strings and rejects unsupported represented names before writes. General
allocation/layout/ownership/lifetime contracts, overlapping input/output,
concurrency and huge successful output remain outside the claim. Zero witnesses
can use stack space proportional to array types. Synthetic addresses prove
formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_pointer_pointee_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-pointer-pointee-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
