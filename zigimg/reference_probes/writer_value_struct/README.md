# Record Writer value dispatch

`WriteStream.print_value` formats ordinary records and aliases with empty or
`any` formats. Positive depth writes `.{`, then each field's separator, name,
` = ` and recursively formatted value in declaration order, followed by ` }`.
Every part retains its own write boundary. Depth zero writes `.{ ... }` without
visiting fields; a positive-depth empty record writes `.{ }`. Field options
propagate unchanged and each record/array level consumes one depth.

Empty format is ambiguous for a record declaring a `format` method, including
at depth zero. V reports this and unsupported formats as errors before writer
effects; Source rejects them statically. `any` reflects those records normally.
Calling custom formatters with `f` remains unported. The public regressions cover
field order, aliases, nested records/slices/fixed arrays, depth, ignored options,
custom-method ambiguity and every capacity around output.

The native fixture calls the original public Zig 0.15.2 Writer.printValue body
without modifying Source or visibility. Six record shapes plus aliases cover
empty records, signed/unsigned 64-bit integers and bool, borrowed byte slices
and fixed i16 arrays, nested records/empty-record slices, enum fields and custom
formatter declarations. Scalars, dynamic slices and nested dynamic slices run
through the complete retained-state matrix. Additional external consumers cover
private fields, i8/u16/f32 and nested fixed-array/slice dispatch.

Five snapshots retain backing, position, pending/unused views and headers,
descriptor state, input payload/spans, options, actual typed leaf bytes and
file/wire contents through caller backing mutation and flush. Memory,
positional/streaming files, replaced pipes and closed descriptors are covered.
Scalar leaf bytes are observed in declaration order, excluding struct padding
and slice descriptors. Shape names specify construction; they do not prove
nested descriptor layout or every copied value. An independent Python model
predicts recursive output, separate writes and retained writer state.

Debug/ordinary and ReleaseSafe/production each compare 12,156 returning records,
360 isolated returning controls and 72 exact panic/state pairs. The main corpus
contains 3,867 independently predicted WriteFailed states; 270 isolated controls
also fail to write. Traps are forbidden enum options reached through record
fields. Earlier write failure or depth cutoff can prevent those traps. Each
trap requires one exact diagnostic, empty stdout and matching retained state,
including production. Four groups cover field order/aliases/depth/extrema,
write order and recursive failures, propagated leaf options and every capacity
through 192 bytes. Both modes retain these goldens:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 12,156 | `50f15d994fc60909d2a6f96193837cb32f2a624cfb826125670ef2553e6bcc8d` |
| Isolated returning controls | 360 | `f750932bae1c4a598e6a86e9dde596e2535969be6ca4044c98b3bc8583bcb2dc` |
| Panic/state controls | 72 | `6ac47dc869241aefa36efa86436e8960200c7e4cd60709093b6a416a218403e9` |

Thirty external compiler pairs per mode cover six accepted consumers, three
paired ordinary argument rejections and measured boundaries. Source requires
compile-time formats; V accepts runtime strings. Unsupported/ambiguous formats
are Source static rejections versus V errors before writer effects. String
fields and direct error/interface values remain outside translated value
dispatch. V also fails C generation for an inline alias cast of a record literal
containing a fixed-array literal; named local values work. The matrix and
portable consumers use named locals for construction.

V 0.5.2 checks an unused IError specialization for reflected generic field calls.
A private field-dispatch helper excludes that specialization while the public
dispatcher retains static rejection of unsupported interface values. Actual
IError fields are outside this proof and return a field-carrier error when
reached; other unsupported carriers retain their existing dispatch boundaries.
The record helper also guards unused compiler-generated specializations.
Tuples, comptime fields/defaults, arbitrary field spelling/attributes,
self-referential records, custom formatter invocation and broader coercions or
ABI/layout remain unproven. Further dispatch and full Writer.print remain
unported. Other formatter bodies, IO and C are unchanged.

All 114 image test files and 21 production/application/Windows/Linux commands
pass. The portable fixture runs natively in both modes and compiles for Windows
in both modes and Linux. Cross builds establish compilation only. Historical
primitive, recursive slice, fixed-array and enum comparisons retain their
previous hashes in both modes. Vaxis source is unchanged and dependencies build;
its runtime tests are not rerun. Ryu tables retain all 1,336 limbs.

Whole Source and selected compiler libraries, Io/fmt/math/meta/enums/base64 /
float/path/encoder pins, versions, implementation, shared models/helpers,
fixtures and inputs are checked before and after. Runtime, fixtures and model
bodies freeze before final comparisons; only six EXPECTED assignments change
from the discovery model. Retained evidence is replayed independently, including
compiler outcomes and build modes. Large command output is compressed losslessly
by a separately pinned logging wrapper and verified on replay. Every archive
member is read back before committing. Development evidence stays separate.

Evidence is pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge
successful output/storage, private allocation and lifetimes remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_struct_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Users/alex/.cache/witty-writer-value-struct-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
