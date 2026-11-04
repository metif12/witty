# Optional fixed-array payload address names

Writer address formatting now names fixed arrays wrapped in a slice element's
optional, for example `?[2]i32@1234` for `[]?[2]int`. Native scalar payloads,
nested fixed arrays, payload/whole-slice aliases, `print_value('*', ...)`, present
optional outer slices with `?*`, and named `Writer.print` arguments are covered.
Direct addresses also name arrays containing optional native scalars, such as
`?[3]?u8`. Value-format calls for that last shape hit a measured V C-generation
limit and are checked separately.

The only runtime change is four lines in `io_value_optional_address_name`: a zero
concrete array witness recurses into the existing array-name helper and prepends
`?`. No caller element is read or unwrapped and no private optional layout is
interpreted. Addresses retain original slice storage, including empty slices,
zero and arbitrary pointer bits. The complete type plus `@` is one write, followed
by lowercase hexadecimal digits. Present options/depth remain ignored; absent
outer slices retain aligned `null`.

The unchanged public pinned Source methods and independent writer-state model
match **24,496 full records per mode**, including **12,920 WriteFailed records**.
All 13 native scalar leaves, flat/nested payloads, direct addresses of payloads
with optional elements, 190 addresses, empty/nonempty slices, capacities, maximal
ignored options and memory/file/pipe/closed-descriptor states are covered. Four
snapshots retain backing/buffered/unused bytes, position, descriptor/file state
and observed input headers through caller-buffer mutation and flush.

**105 isolated returning controls per mode** verify prefix/digit boundaries,
all supported routes, nested names, maximal addresses and null alignment,
including maximal null width in finite memory. No controls panic. Production V
is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 24,496 | `174bfa9d8fd0cdbf2db38f9277063e225b5e9a8f28067cd9468bdc781010d248` |
| Isolated return states | 105 | `6fd6fc3e25300111897f1a294492de24c76cf3ead43efa09efc22918a09d82a5` |

Nineteen external compiler pairs cover native routes, aliases, owned storage,
public reversal of present/absent elements, print composition, nulls, unchanged
`any` contents, formats, unsupported payloads and compiler boundaries. Four public
regressions and a portable consumer also check no-read behavior, unchanged caller
bytes, retained storage, partial writes and optional outer nulls. Named zero
locals avoid V's inline fixed-array argument C-generation issue.

Two independent compiler controls keep limits separate from parity. V reflects
raw `[3]?[2]i16{}` as `[3][2]i16`, losing the optional marker before formatting;
Source retains it. Assigning an optional fixed-array element emits invalid C
without any address-formatting call. A further isolated value-format consumer
for `[]?[3]?bool` reproduces an incorrect `_option_bool` argument clone in the
unused `any` path. Its exact C-generation diagnostic is required; direct address
calls for those represented payloads compile and match. These controls never
count as returning-record parity.

All 133 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical optional-array
and optional-scalar-slice address record/state hashes remain unchanged in both
modes. Vaxis runtime tests are not rerun.

Other runtime bodies, dispatcher/IO and C remain byte-identical; removing the four
new lines reconstructs the previous implementation exactly. Whole Source/library,
compiler executable, implementation, fixture/model/helper and input pins are
checked before/after. Expected outputs and bodies freeze before final runs.
Independent replay checks records, failure states, compiler outcomes and
provenance; every retained archive member is read back before commit.

Optional pointer/record/string leaves, unsupported declaration/assignment forms,
value formatting of optional arrays containing optional elements, bare optional
addresses, whole optional-array pointers, qualifiers/sentinels and arbitrary
named types remain boundaries. Source supports broader names and requires static
formats; V accepts runtime strings and rejects unsupported represented leaves
before writes. General allocation/layout/ownership/lifetime contracts, overlapping
input/output, concurrency and huge successful output remain outside the claim.
Zero witnesses can use stack space proportional to the array type. Synthetic
addresses prove formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_optional_array_payload_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-optional-array-payload-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.


The subsequent [nested optional-array value checkpoint](../writer_nested_optional_array_value/README.md)
binds optional slice elements before dispatch, avoiding the incorrect leaf-option
clone. `optional-elements-value` is now a positive V check, and native/value/outer
compiler consumers cover all three payload shapes. The original returning corpus
and retained-state hashes above are unchanged. Raw declaration reflection and
element-assignment controls remain separate compiler limits.


The subsequent [optional-pointer element checkpoint](../writer_optional_pointer_address/README.md)
adds native/opaque optional pointer element names to slices and concrete fixed
arrays. This driver's former optional-pointer rejection control now checks the
positive canonical V address. Its returning corpus and state hashes are unchanged.
Fixed arrays of optional whole-pointer aliases retain a measured V C-generation
limit; aliases in dynamic slices work.
