# PNG header, chunk and encoder records

`verify_png_records_reference.py` compares the public record contracts at zigimg
commit `d7b7ab0ba0899643831ef042bd73289510b39906`. The unchanged complete `src`
tree is pinned to
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
Zig 0.15.2 memory/debug sources are pinned separately. No Source bodies or
visibility change. Exact commands, versions, modes, fixtures, inputs, output,
diagnostics and before/after provenance checks are retained in the workdir.

From the repository root, with the package directory containing `src`:

```sh
python3 zigimg/verify_png_records_reference.py "$PNG_SOURCE" "$ZIG" "$V" \
  --workdir /tmp/witty-png-records-debug
python3 zigimg/verify_png_records_reference.py "$PNG_SOURCE" "$ZIG" "$V" \
  --v-prod --workdir /tmp/witty-png-records-safe
```

Workdirs must be absent or empty. The default native target is
`aarch64-macos.14.0`; `--target` selects another host. V 0.5.2 ordinary execution
pairs with Source Debug, and production pairs with ReleaseSafe. Each proof uses
a private Zig global cache.

Both modes compare 10,451 returning records, SHA-256
`9cc70d9461b1b38135ca9ed12406d7016c9278e646074cf91277957908a24e03`:

- Fully initialized HeaderData fields, scalar copying and independent mutation,
  validity, zero/extreme dimensions, named closed color/interlace tags and open
  compression/filter tags.
- Direct Chunk construction with independently supplied IDs and live four-byte
  sentinel storage, copied fields, every name byte position and byte value.
- ChunkHeader copying, mutable fields and native-endian live `name()` borrows.
- EncoderOptions defaults, interlaced mutation and replacing copied filter
  choices across try-all, heuristic and all five specified filters.

Eleven omitted required fields produce ordinary compiler rejections in both
languages: seven HeaderData fields and two fields each in Chunk and ChunkHeader.
The specified filter payload has another paired rejection. Three paired const
controls reject mutation of Chunk/EncoderOptions and calling ChunkHeader.name
through an immutable receiver. Signals, backend failures and compiler crashes
cannot satisfy a rejection. Existing callers now explicitly initialize all
required header fields, including former zero/default values in error fallbacks.

Compiler and representation boundaries are measured separately:

- Eleven corresponding V record aliases lose required-field enforcement, while
  Source aliases still reject omissions. The declarations retain required
  annotations; the runner does not count alias acceptance as equivalence.
- Source Chunk.name has type `*const [4:0]u8`. V uses a dynamic string, so direct
  short names compile in V and fail in Source. Chunk.init has a separate runtime
  length guard established by the header proof. Source ChunkHeader.name returns
  const borrowed bytes; V's byte view permits writes. Both Source-only type
  rejections are checked here.
- Mutating a specified payload through a copied FilterChoice updates only the
  Source copy and both boxed V copies. The 25 observations have 20 divergences,
  Source SHA-256
  `1469df14428bc421bcc4aff834e1f6a6cf634da1a3ab3a82c5b8f8e053ef753b`
  and V SHA-256
  `d7f2fe6c87190cd8191c99c70372a837aba9f1320edd828762c815f08a7c52eb`.
  These observations are excluded from the 10,451 equivalent returning records.
  Whole-choice replacement preserves the demonstrated scalar copy behavior.

The Source filtering and header FilterType declarations are nominally distinct;
the V API uses one PngFilterType. Wrapper/sum-type layout, packed aggregate ABI,
sentinel/lifetime enforcement, allocator ownership, undefined Source storage,
arbitrary unsafe enum values and other targets remain outside this proof.
The pinned encoder bodies remain commented and its legacy writer/compressor
helpers remain unsupported by Zig 0.15.2; this proof adds no replacement encoder.
