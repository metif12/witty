# Slice element address names

Address names now recurse into represented slice elements. Examples are
`[]i32@1234` for a slice of integer slices, `[3][]u8@1234` for an array pointer
whose elements are byte slices, and `?[]i32@0` for optional integer slice elements.
Direct addresses and value-format `*` share the helper. Nested slice/array names,
whole-container aliases, optional outer slices and named print arguments compose
with the existing routes; absent outer slices retain aligned `null`.

The helper binds the inner element generic through an empty witness and recursively
names a zero element. It does not index the caller's inner slice headers or read
their targets. The original outer storage bits and separate name-plus-`@` / digits
writes are retained; present options/depth are ignored. The slice conditions in
the direct/value and optional-name helpers now admit this represented kind.
Removing these additions reconstructs the previous runtime exactly; other bodies
and C remain byte-identical.

Unchanged public pinned Source methods and an independent writer-state model
match **46,648 full records per mode**, including **25,907 WriteFailed records**.
Thirteen native scalar element types plus opaque-pointer controls, four routes,
flat/nested/aliased array shapes, 190 addresses, lengths zero/one/three, capacities,
maximal options and memory/file/pipe/closed-descriptor states retain four snapshots
through caller-buffer mutation and flush. These include input headers, position,
backing/buffered/unused bytes and file/descriptor state.

**120 isolated returning controls per mode** check prefix/digit failures, nested
names, zero/maximal addresses and optional outer nulls. No parity controls panic.
Production V is paired with Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 46,648 | `87e39caaf1da972c6c67965577773c9c95919e278b9c44290013fafd444fbb57` |
| Isolated return states | 120 | `e08d9b40930db763aab9da54b3256a4b56f4057a93a5ef38eee777493dab50a1` |

Fourteen external compiler pairs cover array/slice/optional-element native
matrices, nested slices, print/optionals, unchanged contents/pointer addresses,
unsupported inner names and runtime/static formats. Five public regressions and a
portable consumer check no-read formatting, unchanged owned headers, target and
header-order mutation, exact partial writes and nulls. Owned checks compare their
own addresses, not raw addresses across processes.

Two V boundaries are measured separately. Some slices returned by a generic
helper lose the reflected array kind when the element is itself a slice alias;
in a mixed generic consumer this generates empty public dispatcher bodies.
Casting to a named outer alias preserves the required type information. Raw and
named consumers retain the distinct outcomes in both modes; the parity corpus
uses represented aliases.

Production V also inserts GC keepalive walkers that traverse headers in nested
`usize` slices kept live across calls. A matrix using invalid synthetic storage
with nonzero lengths crashed in that generated caller code. Its source, command /
failure receipts and generated GC code are retained separately. The final flat
slice compiler matrix uses empty synthetic views; nonempty owned consumers and
the four-route returning corpus remain covered. No-read statements describe the
formatter. They do not promise that compiler-generated GC/lifetime code ignores
caller elements. Valid storage is required for such compiler traversal.

All 140 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical optional-array
payload addresses and aliased pointer-array values retain record/control/state
hashes in both modes. Vaxis runtime tests are not rerun.

Source/library, executable, implementation, fixture/model/helper and input pins
are checked before/after. Expected returning outputs freeze before final runs.
Independent replay checks observations, failures, compiler outcomes, separate
reflection/GC controls and provenance; every retained archive member is read back
before commit. Completed inactive proof extras were archived and read back before
removing their unpacked duplicates to recover disk space.

Strings, aggregate/function pointees, unsupported inner names, qualifiers /
sentinels and broader representation contracts remain boundaries. Source requires
static formats; V accepts runtime strings. General allocation/layout/ownership /
lifetime contracts, overlapping input/output, concurrency and huge successful
output remain outside the claim. Zero witnesses may use stack space proportional
to array types. Synthetic addresses prove formatting only. Runtime evidence is
little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_slice_element_address_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-slice-element-address-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
