# Optional scalar slice address formatting

`print_address` and `print_value('*', ...)` now accept slices of the 13 supported
native optional scalar types, including scalar payload aliases. Names are
canonical, for example `?i32@1234` for `[]?int`. Whole-slice aliases, present
optional outer slices with `?*`, and named `Writer.print` arguments compose with
the same route. Absent outer slices keep aligned `null`.

The direct slice branch binds an optional payload from `$zero(T)` and reuses the
existing payload-name helper. It never unwraps an element, reads its layout or
visits caller storage. The original data address is retained for empty/nonempty
slices and arbitrary address bits. The type name plus `@` is one write, followed
by hexadecimal digits. Options and depth are ignored for present addresses.

The unchanged public pinned Source methods and an independent writer-state model
match **27,460 full records per mode**, including **16,241 WriteFailed records**.
Direct/value/optional-outer routes, all payload types, 190 addresses, lengths
zero/one/three, finite capacities, maximal ignored options and memory/file/pipe /
closed-descriptor states are covered. Four snapshots retain backing, buffered and
unused bytes, position, descriptor/file state, and the observed input header
through caller-buffer mutation and flush.

**90 isolated returning controls per mode** cover prefix/digit failures, all
three routes, maximal addresses and aligned nulls. A maximal-width null fails in
finite memory after preserving its fill prefix. No controls panic. Production V
is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 27,460 | `d3266d0ce178448f0c9351e6f7c36035767fc11727074745c13b9170c45c5b26` |
| Isolated return states | 90 | `e8c17834eb88fef0f258d0b216a740cd4a8868e47b1fbab8e9283bcb25a9b2a7` |

Seventeen external compiler pairs check all native routes, payload/whole-slice
aliases, owned addresses and mutations, `Writer.print`, null alignment, unchanged
`any` contents, runtime/static formats and unsupported carriers. A dynamic-slice
payload-alias declaration baseline succeeds, separately from the earlier measured
fixed-array alias C-generation limit. Four public regressions and a portable
consumer check no-read behavior, storage identity, unchanged caller bytes,
partial writes, mutation independent of names, and optional outer nulls.

All 132 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical optional-array
address and slice-of-fixed-array address comparisons retain their record/state
hashes in both modes. The latter's optional-scalar-slice compiler control now
accepts V. Vaxis runtime tests are not rerun.

Only the optional branch in `io_address_slice` and its `io_value_slice` dispatch
change the runtime; the prior implementation reconstructs exactly with those
changes removed. Other formatters and C remain byte-identical. Whole Source /
library, compiler executable, implementation, fixture/model/helper and input pins
are checked before/after. Expected bodies and outputs freeze before final runs.
Independent replay checks records, failures, compiler outcomes and provenance;
every retained archive member is read back before commit.

Optional record/pointer/array payloads, pointer-to-optional scalars, bare optional
addresses, nested optional wrappers, qualifiers/sentinels, and arbitrary named
types remain boundaries. Source supports broader names and requires static
formats; V accepts runtime strings and rejects unsupported payload names before
writes. V's inline optional-array constructor syntax remains limited; named
whole-slice aliases work. General allocation/layout/ownership/lifetime contracts,
overlapping input/output, concurrency and huge successful output remain outside
the claim. Synthetic addresses prove formatting only. Runtime evidence is
little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_optional_slice_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-optional-slice-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.


The subsequent [optional fixed-array payload comparison](../writer_optional_array_payload_address/README.md)
extends the helper to represented `[]?[N]T` payloads with native scalar leaves.
Named payload aliases and explicit generic slice returns retain the optional;
raw declarations and some value-format combinations have separately measured
V compiler limits. The scalar corpus and retained-state hashes above are unchanged.


The subsequent [optional-pointer element checkpoint](../writer_optional_pointer_address/README.md)
adds native/opaque optional pointer element names to slices and concrete fixed
arrays. This driver's former optional-pointer rejection control now checks the
positive canonical V address. Its returning corpus and state hashes are unchanged.
Fixed arrays of optional whole-pointer aliases retain a measured V C-generation
limit; aliases in dynamic slices work.
