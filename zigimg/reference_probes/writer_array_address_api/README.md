# Direct fixed-array pointer and slice addresses

`WriteStream.print_address` now accepts nonoptional pointers to fixed arrays and
slices whose elements are fixed arrays. The arrays may contain any of the 13
supported native scalar types; pointee/element aliases and nested arrays use the
same canonical type names as `print_value('*', ...)`. V `int` is spelled `i32`.
For example, both a pointer to `[3]u8` and a slice of `[3]u8` values print
`[3]u8@address`.

The complete type plus `@` is one write, followed by lowercase hexadecimal digits
in a separate write. The address comes from the pointer or original slice data;
slice length does not change it, including zero length. The formatter never reads
the pointee or slice elements. Named zero witnesses bind the array element type
without V reusing another generic specialization's metadata. The public dispatch
checks pointer indirection before accepting a fixed array, preserving rejection
of by-value arrays. Other scalar/opaque/optional address routes are unchanged.

The native fixture calls the unchanged public Source method through the locked
image writer. Eight carrier forms cover native/pointee-alias/nested/single arrays
as pointers and slices. The main corpus exercises all native element types, 190
address samples, empty/nonempty slice headers, capacities and memory/file/pipe /
closed-descriptor states. Four snapshots retain backing/pending/unused bytes,
position, descriptor/file state and observed address/length through caller-buffer
mutation and flush. An independent model predicts both writes and retained state.

Each mode matches **20,115 complete records**, including **12,276 WriteFailed
records**, plus **90 isolated returning controls**. The controls check prefix and
digit failure boundaries for both direct carriers. These address cases do not
panic. Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 20,115 | `ba880bbdde91a8e0dbef54c48a9e2fd9049215fc4312475a89e996b63126b59c` |
| Isolated return states | 90 | `51e454371fb407d016ad34a3daaf1c5d5de41408863bbd424cbc6c744fee0ac1` |

Seventeen external compiler pairs cover all native pointer/slice element types,
aliases, nesting, owned addresses, empty zero-address slices, scalar address
regressions and remaining carrier boundaries. Each owned consumer compares with
its own input address. Source slices are explicitly typed: slicing a many-pointer
with compile-time-known bounds can otherwise produce a pointer to an array.
Four public regressions and a portable consumer additionally verify no-read
behavior, original storage identity, unchanged slice headers after successful
calls, partial failures and unsupported elements before writes. The earlier value
address suite's `direct-api` compiler control now succeeds in V; its record/state
hashes remain unchanged.

All 129 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical value-address
and direct scalar-address/units comparisons retain their record/state hashes in
both modes. Vaxis runtime tests are not rerun.

The runtime changes are confined to array-name branches in the pointer/slice
helpers and the fixed-array pointer dispatch guard in `io.v`. Other function
bodies, dispatcher branches and C remain byte-identical. Whole Source/library,
executable, implementation, fixture/model/helper and input pins are checked
before/after; expected results and bodies freeze before both-mode proofs.
Independent replay checks observations, failures, compiler outcomes and provenance;
every retained archive member is read back before committing.

Optional whole-array addresses, record/optional/pointer elements, pointers to
array pointers, by-value arrays, zero-length array types and whole pointer alias
construction remain boundaries. Value-format `*` for native fixed-array slices
and optional `?*` are now covered by the
[slice value-address comparison](../writer_slice_array_address/README.md).
Source supports broader named and qualified types. General allocation/layout/ownership/lifetime
contracts, overlapping input/output, concurrent mutation and huge successful
output are outside the claim. The witnesses can use stack space proportional to
the fixed-array type. Synthetic addresses prove formatting only. Runtime evidence
is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_array_address_api_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-array-address-api-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.


Native optional scalar array elements are now covered by the
[optional-element address comparison](../writer_optional_array_address/README.md).
The retained optional-element compiler control succeeds in both languages;
its earlier rejection is superseded. Record/pointer payloads and the documented
construction/qualification limits remain boundaries.
