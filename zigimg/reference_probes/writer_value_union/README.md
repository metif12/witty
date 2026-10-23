# Tagged union Writer value dispatch

`WriteStream.print_value` accepts V sum types and their aliases. Empty and `any`
formats write `.{ .Tag = payload }`, using the reflected variant type spelling
as the tag. Each prefix segment and the closing delimiter retain Source's write
boundaries. Payloads recurse with one less depth; depth zero writes `.{ ... }`.
The `t` format aligns the tag, ignores precision and does not consume depth.
Unsupported formats return an error before writer effects. An empty format on
a sum type with a `format` method reports ambiguity before the depth cutoff;
`any` and `t` bypass that method.

The native fixture calls the unmodified public Zig 0.15.2 Writer.printValue
body. Named Zig fields correspond to V variant type names in the tested domain.
Payloads include signed and boolean aliases, byte slices, records, concrete
errors and nested sum types with signed/unsigned integer payloads. Sum-type
aliases, scalar/dynamic/nested/record shapes, options, depth, every capacity
through 65 bytes, memory, positional/streaming files, replaced pipes and closed
descriptors are covered. Five snapshots retain backing, position, pending/unused
views and headers, descriptor state, inputs/options, canonical tag/payload bytes
and file/wire contents through caller backing mutation and flush. Canonical
descriptors use explicit lengths and byte order; private layouts are excluded.
An independent Python model predicts individual writes and retained state.

Debug/ordinary and ReleaseSafe/production each compare 16,812 complete returning
records, 424 isolated returning controls and 96 exact panic/state pairs. The main
corpus has 2,509 independently predicted WriteFailed results. Among isolated
returning controls, 373 fail before a later trap and 51 return through traversal
cutoffs. Error payloads forbid precision and width after union prefixes; earlier
write failures or depth cutoffs can suppress those checks. Huge aligned widths
also exercise overflow order. Every trap requires one exact diagnostic, empty
stdout and matching retained state, including production. Both modes retain:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 16,812 | `248f572d0a57d74e47714ec7ba928c7819574081d059ec2203d6a8cfa2101b1a` |
| Isolated returning controls | 424 | `4f1b8fdde859600544c8cf63c34a616eee54a57abaed1df4f45828637c6486b7` |
| Panic/state controls | 96 | `321f74656bf4aca025acc5873e9bb720fca86541f49623454b848da6d35c0245` |

Twenty-two external compiler pairs per mode include nine accepted consumers,
three paired argument rejections, seven unsupported formats, a runtime format,
custom-method ambiguity and an overlapping-alias compiler limit. Accepted
consumers cover aliases, aligned tags, fixed/dynamic arrays, records, nested
unions and optionals. Source requires static formats and compile-time validity;
V accepts runtime strings and reports unsupported/ambiguous formats without
writing. V 0.5.2 generates the wrong active-tag check when a sum type combines
a boolean alias with a nested boolean variant: a valid alias value reaches the
`invalid sum type` panic. An isolated consumer reproduces this in both modes;
the parity corpus uses disjoint nested integer variants.

V tags identify types, whereas Zig tagged unions can have differently named
fields with the same payload type. V's nested sum types also allow flattened
construction and share boxed payload storage on copies. Module qualification,
tag identity, nested construction, copy/mutation behavior, unsupported payload
carriers and private layouts are not generally equivalent. Runtime formats and
depth cannot suppress V's compilation of unsupported payload specializations.
Untagged auto/extern/packed unions, first-class error unions, custom invocation,
broader pointer recursion/coercions, tuples and full Writer.print remain
unported or unproven.

Four public regressions, all 117 image test files and 21 production/application /
Windows/Linux commands pass. Portable consumers run natively in both modes and
compile for Windows in both modes and Linux. Cross builds establish compilation
only. Historical primitive, recursive slice, fixed-array, enum, record, address,
optional and error comparisons retain their previous hashes in both modes.
Vaxis source is unchanged and dependencies build; its runtime tests are not
rerun. Other formatter helpers, IO and C are unchanged; Ryu tables retain all
1,336 limbs.

Whole Source and selected compiler libraries, Io/fmt/math/meta/enums/base64 /
float/path/encoder pins, versions, implementation, models/helpers, fixtures and
inputs are checked before and after. Runtime, fixtures and model bodies freeze
before final comparisons; only six EXPECTED assignments change from discovery.
Retained observations, controls, compiler outcomes, modes and provenance are
replayed independently. Large command output is compressed losslessly by a
separately pinned wrapper. Every archive member is read back before committing;
development evidence stays separate.

Evidence is pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge successful
output/storage, private allocation, nested descriptor layout and lifetimes
remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_union_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Volumes/codex-fullsuite-20261023/witty-writer-value-union-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
