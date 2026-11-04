# Native pointer elements in array address names

Writer address names now include native pointer array elements, for example
`[3]*u8@1234`, `[2][3]*i32@0` and `[1]*anyopaque@1`. All 13 native scalar pointees,
opaque pointers, nested arrays, array aliases and whole-pointer element aliases
are covered through direct/value pointer and slice routes. Optional outer slices
with `?*` retain aligned nulls; `Writer.print` composes with the same route.

The array-name helper recognizes opaque pointers and inspects a pointer's native
pointee type directly. Whole-pointer aliases normalize a zero type witness before
reflection. The helper never reads caller array elements or their targets. The
complete name plus `@` remains one write, followed by lowercase hexadecimal
digits. Original addresses, empty/nonempty slice headers and ignored present
options/depth are preserved. Zero witnesses are used for type binding only.

The unchanged public pinned Source methods and independent writer-state model
match **46,648 full records per mode**, including **25,541 WriteFailed records**.
Four routes, 14 pointer kinds, flat/nested/aliased payloads, 190 addresses,
capacities, maximal ignored options, memory/file/pipe/closed-descriptor states and
four snapshots preserve backing/buffered/unused bytes, position, descriptor/file
state and observed input headers through caller-buffer mutation and flush.

**120 isolated returning controls per mode** cover prefix/digit boundaries,
nested names, zero/maximal addresses, optional outer presence and null padding.
No controls panic. Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 46,648 | `af5874c78f78c35fbe9777c43bd2762a0d5cad1db4dd6c1d6cbcd7f22d069a27` |
| Isolated return states | 120 | `58237ce908ed88f6fd398cb875fa16f70f91aa4f25dc5cb9cce1eb5c913e8a53` |

Eleven external compiler pairs cover all native kinds/routes, owned storage and
mutation, print/outer optionals, unchanged default pointer-element contents,
unsupported pointee aliases/indirection/optional elements, flat pointer-slice
value addresses, and invalid/runtime formats. Owned consumers check their own
addresses. Four public regressions and a portable consumer also verify no-read
behavior, unchanged caller bytes/storage, target mutations, changed pointer order,
partial writes and optional nulls.

V's generic `&T` rebinding can lose pointee metadata; chained reflected type
properties can also fail to identify native types. The implementation uses the
measured direct reflection path. Whole-pointer aliases work; aliases of the
pointee type remain unsupported by this name helper. Fixture reference-array locals
are explicitly unsafe witnesses, never dereferenced.

All 135 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical value-array
address and direct-array address record/state hashes remain unchanged in both
modes. Their pointer-element compiler controls now accept V and check its own
canonical address; Source additionally checks its own qualifier spelling. The
returning corpus uses nonqualified native element pointer types. Vaxis runtime
tests are not rerun.

Only pointer/opaque dispatch and the private pointer-name helper change the
runtime. Removing them reconstructs the previous implementation exactly; all
other formatters, dispatcher/IO and C remain byte-identical. Whole Source/library,
compiler executable, implementation, fixture/model/helper and input pins are
checked before/after. Expected bodies and outputs freeze before final runs.
Independent replay checks observations, failures, compiler outcomes and provenance;
every retained archive member is read back before commit.

A full disk interrupted a Windows dependency compile. Completed validation inputs,
commands and output hashes were verified before resuming that command. Regenerable
caches and duplicate outputs from completed checkpoints were reclaimed only with
verified archives retained; cleanup and resumption receipts accompany the proof.

Optional pointer elements, aliases of pointee types, deeper pointer indirection,
record/enum/function/array pointees, flat pointer-slice value addresses, broader
optional compositions and qualifiers/sentinels remain outside this comparison.
General allocation/layout/ownership/lifetime contracts, overlapping input/output,
concurrency and huge successful output remain outside the claim. Zero witnesses
can use stack space proportional to the array type. Synthetic addresses prove
formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_pointer_element_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-pointer-element-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.


The later [flat pointer-slice checkpoint](../writer_pointer_slice_address/README.md)
extends direct/value address routes to slices of native scalar pointers and
whole-pointer aliases, and value-format `*` to opaque pointer slices. The former
`flat-pointer-slice` rejection control now returns the canonical `*u8@1234`.
The array corpus and retained-state hashes above remain unchanged.


The subsequent [optional-pointer element checkpoint](../writer_optional_pointer_address/README.md)
adds native/opaque optional pointer element names to slices and concrete fixed
arrays. This driver's former optional-pointer rejection control now checks the
positive canonical V address. Its returning corpus and state hashes are unchanged.
Fixed arrays of optional whole-pointer aliases retain a measured V C-generation
limit; aliases in dynamic slices work.


The subsequent [scalar pointee-alias checkpoint](../writer_pointer_pointee_address/README.md)
adds aliases of native scalar pointee types to array/slice address names. This
driver's former pointee-alias rejection control now checks the canonical V address;
its returning corpus and state hashes are unchanged. Optional fixed-array element
declaration limits and broader aliased-pointer content mismatches remain separate.
