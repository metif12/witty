# Borrowed fixed-array pointer formatting

`WriteStream.print_value` now adapts nonoptional pointers to fixed arrays to
borrowed slices, matching the pinned Zig `Writer.printValue` pointer-to-array
route. It preserves the current depth. Byte arrays accept `s`, `x`, `X`, `b64`
and `any`; other tested arrays use recursive `any` formatting. Pointee aliases,
nested arrays, optional elements and record/enum/sum elements compose with the
existing dispatcher. `Writer.print` accepts these pointers in record arguments.

V copies the pointee for `(*pointer)[..]`. Its generic type metadata can also
reuse another specialization's element type. A concrete zero array witness
binds the element generic without reading the input; a temporary public array
header then borrows the original address with the correct element size and
`nofree` flag. `T{}` avoids the invalid array initializer that V emits for
`$zero(T)` under Windows GCC. Unit checks mutate byte/integer views to verify
storage identity and stride, and keep optional/nested arrays beside scalar
specializations. This is a synchronous formatting adaptation; it makes no general
allocation, layout or ownership equivalence claim. The witness can occupy stack
space proportional to the fixed-array type in an ordinary build.

The native fixture calls the unchanged public Source body through the locked
image writer. Seven forms cover three-byte arrays, signed i16 arrays, booleans,
nested byte arrays, optional byte elements, record elements and absent optional
array pointers. Four snapshots retain position, backing/pending/unused bytes,
descriptor/file state and original binary input through caller-buffer/input
mutation and flush. Memory and positional/streaming files, replaced pipes,
closed descriptors, depth cutoffs, alignment, binary fill and precision are
covered. All 256 byte values are exercised. An independent model predicts each
write and retained state.

Each mode matches **6,673 complete records** (including **2,267 WriteFailed
records**), **39 isolated returns** and **27 exact panic/state pairs**. Forbidden
encoding options trap before writes; failed writes can precede arithmetic
traps, and depth cutoffs bypass leaf options. The same checks run with V
production and Zig ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 6,673 | `78323191db2dc085e2aba42352e910d34e0e8864cab66f2c26caba6bd6b9f35f` |
| Isolated return/trap states | 66 | `e65c3df1e5c415ccad8b86419ca18c7f9642d48b754ec5870730198b12fc75a4` |

Twenty external compiler pairs cover byte encodings, pointee aliases, signed
extrema, boolean/optional/nested/record/enum/sum elements, print composition,
absence, invalid formats, explicit addresses, optional construction, empty arrays
and runtime format strings. Source requires static formats; V accepts runtime
strings and reports unsupported formats at runtime.

Present optional pointers to whole fixed arrays remain unsupported. Inline V
construction generates an invalid C array cast; the control requires that exact
C-generation failure, separately from ordinary checker rejection. Named-pointer
construction can copy pointee bytes into the optional payload. The dispatcher
rejects that present carrier before V's invalid generic unwrap, without writes;
absence still produces aligned `null`, including optional pointer aliases. No
private optional layout is read or fabricated. Source supports present optional
array pointers. Explicit array-pointer `*`/`?*` addresses also remain rejected in
V, where Source supports qualified array type prefixes. Zero-length arrays,
whole pointer alias construction, sentinel/qualifier adaptations, arbitrary
nested pointers, invalid pointers, overlapping input/output, concurrency and
huge successful output remain outside the supported claim.

All 127 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical fixed-array,
optional-value, aggregate-pointer and optional-pointer custom comparisons retain
their record/state hashes in both modes. Vaxis runtime tests are not rerun.

The runtime diff is confined to fixed-array pointer dispatch, its borrowed view
and safe optional/address boundaries. Other leaf formatters and IO/C are
unchanged. Source/library (including base64), executable, implementation,
fixture/model/helper and input pins are checked before/after. Expected outputs
and proof bodies freeze before final runs. Independent replay checks records,
failures, compiler outcomes and provenance; every retained archive member is
read back before the commit. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_array_pointer_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-array-pointer-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
