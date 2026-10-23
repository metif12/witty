# Fixed-array Writer value dispatch

`WriteStream.print_value("any", options, value, max_depth)` now recursively formats
fixed arrays of native integers, f32/f64 and bool, including nested arrays and V
aliases. Fixed arrays and dynamic slices can nest together. Depth zero writes
`{ ... }`; positive depth writes `{ `, the elements separated by `, `, and ` }`.
Options apply to scalar leaves. Byte arrays additionally accept `s`, `x`, `X` and
`b64`, retaining byte alignment, forbidden-option panics and ignored byte depth.

The implementation passes a fixed-array view through the existing byte or
recursive slice helper. Opening, element, separator and closing writes retain
their separate failure boundaries. Unsupported formats return V errors before
writer effects. Other formatter bodies, IO and C remain unchanged. Four public
regressions cover aliases, mixed arrays, depth, byte formats, leaf options,
invalid formats and every capacity around a nested result.

The Source fixture calls the original public Zig 0.15.2 Writer.printValue body
without changing Source or visibility. All 13 scalar types and their V aliases
are represented in six shapes: fixed length three, fixed 2×3, fixed 2×2×3,
fixed length one, a dynamic slice of fixed rows, and a fixed array of dynamic
slices. Cases cover raw-bit edges and depths zero through three. Five complete
snapshots retain writer backing, position, pending/unused views and headers,
descriptor state, input payload/spans, options, actual typed leaf bytes and
file/wire contents through caller mutation and flush. The shape string specifies
fixture construction; it does not observe nested descriptors or every copied
array. Memory, positional/streaming files, replaced pipes and closed descriptors
are covered. Private allocation, layout and lifetimes are outside this proof.

An independent Python model predicts recursive writes, byte encodings and state,
reusing the independently modeled scalar integer and float rules. Debug/ordinary
and ReleaseSafe/production each compare 17,688 complete returning records,
65 isolated returning controls and 127 paired panic/state controls. The main
corpus includes 5,608 independently predicted WriteFailed states; isolated
returning controls add 41. The seven integer-overflow and 120 forbidden-option
panics remain active in production. Isolated controls exercise maximal width/precision across depth cutoffs and forbidden
byte-format options. Panics require the exact diagnostic, empty stdout and
matching retained state. Five groups cover type/bits/shape/depth edges, write
order/failure, every capacity through 65 bytes, byte formats and byte padding.
The frozen bodies produce these hashes in both modes:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 17,688 | `578482d642381e63ac2b442a19895010d670a1ca0d58c001755dcea382b58663` |
| Isolated returning controls | 65 | `4a2e65986abb0f95226a85cf4adc05dc457601d49a2cb28b593635b374387858` |
| Panic/state controls | 127 | `fb41063801086dd0eb8e112382a89a25f6cef9c56127bfdf9ed29f18067fa996` |

Seventeen external compiler pairs per mode cover five commonly accepted
consumers, three paired ordinary argument rejections and nine representation
boundaries. V accepts runtime format strings; Source requires compile-time
formats. Source statically rejects unsupported array formats and array `*`,
where V returns errors before writer effects. Zero-length fixed arrays, record
elements and optional scalar elements remain unrepresented. Pointer elements
with `any` return a V error after the opening bytes. These cases are explicitly
non-equivalent to Source's supported formatting.

The pinned V compiler rejects zero-length fixed-array declarations. Named
row/grid locals and the measured nested nominal-array alias literal work in
both modes. Generic fixture-local `[N]T` constructors retain the first element
specialization, so the comparison uses
concrete constructors for every scalar/alias type. The public formatter remains
generic. These compiler limits do not establish support for arbitrary generic
array construction. Qualifiers, sentinels, arbitrary nominal type names,
broader coercions and ABI/layout remain boundaries. Full Writer.print, custom
formatter reflection and further value dispatch remain unported.

All 112 image test files and 17 production/application/Windows/Linux checks pass.
Historical primitive and recursive slice comparisons retain their previous
hashes in both modes. Vaxis source is unchanged and dependencies build; its
runtime tests are not rerun. The unchanged Ryu tables retain all 1,336 limbs.

Whole Source and selected compiler libraries, Io/fmt/math/meta/base64/float/path /
encoder pins, versions, implementation, shared models/helpers, fixtures and
inputs are checked before and after. Runtime/test/fixture/model bodies freeze
before final comparisons; only six EXPECTED assignments may change afterward.
Every observation, compiler outcome, build mode, binary and provenance pin is
replayed from retained evidence. Every archive member is read back before
committing. Superseded development runs remain separate from final proofs.

Evidence is pinned little-endian 64-bit macOS. Cross builds establish compilation
only. Other runtime widths/platforms, invalid descriptors, injected short devices,
concurrent mutation and huge successful output/storage remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_array_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Users/alex/.cache/witty-writer-value-array-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
