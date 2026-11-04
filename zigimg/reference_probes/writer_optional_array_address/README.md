# Optional scalar elements in array address names

Writer address formatting now names native optional array elements, for example
`[3]?i32@1234` or `[2][3]?bool@0`. This applies to fixed-array pointers and slices
through both `print_address` and `print_value('*', ...)`. The 13 supported native
scalar payload types use canonical names; V `int` is spelled `i32`. Array aliases,
nesting, `Writer.print` and optional outer slices use the same helper.

The helper binds the optional payload generic from a zero witness. It never
unwraps the optional, reads its private layout or examines caller elements. Some
and absent elements therefore have the same address type name. The complete
name plus `@` is one write, followed by lowercase hexadecimal digits. Value-format
options/depth are ignored. The original pointer or slice data address is retained,
including empty slices and synthetic addresses.

The native fixture calls unchanged public Source methods through the locked
image writer. Four routes (direct/value, pointer/slice), three array shapes,
all native payload types, 190 addresses, empty/nonempty headers, options and
memory/file/pipe/closed-descriptor states are covered. Four snapshots retain
backing/pending/unused bytes, position, descriptor/file state and observed input
address/length through caller-buffer mutation and flush. An independent model
predicts each write and retained state.

Each mode matches **43,218 complete records**, including **23,550 WriteFailed
records**, plus **90 isolated returning controls**. The controls verify prefix
and digit failure boundaries across all routes, nested names, zero addresses and
maximal ignored options. These cases do not panic. Production V is paired with
Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 43,218 | `0a918dca530e237ef46e51b231730b7e83fe5cc1b6cee0982f3865731f8f0784` |
| Isolated return states | 90 | `97544571f7e9f4fa2abe05220e4fc37f1604c461e3892626b73bf9187d4d1bf3` |

Twenty external compiler pairs cover all native routes, nesting, owned addresses,
print composition, optional outer slices, changed element presence, unchanged
`any` contents, runtime/static formats and unsupported carriers. Each owned
consumer checks its own address. Four public regressions and a portable consumer
also verify unchanged caller bytes, storage identity, element mutation independent
of the name, prefix/digit failures and null alignment for optional outer slices.

Aliased optional payload declarations hit a measured V C-generation failure
before formatting; the baseline case contains no formatter call and requires the
exact undeclared-alias diagnostic. A raw optional fixed-array declaration works
and is retained as a separate language control. Optional fixed-array payload
names remain unsupported. Inline optional-pointer array constructors double-box
in V; an unsafe zero-array witness reaches the intended unsupported-payload
rejection without reading elements. No private optional layout is fabricated.

All 131 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical array-pointer,
direct array-address and slice value-address comparisons retain their record/state
hashes in both modes. Their optional-element compiler controls now accept V.
Vaxis runtime tests are not rerun.

The runtime diff is confined to optional dispatch and its payload-name helper in
`io_value_array_address_name`. Other formatter bodies, dispatch/IO and C remain
byte-identical. Whole Source/library, executable, implementation, fixture/model /
helper and input pins are checked before/after; expected outputs and bodies freeze
before both-mode runs. Independent replay verifies records, failures, compiler
outcomes and provenance; every retained archive member is read back before commit.

Optional aliased/array/record/pointer payloads, optional whole-array pointers,
whole pointer aliases, nested optional wrappers, qualifiers/sentinels and arbitrary
named types remain boundaries. Source supports broader names. General allocation /
layout/ownership/lifetime contracts, overlapping input/output, concurrency and
huge successful output remain outside the claim. Zero witnesses can use stack
space proportional to the array type. Synthetic addresses prove formatting only.
Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_optional_array_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-optional-array-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
