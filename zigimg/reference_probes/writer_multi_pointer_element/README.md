# Multi-level pointer address element names

Address element names now recurse through additional pointer levels. Examples
include `[3]**u8@…`, `[2][3]***i32@…` and `[3]**[2][3]u16@…`. Each recursion
binds a zero pointer of the next type and prefixes `*`; no caller pointer chain
or outer storage is read. The existing single-pointer path is unchanged.

The shared value-pointee helper now names pointer children through the same
recursion. The fixed-array value guard excludes pointer carriers, so generic
value dispatch can compile address-only containers with pointer/array pointees.
Scalar pointer-value leaves are checked separately. Direct multi-level pointer
carriers in `print_address` remain unported; the main claim covers element names
in array-pointer and slice address carriers.

Unchanged public pinned Source methods and an independent writer-state model
match **14,308 full records per mode**, including **7,985 WriteFailed records**.
Two-, three- and four-level scalar/pointee-array shapes cover three outer shapes,
four APIs, aliases, 190 address patterns, lengths zero/one/three, capacities,
maximal options and memory/file/pipe/closed-descriptor states. Four snapshots
preserve storage bits/length, position, backing/buffered/unused bytes and file
state through caller-buffer mutation and flush. Direct and explicit `*` retain
separate prefix/digit writes; present options/depth are ignored. Optional outer
slices retain their existing present address and aligned-null routes.

**120 isolated returning controls per mode** preserve prefix/digit/null failures,
unused bytes, zero/maximal addresses and outer optionals. No controls panic.
**17 external compiler pairs per mode** cover thirteen native scalar pointees,
owned chains and target mutation, print/outer optionals, flat pointer slices,
native optional pointer elements, six pointer levels, scalar pointer-value leaves,
unchanged byte-array contents, runtime/static formats and retained boundaries.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 14,308 | `515223bf4852a8c1d124a13923f032cf2c0179848138e2854275a9210b14dfb8` |
| Isolated return states | 120 | `494a86489ac3d70aa9219a78e96f4d7ae7d0490875d1ed49bda6ff57bc8fd0f0` |

Five former nested-pointer rejection controls now check owned addresses and
return `address-ok`. They are replayed as compiler pairs in this suite; their
updated runners are provenance inputs. The historical scalar-pointee-alias and
array-pointee suites retain record/control/state hashes in both modes, with the
promoted compiler outcomes recorded separately.

Native `[2]?&&u8` address elements work. Optional pointers to named pointee aliases
still hit V 0.5.2's declaration-order C failure; a standalone control retains the
undeclared `Base0` diagnostic in both modes. Direct multi-level `print_address`
carriers remain a measured V rejection against Source's returning control.
Default formatting of arbitrary pointer chains and aggregate/function pointees
is outside the parity claim. Pointer-value controls use naturally aligned
synthetic addresses, and owned consumers compare their own process addresses.

Four public regressions and a portable consumer check no-read names, aliases,
optional elements, outer nulls, exact partial writes, original storage bits,
preserved pointer bytes and mutations to elements, intermediate pointers and
final targets. All 146 image test files and 24 additional production/application/
platform commands pass. Portable consumers run natively in both modes and compile
for Windows/Linux; cross builds establish compilation only. Vaxis runtime tests
are not rerun.

Removing the recursive element/value-pointee branches and fixed-array value guard
reconstructs the previous runtime exactly. Other bodies, parsing and C are
byte-identical. Source/library, executable, implementation, fixture/model/helper
and input pins are checked before/after; expected outputs freeze before final
runs. Independent replay verifies observations, failures, compiler outcomes and
provenance; every retained archive member is read back before commit. Completed
regenerable caches and verified archive-backed duplicates were reclaimed with
archives retained.

Unrepresented inner types/qualifiers and general layout/allocation/ownership/
lifetime contracts remain boundaries. Compiler-generated GC traversal,
overlapping input/output, concurrency and huge successful output are outside the
claim. Zero array witnesses can use stack space proportional to their types;
recursive naming is also subject to compiler limits. Synthetic addresses prove
formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_multi_pointer_element_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-multi-pointer-element-20261105/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
