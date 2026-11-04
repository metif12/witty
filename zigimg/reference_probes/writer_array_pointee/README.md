# Fixed-array pointees in address element names

Address names now admit pointers to represented fixed arrays. For example, a
pointer to an array of three `*[3]u8` elements prints `[3]*[3]u8@…`; nested
pointees retain all dimensions. The helper names a zero pointee witness through
the existing array-name recursion. A pointer to locally created zero storage,
explicitly cast through `P`, avoids GCC array-copy initialization and preserves
each pointee specialization in V. Scalar pointees keep their existing
value-witness path. A fixed-array value guard keeps pointer
carriers on pointer dispatch before any array indexing. Neither branch reads
caller elements or pointed storage.

Direct `print_address` and explicit value-format `*` share the new names for
array-pointer and slice carriers, including whole-container/pointer aliases,
optional outer slices and named `print` arguments. Original storage bits and
separate prefix/digit writes remain intact. Present address options and depth
are ignored; absent outer slices retain aligned `null`. Existing direct
fixed-array pointer contents formatting is unchanged.

Unchanged public pinned Source methods and an independent writer-state model
match **14,308 full records per mode**, including **7,997 WriteFailed records**.
Four byte/integer/nested/boolean pointee shapes cover three outer shapes, four
APIs, 190 address patterns, lengths zero/one/three, capacities, maximal options
and memory/file/pipe/closed-descriptor states. Four snapshots retain observed
storage bits/length, position, backing/buffered/unused bytes and file state through
caller-buffer mutation and flush. Synthetic addresses establish formatting only.

**120 isolated returning controls per mode** preserve prefix/digit/null failure
state, unused bytes, zero/maximal addresses and present/absent outer optionals.
No controls panic. **Nine external compiler pairs per mode** cover all thirteen
native scalar pointee element types, owned pointer-array storage and mutation,
print/outer optionals, flat pointer slices, unchanged byte contents, unsupported
indirection, runtime/static formats and the existing optional-alias C boundary.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 14,308 | `d8edc81a0ab781fca17f9d3d9c609397b44a6811cb5b5dfcb55919b1cb0252a5` |
| Isolated return states | 120 | `d792ef4c2b30b4c11a9b202f74c92375a910eeaf5362e89f72085c5203857470` |

V 0.5.2 still declares optional pointers to named array pointees before their
alias typedefs. A standalone `[2]?&Base0` control reproduces the undeclared-alias
C failure in both modes; Source returns its length. Native optional array-pointer
syntax also remains restricted by V's parser. Optional **outer slices** compose
through the existing route; the proof does not claim optional pointer elements
whose alias declarations cannot compile.

Four public regression functions and a portable consumer verify no-read names,
exact partial writes, preserved pointer bytes and slice pointer/length, storage
and target mutation,
original storage addresses and outer nulls. All 145 image test files and 24
additional production/application/platform commands pass. Portable consumers run
natively in both modes and compile for Windows/Linux; cross builds establish
compilation only. Historical scalar-pointee-alias and slice-descriptor-pointer
suites retain record/control/state hashes in both modes. Vaxis runtime tests are
not rerun.

Reversing fixed-array naming, its pointer-witness binding and the value guard
reconstructs the previous runtime exactly. Other bodies, parsing and C remain byte-identical. Source/library,
executable, implementation, fixture/model/helper and input pins are checked
before/after; expected outputs freeze before final runs. Independent replay
verifies observations, failure state, compiler outcomes and provenance; every
retained archive member is read back before commit. Completed regenerable caches
and verified archive-backed generated artifacts were reclaimed with archives
retained.

Unsupported inner names, deeper pointer indirection, aggregate/function pointees,
unrepresented qualifiers and broader layout/allocation/ownership/lifetime
contracts remain boundaries. Compiler-generated GC traversal, overlapping input/
output, concurrency and huge successful output are outside the claim. Zero
witnesses can use stack space proportional to array types. Runtime evidence is
little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_array_pointee_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-array-pointee-20261105/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
