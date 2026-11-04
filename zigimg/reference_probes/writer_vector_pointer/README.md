# Pointer lanes in public Writer.printVector

`WriteStream.print_vector` now accepts inline fixed arrays of native scalar
pointers, opaque pointers, pointer/pointee aliases and optional scalar pointers.
The existing numeric and boolean lane behavior remains. Fixed arrays carry
Source vector values; this does not establish native SIMD layout or ABI.

Depth zero writes `{ ... }` once. Otherwise the unchanged vector composition
writes `{ `, each lane at one less depth, separators and ` }`. Default/`any`
pointer lanes write type and `@` as two vectors before lowercase address digits;
width/alignment/fill apply only to digits. Precision and leaf depth are ignored.
Optional `any`/`?`/`?any` lanes unwrap or print aligned `null`. Explicit `*` keeps
its optional-pointer prefix and ignores options; `?*` unwraps first. The target
addresses are never read. Ordinary array/print dispatch and leaf formatters are
unchanged.

V merges a whole pointer alias's generic specialization with an optional pointer
of the same underlying type. Normalizing the nonoptional alias before dispatch
avoids that compiler issue without examining optional storage. Indexed lane
access preserves optional carriers. Named option locals in fixtures avoid V's
invalid C generation for inline optional-pointer array literals. Arrays of
optional whole pointer aliases still fail C generation; a standalone paired
compiler control records this limit.

The native fixture calls the unchanged public Source body through the locked
image writer. Nineteen carriers cover all 13 native scalar pointees, opaque
pointers, pointer/array and pointee aliases, and optional u8/f64/bool pointers.
Lengths one/three/eight, synthetic address bits, presence, options, depth,
capacities and memory/positional/streaming/pipe/closed-descriptor states are
included. Optional targets are aligned/nonzero or absent. Four snapshots retain
backing/views, position, descriptor/file state and constructed lane bits through
caller mutation and flush. Allocation validity is not established.

An independent Python model composes the outer vector writes, two-vector pointer
prefixes, integer padding/digits, optional nulls and individual writer operations.
Each mode compares **13,851 records**, including **9,540 WriteFailed records**.
Thirteen external compiler pairs add all 13 optional pointee widths, alias/option
coexistence, explicit optional addresses, opaque pointers, invalid/runtime formats
and unsupported optional carriers. Source validates static formats even at depth
zero. V checks visited leaves at runtime, after the opening write; depth zero can
bypass invalid leaf formats. Nonpointer optional lanes are rejected at compile
time before the depth cutoff.

Fifteen paired traps and 85 returning controls per mode preserve outer and leaf
prefix/digit/padding failure order. Maximal width traps after the first present
lane's digits, with the exact `integer overflow` panic in production too. The outer prefix also causes absent-first `null` padding to overflow after
the null write. Earlier write failure, depth zero and explicit `*` are controlled.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 13,851 | `79f9752316cdc01908ba9e6af6966823589d3edaea441c406aef26ad50a522a0` |
| Isolated failure/control states | 100 | `6880665087aa55db775dafaaf07dd688030c64ec7c039d7657d503f202ade92a` |

Five regressions and a portable consumer cover alias normalization, optional
presence, digit-only padding, explicit addresses, partial writes and invalid leaf
order. Existing vector/pointer comparisons retain their record/state hashes; the
historical vector pointer compiler control now accepts the V implementation.

All 123 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Vaxis runtime tests
are not rerun. Historical numeric-vector and scalar-pointer comparisons retain
their record/state hashes in both modes; the old vector pointer compiler control
now accepts the V implementation.

Source/library, compiler executable, implementation, fixtures, models/helpers and
inputs are pinned before/after. Expected results and proof bodies freeze before
both-mode runs. Observations, compiler outcomes, failure states and provenance
are replayed independently; every retained archive member is read back.

Optional opaque/whole-alias arrays, broader nested/aggregate/function pointees,
qualifiers, nonnative widths, zero-length arrays and general allocation/layout /
lifetime/copy/mutation contracts remain limits. Runtime evidence is pinned
little-endian 64-bit macOS; cross builds establish compilation only. Huge
successful output/storage and concurrent mutation are outside these tests.

```sh
python3 zigimg/verify_writer_vector_pointer_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-vector-pointer-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
