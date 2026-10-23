# Custom Writer value formatting

`WriteStream.print_value('f', options, value, max_depth)` invokes a concrete
carrier's `format(mut stream WriteStream) !` method. A structural interface
selects the branch; the call keeps the concrete generic type. Options and depth
are not passed to the method, including maximal width/precision and zero depth.
The method's writes and returned error propagate directly. Optional `?f` unwraps
present values; absent values retain aligned `null` behavior. Empty-format
ambiguity and `any`/`t` bypass behavior remain unchanged.

The native fixture calls the unmodified public Zig 0.15.2 Writer.printValue
body. Its six carriers are a record, alias, present/absent optional, sum type and
concrete error carrier. The formatter separately writes `custom(`, a signed
integer, `:`, a borrowed byte slice and `)`, with injected errors before/after
selected writes. Five snapshots retain backing, position, pending/unused views,
borrowed slice headers, inputs/options, canonical payload bytes, method entry
and completed-step counts, and file/wire contents through caller mutation and
flush. Memory, positional/streaming files, replaced pipes, closed descriptors,
options, depth and every capacity through 39 bytes are covered. An independent
Python model predicts individual writes, failures and retained state.

Debug/ordinary and ReleaseSafe/production each compare 6,125 complete returning
records, 106 isolated returning controls and two exact panic/state pairs. The
main corpus includes 4,086 modeled WriteFailed results; all 106 isolated returns
fail. Present formatters ignore maximal options. Absent optionals still exercise
aligned-null overflow and failure order. Every trap requires one exact integer
overflow diagnostic, empty stdout and matching retained state in both modes.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 6,125 | `722ae4a32f6d881fe3189ea0bedfd6ee4648a998b63d7d8e288e815ea7fbe9a0` |
| Isolated returning controls | 106 | `ac3c5bf0362ea046c99d2135bb0b2281385406df0b371b08f7516e9a7a073468` |
| Panic/state controls | 2 | `36d4f88f11bcbc83180f6cefcd3894ac0f515c3cc82cd947f2d4a1a14d2338f3` |

Seventeen external compiler pairs per mode include seven accepted consumers
(record, alias, enum, sum type, optional, absent optional and concrete error),
three paired argument rejections, missing/wrong methods, runtime formats,
empty-format ambiguity, record pointers, nonfallible methods and interface
carriers. Source checks formats and methods statically; V accepts runtime strings
and reports unsupported/ambiguous formats before writes. Source accepts a
nonfallible void formatter; V's fallible method contract rejects it at runtime.
Record pointers and interface carriers remain V compiler limits because other
generic dispatcher branches must compile. The interface is a selection mechanism;
passing an interface value is not established by the concrete-carrier results.

Four public regressions also check arbitrary V error message/code propagation,
partial memory writes, bypass behavior, absent optionals and fixed arrays beside
custom specializations. All 118 image test files and 21 successful production /
application / Windows / Linux commands pass. Portable consumers run natively in
both modes and compile for Windows in both modes and Linux. The first standalone
fixture omitted Result declarations outside test functions; that rejected build
is retained, and the corrected consumer is checked separately. Cross builds
establish compilation only. Historical primitive, recursive slice, fixed-array,
enum, record, address, optional, error and tagged-union comparisons retain their
hashes in both modes. Vaxis source is unchanged and dependencies build; its runtime
tests are not rerun. Other formatter helpers, IO and C are unchanged; Ryu tables
retain all 1,336 limbs.

Whole Source and selected compiler library pins, versions, implementation,
models/helpers, fixtures and inputs are checked before and after. Runtime,
native fixtures and model bodies freeze before final comparisons; only six
EXPECTED assignments change from discovery. The standalone Result correction
has separate before/after hashes. Semantic checks use the pinned V 0.5.2 fallback
compiler; formatting uses V 0.5.2 d1df2de and compares the dispatcher against its
unchanged baseline. Interrupted external checks resume only identical commands
with pinned retained logs, binaries and provenance. Observations, controls,
compiler outcomes, modes and provenance are replayed independently. Large output
is compressed losslessly by a separately pinned wrapper. Every retained archive
member is read back before committing; development evidence stays separate.

Evidence is pinned little-endian 64-bit macOS. Mutable formatter receivers,
custom scalar/array carriers, unsupported field specializations, broader pointer
recursion/coercions, arbitrary interface dispatch, first-class error unions,
private layouts, lifetimes and general copy/mutation equivalence remain unproven.
Other runtime platforms/widths, invalid descriptors, injected short devices,
concurrent mutation and huge successful output/storage remain boundaries.
Full Writer.print remains unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_custom_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Volumes/codex-fullsuite-20261023/witty-writer-value-custom-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
