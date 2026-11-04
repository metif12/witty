# Nested optional array values

V 0.5.2 generated an incorrect leaf-option argument clone when formatting a
slice of optional fixed arrays containing optional scalars. Even an address-only
`print_value('*', ...)` call failed C compilation because its unused `any` path
was generated. Binding the optional slice element to a local before dispatch
preserves its concrete type and fixes that consumer. Nonoptional elements retain
the previous forwarding path.

The mixed address fixture now compiles all 13 native scalar types across flat,
nested and optional-element array payloads, through direct/value/optional-outer
routes. Addresses retain their type names, original data bits, separate prefix /
digit writes, ignored options/depth and no-read behavior.

Recursive `any` contents are also compared for boolean, signed, unsigned and byte
optionals, including nested fixed arrays. Present/absent outer and inner values,
depth zero through four and maximal depth, width/precision/alignment/binary fill,
`Writer.print`, capacities zero through 96, file/pipe/closed-descriptor failures and
caller-buffer mutation/flush preserve Source output and write boundaries. Optional
bytes remain numeric elements. A concrete V observer and recursive Source
observer serialize logical presence and scalar values before/after formatting;
no private optional layout is interpreted.

The unchanged public pinned Source methods and independent writer-state model
match **36,729 full records per mode**, including **18,148 WriteFailed records**.
Four snapshots retain backing/buffered/unused bytes, position, descriptor/file
state, address headers or observed logical inputs. The address cases include 190
addresses and empty/nonempty slices; content cases use owned, correctly typed
storage.

**176 isolated returning controls per mode** check address prefix/digits,
recursive boolean/signed contents, leaf padding, optional nulls and print literals.
Maximal null width fails in finite memory while preserving its fill prefix. No
new controls panic. Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 36,729 | `b99642f780c61f7cdecb55244b6ffb027432a7ebf204b23b0014d5d679446a40` |
| Isolated return states | 176 | `52ea0687fc400c121af8c6a5b4f52fd57d273295d20301ebcc82b2579b9d5079` |

Twenty-three external compiler pairs cover mixed native routes, payload/whole-
slice aliases, owned storage, public reversal, recursive contents, optional outer
values, print, invalid/runtime formats and retained compiler controls. The earlier
`optional-elements-value` C-generation rejection is now a positive check; its
native/value/outer compiler consumers also cover the full payload matrix. Four
public regressions and a portable consumer verify depth, leaf options, numeric
bytes, nested arrays, no-read addresses, unchanged caller bytes and storage,
partial writes, optionals and print composition.

All 134 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical fixed-array
values, optional values and optional-array payload addresses retain their record /
control/state hashes in both modes, including the older panic/state pairs. Vaxis
runtime tests are not rerun.

The runtime change is confined to the optional element branch of `io_value_slice`.
Its nonoptional path retains the original call. Replacing the new branch with
that call reconstructs the old implementation exactly; other formatters, IO and
C remain byte-identical. Whole Source/library, executable, implementation,
fixture/model/helper and input pins are checked before/after. Expected bodies
and outputs freeze before final runs. Independent replay checks observations,
failures, compiler outcomes and provenance; every retained archive member is read
back before commit.

Raw `[3]?[2]i16{}` declarations still lose the optional marker in V reflection.
Optional fixed-array element assignment still produces invalid C without a
formatter call. Their separate compiler controls remain active. Named array
locals avoid inline-constructor limits. Existing unsupported carriers, format
validation differences, qualifiers/sentinels and representation boundaries remain.
General allocation/layout/ownership/lifetime contracts, overlapping input/output,
concurrency and huge successful output remain outside the claim. Zero address
witnesses can use stack space proportional to the array type. Synthetic addresses
prove formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_nested_optional_array_value_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-nested-optional-array-value-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.


The subsequent [optional-pointer element checkpoint](../writer_optional_pointer_address/README.md)
adds native/opaque optional pointer element names to slices and concrete fixed
arrays. This driver's former optional-pointer rejection control now checks the
positive canonical V address. Its returning corpus and state hashes are unchanged.
Fixed arrays of optional whole-pointer aliases retain a measured V C-generation
limit; aliases in dynamic slices work.
