# Slice descriptor pointer formatting

Pointers to represented V slice descriptors now format their descriptor address,
using Source names such as `[]u8`, `[]i32`, `[][]u8` and `[][]const u8`. A zero
pointee witness supplies the existing recursive element-name helper. The
formatter never reads the caller's descriptor or elements. Direct addresses and
explicit `*` keep separate prefix/digit writes; default/`any` keeps type/`@`
vectors followed by aligned hex digits. Direct options and depth are ignored.

Native pointers, pointers to slice aliases, pointer aliases and present/absent
optionals compose with the existing dispatch. `?*` unwraps a present pointer and
aligns `null` for absence; direct optional addresses and bare `*` retain the
leading pointer name, such as `*[]u8@0`. Array/slice element names also admit a
represented slice-descriptor pointee. Native slice values retain their data
addresses and contents formatting.

Unchanged public pinned Source methods and an independent writer-state model
match **21,920 full records per mode**, including **6,790 WriteFailed records**.
Byte/integer descriptor pointers cover seven native/alias/present/absent carriers,
190 input addresses, capacities through 32, options, alignment and memory/file/
pipe/closed-descriptor states. Present optional addresses are nonzero and aligned
to eight bytes for Source's natural pointer type; plain pointers cover all bits.
Four snapshots preserve position, backing/buffered/unused bytes and file state
through caller-buffer mutation and flush. Synthetic addresses prove formatting.

**77 isolated returning controls per mode** preserve partial prefix/digit/null
writes and unused bytes. No parity controls panic. **15 external compiler pairs
per mode** cover routes, aliases, owned descriptor replacement, optionals, pointer
elements, print, thirteen native scalar element names, composite optional/array/
nested/string element names, unsupported formats and runtime formats. Source
rejects unsupported/runtime formats at compilation; V rejects unsupported runtime
formats before writing.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 21,920 | `66689221b5ebf04a9752403d30f400f1f56bca873f051f949d3cf08097570b72` |
| Isolated return states | 77 | `2bb2900d705757d77638c981c67f7320d96ac3845a83cb5bb54d7823890c586b` |

Two compiler boundaries are measured. V rejects `[2]&[]u8` declarations; a named
pointer alias supports the equivalent pointer-element consumer. In production,
V 0.5.2 generates invalid GC helper C for a pointer alias whose pointee is a
nested slice: the helper treats an alias of `array*` as an array value. Its
standalone control returns `[][]u8@1234` in ordinary mode and rejects compilation
in production, retaining the GC diagnostic. The main state corpus uses flat
byte/integer descriptors. Nested/string names are covered by inline callers;
owned consumers check flat descriptors. No claim is made that compiler-generated
lifetime code ignores invalid synthetic descriptors. Earlier four-family ordinary evidence and the production
C failure are retained in separately verified superseded archives.

Five public regression functions and a portable consumer check raw/owned
pointers, aliases, zero/optionals, exact partial writes, composite names,
preserved header bytes, address stability across descriptor replacement and
unchanged contents formatting. All 144 image test files and 24 additional
production/application/platform commands pass. Portable consumers run natively in
both modes and compile for Windows/Linux; cross builds establish compilation
only. Historical string-pointer and slice-element address suites retain their
record/control/state hashes in both modes. Vaxis runtime tests are not rerun.

Only descriptor naming/routing and the shared fallible name calls change in the
runtime; every other body, parsing and C remains byte-identical. Source/library,
executable, implementation, fixture/model/helper and input pins are checked
before/after. Expected returning outputs freeze before final runs. Independent
replay verifies records, failure state, compiler outcomes and provenance; every
retained archive member is read back before commit. Completed regenerable caches
and verified archive-backed duplicates were reclaimed, with archives retained.

The Source slice mapping does not equate descriptor layouts, allocation,
ownership or lifetime. Unsupported inner names, deeper indirection, qualifiers,
compiler-generated GC traversal, overlapping input/output, concurrency and huge
successful output remain boundaries. Zero witnesses can use stack space
proportional to array types. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_slice_pointer_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-slice-pointer-20261105/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
