# Recursive slice Writer value dispatch

`WriteStream.print_value("any", options, value, max_depth)` now formats dynamic
slices of native integers, f32/f64 and bool, recursively including nested slices
and V aliases. At depth zero it writes `{ ... }`; otherwise it writes `{ `,
each element separated by `, `, and ` }`. An empty slice prints `{  }` at positive
depth. Options apply to scalar leaves, so depth cutoffs and empty slices bypass
even maximal width/precision. Byte-slice leaves retain their existing dispatch.

The implementation preserves separate opening, recursive element, separator and
closing writes. Errors retain the exact written prefix and writer state. Scalar
slice `*` continues through the existing address formatter. Other formatter bodies,
IO and C are unchanged. Four public regressions cover nested aliases, depth,
element options, invalid formats and every capacity around a nested result.

The Source fixture calls the original public Zig 0.15.2 Writer.printValue("any")
without changing Source or visibility. All 13 scalar types and their V aliases
are represented in flat, nested and triple slices, with empty/singleton inputs,
raw-bit edges, depths zero through three and maximal depth. Five complete
snapshots retain writer backing, position, pending/unused views and headers,
descriptor state, input payload/spans, options, actual typed leaf bytes and
file/wire contents through caller mutation and flush. The recorded shape string
is the fixture's shape specification, not an observation of nested descriptors.
Memory, positional/streaming files, replaced pipes and closed descriptors are
covered. Private allocation, nested descriptor/layout and lifetimes are outside
this proof.

An independent Python model recursively predicts write boundaries and state,
reusing the independently modeled scalar integer and float formatting rules.
Debug/ordinary and ReleaseSafe/production each compare 17,232 complete returning
records, 186 isolated returning controls and six paired panic/state controls.
The isolated controls exercise maximal options with depth and empty slices.
The 4,380 main-corpus and 150 isolated WriteFailed observations preserve the
independently predicted state. Four groups cover type/bits/shape/depth edges, write order/failure,
empty/singleton options and every capacity through 65 bytes. The frozen bodies
produce these hashes in both modes:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 17,232 | `86a0e7059035dc1caad58b43a9f31b95bf5cf09014fa60c55dc89f2c1ede1783` |
| Isolated returning controls | 186 | `bab7bccc0a39b87be06fc2f4779aa590a63301638619f7c94df32230c9e76cda` |
| Panic/state controls | 6 | `d5c26bd531e5f63e3afd66f3cb090ce51040527952e266dfd0869b7971499681` |

Sixteen external compiler pairs per mode cover four commonly accepted consumers,
four paired ordinary rejections and eight representation boundaries. V accepts runtime format strings;
Source requires compile-time formats. Unsupported non-byte slice formats return
V errors before writer effects, where Source rejects them statically. Fixed
arrays, records and optional scalar elements remain unrepresented. Pointer
elements with `any` return a V error after the opening bytes; nested-slice `*`
returns an error before writes. Those cases are explicitly non-equivalent to
Source's supported formatting. Qualifiers, sentinels, arbitrary nominal type
names, broader coercions and ABI/layout remain boundaries. Full Writer.print,
custom formatter reflection and further value dispatch remain unported.

All 111 image test files and 17 production/application/Windows/Linux checks pass.
Historical primitive and pointer address comparisons retain their previous hashes
in both modes. Vaxis source is unchanged and its dependencies build; its runtime
tests are not rerun. The unchanged Ryu tables retain all 1,336 limbs.

Whole Source and selected compiler libraries, Io/fmt/math/meta/base64/float/path /
encoder pins, versions, implementation, shared models/helpers, fixtures and inputs
are checked before and after. Runtime/test/fixture/model bodies freeze before
final comparisons; only six EXPECTED assignments may change afterward. Every
observation, compiler outcome, build mode, binary and provenance pin is replayed
from retained evidence. Every archive member is read back before committing.
Superseded development runs are retained separately and are not final proofs.

Evidence is pinned little-endian 64-bit macOS. Cross builds establish compilation
only. Other runtime widths/platforms, invalid descriptors, injected short devices,
concurrent mutation and huge successful output/storage remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_slice_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Users/alex/.cache/witty-writer-value-slice-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded; owned RAM is released after commit.
