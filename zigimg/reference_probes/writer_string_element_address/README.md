# String element address names

Array and slice address names now map V string elements to the pinned Source's
read-only byte-slice name, `[]const u8`. Examples are `[3][]const u8@1234`,
`[]const u8@0` and `?[]const u8@1234`. String aliases, nested arrays, optional
string elements, optional fixed-array payloads, optional outer slices and named
print arguments compose through the existing helpers.

This is an explicit representation mapping: V string values correspond to Source
`[]const u8` payloads. It does not equate their layouts, allocation, ownership or
lifetime rules. The formatter does not read string headers or bytes. It retains
the outer storage bits, one name-plus-`@` write followed by lowercase hexadecimal
digits, ignored present options/depth and aligned absent outer nulls.

Unchanged public pinned Source methods and an independent writer-state model
match **8,568 full records per mode**, including **5,028 WriteFailed records**.
Four routes, native/aliased/nested/optional-element arrays, 190 addresses, lengths
zero/one/three, capacities, maximal options and memory/file/pipe/closed-descriptor
states retain four snapshots through caller-buffer mutation and flush. These
include input headers, position, backing/buffered/unused bytes and file state.

**120 isolated returning controls per mode** check prefix/digit failures, nested
names, zero/maximal addresses and optional nulls. No parity controls panic.
Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 8,568 | `5bf1c86030756c297e9c94f0f2b49739c9e71db0f531e5ba494df9b933b17e8a` |
| Isolated return states | 120 | `4e9afb24b8c69ca44a7ab614f7d47274468e7999de97e63046fe4fd19527ed68` |

Twelve external compiler pairs cover direct/value routes, slices, optional
string elements, optional fixed-array payloads, print/optionals, preserved
contents and invalid/runtime formats. Five public regressions and a portable
consumer verify no-read formatting, unchanged owned headers, header/content
mutation, exact partial writes and nulls. Owned checks compare their own addresses.

V still declares optional fixed-array element storage before a string payload
alias (`[3]?Text`, `type Text = string`). A length-only consumer reproduces that
C-generation error without calling a formatter in both modes. Native optional
string elements and named optional string-array payloads pass. Existing generic
array-kind reflection and generated GC traversal limits remain separate: named
outer aliases and empty synthetic views avoid those forms. Nonempty owned
storage remains covered. No-read claims describe the formatter, not generated
GC/lifetime code.

All 141 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical optional-array
payload and slice-element addresses retain record/control/state hashes in both
modes. The former string-array rejection now uses a correctly represented optional
carrier and checks the positive canonical address. Vaxis runtime tests are not rerun.

Only two string-name branches and two widened slice conditions change the runtime.
Removing them reconstructs the prior implementation exactly; other bodies and C
are byte-identical. Source/library, executable, implementation, fixture/model /
helper and input pins are checked before/after. Expected returning outputs freeze
before final runs. Independent replay checks observations, failures, compiler
outcomes and provenance; every retained archive member is read back before commit.

Direct string carriers in `print_address`, pointer-to-string payload names,
unsupported inner types, qualifiers beyond this read-only string mapping and
broader representation contracts remain boundaries. Source requires static
formats; V accepts runtime strings. General allocation/layout/ownership/lifetime
contracts, overlapping input/output, concurrency and huge successful output remain
outside the claim. Zero witnesses may use stack space proportional to array types.
Synthetic addresses prove formatting only. Runtime evidence is little-endian
64-bit macOS.

```sh
python3 zigimg/verify_writer_string_element_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-string-element-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
